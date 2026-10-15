import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { gunzipSync } from 'node:zlib';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const extract = name => {
  const match = source.match(new RegExp(`^function ${name}\\([^]*?^}`, 'm'));
  assert.ok(match, name);
  return match[0];
};
const errors = [];
const context = vm.createContext({
  geometryOnly: false,
  atob, Uint8Array, Blob, URL,
  installMiddaySky() {}, installNightSky() {}, loadConfiguredModel() {},
  configureDiagnostics() {},
  recordLoadingStage() {},
  send: (type, message) => errors.push({ type, message }),
});
vm.runInContext(`let modelTransfer = null, config = null, model = null, viewerDisposed = false;
  ${['beginModelTransfer', 'appendModelChunk', 'configure'].map(extract).join('\n')}
  globalThis.readConfig = () => config;`, context);

const gzip = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/campus_exterior_standard.glb.gz', import.meta.url));
const original = gunzipSync(gzip);
for (const [compression, bytes] of [['gzip', gzip], ['glb', original]]) {
  const encoded = bytes.toString('base64');
  context.beginModelTransfer(compression, encoded.length);
  for (let offset = 0; offset < encoded.length; offset += 65536) {
    context.appendModelChunk(encoded.slice(offset, offset + 65536));
  }
  context.configure({ zones: [] });
  const config = context.readConfig();
  try {
    const response = await fetch(config.modelUrl);
    const body = config.modelCompression === 'gzip'
      ? new Response(response.body.pipeThrough(new DecompressionStream('gzip')))
      : response;
    const decoded = Buffer.from(await body.arrayBuffer());
    assert.deepEqual(decoded, original, 'Every GLB byte is preserved');
    assert.equal(decoded.toString('ascii', 0, 4), 'glTF');
    assert.equal(decoded.readUInt32LE(8), decoded.length);
    console.log(`${compression}: ${encoded.length} bridge characters, exact GLB round trip passed`);
  } finally {
    URL.revokeObjectURL(config.modelUrl);
  }
}
assert.equal(errors.length, 0);
context.beginModelTransfer('gzip', 100);
context.appendModelChunk('YWJj');
context.configure({ zones: [] });
assert.equal(errors.at(-1).type, 'error');
console.log('Incomplete transfer rejected; no partial model is loaded');
for (const [compression, length] of [['zip', 4], ['gzip', -1], ['gzip', NaN], ['glb', 129 * 1024 * 1024]]) {
  assert.throws(() => context.beginModelTransfer(compression, length), /Invalid map transfer/);
}
context.beginModelTransfer('glb', 4);
assert.throws(() => context.appendModelChunk('YWJjYWJj'), /Invalid map transfer chunk/);
context.beginModelTransfer('glb', 100000);
assert.throws(() => context.appendModelChunk('A'.repeat(65540)), /Invalid map transfer chunk/);
vm.runInContext('viewerDisposed = true; modelTransfer = null;', context);
context.beginModelTransfer('glb', 4);
context.appendModelChunk('YWJj');
assert.equal(vm.runInContext('modelTransfer', context), null, 'Late chunks cannot retain memory after disposal');
console.log('Invalid transfers, oversized chunks and late transfer callbacks rejected');
