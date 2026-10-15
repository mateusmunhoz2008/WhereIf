import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

function checkFixedPeriods() {
  const api = window.whereIfMap;
  const original = api.debugSnapshot();
  const result = [];
  const check = (ok, label) => {
    if (!ok) throw new Error(label);
    result.push(label);
  };
  const appearance = () => {
    const snap = api.debugSnapshot();
    return JSON.stringify({
      exposure: snap.exposure, key: snap.keyLight, fill: snap.fillLight,
      grading: snap.grading, shadow: snap.shadow, materials: snap.materials,
      atmosphere: snap.atmosphere, bloom: snap.bloom,
      skies: [snap.morningSky?.visible, snap.middaySky?.visible,
        snap.sunsetSky?.visible, snap.nightSky.visible],
      night: snap.nightSky.amount,
    });
  };
  try {
    for (const [anchor, samples, name] of [
      [360, [330, 331, 450, 659], 'Dawn 05:30–11:00'],
      [720, [660, 661, 850, 989], 'Midday 11:00–16:30'],
      [1080, [990, 991, 1100, 1139], 'Sunset 16:30–19:00'],
      [1260, [1140, 1141, 1439, 0, 300, 329], 'Night 19:00–05:30'],
    ]) {
      api.setPreviewTimeMinutes(anchor);
      // Bloom's camera-facing term is normally refreshed on the next frame.
      // Settle it synchronously so the test also works with the app backgrounded.
      api.setPreviewTimeMinutes(anchor);
      const approved = appearance();
      for (const minute of samples) {
        api.setPreviewTimeMinutes(minute);
        check(appearance() === approved, `${name}: unchanged appearance at minute ${minute}`);
      }
    }
    api.setPreviewTimeMinutes(1080);
    const approvedSunset = window.WHEREIF_MAP_TUNING.renderer.approvedSunsetLook;
    const settings = api.visualTestSettings();
    check(Object.entries(approvedSunset).every(([key, value]) => settings[key] === value),
      'Approved sunset controls preserved');
    check(api.skySettings().cloudCount === 126, 'Approved sunset sky preserved');
    api.setPreviewTimeMinutes(360);
    check(api.skySettings().sunCoreStrength === 0, 'Saved dawn solar strength preserved');
    check(api.ensureGraphicsProfile('cinematic') === false, 'Legacy complete choice cannot change the light profile');
    const perf = api.visualTestSettings();
    check(perf.resting === 3 && perf.moving === 1.72,
      'Approved light resolution in motion and at rest preserved');
    return result;
  } finally {
    if (original.previewLocalTimeMinutes == null) api.clearPreviewTime();
    else api.setPreviewTimeMinutes(original.previewLocalTimeMinutes);
  }
}
const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
console.log(execFileSync(process.execPath,
  [evaluator, process.argv[2] ?? '9234', `(${checkFixedPeriods.toString()})()`],
  { encoding: 'utf8', timeout: 25000 }).trim());
