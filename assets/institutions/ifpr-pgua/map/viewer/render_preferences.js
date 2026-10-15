const key = 'whereif.map.renderSettings.v1';

export function readRenderPreferences() {
  try {
    const value = JSON.parse(localStorage.getItem(key));
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  } catch { return {}; }
}

export function saveRenderPreferences(settings) {
  try { localStorage.setItem(key, JSON.stringify(settings)); } catch {}
}

