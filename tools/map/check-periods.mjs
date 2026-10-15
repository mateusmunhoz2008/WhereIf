// Check every minute against the actual viewer's phase-selection functions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
function extract(name) {
  const start = source.indexOf(`function ${name}(`);
  assert.ok(start >= 0, name);
  const open = source.indexOf('{', start);
  let depth = 1;
  let end = open + 1;
  while (depth > 0) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  return source.slice(start, end);
}
const context = { minute: 0, nightSkyTuning: { enabled: true } };
vm.createContext(context);
vm.runInContext(`function localTimeMinutes() { return minute; }
${['isMorning', 'isMidday', 'isSunset', 'isDayCustomization', 'presetTimeMinutes', 'nightSkyAmount', 'normalizedGraphicsProfile'].map(extract).join('\n')}`, context);
for (let minute = 0; minute < 1440; minute++) {
  context.minute = minute;
  const expected = minute < 330 || minute >= 1140 ? 1260
    : minute < 660 ? 360 : minute < 990 ? 720 : 1080;
  assert.equal(vm.runInContext('presetTimeMinutes()', context), expected, `minute ${minute}`);
  assert.equal(vm.runInContext('nightSkyAmount()', context), expected === 1260 ? 1 : 0);
  assert.equal(vm.runInContext('[isMorning(), isMidday(), isSunset()].filter(Boolean).length', context), expected === 1260 ? 0 : 1);
}
for (const profile of ['basic', 'balanced', 'cinematic', 'auto', null]) {
  context.profile = profile;
  assert.equal(vm.runInContext('normalizedGraphicsProfile(profile)', context), 'basic');
}
// All scheduled rendering samples the fixed preset; actual time is only a selector/diagnostic.
assert.ok(source.includes('cyclicScheduleAmount(settings.schedule, presetTimeMinutes())'));
assert.ok(extract('daylightProfile').includes('const minute = presetTimeMinutes();'));
assert.ok(!extract('effectiveMorningLook').includes('phaseEnvelope(localTimeMinutes()'));
console.log('PASS: all 1440 minutes, exact boundaries, hard night sky switches, fixed approved samples and light-only graphics.');
