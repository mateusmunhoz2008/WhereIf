import * as THREE from './vendor/three.module.min.js';

export function normalizedMapQuality(requested = {}, current = { sharpness: 100, antialias: 'off' }) {
  const percent = requested.sharpness === undefined ? current.sharpness : Number(requested.sharpness);
  const antialias = requested.antialias ?? current.antialias;
  if (!Number.isFinite(percent)) throw new Error('Nitidez inválida.');
  if (!['off', 'light', 'strong'].includes(antialias)) throw new Error('Antisserrilhado inválido.');
  return { sharpness: Math.max(50, Math.min(125, percent)), antialias };
}

// Screen-space edge filtering: one RGBA8 copy and one fullscreen draw. No HDR
// compositor, scene rerender, depth target, MSAA buffers or continuous timer.
// The framebuffer already contains display-sRGB colors (including outlines
// and optional grading). Keep those encoded values: do not convert them twice.
export function createMapAntialias(renderer, level = 'light') {
  let texture = null;
  let width = 0, height = 0;
  const shader = new THREE.ShaderMaterial({
    name: 'MapEdgeAntialias', depthTest: false, depthWrite: false,
    toneMapped: false, blending: THREE.NoBlending,
    uniforms: { inputTexture: { value: null }, texel: { value: new THREE.Vector2() },
      edgeThreshold: { value: .16 }, amount: { value: .75 } },
    vertexShader: `varying vec2 vUv;
      void main(){vUv=uv;gl_Position=vec4(position.xy,0.0,1.0);}`,
    fragmentShader: `
      uniform sampler2D inputTexture; uniform vec2 texel;
      uniform float edgeThreshold; uniform float amount; varying vec2 vUv;
      float edgeLuma(vec3 c){return dot(c,vec3(.299,.587,.114));}
      void main(){
        vec3 center=texture2D(inputTexture,vUv).rgb;
        float nw=edgeLuma(texture2D(inputTexture,vUv+vec2(-1.,-1.)*texel).rgb);
        float ne=edgeLuma(texture2D(inputTexture,vUv+vec2( 1.,-1.)*texel).rgb);
        float sw=edgeLuma(texture2D(inputTexture,vUv+vec2(-1., 1.)*texel).rgb);
        float se=edgeLuma(texture2D(inputTexture,vUv+vec2( 1., 1.)*texel).rgb);
        float m=edgeLuma(center);
        float low=min(m,min(min(nw,ne),min(sw,se)));
        float high=max(m,max(max(nw,ne),max(sw,se)));
        if(high-low<max(.025,high*edgeThreshold)){gl_FragColor=vec4(center,1.);return;}
        vec2 direction=vec2(-((nw+ne)-(sw+se)),(nw+sw)-(ne+se));
        float reduce=max((nw+ne+sw+se)*.03125,.0078125);
        direction=clamp(direction/(min(abs(direction.x),abs(direction.y))+reduce),vec2(-8.),vec2(8.))*texel;
        vec3 a=.5*(texture2D(inputTexture,vUv-direction/6.).rgb+
          texture2D(inputTexture,vUv+direction/6.).rgb);
        vec3 b=a*.5+.25*(texture2D(inputTexture,vUv-direction*.5).rgb+
          texture2D(inputTexture,vUv+direction*.5).rgb);
        float l=edgeLuma(b);
        gl_FragColor=vec4(mix(center,(l<low||l>high)?a:b,amount),1.);
      }`,
  });
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position',new THREE.Float32BufferAttribute([-1,3,0,-1,-1,0,3,-1,0],3));
  geometry.setAttribute('uv',new THREE.Float32BufferAttribute([0,2,0,0,2,0],2));
  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1,1,1,-1,0,1);
  const quad = new THREE.Mesh(geometry,shader); quad.frustumCulled=false; scene.add(quad);
  const size = new THREE.Vector2();
  const pass = {
    setLevel(next) {
      level=next;
      shader.uniforms.edgeThreshold.value=next==='strong'?.0833:.16;
      shader.uniforms.amount.value=next==='strong'?1:.75;
    },
    resize() {
      renderer.getDrawingBufferSize(size);
      if(size.x===width&&size.y===height)return;
      width=size.x;height=size.y;texture?.dispose();
      texture=new THREE.FramebufferTexture(width,height);
      texture.minFilter=THREE.LinearFilter;texture.magFilter=THREE.LinearFilter;
      shader.uniforms.inputTexture.value=texture;
      shader.uniforms.texel.value.set(1/width,1/height);
    },
    warmup() { return renderer.compileAsync(scene,camera); },
    draw() {
      pass.resize();
      renderer.copyFramebufferToTexture(texture);
      const autoClear=renderer.autoClear;
      try {renderer.autoClear=false;renderer.render(scene,camera);}
      finally {renderer.autoClear=autoClear;}
    },
    snapshot() {return {mode:level,size:[width,height],estimatedTextureBytes:width*height*4,passes:1};},
    dispose() {texture?.dispose();texture=null;shader.dispose();geometry.dispose();},
  };
  pass.setLevel(level);
  return pass;
}
