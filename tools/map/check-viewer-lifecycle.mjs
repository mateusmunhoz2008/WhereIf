import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const extract = name => {
  const match = source.match(new RegExp(`^function ${name}\\([^]*?^}`, 'm'));
  assert.ok(match, name);
  return match[0];
};
const releases = new Map();
const resource = name => ({ isTexture: true, dispose() {
  releases.set(name, (releases.get(name) ?? 0) + 1);
} });
const texture = resource('shared texture');
const atmosphere = resource('atmosphere');
const environment = resource('environment');
const events = new AbortController();
const target = new EventTarget();
let resizeEvents = 0;
target.addEventListener('resize', () => resizeEvents++, { signal: events.signal });
const cancelledFrames = [];
const context = vm.createContext({
  viewerEvents: events,
  eventMarkers: resource('event markers'),
  eventAnchorCache: new Map(), fpsCounter: resource('fps counter'),
  featurePanel: null, nightCinema: null,
  clearWindowPresets() {}, testOwnedMaterials: new Set(),
  testMaterialSources: new Map(), testGrassColors: new Map(),
  objectFades: new Set(), releaseSelectedMeshes() {}, disposeSelectionVariants() {},
  clearInterval() {}, cancelAnimationFrame: id => cancelledFrames.push(id),
  cancelRestingResolutionRestore() {}, controls: resource('controls'),
  interiors: null, restoreRawMaterials() {}, selectionOutline: resource('selection outline'),
  pickingTarget: resource('picking target'), hiddenInteriorWindows: new Set(), zoneNodes: new Map(),
  scene: {
    background: atmosphere, environment,
    traverse(visit) { visit({ geometry: resource('geometry'), material: { map: texture, dispose: resource('material').dispose } }); },
    clear() { this.cleared = true; },
  },
  renderer: { dispose: resource('renderer').dispose, forceContextLoss: resource('context').dispose },
  texture, atmosphere, environment,
});
vm.runInContext(`
  let viewerDisposed=false, mapEventNavigationRequest=0, geometryWarmupTarget=null;
  let diagnosticsTimer=null, diagnosticsGpuQuery=null, animationFrame=11, bearingResetFrame=12;
  let modelTransfer={}, mobileBloom=null, mapAntialias=null, effectComposer=null, model={};
  let atmosphereTexture=atmosphere, atmosphereCanvas={}, atmosphereContext={};
  let reflectionEnvironment=environment, reflectionEnvironmentFaces=[{}];
  let selectionWindowMeshes=[], exportedWindowPresetObjects=[];
  ${['disposeViewer', 'setVisible', 'resize'].map(extract).join('\n')}
`, context);

context.disposeViewer();
assert.equal(events.signal.aborted, true);
target.dispatchEvent(new Event('resize'));
assert.equal(resizeEvents, 0, 'Disposed DOM listeners no longer run');
assert.deepEqual(cancelledFrames, [11, 12]);
for (const name of ['shared texture', 'atmosphere', 'environment', 'geometry', 'renderer', 'context']) {
  assert.equal(releases.get(name), 1, `${name} is released once`);
}
assert.equal(context.scene.background, null);
assert.equal(context.scene.environment, null);
assert.equal(context.scene.cleared, true);
const firstReleaseCount = new Map(releases);
context.disposeViewer();
context.setVisible(true);
context.resize();
assert.deepEqual(releases, firstReleaseCount, 'Disposal is idempotent; late callbacks cannot recreate GPU state');
assert.equal((source.match(/capture: true, signal: viewerEvents.signal/g) ?? []).length, 4);
assert.ok(source.includes("window.addEventListener('resize', resize, { signal: viewerEvents.signal })"));
console.log('Viewer disposal, GPU textures, listener cancellation and late lifecycle callbacks passed');

const renderFailure = vm.createContext({
  renderMapFrame() { throw new Error('GPU failure'); },
  setVisible(visible) { assert.equal(visible, false); },
  send(type, payload) { assert.equal(type, 'error'); assert.match(payload.message, /GPU failure/); },
});
vm.runInContext(extract('renderFrame'), renderFailure);
renderFailure.renderFrame(100);
console.log('Critical frame failures stop rendering and report an actionable error');
