// Exercise the actual panorama generator without requiring a connected phone.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/three.module.min.js';

const root = new URL('../../assets/institutions/ifpr-pgua/map/viewer/', import.meta.url);
const config = { window: {} };
vm.runInNewContext(readFileSync(new URL('viewer_config.js', root), 'utf8'), config);
const colors = [];
let drawCount = 0;
let saveDepth = 0;
const gradientStops = [];
const canvasContext = {
  createRadialGradient: () => ({ addColorStop(offset, color) { gradientStops.push(color); } }),
  fillRect(x, y, width, height) {
    drawCount++;
    if (height === 1) colors.push(this.fillStyle);
  },
  save() { saveDepth++; },
  restore() { saveDepth--; },
  translate() {}, scale() {},
};
const canvas = { getContext: () => canvasContext };
const cameraSettings = config.window.WHEREIF_MAP_TUNING.camera;
const camera = new THREE.PerspectiveCamera(cameraSettings.fov, 0.46, 0.1, 5000);
const target = new THREE.Vector3().fromArray(cameraSettings.initialTarget);
camera.position.fromArray(cameraSettings.initialPosition);
camera.lookAt(target);
camera.updateMatrixWorld();
const context = {
  THREE, rendererTuning: config.window.WHEREIF_MAP_TUNING.renderer,
  document: { createElement: () => canvas },
  scene: new THREE.Scene(), camera, middaySkyMesh: null, isMidday: () => true,
};
const source = readFileSync(new URL('viewer.js', root), 'utf8');
const generator = source.slice(source.indexOf('function installMiddaySky('),
  source.indexOf('function updateAtmosphericBackground('));
vm.runInNewContext(`${generator}\ninstallMiddaySky();`, context);
const sky = context.middaySkyMesh;
assert(sky, 'Sky generated');
const cloudCount = context.rendererTuning.middaySky.cloudCount;
assert.equal(sky.userData.cloudDirections.length, cloudCount);
for (let band = 0; band < 3; band++) {
  const sectors = new Set(sky.userData.cloudDirections
    .filter((_, index) => index % 3 === band)
    .map(direction => {
      const angle = (Math.atan2(direction.z, -direction.x) + Math.PI * 2) % (Math.PI * 2);
      return Math.floor(angle / (Math.PI * 2) * 8);
    }));
  assert.equal(sectors.size, 8, 'Every cloud band covers all eight compass sectors');
}
assert(gradientStops.some(color => color.startsWith('rgba(49,105,186,')),
  'Soft blue color patches are generated independently of clouds');
assert(gradientStops.some(color => color.startsWith('rgba(192,211,225,')),
  'Soft desaturated color patches break up the uniform blue');
assert(sky.userData.cloudDirections.some(direction => direction.y < -0.2),
  'Clouds cover the lower panorama seen by the default camera');
assert.equal(sky.geometry.index.count / 3, 1840);
assert.equal(canvas.width, context.rendererTuning.middaySky.resolution);
assert.equal(canvas.height, canvas.width / 2);
assert.equal(saveDepth, 0, 'Canvas transforms are balanced');
assert.equal(colors.length, canvas.height, 'Gradient covers every panorama row');
assert(new Set(colors).size > 40, 'Gradient has many subtle color steps');
const channels = colors.map(color => [1, 3, 5].map(offset =>
  Number.parseInt(color.slice(offset, offset + 2), 16)));
assert(channels.slice(1).every((color, index) => color.every((value, channel) =>
  Math.abs(value - channels[index][channel]) <= 2)), 'No abrupt gradient color bands');
const ray = new THREE.Raycaster();
const defaultViewColors = [1, 0, -1].map(y => {
  ray.setFromCamera(new THREE.Vector2(0, y), camera);
  const row = Math.round(Math.acos(ray.ray.direction.y) / Math.PI * (canvas.height - 1));
  return colors[row];
});
assert(new Set(defaultViewColors).size > 1,
  'Default downward-looking camera must see a gradient, not a flat lower hemisphere');
const widths = sky.userData.cloudSizes.map(size => size[0]);
const skySettings = context.rendererTuning.middaySky;
assert(Math.min(...widths) >= skySettings.cloudWidthMin &&
  Math.max(...widths) <= skySettings.cloudWidthMax &&
  Math.max(...widths) > skySettings.cloudWidthMax * 0.9);
assert(new Set(widths).size === cloudCount, 'Cloud sizes vary');
const project = () => sky.userData.cloudDirections.map(direction =>
  camera.position.clone().addScaledVector(direction, 1900).project(camera).toArray());
const before = JSON.stringify(project());
camera.position.sub(target).applyAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI / 4).add(target);
camera.lookAt(target);
camera.updateMatrixWorld();
assert.notEqual(JSON.stringify(project()), before, 'Cloud projections change with camera rotation');
assert.equal(sky.rotation.y, 0, 'Sky stays anchored to world orientation');
const originalDrawCount = drawCount;
vm.runInNewContext('installMiddaySky();', context);
assert.equal(drawCount, originalDrawCount, 'Panorama is generated only once');
assert.equal(context.scene.children.length, 1, 'Only one lightweight sky mesh');
context.sunsetSkyMesh = null;
context.isSunset = () => true;
vm.runInNewContext('installMiddaySky({ sunset: true });', context);
const sunset = context.sunsetSkyMesh;
assert(sunset.visible && sunset !== sky, 'Sunset sky is separate from the approved noon sky');
assert.equal(sunset.userData.cloudDirections.length, context.rendererTuning.sunsetSky.cloudCount);
assert.equal(sunset.geometry.index.count / 3, 1840);
assert.equal(sunset.material.toneMapped, false, 'Saved exposure does not wash out sunset sky');
assert(gradientStops.includes('rgba(255,223,158,0.96)'), 'Directional warm sunset glow is generated');
assert(gradientStops.some(color => color.startsWith('rgba(67,61,111,')), 'Sunset includes cool violet patches');
const sunsetDrawCount = drawCount;
vm.runInNewContext('installMiddaySky({ sunset: true });', context);
assert.equal(drawCount, sunsetDrawCount, 'Sunset also generates only once');
context.morningSkyMesh = null;
context.isMorning = () => true;
const beforeMorningDraw = drawCount;
vm.runInNewContext('installMiddaySky({ morning: true });', context);
const morningDrawCount = drawCount - beforeMorningDraw;
const originalCloudDirections = JSON.stringify(context.morningSkyMesh.userData.cloudDirections);
assert(context.morningSkyMesh.visible && context.morningSkyMesh !== sunset,
  'Dawn has an independent panoramic sky');
const dawnDirection = new THREE.Vector3().fromArray(context.rendererTuning.morningSky.sunDirection);
const sunsetDirection = new THREE.Vector3().fromArray(context.rendererTuning.sunsetSky.sunDirection);
dawnDirection.y = 0;
sunsetDirection.y = 0;
assert(dawnDirection.normalize().dot(sunsetDirection.normalize()) < -0.99,
  'Dawn glow is opposite the sunset glow');
context.morningSkyMesh = null;
context.rendererTuning.morningSky.sunCoreStrength = 4;
const beforeCoreDraw = drawCount;
vm.runInNewContext('installMiddaySky({ morning: true });', context);
assert.equal(drawCount - beforeCoreDraw, morningDrawCount + 3,
  'Sun core adds only one small wrapped patch, not a global sky change');
assert.equal(JSON.stringify(context.morningSkyMesh.userData.cloudDirections), originalCloudDirections,
  'Sun core does not move or regenerate a different cloud pattern');
assert(gradientStops.some(color => color.startsWith('rgba(255,248,218,')),
  'Localized warm-white sun core is generated');
console.log('PASS: smooth gradient, irregular clouds with blue gaps, panoramic rotation, bounded texture size, one-time generation');
