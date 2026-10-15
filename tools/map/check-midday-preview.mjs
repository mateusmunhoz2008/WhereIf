// Validate phase isolation and material controls in the attached Android map.
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const evaluator = fileURLToPath(new URL('./evaluate-webview.mjs', import.meta.url));
async function checkMidday() {
  const api = window.whereIfMap;
  const original = api.debugSnapshot();
  const settings = api.visualTestSettings();
  if (!settings.midday) throw new Error('Select noon before running this check.');
  const checks = [];
  const check = (condition, label) => {
    if (!condition) throw new Error(label);
    checks.push(label);
  };
  const materials = () => api.debugSnapshot().materials;
  const asphalt = () => materials().find(m => /asphalt/i.test(m.name));
  try {
    api.setPreviewTimeMinutes(720);
    const noon = api.debugSnapshot();
    check(noon.nightSky.visible === false, 'Stars hidden at noon');
    check(noon.bloom.enabled === false, 'No heavy daytime bloom');
    check(noon.middaySky?.visible, 'Panoramic noon sky is visible');
    check(noon.middaySky.cloudCount === window.WHEREIF_MAP_TUNING.renderer.middaySky.cloudCount,
      'Irregular cloud field generated');
    const widths = noon.middaySky.cloudSizes.map(size => size[0]);
    const skySettings = window.WHEREIF_MAP_TUNING.renderer.middaySky;
    check(Math.min(...widths) >= skySettings.cloudWidthMin &&
      Math.max(...widths) <= skySettings.cloudWidthMax &&
      Math.max(...widths) > skySettings.cloudWidthMax * 0.9,
      'Clouds have varied sizes without covering the entire portrait sky');
    check(noon.middaySky.triangles < 2000, 'Sky geometry stays lightweight');
    api.rotateCameraBy(40);
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const rotated = api.debugSnapshot();
    check(JSON.stringify(rotated.middaySky.cloudProjections) !== JSON.stringify(noon.middaySky.cloudProjections),
      'Clouds move across the screen when the camera rotates');
    check(JSON.stringify(rotated.middaySky.rotation) === JSON.stringify(noon.middaySky.rotation),
      'Sky orientation stays anchored to the world');
    check(rotated.middaySky.position.every((value, index) => Math.abs(value - rotated.cameraPosition[index]) < 0.001),
      'Sky follows camera translation without rotating with it');
    check(rotated.middaySky.textureId === noon.middaySky.textureId, 'Camera gestures reuse the same sky texture');
    api.setPreviewCamera({ position: original.cameraPosition, target: original.cameraTarget });
    check(asphalt().roughness >= 0.8, 'Default asphalt is dry and matte');
    check(materials().filter(m => /^Material\.00[13456]$/.test(m.name))
      .every(m => m.roughness >= 0.9 && m.envMapIntensity < 0.05), 'Foliage stays matte');
    api.setPreviewTimeMinutes(840);
    check(JSON.stringify(api.debugSnapshot().keyLight) === JSON.stringify(noon.keyLight),
      'Noon sun stays fixed across the whole period');
    check(JSON.stringify(materials()) === JSON.stringify(noon.materials),
      'Noon materials stay consistent across the period');
    api.setPreviewTimeMinutes(1080);
    check(api.debugSnapshot().middaySky.visible === false, 'Noon sky does not replace sunset');
    check(materials().find(m => m.name === 'Material.001').color === '00490d',
      'Noon foliage color does not leak into sunset');
    check(api.visualTestSettings().key === 10, 'Approved sunset preset preserved');
    api.setPreviewTimeMinutes(1260);
    check(api.debugSnapshot().nightSky.visible, 'Night stars still visible');
    check(api.debugSnapshot().middaySky.visible === false, 'Day clouds are hidden at night');
    check(api.visualTestSettings().exposure === 0.25, 'Approved night exposure preserved');
    api.setPreviewTimeMinutes(360);
    check(api.visualTestSettings().exposure === 0.375, 'Approved dawn exposure preserved');
    api.setPreviewTimeMinutes(720);
    check(JSON.stringify(materials()) === JSON.stringify(noon.materials),
      'Switching periods does not accumulate color changes');
    api.configureMiddayLook({ floorRoughness: 0.28 });
    check(asphalt().roughness === 0.28, 'Floor roughness control works');
    api.configureMiddayLook({ reflections: 8 });
    check(materials().find(m => /concrete/i.test(m.name)).envMapIntensity > 0.5,
      'Reflection control updates material response');
    return checks;
  } finally {
    api.configureMiddayLook(settings);
    api.setPreviewTimeMinutes(original.previewLocalTimeMinutes);
    api.setPreviewCamera({ position: original.cameraPosition, target: original.cameraTarget });
  }
}
const output = execFileSync(process.execPath, [evaluator, process.argv[2] ?? '9234',
  `(${checkMidday.toString()})()`], { encoding: 'utf8', timeout: 25000 });
for (const label of JSON.parse(output)) console.log(`PASS: ${label}`);
