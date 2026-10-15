import { selectionCacheModelHash, selectionCacheLayout, selectionCachePayload } from './selection_cache_data.js';

export function selectionLayout(zones) {
  return JSON.stringify(zones.map(zone => [zone.nodeName,
    (zone.floors ?? []).map(floor => [floor.id, floor.nodeNames, floor.spaces.map(space => space.nodeName)])]));
}

function typed(encoded, Type) {
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return new Type(bytes.buffer);
}

export async function loadSelectionCache(modelBytes, zones) {
  // A changed GLB or interior layout must never reuse an old silhouette.
  if (!globalThis.crypto?.subtle || typeof DecompressionStream !== 'function' ||
      selectionLayout(zones) !== selectionCacheLayout) return null;
  try {
    const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', modelBytes))]
      .map(value => value.toString(16).padStart(2, '0')).join('');
    if (hash !== selectionCacheModelHash) return null;
    return async () => {
      try {
        const bytes = typed(selectionCachePayload, Uint8Array);
        const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
        const entries = await new Response(stream).json();
        for (const entry of Object.values(entries)) {
          for (const key of ['maskPositions', 'edgeStart', 'edgeEnd']) entry[key] = typed(entry[key], Float32Array);
          entry.maskIndices = typed(entry.maskIndices, Uint32Array);
        }
        return entries;
      } catch { return null; }
    };
  } catch { return null; }
}
