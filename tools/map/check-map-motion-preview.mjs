import assert from 'node:assert/strict';

const port = process.argv[2] ?? 9234;
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html') && JSON.parse(p.description || '{}').attached);
assert.ok(page, 'Map must be open');
const url = new URL(page.webSocketDebuggerUrl);
url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
let sequence = 0;
const pending = new Map();
socket.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data);
  if (pending.has(message.id)) {
    pending.get(message.id)(message);
    pending.delete(message.id);
  }
});
async function call(method, params) {
  const id = ++sequence;
  const response = new Promise(resolve => pending.set(id, resolve));
  socket.send(JSON.stringify({ id, method, params }));
  const message = await response;
  assert.ok(!message.error && !message.result?.exceptionDetails, JSON.stringify(message));
  return message.result;
}
const evaluate = async expression => (await call('Runtime.evaluate', {
  expression, returnByValue: true, awaitPromise: true,
})).result.value;
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const state = () => evaluate(`(()=>{const s=window.whereIfMap.debugSnapshot();return {
  position:s.cameraPosition,target:s.cameraTarget,zoom:s.cameraZoom,
  mode:s.viewMode,transition:s.viewTransition,spring:s.navigationReturning,error:s.navigationError
}})()`);
const touch = (type, points) => call('Input.dispatchTouchEvent', {
  type, touchPoints: points.map(([x,y], id) => ({x,y,id,radiusX:2,radiusY:2,force:1})),
});
const watchdog = setTimeout(() => { console.error('Motion verification timed out'); socket.close(); process.exit(1); }, 55000);
try {
  await evaluate('window.whereIfMap.resetBearing()');
  await pause(1600);
  await evaluate('window.whereIfMap.rotateCameraBy(32)');
  const start = await state();
  await evaluate('window.whereIfMap.setMapViewMode("2d")');
  const beginning = await state();
  assert.ok(beginning.transition, 'Transition starts instead of switching cameras instantly');
  assert.ok(Math.hypot(...beginning.position.map((v,i)=>v-start.position[i])) < 15,
    'Starts from the current 3D camera');
  await pause(300);
  const middle = await state();
  assert.ok(middle.transition && middle.position.every(Number.isFinite), 'Continuous intermediate camera');
  await pause(1800);
  const top = await state();
  assert.equal(top.mode, '2d');
  assert.equal(top.transition, null);
  assert.ok(top.error < 0.001, 'Top view rests within map boundaries');
  const savedView = await evaluate('window.WHEREIF_MAP_TUNING.camera.topView');
  assert.ok(top.target.every((v,i) => Math.abs(v-savedView.initialTarget[i]) < 0.00001),
    'Map boundaries preserve the approved top-view framing');
  console.log('PASS: current 3D camera animates to 2D and rests inside the map');

  const settings = await evaluate('window.WHEREIF_MAP_TUNING.camera.topView');
  const upper = settings.zoom * 1.20, lower = settings.zoom / 1.18;
  for (const delta of [-50000, 50000]) {
    await evaluate(`document.querySelector('canvas').dispatchEvent(new WheelEvent('wheel', {
      deltaY:${delta},clientX:172,clientY:370,bubbles:true,cancelable:true}))`);
    const stretch = await state();
    assert.ok(stretch.spring, 'Zoom release starts a visible spring');
    assert.ok(delta < 0 ? stretch.zoom > upper : stretch.zoom < lower, 'Zoom visibly stretches beyond the resting limit');
    await pause(180);
    const returning = await state();
    assert.ok(Math.abs(returning.zoom - stretch.zoom) > 0.01, 'Spring animates over time');
    await pause(900);
    const settled = await state();
    assert.ok(Math.abs(settled.zoom - (delta < 0 ? upper : lower)) < 0.00001, 'Zoom settles exactly at its allowed limit');
    assert.ok(!settled.spring);
  }
  console.log('PASS: both zoom limits visibly stretch and spring back to the saved range');

  for (const [x,y] of [[1800,370],[-1500,370],[172,2300],[172,-1700]]) {
    await touch('touchStart', [[172,370]]);
    await touch('touchMove', [[x,y]]);
    await pause(160);
    const stretch = await state();
    assert.ok(stretch.error > 0.01, 'Drag can stretch slightly beyond the boundary');
    await touch('touchEnd', []);
    await pause(100);
    assert.ok((await state()).spring, 'Boundary release animates back');
    await pause(1100);
    const settled = await state();
    assert.ok(settled.error < 0.001 && !settled.spring, 'Drag settles within map boundaries');
  }
  console.log('PASS: real touch drags in four directions stretch and return inside map boundaries');
  await evaluate('window.whereIfMap.resetBearing()');
  await pause(1700);
  assert.equal((await state()).mode, '3d');
  console.log('PASS: 0° returns to 3D smoothly');
} finally {
  await touch('touchEnd', []).catch(() => {});
  await evaluate('window.whereIfMap.setMapViewMode("2d")').catch(() => {});
  clearTimeout(watchdog);
  socket.close();
}
