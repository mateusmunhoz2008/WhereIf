// Evaluate a diagnostic expression in the attached Android map WebView.
const port = Number(process.argv[2] ?? 9234);
const expression = process.argv[3];
if (!expression) throw new Error('Pass a JavaScript expression as the third argument.');
const pages = await (await fetch(`http://127.0.0.1:${port}/json`, {
  signal: AbortSignal.timeout(10000),
})).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html') &&
  JSON.parse(p.description || '{}').attached);
if (!page) throw new Error('Open the campus map in the app first.');
const url = new URL(page.webSocketDebuggerUrl);
url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
const timer = setTimeout(() => {
  console.error('WebView evaluation timed out.');
  socket.close();
  process.exitCode = 1;
}, 15000);
try {
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  const response = new Promise(resolve => {
    socket.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data);
      if (message.id === 1) resolve(message);
    });
  });
  socket.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: {
    expression, returnByValue: true, awaitPromise: true,
  } }));
  const result = await response;
  if (result.error || result.result?.exceptionDetails) {
    throw new Error(JSON.stringify(result));
  }
  console.log(JSON.stringify(result.result.result.value));
} finally {
  clearTimeout(timer);
  socket.close();
}
