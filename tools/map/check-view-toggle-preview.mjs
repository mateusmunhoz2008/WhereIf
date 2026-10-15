import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

async function checkViewToggle() {
  const api = window.whereIfMap;
  const checks = [];
  const check = (ok, name) => {
    if (!ok) throw new Error(name);
    checks.push(name);
  };
  const pause = async () => {
    await new Promise(resolve => setTimeout(resolve, 400));
    for (let i = 0; i < 60; i++) {
      await new Promise(resolve => setTimeout(resolve, 50));
      const state = api.debugSnapshot();
      if (!state.viewTransition && !state.navigationReturning) return;
    }
    throw new Error('Camera did not settle');
  };
  api.resetBearing();
  await pause();
  const zero = api.debugSnapshot();
  const sameCamera = snapshot => ['cameraPosition', 'cameraTarget'].every(key =>
    snapshot[key].every((value, index) => Math.abs(value - zero[key][index]) < 0.00001));
  try {
    for (let cycle = 0; cycle < 2; cycle++) {
      check(api.setMapViewMode('2d'), '2D mode accepted');
      await pause();
      const top = api.debugSnapshot();
      check(top.viewMode === '2d' && top.cameraProjection === 'orthographic', 'Real orthographic top view');
      const offset = top.cameraPosition.map((value, index) => value - top.cameraTarget[index]);
      check(offset[1] > 0 && Math.hypot(offset[0], offset[2]) / offset[1] < 0.0002,
        'Camera looks straight down');
      const saved = window.WHEREIF_MAP_TUNING.camera.topView;
      check(Math.abs(top.cameraZoom - saved.zoom) < 0.000001, 'Each top-view entry restores the captured zoom');
      check(top.cameraPosition.every((v, i) => Math.abs(v - saved.initialPosition[i]) < 0.00001) &&
        top.cameraTarget.every((v, i) => Math.abs(v - saved.initialTarget[i]) < 0.00001),
        'Captured top-view position and orientation restored');
      check(Math.abs(top.zoomLimits[0] - saved.zoom / 1.18) < 0.000001 &&
        Math.abs(top.zoomLimits[1] - saved.zoom * 1.20) < 0.000001,
        'Zoom limits stay within 20% closer and 18% farther from the saved view');
      api.rotateCameraBy(35);
      await pause();
      check(api.debugSnapshot().viewMode === '2d', 'Bearing changes keep the top view');
      if (cycle === 0) api.setMapViewMode('3d');
      else api.resetBearing();
      await pause();
      const normal = api.debugSnapshot();
      check(normal.viewMode === '3d' && normal.cameraProjection === 'perspective', 'Normal perspective restored');
      check(sameCamera(normal), cycle === 0 ? '3D toggle restores exact zero camera' : 'Zero button exits 2D and restores exact zero camera');
    }
    api.setMapViewMode('2d');
    await pause();
    check(api.focusZone('quadra', { immediate: true }), 'Court focus remains available');
    const court = api.debugSnapshot();
    check(court.viewMode === '3d' && court.cameraProjection === 'perspective', 'Building focus exits the top view');
    check(Math.abs(court.cameraTarget[1] - 4.583362102508552) < 0.00001, 'Saved court target preserved');
    return checks;
  } finally {
    api.resetBearing();
  }
}
const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
console.log(execFileSync(process.execPath,
  [evaluator, process.argv[2] ?? '9234', `(${checkViewToggle.toString()})()`],
  { encoding: 'utf8', timeout: 25000 }).trim());
