import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const root = new URL('../../assets/institutions/ifpr-pgua/map/viewer/', import.meta.url);
const context = { window: {} };
vm.createContext(context);
vm.runInContext(readFileSync(new URL('viewer_config.js', root), 'utf8'), context);
context.cameraTuning = context.window.WHEREIF_MAP_TUNING.camera;
const source = readFileSync(new URL('viewer.js', root), 'utf8');
vm.runInContext(source.slice(source.indexOf('function topViewZoomLimits()'),
  source.indexOf('function activateMapCamera(')), context);
for (const baseline of [1, 3.0004558811435977, 4]) {
  context.cameraTuning.topView.zoom = baseline;
  const limits = vm.runInContext('topViewZoomLimits()', context);
  assert.ok(Math.abs(limits.max / baseline - 1.20) < 1e-10);
  assert.ok(Math.abs(baseline / limits.min - 1.18) < 1e-10);
  assert.ok(limits.min < baseline && limits.max > baseline);
}
console.log('PASS: 2D limits follow the saved baseline: +20% magnification and +18% visible area dimensions, including when the baseline changes.');
