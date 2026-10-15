import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { GLTFLoader } from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/loaders/GLTFLoader.js';
import * as THREE from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/three.module.min.js';
import { createGeometrySelectionOutline, collectSelectionWindowMeshes } from '../../assets/institutions/ifpr-pgua/map/viewer/selection_geometry_outline.js';
import { createInteriorNavigation } from '../../assets/institutions/ifpr-pgua/map/viewer/interior_navigation.js';
import { loadSelectionCache } from '../../assets/institutions/ifpr-pgua/map/viewer/selection_cache.js';
import { readRenderPreferences, saveRenderPreferences } from '../../assets/institutions/ifpr-pgua/map/viewer/render_preferences.js';

const base = new URL('../../assets/institutions/ifpr-pgua/map/', import.meta.url);
const bytes = gunzipSync(readFileSync(new URL('campus_exterior_standard.glb.gz', base)));
const { zones } = JSON.parse(readFileSync(new URL('campus_map.json', base), 'utf8'));
const decode = await loadSelectionCache(bytes, zones);
assert.equal(typeof decode, 'function');
const cache = await decode();
const changed = Buffer.from(bytes); changed[changed.length - 1] ^= 1;
assert.equal(await loadSelectionCache(changed, zones), null, 'Changed GLB cannot reuse a silhouette');
assert.equal(await loadSelectionCache(bytes, []), null, 'Changed floor definitions invalidate the cache');
const loader = new GLTFLoader();
loader.register(() => ({ name: 'OUTLINE_CHECK', loadTexture: () => Promise.resolve(null) }));
const { scene: model } = await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '');
const find = (root, name) => {
  let result = root.getObjectByName(name);
  root.traverse(node => { if (!result && node.userData?.name === name) result = node; });
  return result;
};
const campus = new THREE.Scene(); campus.add(model);
const interiors = createInteriorNavigation(model, zones, find, campus);
const windows = collectSelectionWindowMeshes(model),exteriorNodes=new Set(zones.map(zone=>find(model,zone.nodeName)));
const original = createGeometrySelectionOutline(null, { windowNodesFor: node => exteriorNodes.has(node)?windows:[] });
const baked = createGeometrySelectionOutline(null, { preparedFor: node => cache[node.name],
  windowNodesFor: () => { throw new Error('Baked outlines must not recalculate edges'); } });
for (const node of [...zones.map(zone => find(model, zone.nodeName)), ...[...interiors.floors.values()].map(floor => floor.group)]) {
  const expected = original.prepare(node), actual = baked.prepare(node);
  assert.equal(actual.count, expected.count, node.name);
  for (const key of ['edgeStart', 'edgeEnd']) assert.deepEqual(actual.geometry.getAttribute(key).array, expected.geometry.getAttribute(key).array);
  assert.deepEqual(actual.maskGeometry.getAttribute('position').array, expected.maskGeometry.getAttribute('position').array);
  assert.deepEqual([...actual.maskGeometry.index.array], [...expected.maskGeometry.index.array]);
  assert.deepEqual(actual.sphere, expected.sphere);
}
original.dispose(); baked.dispose(); interiors.dispose();
// Shared meshes must be recognized by material, not a building-name suffix.
// Their distant triangles must never enlarge this block's stencil or sphere.
const block = new THREE.Mesh(new THREE.BoxGeometry(4,4,2),new THREE.MeshBasicMaterial());
const shared = new THREE.Group(),windowMaterial = new THREE.MeshBasicMaterial();windowMaterial.name='WhereIF_Windows';
const windowGeometry = new THREE.PlaneGeometry(1,1);
for(const x of [0,100]) {const pane=new THREE.Mesh(windowGeometry,windowMaterial);pane.name='shared_part';pane.position.set(x,0,1);shared.add(pane);}
shared.updateMatrixWorld(true);
const collected=collectSelectionWindowMeshes(shared);assert.equal(collected.length,2);
const clipped=createGeometrySelectionOutline(null,{windowNodesFor:()=>collected});
const entry=clipped.prepare(block),points=entry.maskGeometry.getAttribute('position');
assert.ok(entry.windowRows>0,'Shared window material contributes its local aperture mask');
assert.ok(entry.sphere.radius<6,'Distant windows never expand the selected block sphere (including the two-unit culling margin)');
for(let i=0;i<points.count;i++)assert.ok(Math.abs(points.getX(i))<4,'Only local window triangles are copied to the selected block');
const windowOnly=createGeometrySelectionOutline(null);assert.equal(windowOnly.prepare(collected[0]).count,0,'Window-only objects never supply visible edge ribbons');
windowOnly.dispose();clipped.dispose();block.geometry.dispose();block.material.dispose();windowGeometry.dispose();windowMaterial.dispose();
const storage = new Map();
globalThis.localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value) };
const settings = { features: { lighting: false }, quality: { sharpness: 75, antialias: 'off' }, interfaceBlurEnabled: false };
saveRenderPreferences(settings); assert.deepEqual(readRenderPreferences(), settings);
storage.set('whereif.map.renderSettings.v1', 'invalid'); assert.deepEqual(readRenderPreferences(), {});
globalThis.localStorage = { getItem: () => { throw Error('denied'); }, setItem: () => { throw Error('denied'); } };
assert.deepEqual(readRenderPreferences(), {}); saveRenderPreferences(settings);
delete globalThis.localStorage;
console.log('PASS: identical building/floor outlines, shared-window clipping/exclusion, model/layout invalidation, render preference recovery');
