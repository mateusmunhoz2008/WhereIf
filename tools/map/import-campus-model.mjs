// Preserve the exported GLB byte-for-byte; gzip only reduces storage/transfer.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { gzipSync, gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';

const input = process.argv[2];
assert.ok(input, 'Usage: node tools/map/import-campus-model.mjs <source.glb>');
const target = resolve('assets/institutions/ifpr-pgua/map/campus_exterior_standard.glb.gz');
assert.notEqual(resolve(input), target);
const bytes = readFileSync(input);
assert.equal(bytes.toString('ascii', 0, 4), 'glTF');
assert.equal(bytes.readUInt32LE(4), 2);
assert.equal(bytes.readUInt32LE(8), bytes.length);
assert.equal(bytes.toString('ascii', 16, 20), 'JSON');
const gltf = JSON.parse(bytes.subarray(20, 20 + bytes.readUInt32LE(12)).toString('utf8'));
const names = new Set(gltf.nodes.map(node => node.name));
const metadata = JSON.parse(readFileSync(resolve('assets/institutions/ifpr-pgua/map/campus_map.json'), 'utf8'));
for (const zone of metadata.zones) {
  assert.ok(names.has(zone.nodeName), `Missing exterior: ${zone.nodeName}`);
  for (const floor of zone.floors ?? []) {
    for (const name of [...floor.nodeNames, ...floor.spaces.map(space => space.nodeName)]) {
      assert.ok(names.has(name), `Missing interior: ${name}`);
    }
  }
}
const compressed = gzipSync(bytes, { level: 9 });
assert.deepEqual(gunzipSync(compressed), bytes);
let previous = null;
if (existsSync(target)) {
  const old = readFileSync(target);
  previous = { compressed: old.length, glb: gunzipSync(old).length };
  const backup = resolve('recovery', `map-update-${new Date().toISOString().replace(/[:.]/g, '-')}`);
  mkdirSync(backup, { recursive: true });
  copyFileSync(target, resolve(backup, 'campus_exterior_standard-before.glb.gz'));
  console.log(`Previous asset saved: ${backup}`);
}
writeFileSync(target, compressed);
await import('./build-selection-cache.mjs');
console.log(JSON.stringify({ source: resolve(input), target, previous,
  current: { glb: bytes.length, compressed: compressed.length,
    sha256: createHash('sha256').update(bytes).digest('hex'),
    nodes: gltf.nodes.length, meshes: gltf.meshes.length },
  floors: metadata.zones.flatMap(zone => (zone.floors ?? []).map(floor => ({
    zone: zone.id, id: floor.id, spaces: floor.spaces.length,
  }))),
}, null, 2));
