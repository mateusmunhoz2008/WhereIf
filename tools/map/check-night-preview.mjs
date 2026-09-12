// Validate the actual Android WebView after forwarding its devtools socket.
// Usage: node tools/map/check-night-preview.mjs [port] [--inspect]
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const port = Number(process.argv[2] || 9223);
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find((item) => item.url.includes('/map/viewer/index.html'));
assert(page, 'Campus map WebView not found');
const socketUrl = new URL(page.webSocketDebuggerUrl);
socketUrl.host = `127.0.0.1:${port}`;
const socket = new WebSocket(socketUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let id = 0;
const pending = new Map();
socket.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data);
  if (pending.has(message.id)) {
    pending.get(message.id)(message);
    pending.delete(message.id);
  }
});
async function evaluate(expression) {
  const requestId = ++id;
  const response = new Promise((resolve) => pending.set(requestId, resolve));
  socket.send(JSON.stringify({ id: requestId, method: 'Runtime.evaluate', params: {
    expression, returnByValue: true, awaitPromise: true,
  } }));
  const timeout = setTimeout(() => { socket.close(); throw new Error('WebView check timed out'); }, 45000);
  try {
    const result = await response;
    assert(!result.error, JSON.stringify(result.error));
    assert(!result.result.exceptionDetails, JSON.stringify(result.result.exceptionDetails));
    return result.result.result.value;
  } finally { clearTimeout(timeout); }
}

async function checkInViewer() {
  const api = window.whereIfMap;
  const original = api.visualTestSettings();
  const originalTime = api.debugSnapshot().previewLocalTimeMinutes;
  const frame = () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const checks = [];
  const check = (ok, label) => { if (!ok) throw new Error(label); checks.push(label); };
  const snapshot = () => api.debugSnapshot();
  try {
    api.setPreviewTimeMinutes(0);
    const baseline = snapshot();
    check(baseline.materials.length > 0, 'Model materials loaded');
    check(baseline.nightSky.visible, 'Stars visible at midnight');
    api.configureNightLook({ exposure: 0.3 });
    const low = snapshot();
    api.configureNightLook({ exposure: 1.1 });
    const high = snapshot();
    check(high.exposure > low.exposure, 'Exposure control changes the scene');
    check(JSON.stringify(high.materials) === JSON.stringify(low.materials), 'Exposure does not disable night reflections');
    api.configureNightLook({ wetness: 0 });
    const dry = snapshot().materials;
    api.configureNightLook({ wetness: 1 });
    const wet = snapshot().materials;
    check(wet.some((material, index) => material.roughness < dry[index].roughness), 'Wet pavement changes material response');
    check(wet.filter((m) => /grass/i.test(m.name)).every((m) => m.roughness >= 0.9), 'Grass remains matte');
    const textured = snapshot().materials;
    check(textured.some((m) => m.proceduralTexture), 'Standard GLB receives procedural surface detail');
    api.configureNightLook({ textures: false });
    check(snapshot().materials.every((m) => !m.hasColorTexture && !m.hasNormalTexture), 'Textures can be disabled');
    check(!snapshot().nightCinema.textures, 'Procedural textures switch off');
    api.configureNightLook({ textures: true });
    check(JSON.stringify(snapshot().materials) === JSON.stringify(textured), 'Textures restore without losing materials');
    check(snapshot().nightCinema.textures, 'Procedural textures switch on');
    check(snapshot().nightCinema.windowProjections > 0, 'Window light projections attached to real facades');
    check(snapshot().nightCinema.moonShafts > 0, 'Moon shafts reach unobstructed ground');
    api.configureNightLook({ reflections: 0 });
    check(snapshot().materials.filter((m) => /concrete|pavement|asphalt/i.test(m.name))
      .every((m) => m.envMapIntensity === 0), 'Reflection control switches floor and building reflections off');
    api.configureNightLook({ reflections: 3, wetness: 0, floorReflection: 0.7 });
    check(snapshot().materials.filter((m) => /pavement|asphalt/i.test(m.name))
      .every((m) => m.envMapIntensity > 1), 'Dry floor has independently adjustable reflections');
    api.configureNightLook({ floorRoughness: 0.15 });
    const polished = snapshot().materials.find((m) => /pavement/i.test(m.name));
    api.configureNightLook({ floorRoughness: 0.75 });
    const matte = snapshot().materials.find((m) => /pavement/i.test(m.name));
    check(matte.roughness > polished.roughness, 'Floor roughness control responds');
    api.configureNightLook({ grassBrightness: 0.3 });
    const litGrass = snapshot().materials.find((m) => /grass/i.test(m.name));
    api.configureNightLook({ grassBrightness: 0.045 });
    const darkGrass = snapshot().materials.find((m) => /grass/i.test(m.name));
    check(litGrass.color !== darkGrass.color, 'Grass darkness is independently adjustable');
    api.setPreviewTimeMinutes(720);
    const day = snapshot();
    api.configureNightLook({ exposure: 0.8, moonlight: 5, reflections: 2.5, wetness: 0.1 });
    const dayAfter = snapshot();
    check(!dayAfter.nightSky.visible, 'Stars hidden during the day');
    check(day.exposure === dayAfter.exposure && JSON.stringify(day.materials) === JSON.stringify(dayAfter.materials), 'Night controls preserve daytime appearance');
    api.setPreviewTimeMinutes(0);
    api.configureBloom({ enabled: true });
    await frame();
    check(snapshot().bloom?.enabled === true, 'Optional light halo initializes at runtime');
    api.configureBloom({ enabled: false });
    await frame();
    check(snapshot().bloom?.enabled === false, 'Light halo switches off again');
    api.resetNightLook();
    check(api.visualTestSettings().textures === true, 'Night reset restores textures');
    return { passed: checks.length, checks };
  } finally {
    api.configureNightLook(original);
    api.setToneMapping(original.toneMapping);
    api.configureBloom({ enabled: original.bloom, strength: original.bloomStrength });
    if (originalTime == null) api.clearPreviewTime();
    else api.setPreviewTimeMinutes(originalTime);
  }
}

try {
  const restoreIndex = process.argv.indexOf('--restore');
  const saved = restoreIndex >= 0
    ? JSON.parse(await readFile(process.argv[restoreIndex + 1], 'utf8')) : null;
  const expression = saved ? `(() => {
    const saved = ${JSON.stringify(saved)};
    const api = window.whereIfMap;
    api.configureNightLook(saved.settings);
    api.setToneMapping(saved.settings.toneMapping);
    api.configureBloom({enabled:saved.settings.bloom, strength:saved.settings.bloomStrength});
    api.setRestingRenderScale(saved.settings.resting);
    api.setInteractionRenderScale(saved.settings.moving);
    api.setShadowMapSize(saved.settings.shadows);
    api.setPreviewTimeMinutes(saved.settings.minutes);
    api.setPreviewCamera({position:saved.scene.cameraPosition, target:saved.scene.cameraTarget});
    return api.visualTestSettings();
  })()` : process.argv.includes('--inspect')
    ? '({ settings: window.whereIfMap.visualTestSettings(), scene: window.whereIfMap.debugSnapshot() })'
    : `(${checkInViewer.toString()})()`;
  console.log(JSON.stringify(await evaluate(expression), null, 2));
} finally { socket.close(); }
