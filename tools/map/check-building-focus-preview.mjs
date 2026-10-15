import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

async function checkBuildingFocus(zoneId) {
  const api = window.whereIfMap;
  const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
  const snapshot = () => {
    const s = api.debugSnapshot();
    return { position: s.cameraPosition, target: s.cameraTarget,
      projection: s.cameraProjection, transition: s.viewTransition };
  };
  const distance = (a, b) => Math.hypot(...a.map((v, i) => v - b[i]));
  const check = (ok, name) => { if (!ok) throw new Error(`${zoneId}: ${name}`); };
  api.resetBearing();
  await pause(1400);
  check(api.focusZone(zoneId, { immediate: true }), 'Zone exists');
  await pause(300);
  const expected = snapshot();
  api.setMapViewMode('2d');
  await pause(1600);
  api.rotateCameraBy(24);
  await pause(400);
  const start = snapshot();
  check(start.projection === 'orthographic', 'Starts in 2D');
  check(api.focusZone(zoneId), 'Focus accepted');
  const first = snapshot();
  check(first.transition?.mode === '3d', 'Animated projection transition starts');
  check(distance(first.position, start.position) < 0.001 &&
    distance(first.target, start.target) < 0.001, 'No jump from current 2D pose');
  await pause(150);
  const middle = snapshot();
  check(middle.transition && distance(middle.position, start.position) > 0.01,
    'Camera moves during the transition');
  check([...middle.position, ...middle.target].every(Number.isFinite), 'Finite intermediate pose');
  await pause(1600);
  const end = snapshot();
  check(!end.transition && end.projection === 'perspective', 'Ends in normal 3D');
  check(distance(end.position, expected.position) < 0.01 &&
    distance(end.target, expected.target) < 0.01, 'Saved building framing preserved');
  return { zoneId, passed: true };
}

const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
for (const zone of ['bloco-central', 'bloco-didatico', 'bloco-administrativo',
  'bloco-tecnologico', 'quadra', 'portaria']) {
  const result = JSON.parse(execFileSync(process.execPath,
    [evaluator, process.argv[2] ?? '9234', `(${checkBuildingFocus.toString()})(${JSON.stringify(zone)})`],
    { encoding: 'utf8', timeout: 20000 }).trim());
  assert.equal(result.passed, true);
  console.log(`${zone}: continuous 2D-to-3D focus passed`);
}
