import assert from 'node:assert/strict';
import { mapFeatureTopics, normalizedMapFeatures, toggledMapFeatures } from '../../assets/institutions/ifpr-pgua/map/viewer/map_feature_panel.js';
import { normalizedMapQuality } from '../../assets/institutions/ifpr-pgua/map/viewer/map_antialias.js';
import { selectionOptionTopics, normalizedSelectionOptions, selectionOptionsPreset,
  optimizedSelectionOptions } from '../../assets/institutions/ifpr-pgua/map/viewer/selection_options.js';
assert.equal(selectionOptionTopics.length, 10);
assert.deepEqual(normalizedSelectionOptions(), optimizedSelectionOptions);
assert.equal(normalizedSelectionOptions().glass, false, 'Current optimized appearance remains the default');
const selectionBasic = selectionOptionsPreset('basic');
assert.deepEqual(Object.keys(selectionBasic).filter(key => selectionBasic[key]), ['labels', 'floors']);
assert.ok(Object.values(selectionOptionsPreset('complete')).every(Boolean));
for (const [key] of selectionOptionTopics) {
  const toggled = normalizedSelectionOptions({ [key]: false });
  assert.equal(toggled[key], false);
  for (const [other] of selectionOptionTopics) if (other !== key) {
    assert.equal(toggled[other], optimizedSelectionOptions[other], 'Selection switches have no hidden dependencies');
  }
}
assert.throws(() => normalizedSelectionOptions({ outline: 1 }));
assert.throws(() => normalizedSelectionOptions({ unknown: true }));
assert.throws(() => selectionOptionsPreset('unknown'));
const isolated = { roomGlow: false }; normalizedSelectionOptions(isolated);
assert.deepEqual(isolated, { roomGlow: false });
assert.deepEqual(normalizedMapQuality(),{sharpness:100,antialias:'off'});
assert.deepEqual(normalizedMapQuality({sharpness:1,antialias:'strong'}),{sharpness:50,antialias:'strong'});
assert.equal(normalizedMapQuality({sharpness:200}).sharpness,125);
assert.deepEqual(normalizedMapQuality({antialias:'light'},{sharpness:75,antialias:'off'}),{sharpness:75,antialias:'light'});
assert.throws(()=>normalizedMapQuality({sharpness:NaN}));
assert.throws(()=>normalizedMapQuality({antialias:'unknown'}));
assert.equal(mapFeatureTopics.length, 12);
assert.ok(Object.values(normalizedMapFeatures()).every(value => value === false));
for (const key of ['reflections', 'textures', 'shaders', 'windows']) {
  const state = normalizedMapFeatures({ [key]: true });
  assert.equal(state[key], true); assert.equal(state.pbr, true); assert.equal(state.lighting, true);
  assert.equal(Object.values(state).filter(Boolean).length, 3);
}
assert.deepEqual(normalizedMapFeatures({windowLighting:true}),
  normalizedMapFeatures({windows:true,windowLighting:true}), 'Complete windows include basic emission');
assert.equal(Object.values(normalizedMapFeatures({windowLighting:true})).filter(Boolean).length,4);
assert.deepEqual(Object.entries(normalizedMapFeatures({ shadows: true })).filter(([, value]) => value).map(([key]) => key), ['lighting', 'shadows']);
for (const key of ['sky', 'grading', 'bloom', 'selection']) {
  assert.equal(Object.values(normalizedMapFeatures({ [key]: true })).filter(Boolean).length, 1);
}
const requested = { textures: true };
normalizedMapFeatures(requested);
assert.deepEqual(requested, { textures: true }, 'Dependencies do not mutate caller preferences');
assert.ok(Object.values(normalizedMapFeatures(Object.fromEntries(mapFeatureTopics.map(([key]) => [key, true])))).every(Boolean));
const all = normalizedMapFeatures(Object.fromEntries(mapFeatureTopics.map(([key]) => [key, true])));
const noPbr = toggledMapFeatures(all, 'pbr', false);
for (const name of ['pbr', 'reflections', 'textures', 'shaders','windows','windowLighting']) assert.equal(noPbr[name], false);
assert.equal(noPbr.lighting, true); assert.equal(noPbr.shadows, true);
const noLight = toggledMapFeatures(all, 'lighting', false);
for (const name of ['lighting', 'pbr', 'shadows', 'reflections', 'textures', 'shaders','windows','windowLighting']) assert.equal(noLight[name], false);
assert.equal(noLight.sky, true);
assert.ok(Object.values(all).every(Boolean), 'Cascading toggles do not mutate the current state');
const basicWindows=toggledMapFeatures(all,'windowLighting',false);
assert.equal(basicWindows.windows,true);
assert.equal(basicWindows.windowLighting,false);
const noWindows=toggledMapFeatures(all,'windows',false);
assert.equal(noWindows.windows,false); assert.equal(noWindows.windowLighting,false);
assert.equal(noWindows.shaders,true); assert.equal(noWindows.lighting,true);
console.log('PASS: 12 feature switches, basic/complete windows, explicit dependencies and raw/all presets.');
console.log('PASS: 10 independent selection options, basic/optimized/complete presets and input validation.');
