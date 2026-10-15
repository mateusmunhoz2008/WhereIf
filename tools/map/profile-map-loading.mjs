// Measures a real Android WebView reload, including Flutter's model transfer.
// The Flutter page-finished callback supplies the model again after reload.
const port = Number(process.argv[2] ?? 9234);
const pages = await (await fetch(`http://127.0.0.1:${port}/json`, {
  signal: AbortSignal.timeout(10000),
})).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html') &&
  JSON.parse(p.description || '{}').attached);
if (!page) throw new Error('Open the map in the app first.');
const url = new URL(page.webSocketDebuggerUrl);
url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let sequence = 0;
const pending = new Map();
socket.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data);
  const request = pending.get(message.id);
  if (!request) return;
  pending.delete(message.id);
  clearTimeout(request.timer);
  message.error ? request.reject(message.error) : request.resolve(message.result);
});
const call = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++sequence;
  const timer = setTimeout(() => {
    pending.delete(id);
    reject(new Error(`${method} timed out; check the screen and USB connection.`));
  }, 10000);
  pending.set(id, { resolve, reject, timer });
  socket.send(JSON.stringify({ id, method, params }));
});
try {
  await call('Page.reload');
  const stages = [];
  const started = Date.now();
  let snapshot;
  while (Date.now() - started < 90000) {
    const response = await call('Runtime.evaluate', {
      expression: 'window.whereIfMap?.diagnosticsSnapshot ? ({now:performance.now(),ready:document.querySelector("canvas.is-ready")!==null,snapshot:whereIfMap.diagnosticsSnapshot()}) : null',
      returnByValue: true,
    });
    if (response.exceptionDetails) throw new Error(JSON.stringify(response.exceptionDetails));
    const value = response.result.value;
    if (value) {
      snapshot = value;
      if (stages.at(-1)?.stage !== value.snapshot.stage) {
        const entry = { stage: value.snapshot.stage, atMs: Math.round(value.now) };
        stages.push(entry);
        console.log(JSON.stringify(entry));
      }
      if (value.ready) break;
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  if (!snapshot?.ready) throw new Error('Map did not become ready.');
  console.log(JSON.stringify({ totalMs: Math.round(snapshot.now), stages, snapshot: snapshot.snapshot }, null, 2));
} finally {
  for (const request of pending.values()) clearTimeout(request.timer);
  socket.close();
}
