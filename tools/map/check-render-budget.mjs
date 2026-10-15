import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { normalizedMapQuality } from '../../assets/institutions/ifpr-pgua/map/viewer/map_antialias.js';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const policy = source.slice(source.indexOf('const renderBudget ='), source.indexOf('function applyBasicGraphicsTuning'));
for (const memory of [undefined, 2, 4, 8]) {
 for (const cores of [undefined, 2, 4, 8]) {
  for (const sharpness of [65, 70, 100, 125]) {
  for (const [width, height, dpr] of [[360, 800, 3], [800, 360, 3], [1024, 1600, 2], [390, 844, 1]]) {
    const context = vm.createContext({ normalizedMapQuality, initialRenderPreferences: {quality:{sharpness,antialias:'off'}}, rendererTuning: {},
      THREE: { MathUtils: { clamp: (value, min, max) => Math.max(min, Math.min(max, value)) } },
      navigator: { deviceMemory: memory, hardwareConcurrency: cores },
      window: { devicePixelRatio: dpr }, document: { documentElement: { clientWidth: width, clientHeight: height } } });
    vm.runInContext(policy, context);
    const result = vm.runInContext('({ratio: budgetPixelRatio(), budget: renderBudget})', context);
    assert.equal(result.ratio, 3 * sharpness / 100,
      'Selected sharpness is identical on every device, orientation and RAM/CPU report');
    assert.equal(result.budget.pixels, Infinity, 'No hardware-specific pixel cap');
    assert.equal(result.budget.shadowSize, 2048, 'Identical shadow quality on all devices');
    assert.equal(vm.runInContext('budgetPixelRatio()', context), result.ratio,
      'Slow frames cannot silently degrade a stable image');
  }
  }
 }
}
const timeSetter = source.match(/^function setLocalTimeMinutes\([^]*?^}/m)[0];
const context = vm.createContext({ config: { localTimeMinutes: 720 }, model: {}, changes: 0,
  presetTimeMinutes() { return context.config.localTimeMinutes < 990 ? 720 : 1080; },
  applyDaylightProfile() { context.changes++; }, requestRender() {} });
vm.runInContext(timeSetter, context);
context.setLocalTimeMinutes(721);
assert.equal(context.changes, 0, 'Clock ticks do not rebuild an unchanged preset');
context.setLocalTimeMinutes(990);
assert.equal(context.changes, 1, 'Crossing a period still applies the new preset');
assert.match(source, /await prepareGpuGeometry\(model\)/,
  'Geometry prewarming prevents first-interaction upload stalls');
console.log('PASS: uniform manual quality on all hardware, geometry prewarming and clock updates');
