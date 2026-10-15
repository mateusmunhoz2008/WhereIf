import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const extract = (name) => {
  const match = source.match(new RegExp(`^function ${name}\\([^]*?^}`, 'm'));
  assert.ok(match, `${name} exists`);
  return match[0];
};

class Color {
  constructor(value) { this.value = value; }
  clone() { return new Color(this.value); }
}
class BasicMaterial {
  constructor(options) { Object.assign(this, options); this.disposed = false; }
  dispose() { this.disposed = true; }
}

const original = { color: new Color('#347a32'), map: { id: 'texture' },
  vertexColors: true, transparent: false, opacity: 1 };
const meshes = [
  { isMesh: true, material: original },
  { isMesh: true, material: [original] },
];
const messages = [];
let profileUpdates = 0;
let renders = 0;
const context = vm.createContext({
  geometryOnly: false,
  basicLightingTest: false,
  THREE: { MeshBasicMaterial: BasicMaterial, Color, FrontSide: 0 },
  model: { traverse: (visit) => meshes.forEach(visit) },
  interiors: null,
  rawMaterialStates: [], rawMaterials: new Set(),
  diagnosticsEnabled: false,
  clearSelection() {}, send: (type) => messages.push(type),
  applyDaylightProfile() { profileUpdates++; },
  requestRender() { renders++; },
});
vm.runInContext(`let rawModeEnabled = false;
${extract('restoreRawMaterials')}
${extract('setRawMode')}`, context);

assert.equal(vm.runInContext('setRawMode(true)', context), true);
assert.ok(meshes[0].material instanceof BasicMaterial);
assert.equal(meshes[0].material, meshes[1].material[0], 'shared source stays shared');
assert.equal(meshes[0].material.map, original.map, 'base texture survives');
assert.equal(meshes[0].material.vertexColors, true, 'tree vertex colors survive');
assert.equal(meshes[0].material.toneMapped, false, 'no color treatment');
const raw = meshes[0].material;
assert.equal(vm.runInContext('setRawMode(true)', context), true, 'toggle is idempotent');
assert.equal(context.rawMaterialStates.length, 2);
assert.equal(vm.runInContext('setRawMode(false)', context), false);
assert.equal(meshes[0].material, original);
assert.equal(meshes[1].material[0], original);
assert.equal(raw.disposed, true);
assert.equal(profileUpdates, 1, 'normal lighting restores once');
assert.equal(renders, 2);
assert.deepEqual(messages, ['selected', 'selected']);

const render = extract('renderSceneWithSelection');
for (const bypass of [
  'scene.fog = null',
  'renderer.shadowMap.enabled = false',
  'renderer.toneMapping = THREE.NoToneMapping',
  'renderer.render(scene, camera)',
]) assert.ok(render.includes(bypass), `raw render bypasses ${bypass}`);
assert.ok(render.indexOf('if (rawModeEnabled)') < render.indexOf('effectComposer.render()'),
  'raw path returns before post-processing');
console.log('PASS: raw materials preserve model colors, bypass effects and restore safely');
