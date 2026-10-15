import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

async function checkZoomGestures() {
  const api = window.whereIfMap;
  const baseline = window.WHEREIF_MAP_TUNING.camera.topView.zoom;
  const checks = [];
  const check = (ok, label) => { if (!ok) throw new Error(label); checks.push(label); };
  try {
    api.setMapViewMode('2d');
    await new Promise(resolve => setTimeout(resolve, 1800));
    const canvas = document.querySelector('canvas');
    const wheel = deltaY => canvas.dispatchEvent(new WheelEvent('wheel', {
      deltaY, clientX: canvas.clientWidth / 2, clientY: canvas.clientHeight / 2,
      bubbles: true, cancelable: true,
    }));
    for (let i = 0; i < 3; i++) wheel(-50000);
    check(api.debugSnapshot().cameraZoom > baseline * 1.20,
      'Zoom-in gesture visibly stretches beyond the resting limit');
    await new Promise(resolve => setTimeout(resolve, 900));
    let zoom = api.debugSnapshot().cameraZoom;
    check(Math.abs(zoom - baseline * 1.20) < 0.000001,
      'Real zoom gesture stops at 20% above the default magnification');
    wheel(-50000);
    await new Promise(resolve => setTimeout(resolve, 900));
    check(Math.abs(api.debugSnapshot().cameraZoom - zoom) < 0.000001,
      'Additional zoom-in gestures return to the same resting limit');
    for (let i = 0; i < 3; i++) wheel(50000);
    check(api.debugSnapshot().cameraZoom < baseline / 1.18,
      'Zoom-out gesture visibly stretches beyond the resting limit');
    await new Promise(resolve => setTimeout(resolve, 900));
    zoom = api.debugSnapshot().cameraZoom;
    check(Math.abs(zoom - baseline / 1.18) < 0.000001,
      'Real zoom-out gesture stops at 18% more visible width/height than the default');
    wheel(50000);
    await new Promise(resolve => setTimeout(resolve, 900));
    check(Math.abs(api.debugSnapshot().cameraZoom - zoom) < 0.000001,
      'Additional zoom-out gestures return to the same resting limit');
    check(api.debugSnapshot().viewMode === '2d', 'Gestures keep the 2D view');
    return checks;
  } finally {
    api.setMapViewMode('2d');
  }
}
const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
console.log(execFileSync(process.execPath,
  [evaluator, process.argv[2] ?? '9234', `(${checkZoomGestures.toString()})()`],
  { encoding: 'utf8', timeout: 25000 }).trim());
