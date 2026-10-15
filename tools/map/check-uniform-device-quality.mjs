import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { performanceMapPreset } from '../../assets/institutions/ifpr-pgua/map/viewer/map_performance_preset.js';

const read = path => readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
const base = 'assets/institutions/ifpr-pgua/map/viewer/';
for (const path of [base + 'viewer.js', base + 'viewer.bundle.js',
  base + 'render_preferences.js',
  'lib/map/presentation/widgets/campus_map_viewport.dart',
  'lib/map/presentation/widgets/map_diagnostics_panel.dart']) {
  assert.doesNotMatch(read(path), /weakDeviceTestMode|setWeakDeviceTestMode|limitedDevice|gpuRenderBudget|detectGraphicsProfile/,
    'No legacy hardware downgrade or 30-FPS test survives in ' + path);
}
assert.doesNotMatch(read(base + 'viewer.js'), /navigator\.(deviceMemory|hardwareConcurrency)/,
  'Missing hardware information cannot lower image quality');
assert.equal(performanceMapPreset.quality.sharpness, 65,
  'The manually selected performance preset remains unchanged');
assert.match(read('lib/settings/presentation/pages/settings_page.dart'), /settings-map-performance/);
assert.match(read('lib/map/presentation/viewmodels/map_performance_controller.dart'), /map\.performanceMode/);
console.log('PASS: no automatic hardware downgrade or legacy FPS cap; manual performance mode preserved');
