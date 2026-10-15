// Panning translates camera and target together. The projected ground offsets
// depend on their relative pose, projection and height, not their map X/Z.
export function createNavigationOffsetCache() {
  const entries = new WeakMap();
  const scratch = new Float64Array(30);
  function pose(camera, target, height, viewport) {
    scratch[0] = camera.position.x - target.x;
    scratch[1] = camera.position.y - target.y;
    scratch[2] = camera.position.z - target.z;
    scratch[3] = target.y; scratch[4] = height;
    const q = camera.quaternion;
    scratch[5] = q.x; scratch[6] = q.y; scratch[7] = q.z; scratch[8] = q.w;
    scratch[9] = viewport.left ?? .58; scratch[10] = viewport.right ?? .58;
    scratch[11] = viewport.top ?? .42; scratch[12] = viewport.bottom ?? .58;
    scratch[13] = camera.isOrthographicCamera ? 1 : 0;
    scratch.set(camera.projectionMatrix.elements, 14);
  }
  return {
    get(camera, target, height, viewport) {
      const entry = entries.get(camera);
      if (!entry) return null;
      pose(camera, target, height, viewport);
      for (let i = 0; i < scratch.length; i++) {
        // Ignore only subtraction noise from translating world coordinates;
        // projection, zoom and viewport changes require exact invalidation.
        if (i < 9 ? Math.abs(entry.pose[i] - scratch[i]) > 1e-10 : entry.pose[i] !== scratch[i]) return null;
      }
      return entry;
    },
    set(camera, target, height, viewport, offsets) {
      pose(camera, target, height, viewport);
      const entry = entries.get(camera) ?? { pose: new Float64Array(30) };
      entry.pose.set(scratch); entry.offsets = offsets;
      entries.set(camera, entry);
      return offsets;
    },
  };
}
