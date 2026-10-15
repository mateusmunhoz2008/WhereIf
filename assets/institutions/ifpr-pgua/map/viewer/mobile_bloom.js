import * as THREE from './vendor/three.module.min.js';

// Bloom-only mobile path: one native-resolution HDR scene, five bounded
// dual-filter passes and one output pass. No full-size ping-pong compositor.
// HDR is retained so warm window emission and the dark sky are not quantized.
export function createMobileBloom(renderer, settings = {}) {
  const makeTarget = (name, depthBuffer = false) => {
    const target = new THREE.WebGLRenderTarget(1, 1, {
      type: THREE.HalfFloatType, depthBuffer, stencilBuffer: false,
      minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
      generateMipmaps: false,
    });
    target.texture.name = name;
    return target;
  };
  const source = makeTarget('mobile-bloom-scene', true);
  const bright = makeTarget('mobile-bloom-bright');
  const middle = makeTarget('mobile-bloom-middle');
  const small = makeTarget('mobile-bloom-small');
  const middleUp = makeTarget('mobile-bloom-middle-up');
  const largeUp = makeTarget('mobile-bloom-large-up');
  const targets = [source, bright, middle, small, middleUp, largeUp];
  const vertexShader = `varying vec2 vUv;
    void main() { vUv=uv; gl_Position=vec4(position.xy,0.0,1.0); }`;
  const material = (uniforms, fragmentShader) => new THREE.ShaderMaterial({
    uniforms, vertexShader, fragmentShader, depthTest: false, depthWrite: false,
    blending: THREE.NoBlending, toneMapped: false,
  });
  const extract = material({ inputTexture: { value: null },
    texel: { value: new THREE.Vector2() }, threshold: { value: .93 } }, `
    uniform sampler2D inputTexture; uniform vec2 texel; uniform float threshold;
    varying vec2 vUv;
    vec3 highlight(vec2 uv) {
      vec3 c=texture2D(inputTexture,uv).rgb;
      float l=dot(c,vec3(.299,.587,.114));
      return c*smoothstep(threshold,threshold+.05,l);
    }
    void main() {
      vec3 c=highlight(vUv)*4.0;
      c+=highlight(vUv+texel)+highlight(vUv-texel);
      c+=highlight(vUv+vec2(texel.x,-texel.y))+highlight(vUv+vec2(-texel.x,texel.y));
      gl_FragColor=vec4(c*.125,1.0);
    }`);
  const down = material({ inputTexture: { value: null },
    texel: { value: new THREE.Vector2() } }, `
    uniform sampler2D inputTexture; uniform vec2 texel; varying vec2 vUv;
    void main() {
      vec3 c=texture2D(inputTexture,vUv).rgb*4.0;
      c+=texture2D(inputTexture,vUv+texel).rgb+texture2D(inputTexture,vUv-texel).rgb;
      c+=texture2D(inputTexture,vUv+vec2(texel.x,-texel.y)).rgb;
      c+=texture2D(inputTexture,vUv+vec2(-texel.x,texel.y)).rgb;
      gl_FragColor=vec4(c*.125,1.0);
    }`);
  const up = material({ inputTexture: { value: null }, baseTexture: { value: null },
    texel: { value: new THREE.Vector2() } }, `
    uniform sampler2D inputTexture; uniform sampler2D baseTexture;
    uniform vec2 texel; varying vec2 vUv;
    void main() {
      vec3 c=texture2D(inputTexture,vUv+vec2(texel.x*2.0,0.0)).rgb;
      c+=texture2D(inputTexture,vUv-vec2(texel.x*2.0,0.0)).rgb;
      c+=texture2D(inputTexture,vUv+vec2(0.0,texel.y*2.0)).rgb;
      c+=texture2D(inputTexture,vUv-vec2(0.0,texel.y*2.0)).rgb;
      c+=2.0*(texture2D(inputTexture,vUv+texel).rgb+texture2D(inputTexture,vUv-texel).rgb);
      c+=2.0*(texture2D(inputTexture,vUv+vec2(texel.x,-texel.y)).rgb+
        texture2D(inputTexture,vUv+vec2(-texel.x,texel.y)).rgb);
      gl_FragColor=vec4(mix(texture2D(baseTexture,vUv).rgb,c/12.0,.72),1.0);
    }`);
  const output = material({ inputTexture: { value: source.texture },
    bloomTexture: { value: largeUp.texture }, strength: { value: 0 } }, `
    uniform sampler2D inputTexture; uniform sampler2D bloomTexture;
    uniform float strength; varying vec2 vUv;
    void main() {
      vec3 c=texture2D(inputTexture,vUv).rgb+texture2D(bloomTexture,vUv).rgb*strength;
      gl_FragColor=vec4(c,1.0);
      #include <colorspace_fragment>
    }`);
  const quadScene = new THREE.Scene();
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute([-1,3,0,-1,-1,0,3,-1,0],3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute([0,2,0,0,2,0],2));
  const quad = new THREE.Mesh(geometry, output);
  quad.frustumCulled = false;
  quadScene.add(quad);
  const cameraState = new Float64Array(32);
  let cacheValid = false, cachedThreshold = NaN, cachedRadius = NaN;
  let filterUpdates = 0, cacheHits = 0;
  const draw = (shader, target, input, offset = 1, base = null) => {
    shader.uniforms.inputTexture.value = input.texture;
    shader.uniforms.texel?.value.set(offset / input.width, offset / input.height);
    if (base) shader.uniforms.baseTexture.value = base.texture;
    quad.material = shader;
    renderer.setRenderTarget(target);
    renderer.render(quadScene, quadCamera);
  };
  const bloom = {
    enabled: true, strength: settings.strength ?? .15,
    radius: settings.radius ?? .24, threshold: settings.threshold ?? .93,
    invalidate() { cacheValid = false; },
    setSize(width, height) {
      width = Math.max(1, Math.round(width)); height = Math.max(1, Math.round(height));
      if (source.width === width && source.height === height) return;
      source.setSize(width, height);
      const scale = Math.min(.25, Math.sqrt(128000 / (width * height)));
      const w = Math.max(1, Math.round(width * scale));
      const h = Math.max(1, Math.round(height * scale));
      bright.setSize(w,h); largeUp.setSize(w,h);
      middle.setSize(Math.max(1,Math.round(w/2)),Math.max(1,Math.round(h/2)));
      middleUp.setSize(middle.width,middle.height);
      small.setSize(Math.max(1,Math.round(w/4)),Math.max(1,Math.round(h/4)));
      cacheValid = false;
    },
    async warmup(scene, camera) {
      const target = renderer.getRenderTarget();
      let scenePrograms;
      try {
        renderer.setRenderTarget(source);
        scenePrograms = renderer.compileAsync(scene, camera);
      } finally { renderer.setRenderTarget(target); }
      await scenePrograms;
      for (const shader of [extract, down, up, output]) {
        quad.material = shader;
        await renderer.compileAsync(quadScene, quadCamera);
      }
    },
    render(scene, camera, dynamic = false) {
      const target = renderer.getRenderTarget();
      const autoClear = renderer.autoClear;
      try {
        renderer.autoClear = true;
        renderer.setRenderTarget(source);
        renderer.render(scene, camera);
        let changed = !cacheValid || dynamic || cachedThreshold !== bloom.threshold || cachedRadius !== bloom.radius;
        for (let i=0;i<16;i++) {
          const world = camera.matrixWorld.elements[i], projection = camera.projectionMatrix.elements[i];
          if (world !== cameraState[i] || projection !== cameraState[i+16]) changed = true;
          cameraState[i] = world; cameraState[i+16] = projection;
        }
        if (changed) {
          const offset = .7 + Math.max(0,bloom.radius) * 1.5;
          extract.uniforms.threshold.value = bloom.threshold;
          draw(extract,bright,source,2);
          draw(down,middle,bright,offset);
          draw(down,small,middle,offset);
          draw(up,middleUp,small,offset,middle);
          draw(up,largeUp,middleUp,offset,bright);
          cachedThreshold = bloom.threshold; cachedRadius = bloom.radius;
          cacheValid = !dynamic; filterUpdates++;
        } else cacheHits++;
        // The previous five mip weights sum to three. Retain their overall
        // brightness instead of making the optimization merely a weaker glow.
        output.uniforms.strength.value = bloom.strength * 3;
        quad.material = output;
        renderer.setRenderTarget(target);
        renderer.render(quadScene, quadCamera);
      } finally {
        renderer.setRenderTarget(target); renderer.autoClear = autoClear;
      }
    },
    snapshot() {
      return { mode: 'mobile-dual-filter', sourceSize: [source.width,source.height],
        filterSize: [bright.width,bright.height], filterPasses: 5, outputPasses: 1,
        targetCount: targets.length, filterUpdates, cacheHits,
        estimatedTargetBytes: targets.reduce((sum,t)=>sum+t.width*t.height*(8+(t.depthBuffer?4:0)),0) };
    },
    dispose() {
      for (const target of targets) target.dispose();
      for (const shader of [extract,down,up,output]) shader.dispose();
      geometry.dispose(); cacheValid = false;
    },
  };
  return bloom;
}
