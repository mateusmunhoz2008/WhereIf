import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import * as THREE from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/three.module.min.js';
import { createInteriorNavigation } from '../../assets/institutions/ifpr-pgua/map/viewer/interior_navigation.js';

// Test the actual exported curved rooms, not a rectangular approximation.
const bytes = gunzipSync(readFileSync('assets/institutions/ifpr-pgua/map/campus_exterior_standard.glb.gz'));
const jsonLength = bytes.readUInt32LE(12);
const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength));
const binaryOffset = 28 + jsonLength;
const metadata = JSON.parse(readFileSync('assets/institutions/ifpr-pgua/map/campus_map.json'));
const zone = metadata.zones.find(zone => zone.id === 'bloco-central');
const interiorZones = metadata.zones.filter(entry => entry.floors?.length);
const names = new Set(interiorZones.flatMap(entry => entry.floors.flatMap(floor =>
  [...floor.nodeNames, ...floor.spaces.map(space => space.nodeName)])));
const root = new THREE.Group();
const scene = new THREE.Scene();
scene.add(root);

function accessor(index) {
  const entry = gltf.accessors[index];
  const view = gltf.bufferViews[entry.bufferView];
  const count = entry.type === 'VEC3' ? 3 : 1;
  const types = { 5126: Float32Array, 5125: Uint32Array, 5123: Uint16Array, 5121: Uint8Array };
  const Type = types[entry.componentType];
  assert.ok(Type);
  assert.ok(!view.byteStride, 'Fixture accessors are packed');
  const offset = binaryOffset + (view.byteOffset ?? 0) + (entry.byteOffset ?? 0);
  const values = bytes.subarray(offset, offset + entry.count * count * Type.BYTES_PER_ELEMENT);
  return new THREE.BufferAttribute(new Type(values.buffer, values.byteOffset, entry.count * count), count);
}

for (const definition of gltf.nodes.filter(node => names.has(node.name))) {
  const node = new THREE.Group();
  node.name = definition.name;
  if (definition.translation) node.position.fromArray(definition.translation);
  if (definition.rotation) node.quaternion.fromArray(definition.rotation);
  if (definition.scale) node.scale.fromArray(definition.scale);
  for (const primitive of gltf.meshes[definition.mesh].primitives) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', accessor(primitive.attributes.POSITION));
    if (primitive.indices !== undefined) geometry.setIndex(accessor(primitive.indices));
    node.add(new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide })));
  }
  root.add(node);
}
const navigation = createInteriorNavigation(root, interiorZones, (root, name) => root.getObjectByName(name), scene);
const floor = navigation.enter('central-p1');
scene.updateMatrixWorld(true);
let tested = 0;
let oldWrongPicks = 0;
for (const space of floor.spaces) {
  let roomSamples = 0;
  space.node.traverse(mesh => {
    if (!mesh.isMesh) return;
    const positions = mesh.geometry.attributes.position;
    const indices = mesh.geometry.index;
    const vertex = index => new THREE.Vector3().fromBufferAttribute(positions,
      indices ? indices.getX(index) : index).applyMatrix4(mesh.matrixWorld);
    for (let index = 0; index < (indices?.count ?? positions.count); index += 3) {
      const vertices = [vertex(index), vertex(index + 1), vertex(index + 2)];
      // Wall clicks also work; here floor triangle centroids give unambiguous
      // expected room identities, including near the curved/shared edges.
      if (vertices.some(point => Math.abs(point.y - space.bounds.min.y) > 0.01)) continue;
      const center = vertices.reduce((sum, point) => sum.add(point), new THREE.Vector3()).multiplyScalar(1 / 3);
      const raycaster = new THREE.Raycaster(center.clone().add(new THREE.Vector3(0, 100, 0)), new THREE.Vector3(0, -1, 0));
      assert.equal(navigation.pick(raycaster)?.nodeName, space.nodeName, `Exact floor shape: ${space.nodeName}, triangle ${index / 3}`);
      const oldHit = raycaster.intersectObjects(floor.spaces.map(space => space.marker), false)[0];
      if (oldHit?.object.userData.interiorSpace.nodeName !== space.nodeName) oldWrongPicks++;
      roomSamples++;
      tested++;
    }
  });
  assert.ok(roomSamples > 0, `${space.nodeName}: tested floor triangles`);
}
assert.ok(oldWrongPicks > 0, 'The fixture reproduces the overlapping-marker bug');
assert.equal(navigation.pick(new THREE.Raycaster(new THREE.Vector3(10000, 100, 10000), new THREE.Vector3(0, -1, 0))), null);
for (const definition of interiorZones.find(entry=>entry.id==='bloco-didatico').floors) {
  const didatico = navigation.enter(definition.id);
  scene.updateMatrixWorld(true);
  for (const space of didatico.spaces) {
    assert.equal(space.marker.visible, false, 'Picking planes never generate transparent GPU draws');
    const center = space.bounds.getCenter(new THREE.Vector3());
    const raycaster = new THREE.Raycaster(center.clone().add(new THREE.Vector3(0,100,0)),
      new THREE.Vector3(0,-1,0));
    assert.equal(navigation.pick(raycaster)?.nodeName, space.nodeName,
      `Hidden CPU hit target still selects ${space.nodeName}`);
  }
}
navigation.dispose();
console.log(`PASS: ${tested} floor samples across all 7 Central spaces; ${oldWrongPicks} formerly incorrect taps now select the exact room.`);
console.log('PASS: every Didatico room remains selectable with invisible, non-rendered hit targets.');
