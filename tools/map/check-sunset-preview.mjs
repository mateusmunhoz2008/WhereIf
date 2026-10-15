import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
async function checkSunset() {
  const api = window.whereIfMap;
  const original = api.debugSnapshot();
  const checks = [];
  const check = (condition, label) => {
    if (!condition) throw new Error(label);
    checks.push(label);
  };
  try {
    api.setPreviewTimeMinutes(1080);
    const settings = api.visualTestSettings();
    for (const [key, value] of Object.entries(window.WHEREIF_MAP_TUNING.renderer.approvedSunsetLook)) {
      check(settings[key] === value, `Saved sunset ${key} preserved`);
    }
    const before = api.debugSnapshot();
    const originalSky = api.skySettings();
    try {
      api.configureSky({ cloudCount: 12, brightness: 0.8, patchStrength: 0.5, glowStrength: 0.4 });
      const edited = api.debugSnapshot();
      check(edited.sunsetSky.cloudCount === 12, 'Sky cloud count control changes the generated sky');
      check(edited.sunsetSky.textureId !== before.sunsetSky.textureId, 'Sky edits replace the sky texture');
      check(api.skySettings().brightness === 0.8 && api.skySettings().glowStrength === 0.4,
        'Sky brightness and glow controls are accepted');
      check(JSON.stringify(edited.materials) === JSON.stringify(before.materials) &&
        JSON.stringify(edited.keyLight) === JSON.stringify(before.keyLight),
        'Sky controls do not change campus materials or lighting');
    } finally {
      api.configureSky(originalSky);
    }
    const restored = api.debugSnapshot();
    check(before.sunsetSky.visible && !before.middaySky.visible && !before.nightSky.visible,
      'Only the sunset sky is visible at 18h');
    check(before.sunsetSky.cloudCount === window.WHEREIF_MAP_TUNING.renderer.sunsetSky.cloudCount, 'Sunset clouds cover the full panorama');
    api.rotateCameraBy(80);
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const after = api.debugSnapshot();
    check(JSON.stringify(before.sunsetSky.cloudProjections) !== JSON.stringify(after.sunsetSky.cloudProjections),
      'Sunset clouds move with camera rotation');
    check(restored.sunsetSky.textureId === after.sunsetSky.textureId,
      'Camera gestures do not regenerate the sky');
    check(after.sunsetSky.position.every((value, index) => Math.abs(value - after.cameraPosition[index]) < 0.001),
      'Sunset panorama stays centered on the camera');
    check(after.sunsetSky.rotation[1] === 0, 'Sunset orientation remains fixed in the world');
    api.setPreviewTimeMinutes(720);
    check(!api.debugSnapshot().sunsetSky.visible && api.debugSnapshot().middaySky.visible,
      'Approved noon sky preserved');
    api.setPreviewTimeMinutes(1260);
    check(!api.debugSnapshot().sunsetSky.visible && api.debugSnapshot().nightSky.visible,
      'Night sky preserved');
    api.setPreviewTimeMinutes(360);
    check(!api.debugSnapshot().sunsetSky.visible && api.debugSnapshot().morningSky.visible,
      'Dawn has its own sky, not the sunset sky');
    const dawn = api.skySettings();
    check(dawn.morning && dawn.supported, 'Sky panel supports dawn');
    const dawnBefore = api.debugSnapshot();
    const dawnPixels = api.skyPixelSamples();
    try {
      api.configureSky({ sunCoreStrength: dawn.sunCoreStrength > 0 ? 0 : 4 });
      const changedPixels = api.skyPixelSamples();
      check(JSON.stringify(changedPixels.solar) !== JSON.stringify(dawnPixels.solar),
        'Sun strength changes actual sky pixels, not just a setting');
      check(JSON.stringify(changedPixels.solarLower) !== JSON.stringify(dawnPixels.solarLower),
        'Solar effect reaches the lower panorama visible from the map');
      check(JSON.stringify(changedPixels.opposite) === JSON.stringify(dawnPixels.opposite),
        'Opposite sky pixels remain exactly unchanged');
    } finally { api.configureSky(dawn); }
    try {
      api.configureSky({ cloudCount: 30, brightness: 0.7, sunCoreStrength: 2 });
      check(api.skySettings().sunCoreStrength === 2, 'Localized sun strength control works');
      check(api.debugSnapshot().morningSky.cloudCount === 30, 'Dawn cloud control works');
      check(JSON.stringify(api.debugSnapshot().keyLight) === JSON.stringify(dawnBefore.keyLight),
        'Dawn sky controls leave map lighting unchanged');
    } finally { api.configureSky(dawn); }
    api.setPreviewTimeMinutes(1080);
    check(api.skySettings().seed === originalSky.seed &&
      api.skySettings().cloudCount === originalSky.cloudCount &&
      api.skySettings().zenithColor === originalSky.zenithColor,
      'Editing dawn preserves the approved sunset sky');
    return checks;
  } finally {
    api.setPreviewTimeMinutes(original.effectiveLocalTimeMinutes);
    api.setPreviewCamera({ position: original.cameraPosition, target: original.cameraTarget });
  }
}
const result = execFileSync(process.execPath, [evaluator, process.argv[2] ?? '9234', `(${checkSunset.toString()})()`], { encoding: 'utf8' });
for (const check of JSON.parse(result)) console.log(`PASS: ${check}`);
