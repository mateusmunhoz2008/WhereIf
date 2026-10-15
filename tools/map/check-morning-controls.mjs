// Compare actual WebView screenshots at opposite control values.
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';
const port = Number(process.argv[2] ?? 9234);
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html'));
assert(page, 'Map must be open');
const url = new URL(page.webSocketDebuggerUrl);
url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
await new Promise(resolve => socket.addEventListener('open', resolve, { once: true }));
let id = 0;
const pending = new Map();
socket.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data);
  pending.get(message.id)?.(message);
});
async function call(method, params = {}) {
  const current = ++id;
  const timeout = setTimeout(() => { socket.close(); throw Error('WebView timeout'); }, 15000);
  try {
    const response = new Promise(resolve => pending.set(current, resolve));
    socket.send(JSON.stringify({ id: current, method, params }));
    const result = await response;
    assert(!result.error, JSON.stringify(result.error));
    assert(!result.result?.exceptionDetails, JSON.stringify(result.result?.exceptionDetails));
    return result.result;
  } finally { clearTimeout(timeout); pending.delete(current); }
}
const evaluate = expression => call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
const original = (await evaluate('window.whereIfMap.visualTestSettings()')).result.value;
const originalCamera = (await evaluate('window.whereIfMap.debugSnapshot()')).result.value;
async function capture(settings) {
  const result = await evaluate(`new Promise(resolve=>{
    ${process.argv.includes('--selection') ? `window.whereIfMap.setPreviewCamera(${JSON.stringify({position: originalCamera.cameraPosition, target: originalCamera.cameraTarget, constrain:false})});` : ''}
    window.whereIfMap.configureMorningLook(${JSON.stringify(settings)});
    requestAnimationFrame(()=>resolve(document.querySelector('canvas').toDataURL('image/png')));
  })`);
  const png = Buffer.from(result.result.value.split(',')[1], 'base64');
  const chunks = [];
  for (let offset = 8; offset < png.length;) {
    const length = png.readUInt32BE(offset);
    if (png.toString('ascii', offset + 4, offset + 8) === 'IDAT')
      chunks.push(png.subarray(offset + 8, offset + 8 + length));
    offset += length + 12;
  }
  const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
  const bpp = png[25] === 6 ? 4 : 3;
  assert(png[24] === 8 && [2, 6].includes(png[25]), 'Unsupported screenshot format');
  const raw = inflateSync(Buffer.concat(chunks)), stride = width * bpp;
  const pixels = Buffer.alloc(stride * height);
  const paeth = (a, b, c) => {
    const p = a + b - c, pa = Math.abs(p-a), pb = Math.abs(p-b), pc = Math.abs(p-c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const i = y * stride + x, a = x >= bpp ? pixels[i-bpp] : 0;
      const b = y ? pixels[i-stride] : 0, c = y && x >= bpp ? pixels[i-stride-bpp] : 0;
      pixels[i] = raw[y*(stride+1)+1+x] +
        (filter === 1 ? a : filter === 2 ? b : filter === 3 ? Math.floor((a+b)/2) : filter === 4 ? paeth(a,b,c) : 0);
    }
  }
  return pixels;
}
function difference(a, b) {
  assert(a.length === b.length, 'Screen dimensions changed');
  let total = 0;
  for (let i = 0; i < a.length; i++) total += Math.abs(a[i]-b[i]);
  return total / a.length;
}
try {
  if (process.argv.includes('--selection')) {
    await evaluate(`window.whereIfMap.selectZone('');window.whereIfMap.selectZone('bloco-central');new Promise(r=>setTimeout(r,1800))`);
    const selected = await capture({});
    const selectedState = (await evaluate('window.whereIfMap.debugSnapshot()')).result.value;
    await evaluate(`window.whereIfMap.selectZone('bloco-central');new Promise(r=>setTimeout(r,700))`);
    const unselected = await capture({});
    const unselectedState = (await evaluate('window.whereIfMap.debugSnapshot()')).result.value;
    console.log(JSON.stringify({ selectedCamera: selectedState.cameraPosition, unselectedCamera: unselectedState.cameraPosition,
      selectedMaterials: selectedState.materials.slice(0, 3), unselectedMaterials: unselectedState.materials.slice(0,3) }));
    const brightness = data => data.reduce((sum, v, i) => sum + (i % 4 === 3 ? 0 : v), 0);
    const ratio = brightness(selected) / brightness(unselected);
    assert(ratio > 0.95 && ratio < 1.1, `Selection changed surface brightness: ${ratio}`);
    console.log(`Selected/unselected brightness ratio: ${ratio.toFixed(4)}`);
  } else {
  await evaluate('window.whereIfMap.setPreviewTimeMinutes(480)');
  await evaluate('new Promise(r=>setTimeout(r,1200))');
  const noise = difference(await capture({}), await capture({}));
  console.log(`Baseline image variation: ${noise.toFixed(3)}`);
  for (const [key, low, high] of [['saturation', 0, 1.6], ['contrast', 0.8, 1.4],
    ['floorRoughness', 0.07, 1], ['reflections', 0, 16], ['sunHighlights', 0.15, 6]]) {
    const before = await capture({ [key]: low });
    const after = await capture({ [key]: high });
    const change = difference(before, after);
    assert(change > Math.max(0.1, noise * 3), `${key}: change ${change.toFixed(3)} is not above baseline ${noise.toFixed(3)}`);
    console.log(`${key}: rendered image change ${change.toFixed(3)}`);
    await capture({ [key]: original[key] });
  }
  }
} finally {
  await evaluate(`window.whereIfMap.configureMorningLook(${JSON.stringify(original)});window.whereIfMap.setPreviewTimeMinutes(${original.minutes})`);
  if (process.argv.includes('--selection')) await evaluate(`window.whereIfMap.setPreviewCamera(${JSON.stringify({ position: originalCamera.cameraPosition, target: originalCamera.cameraTarget })})`);
  socket.close();
}
