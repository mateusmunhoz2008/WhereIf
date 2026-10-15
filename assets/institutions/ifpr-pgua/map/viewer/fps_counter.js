// Counts completed map renders, not a separate animation loop or screen Hz.
// Never requests new renders: the map can still sleep when the camera stops.
export function createFpsCounter(enabled) {
  if (!enabled) return { recordFrame() {}, setReady() {}, dispose() {} };
  const badge = document.createElement('div');
  badge.id = 'map-fps-counter';
  badge.textContent = '— FPS';
  badge.style.cssText = 'position:fixed;top:12px;right:12px;z-index:20;pointer-events:none;display:none;padding:5px 8px;border-radius:7px;background:#000b;color:#fff;font:600 12px monospace;font-variant-numeric:tabular-nums;';
  document.body.appendChild(badge);
  let ready = false;
  let frames = 0;
  let startedAt = performance.now();
  const timer = setInterval(() => {
    const now = performance.now();
    if (ready && !document.hidden) {
      badge.textContent = frames > 0
        ? `${Math.round(frames * 1000 / Math.max(1, now - startedAt))} FPS`
        : '— FPS · parado';
    }
    frames = 0;
    startedAt = now;
  }, 250);
  return {
    recordFrame() { if (ready) frames++; },
    setReady() {
      ready = true;
      frames = 0;
      startedAt = performance.now();
      badge.style.display = 'block';
    },
    dispose() { clearInterval(timer); badge.remove(); },
  };
}
