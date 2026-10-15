import * as THREE from './vendor/three.module.min.js';
import { createGeometrySelectionOutline } from './selection_geometry_outline.js';

export function createSelectionOutline(renderer, options = {}) {
  return renderer.getContext().getContextAttributes().stencil
    ? createGeometrySelectionOutline(renderer,options) : createTextureSelectionOutline(renderer);
}

// Native-resolution, cropped silhouettes. The campus is never re-rendered to
// make a mask: lightweight proxies share only the selected object's geometry.
// Camera/geometry and edge width have separate caches, so color/opacity fades
// require just one texture lookup and one small compositing draw.
export function createTextureSelectionOutline(renderer) {
  const maskTarget = new THREE.WebGLRenderTarget(1, 1, {
    minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
    depthBuffer: true, stencilBuffer: false,
  });
  const edgeTarget = new THREE.WebGLRenderTarget(1, 1, {
    minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
    depthBuffer: false, stencilBuffer: false,
  });
  const maskScene = new THREE.Scene();
  maskScene.userData.selectionMask = true;
  const maskMaterial = new THREE.MeshBasicMaterial({
    color: 'white', side: THREE.DoubleSide, toneMapped: false,
  });
  const quadGeometry = new THREE.PlaneGeometry(2, 2);
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const edgeScene = new THREE.Scene();
  const edgeMaterial = new THREE.ShaderMaterial({
    depthTest: false, depthWrite: false, toneMapped: false,
    uniforms: {
      maskTexture: { value: maskTarget.texture },
      texelSize: { value: new THREE.Vector2() },
      uvScale: { value: new THREE.Vector2(1, 1) },
      edgeWidth: { value: 1 },
    },
    vertexShader: `varying vec2 vUv;
      void main() { vUv = uv; gl_Position = vec4(position.xy, 0., 1.); }`,
    fragmentShader: `
      uniform sampler2D maskTexture;
      uniform vec2 texelSize;
      uniform vec2 uvScale;
      uniform float edgeWidth;
      varying vec2 vUv;
      float at(vec2 direction, float radius) {
        vec2 uv = vUv * uvScale + direction * texelSize * radius;
        if (any(lessThan(uv, vec2(0.))) || any(greaterThan(uv, uvScale))) return 0.;
        return texture2D(maskTexture, uv).r;
      }
      float enclosed(float radius) {
        float horizontal = min(at(vec2(-1.,0.), radius), at(vec2(1.,0.), radius));
        float vertical = min(at(vec2(0.,-1.), radius), at(vec2(0.,1.), radius));
        float diagonalA = min(at(vec2(-.707,-.707), radius), at(vec2(.707,.707), radius));
        float diagonalB = min(at(vec2(-.707,.707), radius), at(vec2(.707,-.707), radius));
        return max(max(horizontal, vertical), max(diagonalA, diagonalB));
      }
      void main() {
        float center = texture2D(maskTexture, vUv * uvScale).r;
        // No expensive work inside the silhouette; its exterior is all we draw.
        if (center > .98) { gl_FragColor = vec4(0.,0.,0.,1.); return; }
        float ring = at(vec2(1.,0.),edgeWidth) + at(vec2(-1.,0.),edgeWidth)
          + at(vec2(0.,1.),edgeWidth) + at(vec2(0.,-1.),edgeWidth)
          + at(vec2(.707,.707),edgeWidth) + at(vec2(-.707,.707),edgeWidth)
          + at(vec2(.707,-.707),edgeWidth) + at(vec2(-.707,-.707),edgeWidth);
        if (ring < .02) { gl_FragColor = vec4(0.,0.,0.,1.); return; }
        // Window surfaces are solid white in the mask (not highlighted in the
        // real scene). This guard also suppresses small unmodelled openings.
        float interior = max(enclosed(8.), enclosed(48.));
        float edge = smoothstep(.04,.7,ring) * (1.-center)
          * (1.-smoothstep(.72,.96,ring/8.)) * (1.-smoothstep(.08,.55,interior));
        gl_FragColor = vec4(edge,0.,0.,1.);
      }`,
  });
  edgeScene.add(new THREE.Mesh(quadGeometry, edgeMaterial));
  const material = new THREE.ShaderMaterial({
    transparent: true, depthTest: false, depthWrite: false, toneMapped: false,
    uniforms: {
      outlineColor: { value: new THREE.Color('white') },
      outlineOpacity: { value: 0 }, outlineWidth: { value: 1 },
      edgeTexture: { value: edgeTarget.texture },
      uvScale: { value: new THREE.Vector2(1, 1) },
      rect: { value: new THREE.Vector4(0, 0, 1, 1) },
    },
    vertexShader: `varying vec2 vUv; uniform vec4 rect;
      void main() { vUv=uv; gl_Position=vec4(position.xy*rect.zw+rect.xy,0.,1.); }`,
    fragmentShader: `varying vec2 vUv; uniform sampler2D edgeTexture;
      uniform vec2 uvScale; uniform vec3 outlineColor; uniform float outlineOpacity;
      void main() { float edge=texture2D(edgeTexture,vUv*uvScale).r;
        gl_FragColor=vec4(outlineColor,edge*outlineOpacity); }`,
  });
  const compositeScene = new THREE.Scene();
  compositeScene.userData.selectionComposite = true;
  compositeScene.add(new THREE.Mesh(quadGeometry, material));
  // During camera travel, calculate edges directly into the main image. An
  // intermediate edge framebuffer is worthwhile only when it can be cached.
  const liveEdgeMaterial = new THREE.ShaderMaterial({
    transparent: true, depthTest: false, depthWrite: false, toneMapped: false,
    uniforms: { ...edgeMaterial.uniforms,
      rect: material.uniforms.rect,
      outlineColor: material.uniforms.outlineColor,
      outlineOpacity: material.uniforms.outlineOpacity },
    vertexShader: material.vertexShader,
    fragmentShader: `uniform vec3 outlineColor; uniform float outlineOpacity;\n${edgeMaterial.fragmentShader}`
      .replaceAll('vec4(0.,0.,0.,1.)', 'vec4(0.)')
      .replace('vec4(edge,0.,0.,1.)', 'vec4(outlineColor,edge*outlineOpacity)'),
  });
  const liveEdgeScene = new THREE.Scene();
  liveEdgeScene.userData.selectionComposite = true;
  liveEdgeScene.add(new THREE.Mesh(quadGeometry, liveEdgeMaterial));
  const cropPerspective = new THREE.PerspectiveCamera();
  const cropOrthographic = new THREE.OrthographicCamera();
  const cropMatrix = new THREE.Matrix4();
  const viewProjection = new THREE.Matrix4();
  const lastProjection = new Float64Array(16).fill(NaN);
  const point = new THREE.Vector4();
  const size = new THREE.Vector2();
  const bounds = new THREE.Box3();
  const partBounds = new THREE.Box3();
  const savedColor = new THREE.Color();
  const proxies = [];
  let maskValid = false, edgeValid = false, widthKey = NaN;
  let previousWidth = 0, previousHeight = 0;
  let tile = null;
  const counters = { maskRenders: 0, edgeRenders: 0, composites: 0, liveEdges: 0 };

  function select(node) {
    maskScene.clear(); proxies.length = 0; bounds.makeEmpty();
    node?.updateWorldMatrix(true, true);
    node?.traverseVisible(source => {
      if (!source.isMesh || !source.geometry || source.userData.interiorSpace?.marker === source) return;
      // One opaque material renders all primitive groups in one draw, including
      // glass slots. Their internal frame edges must not become room outlines.
      const proxy = new THREE.Mesh(source.geometry, maskMaterial);
      proxy.matrixAutoUpdate = false; proxy.matrixWorldAutoUpdate = false;
      proxy.matrix.copy(source.matrixWorld); proxy.matrixWorld.copy(source.matrixWorld);
      maskScene.add(proxy); proxies.push(proxy);
      if (!source.geometry.boundingBox) source.geometry.computeBoundingBox();
      partBounds.copy(source.geometry.boundingBox).applyMatrix4(source.matrixWorld);
      bounds.union(partBounds);
    });
    maskScene.updateMatrixWorld(true);
    maskValid = edgeValid = false; tile = null;
  }

  function clear({ release = false } = {}) {
    maskScene.clear(); proxies.length = 0; bounds.makeEmpty();
    maskValid = edgeValid = false; tile = null;
    if (release) { maskTarget.setSize(1, 1); edgeTarget.setSize(1, 1); }
  }

  function projectTile(camera, viewportWidth, viewportHeight) {
    let minX = 1, minY = 1, maxX = -1, maxY = -1;
    for (let corner = 0; corner < 8; corner++) {
      point.set(corner & 1 ? bounds.max.x : bounds.min.x,
        corner & 2 ? bounds.max.y : bounds.min.y,
        corner & 4 ? bounds.max.z : bounds.min.z, 1).applyMatrix4(viewProjection);
      // A box crossing the near plane needs the full safe viewport, not an
      // invalid projected rectangle that clips the staircase or disappears.
      if (point.w <= 0.001 || point.z < -point.w) {
        return { x: 0, y: 0, width: viewportWidth, height: viewportHeight };
      }
      minX = Math.min(minX, point.x / point.w); maxX = Math.max(maxX, point.x / point.w);
      minY = Math.min(minY, point.y / point.w); maxY = Math.max(maxY, point.y / point.w);
    }
    const padding = 52 + Math.ceil(material.uniforms.outlineWidth.value);
    const x = Math.max(0, Math.floor((minX * .5 + .5) * viewportWidth) - padding);
    const y = Math.max(0, Math.floor((minY * .5 + .5) * viewportHeight) - padding);
    const right = Math.min(viewportWidth, Math.ceil((maxX * .5 + .5) * viewportWidth) + padding);
    const top = Math.min(viewportHeight, Math.ceil((maxY * .5 + .5) * viewportHeight) + padding);
    return right > x && top > y ? { x, y, width: right - x, height: top - y } : null;
  }

  function grow(target, width, height) {
    const capacityWidth = Math.max(target.width, Math.ceil(width / 64) * 64);
    const capacityHeight = Math.max(target.height, Math.ceil(height / 64) * 64);
    if (target.width !== capacityWidth || target.height !== capacityHeight) {
      target.setSize(capacityWidth, capacityHeight);
    }
    target.viewport.set(0, 0, width, height);
    target.scissor.set(0, 0, width, height); target.scissorTest = true;
  }

  function draw(camera) {
    if (!proxies.length || material.uniforms.outlineOpacity.value <= 0.001) return;
    renderer.getDrawingBufferSize(size);
    viewProjection.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
    const elements = viewProjection.elements;
    let changed = size.x !== previousWidth || size.y !== previousHeight;
    for (let i = 0; i < 16; i++) {
      if (!Number.isFinite(lastProjection[i]) || Math.abs(elements[i] - lastProjection[i]) > 1e-10) changed = true;
    }
    if (changed || !maskValid) {
      tile = projectTile(camera, size.x, size.y);
      lastProjection.set(elements); previousWidth = size.x; previousHeight = size.y;
      maskValid = false; edgeValid = false;
    }
    if (!tile) return;
    const width = Math.round(material.uniforms.outlineWidth.value * 8) / 8;
    const widthChanged = width !== widthKey;
    if (widthChanged) { widthKey = width; edgeValid = false; }
    const target = renderer.getRenderTarget();
    const autoClear = renderer.autoClear;
    const clearAlpha = renderer.getClearAlpha();
    const shadows = renderer.shadowMap.enabled;
    renderer.getClearColor(savedColor);
    try {
      renderer.shadowMap.enabled = false;
      renderer.autoClear = true;
      renderer.setClearColor(0, 1);
      if (!maskValid) {
        grow(maskTarget, tile.width, tile.height);
        const cropCamera = camera.isOrthographicCamera ? cropOrthographic : cropPerspective;
        cropCamera.matrixAutoUpdate = false; cropCamera.matrixWorldAutoUpdate = false;
        cropCamera.matrixWorld.copy(camera.matrixWorld);
        cropCamera.matrixWorldInverse.copy(camera.matrixWorldInverse);
        cropMatrix.set(size.x / tile.width, 0, 0, (size.x - 2 * tile.x - tile.width) / tile.width,
          0, size.y / tile.height, 0, (size.y - 2 * tile.y - tile.height) / tile.height,
          0, 0, 1, 0, 0, 0, 0, 1);
        cropCamera.projectionMatrix.copy(camera.projectionMatrix).premultiply(cropMatrix);
        cropCamera.projectionMatrixInverse.copy(cropCamera.projectionMatrix).invert();
        renderer.setRenderTarget(maskTarget); renderer.render(maskScene, cropCamera);
        maskValid = true; counters.maskRenders++;
      }
      const live = changed || widthChanged;
      material.uniforms.rect.value.set((2 * tile.x + tile.width) / size.x - 1,
        (2 * tile.y + tile.height) / size.y - 1, tile.width / size.x, tile.height / size.y);
      edgeMaterial.uniforms.texelSize.value.set(1 / maskTarget.width, 1 / maskTarget.height);
      edgeMaterial.uniforms.uvScale.value.set(tile.width / maskTarget.width, tile.height / maskTarget.height);
      edgeMaterial.uniforms.edgeWidth.value = width;
      if (!edgeValid && !live) {
        grow(edgeTarget, tile.width, tile.height);
        renderer.setRenderTarget(edgeTarget); renderer.render(edgeScene, quadCamera);
        edgeValid = true; counters.edgeRenders++;
      }
      material.uniforms.uvScale.value.set(tile.width / edgeTarget.width, tile.height / edgeTarget.height);
      renderer.setRenderTarget(target); renderer.autoClear = false;
      renderer.render(live ? liveEdgeScene : compositeScene, quadCamera);
      if (live) counters.liveEdges++;
      counters.composites++;
    } finally {
      renderer.setRenderTarget(target); renderer.autoClear = autoClear;
      renderer.setClearColor(savedColor, clearAlpha); renderer.shadowMap.enabled = shadows;
    }
  }

  return { maskTarget, material, scene: compositeScene, camera: quadCamera,
    select, clear, draw,
    snapshot: () => ({ ...counters, proxies: proxies.length, maskValid, edgeValid,
      tile: tile ? { ...tile } : null, capacity: [maskTarget.width, maskTarget.height],
      maxEdgeSamples: 25, compositeSamples: 1 }),
    dispose() { clear(); maskTarget.dispose(); edgeTarget.dispose();
      maskMaterial.dispose(); edgeMaterial.dispose(); liveEdgeMaterial.dispose();
      material.dispose(); quadGeometry.dispose(); },
  };
}
