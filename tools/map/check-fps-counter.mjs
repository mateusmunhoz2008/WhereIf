import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

let now = 0;
let refresh;
let removed = false;
let cancelled = false;
const badge = { style: {}, remove() { removed = true; } };
const context = vm.createContext({
  document: { hidden: false, createElement: () => badge, body: { appendChild() {} } },
  performance: { now: () => now },
  setInterval(callback, delay) { assert.equal(delay, 250); refresh = callback; return 1; },
  clearInterval(id) { assert.equal(id, 1); cancelled = true; },
});
const source = readFileSync('assets/institutions/ifpr-pgua/map/viewer/fps_counter.js', 'utf8');
vm.runInContext(source.replace('export function', 'function'), context);
const disabled = context.createFpsCounter(false);
disabled.recordFrame(); disabled.setReady(); disabled.dispose();
assert.equal(refresh, undefined, 'Disabled counter creates no timer');
const counter = context.createFpsCounter(true);
assert.equal(badge.style.display, undefined, 'Hidden until model is ready');
counter.setReady();
assert.equal(badge.style.display, 'block');
for (let frame = 0; frame < 23; frame++) counter.recordFrame();
now = 250; refresh();
assert.equal(badge.textContent, '92 FPS');
now = 500; refresh();
assert.equal(badge.textContent, '— FPS · parado', 'Idle is not represented as poor performance');
for (let frame = 0; frame < 15; frame++) counter.recordFrame();
now = 750; refresh();
assert.equal(badge.textContent, '60 FPS');
counter.dispose();
assert.ok(removed && cancelled, 'Counter resources are released');
assert.ok(!source.includes('requestAnimationFrame'), 'Counter does not force continuous rendering');
console.log('PASS: actual render counts, 250 ms refresh, idle indication and cleanup; no extra render loop.');
