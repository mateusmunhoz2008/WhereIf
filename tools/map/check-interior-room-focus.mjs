import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/three.module.min.js';

const viewer = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const configSource = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer_config.js', import.meta.url), 'utf8');
const context = vm.createContext({ THREE, window: {}, camera: { position: new THREE.Vector3(1, 1, 1) }, controls: { target: new THREE.Vector3() } });
vm.runInContext(configSource, context);
const metadata = JSON.parse(readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/campus_map.json', import.meta.url)));
context.config = metadata;
context.cameraTuning = context.window.WHEREIF_MAP_TUNING.camera;
for (const name of ['interiorDirection', 'interiorRoomDirection']) {
  const source = viewer.match(new RegExp(`^function ${name}\\([^]*?^}`, 'm'))?.[0];
  assert.ok(source, name);
  vm.runInContext(source, context);
}
const floor = context.interiorDirection('bloco-central');
const room = context.interiorRoomDirection('bloco-central');
assert.ok(Math.abs(Math.atan2(floor.x, floor.z) - Math.atan2(room.x, room.z)) < 1e-9);
assert.ok(THREE.MathUtils.radToDeg(Math.asin(room.y)) >= 50 - 1e-9);
assert.ok(context.interiorDirection('bloco-didatico').distanceTo(context.interiorRoomDirection('bloco-didatico')) < 1e-9);
const zone = metadata.zones.find(zone => zone.id === 'bloco-central');
zone.focus = { direction: [1, 2, 0] };
assert.ok(context.interiorDirection('bloco-central').distanceTo(context.interiorRoomDirection('bloco-central')) < 1e-9);
assert.match(viewer, /direction: interiorRoomDirection\(interiors.current.zoneId\).toArray\(\)/);
assert.equal(context.cameraTuning.interiorRoomDistanceScales['bloco-central'], 1.8);
assert.equal(context.cameraTuning.interiorRoomDistanceScales['bloco-didatico'], undefined);
assert.match(viewer, /distanceScale: cameraTuning.interiorRoomDistanceScales\?\.\[interiors.current.zoneId\] \?\? 1.25/);
console.log('PASS: Central rooms rise to 50 degrees with wider framing; floor and Didatico angles stay unchanged.');
