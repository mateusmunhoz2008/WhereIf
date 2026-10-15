import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, mkdtemp } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { spawn } from 'node:child_process';
import { gunzipSync } from 'node:zlib';
import assert from 'node:assert/strict';
import { normalizedMapFeatures, mapFeatureTopics } from '../../assets/institutions/ifpr-pgua/map/viewer/map_feature_panel.js';
import { selectionOptionTopics, selectionOptionsPreset } from '../../assets/institutions/ifpr-pgua/map/viewer/selection_options.js';
import { performanceMapPreset } from '../../assets/institutions/ifpr-pgua/map/viewer/map_performance_preset.js';

const root = resolve('.');
const base = '/assets/institutions/ifpr-pgua/map/';
const output = resolve('build/raw-map-preview');
const approvedDefaults = process.argv.includes('--approved-defaults');
const featurePanel = approvedDefaults || process.argv.includes('--feature-panel');
const basicLighting = featurePanel || process.argv.includes('--basic-lighting');
await mkdir(output, { recursive: true });
const profile = await mkdtemp(resolve(output, 'chrome-'));
const server = createServer(async (req, res) => {
  try {
    if (new URL(req.url, 'http://localhost').pathname === '/') {
      const nativeMode=new URL(req.url,'http://localhost').searchParams.get('mode');
      let entry = await readFile(resolve(root, '.' + base + 'viewer/index.html'), 'utf8');
      if (!basicLighting) entry = entry.replace('window.WHEREIF_BASIC_LIGHTING = true', 'window.WHEREIF_BASIC_LIGHTING = false');
      if (!featurePanel) entry = entry.replace('window.WHEREIF_FEATURE_PANEL = true', 'window.WHEREIF_FEATURE_PANEL = false');
      if (!approvedDefaults) entry = entry.replace('<script src="./viewer.bundle.js',
        '<script>window.WHEREIF_MAP_TUNING.renderer.approvedMapFeatures=null;</script><script src="./viewer.bundle.js');
      res.setHeader('Content-Type', 'text/html');
      res.end(entry.replace('<head>', '<head><script>window.messages=[];window.MapBridge={postMessage:m=>messages.push(JSON.parse(m))};window.addEventListener("error",e=>messages.push({type:"error",message:e.message}));const oldConsoleError=console.error;console.error=(...args)=>{messages.push({type:"error",message:args.map(String).join(" ")});oldConsoleError(...args);};</script>')
        .replaceAll('src="./', `src="${base}viewer/`)
        .replace('</body>', `<script>(async()=>{const metadata=await(await fetch('${base}campus_map.json')).json();
          whereIfMap.configure({...metadata,modelUrl:'${base}campus_exterior_standard.glb.gz',modelCompression:'gzip',localTimeMinutes:720,diagnosticsEnabled:true${nativeMode===null?'':`,performanceMode:${nativeMode==='performance'}`}});})();</script></body>`));
      return;
    }
    const path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
    assert.ok(path.startsWith(root + '\\') || path.startsWith(root + '/'));
    res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.json': 'application/json' })[extname(path)] ?? 'application/octet-stream');
    res.end(await readFile(path));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', '--remote-debugging-port=9248', `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding', '--window-size=412,892', `http://127.0.0.1:${server.address().port}/`,
], { windowsHide: true, stdio: 'ignore' });
const pause = ms => new Promise(r => setTimeout(r, ms));
let socket;
try {
  let page;
  for (let i = 0; i < 50; i++) {
    try { page = (await (await fetch('http://127.0.0.1:9248/json')).json()).find(p => p.type === 'page'); if (page) break; } catch {}
    await pause(200);
  }
  assert.ok(page, 'Headless Chrome starts');
  socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => socket.addEventListener('open', r, { once: true }));
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', ({ data }) => {
    const message = JSON.parse(data);
    if (!message.id) return;
    const promise = pending.get(message.id);
    pending.delete(message.id);
    message.error ? promise?.reject(message.error) : promise?.resolve(message.result);
  });
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    assert.equal(result.exceptionDetails, undefined, JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  const emptyCampusPoint=()=>evaluate(`(async()=>{
    const THREE=await import('${base}viewer/vendor/three.module.min.js');
    const d=whereIfMap.debugSnapshot(),f=whereIfMap.interiorSnapshot(),c=new THREE.PerspectiveCamera();
    c.projectionMatrix.fromArray(d.cameraProjectionMatrix);c.projectionMatrixInverse.copy(c.projectionMatrix).invert();c.matrixWorld.fromArray(d.cameraMatrixWorld);
    const ray=new THREE.Raycaster(),bounds=f.activeFloorBounds.map(b=>new THREE.Box3(new THREE.Vector3().fromArray(b.min),new THREE.Vector3().fromArray(b.max)));
    for(const y of [.86,.45,.14])for(const x of [.96,.04,.75,.25]){
      const px=x*innerWidth,py=y*innerHeight;ray.setFromCamera(new THREE.Vector2(x*2-1,1-y*2),c);
      const nearControl=[...document.querySelectorAll('button,input,select')].some(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&px>r.left-24&&px<r.right+24&&py>r.top-24&&py<r.bottom+24;});
      if(!nearControl&&document.elementFromPoint(px,py)?.tagName==='CANVAS' && !bounds.some(b=>ray.ray.intersectsBox(b)))return {x:px,y:py};
    }
    return null;
  })()`);
  await call('Emulation.setDeviceMetricsOverride', { width: 412, height: 892, deviceScaleFactor: 1, mobile: true });
  let ready;
  for (let i = 0; i < 150; i++) {
    const messages = await evaluate('window.messages ?? []');
    assert.deepEqual(messages.filter(m => m.type === 'error'), []);
    ready = messages.find(m => m.type === 'ready');
    if (ready) break;
    await pause(200);
  }
  assert.ok(ready, 'Raw map loads');
  if (featurePanel) {
    const beforePopupSize=await evaluate('({quality:whereIfMap.debugSnapshot().quality,camera:whereIfMap.debugSnapshot().cameraPosition,features:whereIfMap.mapTestSnapshot().features,mode:whereIfMap.mapTestSnapshot().performanceModeEnabled})');
    await evaluate('(()=>{const input=document.getElementById("map-interior-event-size");input.value=135;input.dispatchEvent(new Event("input"));})()');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).interiorSize,135);
    assert.equal(await evaluate('document.querySelector("output[for=map-interior-event-size]").textContent'),'135%');
    assert.equal(await evaluate('JSON.parse(localStorage.getItem("whereif.map.renderSettings.v1")).interiorEventSize'),135,'Test size is stored locally');
    assert.deepEqual(await evaluate('({quality:whereIfMap.debugSnapshot().quality,camera:whereIfMap.debugSnapshot().cameraPosition,features:whereIfMap.mapTestSnapshot().features,mode:whereIfMap.mapTestSnapshot().performanceModeEnabled})'),beforePopupSize,'Size has no effect on rendering quality, camera or performance mode');
    await evaluate('document.querySelector("[data-interior-event-size-reset]").click()');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).interiorSize,100);
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).autoLayout,true,'Automatic placement is the initial default');
    await evaluate('(()=>{const input=document.getElementById("map-event-layout");input.value="normal";input.dispatchEvent(new Event("change"));})()');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).autoLayout,false);
    assert.equal(await evaluate('JSON.parse(localStorage.getItem("whereif.map.renderSettings.v1")).eventMarkerAutoLayout'),false,'Normal placement is saved locally');
    assert.deepEqual(await evaluate('({quality:whereIfMap.debugSnapshot().quality,camera:whereIfMap.debugSnapshot().cameraPosition,features:whereIfMap.mapTestSnapshot().features,mode:whereIfMap.mapTestSnapshot().performanceModeEnabled})'),beforePopupSize,'Placement changes do not affect camera, quality or performance settings');
    await call('Page.reload');
    let placementReloaded=false;
    for(let i=0;i<150;i++){
      placementReloaded=await evaluate('Boolean(window.messages?.some(m=>m.type==="ready"))');
      if(placementReloaded)break;
      await pause(200);
    }
    assert.ok(placementReloaded,'Map reloads with the saved placement preference');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).autoLayout,false);
    assert.equal(await evaluate('document.getElementById("map-event-layout").value'),'normal');
    await evaluate('(()=>{const input=document.getElementById("map-event-layout");input.value="auto";input.dispatchEvent(new Event("change"));})()');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).autoLayout,true);
    assert.equal(await evaluate('JSON.parse(localStorage.getItem("whereif.map.renderSettings.v1")).eventMarkerAutoLayout'),true);
    console.log('PASS: normal/automatic popup placement switches immediately, survives reload and preserves graphics/camera');
    const bloomCheck = await evaluate(`(async()=>{
      const THREE=await import('${base}viewer/vendor/three.module.min.js');
      const {createMobileBloom}=await import('${base}viewer/mobile_bloom.js');
      const renderer=new THREE.WebGLRenderer({preserveDrawingBuffer:true});
      renderer.setSize(80,64);renderer.outputColorSpace=THREE.SRGBColorSpace;
      renderer.toneMapping=THREE.NoToneMapping;
      const scene=new THREE.Scene();scene.background=new THREE.Color(.001,.003,.005);
      const camera=new THREE.OrthographicCamera(-1,1,1,-1,.1,10);camera.position.z=2;
      const geometry=new THREE.PlaneGeometry(2,2);
      const backdrop=new THREE.ShaderMaterial({toneMapped:false,
        vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',
        fragmentShader:'varying vec2 vUv;void main(){gl_FragColor=vec4(vec3(vUv.x*vUv.x*.4),1.0);#include <colorspace_fragment> }'.replace('#include','\\n#include').replace('> }','>\\n}')});
      scene.add(new THREE.Mesh(geometry,backdrop));
      const glowMaterial=new THREE.MeshBasicMaterial({color:new THREE.Color(4,1,.3),toneMapped:false});
      const glow=new THREE.Mesh(geometry,glowMaterial);glow.scale.set(.035,.3,1);glow.position.z=.1;scene.add(glow);
      const gl=renderer.getContext();
      const pixels=()=>{const data=new Uint8Array(80*64*4);gl.readPixels(0,0,80,64,gl.RGBA,gl.UNSIGNED_BYTE,data);return data;};
      const bloom=createMobileBloom(renderer,{strength:0,threshold:.93,radius:.24});
      try {
        renderer.render(scene,camera);const direct=pixels();
        bloom.setSize(80,64);await bloom.warmup(scene,camera);bloom.render(scene,camera);
        const noGlow=pixels();let maxBaseDifference=0;
        for(let i=0;i<direct.length;i++)maxBaseDifference=Math.max(maxBaseDifference,Math.abs(direct[i]-noGlow[i]));
        const first=bloom.snapshot();bloom.render(scene,camera);const cached=bloom.snapshot();
        bloom.strength=.8;bloom.render(scene,camera);const lit=pixels();let brighterPixels=0;
        for(let i=0;i<direct.length;i+=4)if(lit[i]>direct[i]+2)brighterPixels++;
        const strengthOnly=bloom.snapshot();camera.position.x=.1;camera.updateMatrixWorld();bloom.render(scene,camera);
        const moved=bloom.snapshot();bloom.render(scene,camera,true);const animated=bloom.snapshot();
        bloom.invalidate();bloom.render(scene,camera);const invalidated=bloom.snapshot();
        bloom.setSize(1296,2808);const resized=bloom.snapshot();
        return {maxBaseDifference,brighterPixels,first,cached,strengthOnly,moved,animated,invalidated,resized};
      } finally {bloom.dispose();geometry.dispose();backdrop.dispose();glowMaterial.dispose();renderer.dispose();}
    })()`);
    assert.ok(bloomCheck.maxBaseDifference<=1,'HDR bloom does not alter the native map color when strength is zero');
    assert.ok(bloomCheck.brighterPixels>0,'Thin bright geometry produces visible bloom');
    assert.equal(bloomCheck.cached.filterUpdates,bloomCheck.first.filterUpdates,'Stationary camera reuses all blur passes');
    assert.equal(bloomCheck.strengthOnly.filterUpdates,bloomCheck.first.filterUpdates,'Strength changes reuse the blur');
    assert.equal(bloomCheck.moved.filterUpdates,bloomCheck.first.filterUpdates+1,'Camera motion updates bloom immediately');
    assert.equal(bloomCheck.animated.filterUpdates,bloomCheck.moved.filterUpdates+1,'Fades cannot reuse a stale image');
    assert.equal(bloomCheck.invalidated.filterUpdates,bloomCheck.animated.filterUpdates+1,'Climate/material changes invalidate the cache');
    assert.deepEqual(bloomCheck.resized.sourceSize,[1296,2808],'Native map sharpness is retained');
    assert.ok(bloomCheck.resized.filterSize[0]*bloomCheck.resized.filterSize[1]<129000,'Only bloom has a bounded low-resolution budget');
    console.log('PASS: mobile bloom preserves colors/sharpness, adds visible glow, caches idle blur and updates motion/fades/climate');
    const antialiasCheck=await evaluate(`(async()=>{
      const THREE=await import('${base}viewer/vendor/three.module.min.js');
      const {createMapAntialias}=await import('${base}viewer/map_antialias.js');
      const renderer=new THREE.WebGLRenderer({preserveDrawingBuffer:true});renderer.setSize(80,64);
      const scene=new THREE.Scene();scene.background=new THREE.Color('#224466');
      const camera=new THREE.OrthographicCamera(-1,1,1,-1,.1,10);camera.position.z=2;
      const geometry=new THREE.PlaneGeometry(.8,1.3),material=new THREE.MeshBasicMaterial({color:'white',toneMapped:false});
      const mesh=new THREE.Mesh(geometry,material);mesh.rotation.z=.37;scene.add(mesh);
      const filter=createMapAntialias(renderer,'light');
      const gl=renderer.getContext(),pixels=()=>{const p=new Uint8Array(80*64*4);gl.readPixels(0,0,80,64,gl.RGBA,gl.UNSIGNED_BYTE,p);return p;};
      try{
        await filter.warmup();renderer.render(scene,camera);const direct=pixels();filter.draw();const light=pixels();
        let changedPixels=0,flatDifference=0;
        for(let y=0;y<64;y++)for(let x=0;x<80;x++){
          const i=(y*80+x)*4;let difference=0;
          for(let c=0;c<3;c++)difference=Math.max(difference,Math.abs(direct[i+c]-light[i+c]));
          if(difference>2)changedPixels++;
          if(x<8||x>71)flatDifference=Math.max(flatDifference,difference);
        }
        filter.setLevel('strong');renderer.render(scene,camera);filter.draw();const strong=pixels();
        const levelsDiffer=strong.some((v,i)=>Math.abs(v-light[i])>2);
        return {changedPixels,flatDifference,levelsDiffer,glError:gl.getError(),snapshot:filter.snapshot(),errors:window.messages.filter(m=>m.type==='error')};
      }finally{filter.dispose();geometry.dispose();material.dispose();renderer.dispose();}
    })()`);
    assert.deepEqual(antialiasCheck.errors,[],'Antialias has no shader compilation errors');
    assert.equal(antialiasCheck.glError,0,'Framebuffer copy/filter have no WebGL errors');
    assert.ok(antialiasCheck.changedPixels>0,'The antialias control actually smooths edges');
    assert.ok(antialiasCheck.flatDifference<=1,'Antialias does not shift the sky or flat surface colors');
    assert.equal(antialiasCheck.levelsDiffer,true,'Light and strong are genuinely different strengths');
    assert.equal(antialiasCheck.snapshot.estimatedTextureBytes,80*64*4,'Only one RGBA8 texture, no depth/HDR ping-pong');
    console.log('PASS: antialias smooths actual edges in one pass, preserves flat colors and has distinct light/strong levels');
    const edgeCheck=await evaluate(`(async()=>{
      const THREE=await import('${base}viewer/vendor/three.module.min.js');
      const {createGeometrySelectionOutline}=await import('${base}viewer/selection_geometry_outline.js');
      const renderer=new THREE.WebGLRenderer({stencil:true,preserveDrawingBuffer:true});renderer.setSize(80,80);
      const scene=new THREE.Scene();scene.background=new THREE.Color('black');
      const camera=new THREE.OrthographicCamera(-2.2,2.2,2.2,-2.2,.1,10);camera.position.z=3;
      const root=new THREE.Group(),material=new THREE.MeshBasicMaterial({color:'#555555'});scene.add(root);
      const geometries=[];
      for(const offset of [-1.4,-.45,.45,1.4]){
        for(const vertical of [false,true]){
          const g=new THREE.BoxGeometry(vertical?.045:3.6,vertical?3.6:.045,.08);geometries.push(g);
          const m=new THREE.Mesh(g,material);if(vertical)m.position.x=offset;else m.position.y=offset;root.add(m);
        }
      }
      const edge=createGeometrySelectionOutline(renderer);edge.select(root);
      edge.material.uniforms.outlineColor.value.set('red');edge.material.uniforms.outlineWidth.value=2;
      edge.material.uniforms.outlineOpacity.value=1;
      const gl=renderer.getContext(),pixels=()=>{const p=new Uint8Array(80*80*4);gl.readPixels(0,0,80,80,gl.RGBA,gl.UNSIGNED_BYTE,p);return p;};
      try{
        renderer.render(scene,camera);const basePixels=pixels();edge.draw(camera);const highlighted=pixels();
        let centerDifference=0,changed=0;
        for(let y=0;y<80;y++)for(let x=0;x<80;x++){
          const i=(y*80+x)*4;let difference=0;
          for(let c=0;c<3;c++)difference=Math.max(difference,Math.abs(basePixels[i+c]-highlighted[i+c]));
          if(difference>2)changed++;
          if(x>=30&&x<50&&y>=30&&y<50)centerDifference=Math.max(centerDifference,difference);
        }
        const before=edge.snapshot();camera.position.x=.15;camera.lookAt(0,0,0);camera.updateMatrixWorld();
        renderer.render(scene,camera);edge.draw(camera);const after=edge.snapshot();
        return {centerDifference,changed,before,after,glError:gl.getError(),errors:messages.filter(m=>m.type==='error')};
      }finally{edge.dispose();for(const g of geometries)g.dispose();material.dispose();renderer.dispose();}
    })()`);
    assert.equal(edgeCheck.glError,0);assert.deepEqual(edgeCheck.errors,[]);
    assert.ok(edgeCheck.changed>0,'Geometry selection creates a visible exterior contour');
    assert.equal(edgeCheck.centerDifference,0,'Disconnected concrete window/grille apertures remain completely unoutlined');
    assert.ok(edgeCheck.before.facadeEnvelopes>0,'Exported disconnected beam faces are handled without pixel filters');
    assert.equal(edgeCheck.before.textureTargets,0);
    assert.equal(edgeCheck.before.proxies,1,'Many pieces are batched into a single stencil draw');
    assert.equal(edgeCheck.after.geometryBuilds,edgeCheck.before.geometryBuilds,'Camera movement never rebuilds selection geometry');
    console.log('PASS: exterior geometry contour is visible, window/grille interiors are untouched and camera motion allocates no targets/geometry');
  }
  assert.equal(await evaluate('getComputedStyle(document.getElementById("map-fps-counter")).display'), 'block');
  await pause(550);
  assert.equal(await evaluate('document.getElementById("map-fps-counter").textContent'), '— FPS · parado');
  const glb = gunzipSync(await readFile(resolve(root, '.' + base + 'campus_exterior_standard.glb.gz')));
  const gltf = JSON.parse(glb.subarray(20, 20 + glb.readUInt32LE(12)));
  const expectedMeshes = gltf.nodes.filter(node => node.mesh !== undefined)
    .reduce((sum, node) => sum + gltf.meshes[node.mesh].primitives.length, 0);
  const expectedTriangles = gltf.nodes.filter(node => node.mesh !== undefined)
    .reduce((sum, node) => sum + gltf.meshes[node.mesh].primitives.reduce((sum, primitive) =>
      sum + gltf.accessors[primitive.indices ?? primitive.attributes.POSITION].count / 3, 0), 0);
  if (approvedDefaults) {
    const approved = normalizedMapFeatures({ lighting:true, pbr:true, shadows:true,
      shaders:true, sky:true, selection:true, windows:true });
    const startup = await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(startup.quality.sharpness,70,'Captured 70% sharpness is the default');
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).interfaceBlurEnabled,false);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).navBlurEnabled,false);
    await evaluate('whereIfMap.setMapQuality({sharpness:100,antialias:"off"})');
    const initial = await evaluate('whereIfMap.debugSnapshot()');
    assert.deepEqual(initial.features, approved, 'Captured S24 combination is the startup default');
    assert.equal(initial.postProcessingAllocated, false);
    assert.equal(initial.bloom,null);
    assert.equal(initial.quality.antialiasPass,null);
    assert.equal(initial.quality.sharpness,100);
    assert.equal(initial.quality.antialias,'off');
    assert.equal(initial.reflectionEnvironmentInstalled, false);
    assert.equal(initial.nightCinema.textures, false);
    assert.equal(initial.shadowsAllocated, true);
    assert.equal(initial.windows.mode,'basic');
    assert.equal(initial.windows.pointLights,0,'Default emission adds no lights');
    assert.ok(initial.windows.presets>0,'Exported window objects are prepared');
    assert.equal(initial.windows.litPresets,0,'Daytime windows stay off');
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floors.length, 3);
    const baselinePose=[initial.cameraPosition,initial.cameraTarget];
    await evaluate('document.getElementById("map-sharpness").value="75";document.getElementById("map-sharpness").dispatchEvent(new Event("change"))');
    for(let i=0;i<50;i++){
      if((await evaluate('whereIfMap.debugSnapshot()')).quality.sharpness===75)break;
      await pause(30);
    }
    const lower=await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(lower.quality.sharpness,75);
    assert.ok(Math.abs(lower.quality.pixelRatio-initial.quality.pixelRatio*.75)<.01,'Nitidez changes the actual drawing buffer');
    assert.deepEqual([lower.cameraPosition,lower.cameraTarget],baselinePose,'Resolution does not reset the camera');
    assert.deepEqual(lower.features,approved,'Quality controls do not alter lighting/effect switches');
    await evaluate('whereIfMap.setMapQuality({antialias:"light"})');
    await pause(100);
    const filtered=await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(filtered.quality.antialiasPass.mode,'light');
    assert.equal(filtered.postProcessingAllocated,false,'Antialias does not activate bloom or a compositor');
    assert.equal(filtered.quality.antialiasPass.passes,1);
    await evaluate('whereIfMap.setPreviewTimeMinutes(1320)');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).quality.antialias,'light','Climate changes retain the AA setting');
    const aaShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'approved-antialias-light.png'),Buffer.from(aaShot.data,'base64'));
    await evaluate('whereIfMap.setMapQuality({sharpness:125,antialias:"strong"})');
    await pause(100);
    const higher=await evaluate('whereIfMap.debugSnapshot()');
    assert.ok(higher.quality.pixelRatio>initial.quality.pixelRatio,'Higher sharpness really renders more pixels');
    assert.equal(higher.quality.antialiasPass.mode,'strong');
    await evaluate('whereIfMap.setMapQuality({sharpness:100,antialias:"off"});');
    await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
    const qualityReset=await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(qualityReset.quality.antialiasPass,null,'Turning AA off releases its texture/pass');
    assert.equal(qualityReset.quality.pixelRatio,initial.quality.pixelRatio,'100% restores the exact old native resolution');
    assert.deepEqual(qualityReset.features,approved);
    console.log('PASS: quality UI changes actual resolution, keeps camera/effects/climate and releases AA when off');
    const grassColors = state => state.materials.filter(m=>/grass|grama/i.test(m.name)).map(m=>m.color);
    const middayGrass = grassColors(initial);
    assert.ok(middayGrass.length > 0);
    const baselineFoliage = initial.materials.filter(m=>/^Material\./.test(m.name));
    for (const [name, minute, gain] of [['morning',360,.55],['sunset',1050,.95],['night',1320,1]]) {
      await evaluate(`whereIfMap.setPreviewTimeMinutes(${minute})`);
      await pause(120);
      const climate = await evaluate('whereIfMap.debugSnapshot()');
      const look = await evaluate('whereIfMap.visualTestSettings()');
      assert.deepEqual(climate.features, approved, 'Changing climate retains the captured switches');
      assert.deepEqual(climate.materials.filter(m=>/^Material\./.test(m.name)), baselineFoliage,
        'Tree materials are not recolored');
      const originalBoost = name==='night' ? 1 : look.sunHighlights;
      assert.ok(Math.abs(climate.nightCinema.sunHighlights-originalBoost*gain)<1e-6,
        `${name}: existing sunlight shader gain only`);
      if(name==='night') {
        assert.ok(climate.windows.litPresets>0,'Nighttime windows emit warm light');
        assert.equal(climate.windows.pointLights,0);
        assert.notDeepEqual(grassColors(climate),middayGrass,'Only nighttime grass is darker');
        await evaluate('whereIfMap.setPreviewTimeMinutes(1330)');
        assert.deepEqual(grassColors(await evaluate('whereIfMap.debugSnapshot()')),grassColors(climate),
          'Repeated night updates do not accumulate color changes');
      } else assert.deepEqual(grassColors(climate),middayGrass,'Daytime grass stays unchanged');
      if(name!=='night') assert.equal(climate.windows.litPresets,0,'No windows glow in daylight');
      const shot=await call('Page.captureScreenshot',{format:'png'});
      await writeFile(resolve(output,`approved-${name}.png`),Buffer.from(shot.data,'base64'));
    }
    await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
    const returned = await evaluate('whereIfMap.debugSnapshot()');
    assert.deepEqual(grassColors(returned),middayGrass,'Leaving night restores the exact grass color');
    assert.equal(returned.nightCinema.sunHighlights,initial.nightCinema.sunHighlights,
      'Afternoon shader brightness stays unchanged');
    const shot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'approved-midday.png'),Buffer.from(shot.data,'base64'));
    await evaluate('whereIfMap.setPreviewTimeMinutes(1320);whereIfMap.setMapTestFeature("windowLighting",true)');
    const complete = await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(complete.windows.mode,'full');
    assert.ok(complete.windows.pointLights>0 && complete.windows.pointLights<=4);
    assert.ok(complete.windows.activePointLights>0);
    assert.equal(complete.windows.pointLightShadows,0);
    assert.equal(complete.postProcessingAllocated,false);
    assert.equal(complete.reflectionEnvironmentInstalled,false);
    assert.deepEqual(complete.features,normalizedMapFeatures({...approved,windowLighting:true}));
    const completeShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'approved-windows-full.png'),Buffer.from(completeShot.data,'base64'));
    await evaluate('whereIfMap.setMapTestFeature("windowLighting",false)');
    assert.deepEqual((await evaluate('whereIfMap.debugSnapshot()')).features,approved);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).windows.pointLights,0,
      'Returning to basic releases all extra lights');
    await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
    console.log('PASS: approved startup without bloom/AA, no reflection/texture/grading, isolated dawn/dusk gains, darker night grass and unchanged tree/day materials');
    await evaluate('whereIfMap.setMapTestFeatures({lighting:true})');
  }
  const state = await evaluate('whereIfMap.debugSnapshot()');
  assert.equal(state.geometryOnly, true);
  assert.equal(state.modelMeshes, expectedMeshes, 'Every exported mesh is retained');
  assert.equal(state.modelTriangles, expectedTriangles, 'Geometry is not simplified or removed');
  assert.equal(state.postProcessingAllocated, false, 'No composer allocation');
  assert.equal(state.basicLightingTest, basicLighting);
  assert.equal(state.testStage, basicLighting ? 'basic-lighting' : 'raw');
  if (basicLighting) {
    assert.equal(state.keyLight.intensity, 2);
    assert.equal(state.keyLight.castShadow, false);
    assert.equal(state.hemisphereIntensity, 1);
    assert.ok(state.materials.every(material => material.type === 'MeshLambertMaterial'));
  } else {
    assert.equal(state.keyLight, null);
    assert.equal(state.hemisphereIntensity, null);
    assert.equal(state.shadow, null);
    assert.ok(state.materials.every(material => material.type === 'MeshBasicMaterial'));
  }
  assert.equal(state.ambientIntensity, null);
  assert.equal(state.fillLight, null);
  assert.equal(state.bloom, null);
  assert.equal(state.atmosphere.canvasSize, null);
  assert.equal(state.nightSky.generated, false);
  for (const sky of ['middaySky', 'sunsetSky', 'morningSky']) assert.equal(state[sky], null);
  assert.ok(state.materials.every(material => !material.proceduralTexture && !material.hasNormalTexture));
  assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floors.length, approvedDefaults ? 3 : 0,
    'Basic/raw startup does not prepare interiors; approved selection keeps its existing lazy navigation');
  const diagnostics = await evaluate('whereIfMap.diagnosticsSnapshot()');
  assert.equal(diagnostics.rawMode, true);
  assert.equal(diagnostics.shadowMapSize, 0);
  assert.equal(diagnostics.msaaSamples, 0);
  await evaluate("whereIfMap.setRawMode(false);whereIfMap.setLocalTimeMinutes(1260);whereIfMap.refreshMaterialFinish();whereIfMap.selectZone('bloco-central')");
  assert.equal((await evaluate('whereIfMap.diagnosticsSnapshot()')).rawMode, true);
  assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.active, false);
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', x: 180, y: 450, button: 'left', clickCount: 1 });
  await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 250, y: 450, button: 'left', buttons: 1 });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 250, y: 450, button: 'left', clickCount: 1 });
  await pause(700);
  assert.notDeepEqual((await evaluate('whereIfMap.debugSnapshot()')).cameraPosition, state.cameraPosition, 'Rotation works');
  if (featurePanel) {
    await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
    assert.equal(await evaluate('document.querySelectorAll("#map-feature-panel input[data-feature]").length'), mapFeatureTopics.length);
    assert.equal(await evaluate('document.querySelector("#map-feature-panel .feature-body").hidden'), true);
    await evaluate('document.querySelector("#map-feature-panel > button").click()');
    assert.equal(await evaluate('document.querySelector("#map-feature-panel .feature-body").hidden'), false);
    const ratio = (await evaluate('whereIfMap.diagnosticsSnapshot()')).pixelRatio;
    const stableCamera = (await evaluate('whereIfMap.debugSnapshot()')).cameraPosition;
    for (const [key] of mapFeatureTopics) {
      await evaluate(`whereIfMap.setMapTestFeatures({${key}:true})`);
      const active = await evaluate('whereIfMap.debugSnapshot()');
      assert.deepEqual(active.features, normalizedMapFeatures({ [key]: true }), key);
      assert.equal(active.postProcessingAllocated, key === 'grading' || key === 'bloom', key);
      assert.equal(active.reflectionEnvironmentInstalled, key === 'reflections', key);
      assert.equal(active.shadowsAllocated, key === 'shadows', key);
      assert.equal(active.selection.active, false);
      assert.equal(active.nightCinema?.textures ?? false, key === 'textures', key);
      assert.equal(active.nightCinema?.shaders ?? false, key === 'shaders', key);
      assert.equal(active.middaySky !== null, key === 'sky', key);
      assert.equal((await evaluate('whereIfMap.diagnosticsSnapshot()')).pixelRatio, ratio);
      assert.deepEqual(active.cameraPosition, stableCamera, 'Feature toggles do not reframe the camera');
      assert.deepEqual((await evaluate('window.messages')).filter(m => m.type === 'error'), [], key);
      if(key==='windows'||key==='windowLighting') {
        assert.equal(active.windows.mode,key==='windows'?'basic':'full');
        assert.equal(active.windows.pointLightShadows,0);
        assert.ok(active.windows.pointLights<=4);
      }
      await evaluate('whereIfMap.setMapTestFeatures({})');
      const raw = await evaluate('whereIfMap.debugSnapshot()');
      assert.equal(raw.modelMeshes, expectedMeshes, 'Reset restores every original mesh');
      assert.equal(raw.modelTriangles, expectedTriangles);
      assert.equal(raw.postProcessingAllocated, false);
      assert.equal(raw.reflectionEnvironmentInstalled, false);
      assert.equal(raw.shadowsAllocated, false);
      assert.equal(raw.nightCinema, undefined);
      assert.equal(raw.windows.pointLights,0); assert.equal(raw.windows.presets,0);
      assert.ok(raw.materials.every(material => material.type === 'MeshBasicMaterial'));
      console.log(`PASS: ${key} toggles independently and releases its effects on raw reset`);
    }
    await evaluate(`whereIfMap.setMapTestFeatures(${JSON.stringify(Object.fromEntries(mapFeatureTopics.map(([key])=>[key,true])))})`);
    await evaluate("whereIfMap.setPreviewTimeMinutes(1320);whereIfMap.setMapTestFeatures(whereIfMap.mapTestSnapshot().features)");
    const night = await evaluate('whereIfMap.debugSnapshot()');
    assert.equal(night.nightSky.visible, true);
    assert.ok(night.nightCinema.moonShafts >= 0);
    assert.ok(Object.values(night.features).every(Boolean));
    assert.deepEqual((await evaluate('window.messages')).filter(m => m.type === 'error'), []);
    await evaluate('document.querySelector("#map-feature-panel > button").click()');
    await evaluate("whereIfMap.selectZone('bloco-central')");
    await pause(800);
    for (let i=0;i<40 && (await evaluate('whereIfMap.debugSnapshot()')).cameraAnimating;i++) await pause(50);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.active, true, 'Exterior outline works with diagnostic rendering');
    const outline = (await evaluate('whereIfMap.debugSnapshot()')).selection.outline;
    assert.equal(outline.mode,'stencil-edge-ribbons');
    assert.equal(outline.textureTargets,0,'Selection creates no image-sized mask or edge targets');
    assert.equal(outline.textureSamples,0,'Selection performs no fullscreen texture filtering');
    assert.ok(outline.edges>0,'The actual selected geometry supplies its outline');
    assert.ok(outline.windowRows>0,'Separate exported window objects also fill the silhouette mask');
    assert.equal(outline.proxies,1,'All selected pieces/windows share one mask draw');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.animatedMaterials, 0,
      'Exterior pulse restores the real materials once finished');
    // Camera/color changes may rerasterize stencil, but must never rebuild
    // the edge geometry or allocate color targets.
    const restingFrame = () => evaluate('new Promise(resolve=>{whereIfMap.setVisible(true);requestAnimationFrame(()=>requestAnimationFrame(resolve))})');
    for (let i=0;i<2;i++) await restingFrame();
    const cachedOutline = (await evaluate('whereIfMap.debugSnapshot()')).selection.outline;
    assert.ok(cachedOutline.cachedGeometries>0,'Selected edge geometry is cached');
    for (let i=0;i<10;i++) await restingFrame();
    const reusedOutline = (await evaluate('whereIfMap.debugSnapshot()')).selection.outline;
    assert.equal(reusedOutline.geometryBuilds,cachedOutline.geometryBuilds,'Idle selection reuses its edge buffers');
    assert.equal(reusedOutline.geometryBytes,cachedOutline.geometryBytes,'Idle selection allocates no edge buffers');
    assert.ok(reusedOutline.composites > cachedOutline.composites, 'Color composition still renders');
    const selectionShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'selection-geometry-central.png'),Buffer.from(selectionShot.data,'base64'));
    console.log('PASS: native-resolution stencil/ribbon outline, zero texture filters/targets and cached geometry');
    const fullWindowsImmediately=await evaluate("(()=>{window.fullFloorTravel=whereIfMap.setInteriorFloor('bloco-central','central-p1');return whereIfMap.interiorSnapshot().exportedWindowPresetsVisible;})()");
    assert.equal(fullWindowsImmediately,false,'Windows hide before the exterior fade even with complete effects');
    await evaluate('window.fullFloorTravel');
    await pause(1000);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId, 'central-p1');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).windows.litPresets,0,
      'Window presets hide with the exterior during interior navigation');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).windows.activePointLights,0,
      'Complete window lights do not illuminate a hidden exterior');
    const roomPoint=(await evaluate('whereIfMap.interiorSnapshot()')).visibleSpaces.find(space=>space.nodeName==='sala_3_central');
    await call('Input.dispatchMouseEvent',{type:'mousePressed',x:roomPoint.x,y:roomPoint.y,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:roomPoint.x,y:roomPoint.y,button:'left',clickCount:1});
    await pause(800);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace, 'sala_3_central');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.active, true);
    const roomShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'selection-geometry-room.png'),Buffer.from(roomShot.data,'base64'));
    for (let i=0;i<40 && (await evaluate('whereIfMap.debugSnapshot()')).cameraAnimating;i++) await pause(50);
    await evaluate('whereIfMap.setInterfaceBlur(true);whereIfMap.setNavBlur(true)');
    const beforeSelectionOptions = await evaluate('whereIfMap.debugSnapshot()');
    const originalFeatures = (await evaluate('whereIfMap.mapTestSnapshot()')).features;
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).interfaceBlurEnabled,true);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).navBlurEnabled,true);
    await evaluate("document.querySelector('[data-nav-blur]').click()");
    await pause(80);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).navBlurEnabled,false);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).interfaceBlurEnabled,true);
    await evaluate("document.querySelector('[data-interface-blur]').click()");
    await pause(80);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).interfaceBlurEnabled,false);
    assert.equal((await evaluate('window.messages.filter(m=>m.type==="interfaceBlur").at(-1)')).enabled,false);
    assert.equal((await evaluate('window.messages.filter(m=>m.type==="navBlur").at(-1)')).enabled,false);
    assert.deepEqual((await evaluate('whereIfMap.mapTestSnapshot()')).features,originalFeatures);
    await evaluate("document.querySelector('[data-nav-blur]').click()");
    await evaluate("document.querySelector('[data-interface-blur]').click()");
    await pause(80);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).navBlurEnabled,true);
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).interfaceBlurEnabled,true);
    assert.equal(await evaluate('document.querySelectorAll("[data-selection-option]").length'), 10);
    await evaluate("document.querySelector('[data-selection-preset=basic]').click()");
    await pause(100);
    const basicSelection = await evaluate('whereIfMap.debugSnapshot()');
    assert.deepEqual(basicSelection.selection.options, selectionOptionsPreset('basic'));
    assert.equal(basicSelection.selection.active, true, 'Basic preserves the current selection');
    assert.equal(basicSelection.selection.animatedMaterials, 0, 'Basic uses the real room materials');
    assert.equal(basicSelection.selection.outline.proxies, 0, 'Basic removes the actual outline proxy');
    const basicDraws = basicSelection.selection.outline.composites;
    await restingFrame(); await restingFrame();
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.outline.composites, basicDraws,
      'Disabling outline eliminates its render calls, not just its opacity');
    assert.deepEqual(basicSelection.cameraPosition, beforeSelectionOptions.cameraPosition);
    assert.deepEqual(basicSelection.cameraTarget, beforeSelectionOptions.cameraTarget);
    assert.deepEqual((await evaluate('whereIfMap.mapTestSnapshot()')).features, originalFeatures);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace, 'sala_3_central');
    for (const [key] of selectionOptionTopics) {
      await evaluate(`(()=>{const input=document.querySelector('[data-selection-option=${key}]');input.checked=true;input.dispatchEvent(new Event('change'));})()`);
      await pause(450);
      assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.options[key], true, `${key} enables through its real UI`);
      await evaluate(`(()=>{const input=document.querySelector('[data-selection-option=${key}]');input.checked=false;input.dispatchEvent(new Event('change'));})()`);
      await pause(50);
      assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.options[key], false, `${key} disables independently`);
      assert.deepEqual((await evaluate('whereIfMap.debugSnapshot()')).cameraPosition, beforeSelectionOptions.cameraPosition);
      assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace, 'sala_3_central');
    }
    await evaluate("whereIfMap.setSelectionOptions({roomGlow:true})");
    assert.ok((await evaluate('whereIfMap.debugSnapshot()')).selection.animatedMaterials > 0,
      'Room glow alone attaches the colored shader, even without outline or pulse');
    await evaluate("whereIfMap.setSelectionOptions({roomGlow:false})");
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.animatedMaterials, 0);
    await evaluate("document.querySelector('[data-selection-preset=complete]').click()"); await pause(450);
    assert.deepEqual((await evaluate('whereIfMap.debugSnapshot()')).selection.options, selectionOptionsPreset('complete'));
    assert.equal((await evaluate('window.messages.filter(m=>m.type==="selectionOptions").at(-1)')).options.glass, true,
      'Native UI receives the glass / animation / visibility switches');
    await evaluate("document.querySelector('[data-selection-preset=basic]').click()"); await pause(100);
    await evaluate("whereIfMap.setInteriorFloor('bloco-central',null)");
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId, null, 'Exterior works without a fade');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.objectFades, 0);
    await evaluate("whereIfMap.setInteriorFloor('bloco-didatico','didatico-p2')");
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId, 'didatico-p2');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).cameraAnimating, false, 'Basic focus is immediate');
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.objectFades, 0);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.animatedMaterials, 0);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.outline.proxies, 0);
    await evaluate("whereIfMap.setInteriorFloor('bloco-didatico',null)");
    await evaluate("document.querySelector('[data-selection-preset=optimized]').click()"); await pause(50);
    assert.deepEqual((await evaluate('whereIfMap.debugSnapshot()')).selection.options, selectionOptionsPreset('optimized'));
    assert.deepEqual((await evaluate('whereIfMap.mapTestSnapshot()')).features, originalFeatures);
    assert.deepEqual((await evaluate('window.messages')).filter(m => m.type === 'error'), []);
    console.log('PASS: selection UI switches/presets independently remove actual render/shader/fade work; room/pose/lighting/quality survive; basic floor travel remains functional');
    await evaluate('whereIfMap.setMapTestFeatures({})');
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId, null);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).modelMeshes, expectedMeshes);
    await evaluate("document.querySelector('#map-feature-panel button[data-preset=basic]').click()");
    await pause(1000);
    assert.deepEqual((await evaluate('whereIfMap.mapTestSnapshot()')).features, normalizedMapFeatures({ lighting: true }));
    await evaluate('document.querySelector("#map-feature-panel > button").click()');
    const expanded=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'feature-panel.png'),Buffer.from(expanded.data,'base64'));
    await evaluate('document.querySelector("#map-feature-panel > button").click()');
    assert.equal(await evaluate('document.querySelector("#map-feature-panel .feature-body").hidden'), true);
    console.log('PASS: all effects together at night, floor navigation, raw reset, UI presets and panel collapse');

    const beforePerformance=await evaluate('({settings:whereIfMap.mapTestSnapshot(),quality:whereIfMap.debugSnapshot().quality,camera:whereIfMap.debugSnapshot().cameraPosition,time:whereIfMap.debugSnapshot().effectiveLocalTimeMinutes})');
    await evaluate('whereIfMap.setMapPerformanceMode(true)');
    const performance=await evaluate('({settings:whereIfMap.mapTestSnapshot(),quality:whereIfMap.debugSnapshot().quality,camera:whereIfMap.debugSnapshot().cameraPosition,time:whereIfMap.debugSnapshot().effectiveLocalTimeMinutes})');
    assert.equal(performance.settings.performanceModeEnabled,true);
    assert.deepEqual(performance.settings.features,performanceMapPreset.features);
    assert.deepEqual(performance.settings.selectionOptions,performanceMapPreset.selectionOptions);
    assert.equal(performance.quality.sharpness,65);assert.equal(performance.quality.antialias,'off');
    assert.equal(performance.settings.interfaceBlurEnabled,false);assert.equal(performance.settings.navBlurEnabled,false);
    assert.deepEqual(performance.camera,beforePerformance.camera);assert.equal(performance.time,beforePerformance.time);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).exportedWindowPresetsVisible,true,'GLB windows exist even when their light feature is off');
    const immediateWindows=await evaluate(`(()=>{window.floorTravel=whereIfMap.setInteriorFloor('bloco-didatico','didatico-p2');return whereIfMap.interiorSnapshot().exportedWindowPresetsVisible;})()`);
    assert.equal(immediateWindows,false,'Every exported window preset hides immediately before floor preparation, with no fade');
    await evaluate('window.floorTravel');
    const colors=(await evaluate('whereIfMap.interiorSnapshot()')).spaceColors;
    const color=name=>colors.find(space=>space.nodeName===name).colors;
    assert.notDeepEqual(color('sala_1_did'),color('lab_0_did'),'Rooms and labs have distinct passive colors');
    assert.notDeepEqual(color('lab_0_did'),color('wc_fem_didatico_p2'),'Bathrooms keep their own passive color');
    await evaluate(`whereIfMap.setMapTestFeatures(${JSON.stringify(performanceMapPreset.features)})`);
    await evaluate("whereIfMap.setInteriorFloor('bloco-didatico','didatico-p2')");
    assert.deepEqual((await evaluate('whereIfMap.interiorSnapshot()')).spaceColors,colors,'A graphics rebuild does not erase prepared room colors');
    await evaluate("whereIfMap.setInteriorFloor('bloco-didatico',null)");
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).exportedWindowPresetsVisible,true,'Exterior restores the original window visibility');
    await call('Page.reload');await pause(400);
    let performanceReloadReady=false;
    for(let i=0;i<150;i++){
      performanceReloadReady=await evaluate('Boolean(window.messages?.some(m=>m.type==="ready"))');
      if(performanceReloadReady)break;await pause(200);
    }
    assert.ok(performanceReloadReady,'Performance preset reloads');
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).performanceModeEnabled,true);
    assert.deepEqual((await evaluate('whereIfMap.mapTestSnapshot()')).features,performanceMapPreset.features);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).quality.sharpness,65);
    await call('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?mode=normal`});await pause(400);
    let nativeNormalReady=false;
    for(let i=0;i<150;i++){
      nativeNormalReady=await evaluate('Boolean(window.messages?.some(m=>m.type==="ready"))');
      if(nativeNormalReady)break;await pause(200);
    }
    assert.ok(nativeNormalReady,'Native Settings choice overrides saved performance mode before startup');
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).performanceModeEnabled,false);
    const normalAgain=await evaluate('({settings:whereIfMap.mapTestSnapshot(),quality:whereIfMap.debugSnapshot().quality})');
    assert.deepEqual(normalAgain.settings.features,beforePerformance.settings.features);
    assert.deepEqual(normalAgain.settings.selectionOptions,beforePerformance.settings.selectionOptions);
    assert.equal(normalAgain.quality.sharpness,beforePerformance.quality.sharpness);
    assert.equal(normalAgain.settings.interfaceBlurEnabled,beforePerformance.settings.interfaceBlurEnabled);
    assert.equal(normalAgain.settings.navBlurEnabled,beforePerformance.settings.navBlurEnabled);
    await evaluate('Promise.all([whereIfMap.setMapPerformanceMode(true),whereIfMap.setMapPerformanceMode(false),whereIfMap.setMapPerformanceMode(true)])');
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).performanceModeEnabled,true,'Rapid mode toggles resolve in order');
    await evaluate('whereIfMap.setMapQuality({sharpness:66})');
    assert.equal((await evaluate('whereIfMap.mapTestSnapshot()')).performanceModeEnabled,false,'Manual graphics customization leaves the named preset');
    assert.equal((await evaluate('window.messages.filter(m=>m.type==="performanceMode").at(-1)')).source,'customization');
    assert.deepEqual((await evaluate('window.messages')).filter(m=>m.type==='error'),[]);
    console.log('PASS: exact captured performance preset, persistent reload, normal restoration, ordered toggles, immediate windows and restored room/lab/bathroom colors');
    const roomLocation={institutionId:'ifpr-pgua',zoneId:'bloco-didatico',floorId:'didatico-p2',spaceNodeName:'sala_1_did',label:'Sala 1'};
    const floorLocation={institutionId:'ifpr-pgua',zoneId:'bloco-didatico',floorId:'didatico-p1',label:'Piso 1'};
    const blockLocation={institutionId:'ifpr-pgua',zoneId:'quadra',label:'Quadra'};
    const markerFixture=[
      {eventId:'room-event',title:'Mostra de projetos desenvolvidos pelos estudantes',imageUrl:'assets/institutions/ifpr-pgua/event_banners/arts_culture.png',color:'#ad83ef',foreground:'#151015',locations:[roomLocation,blockLocation]},
      {eventId:'second-room-event',title:'Oficina de desenho',color:'#ad83ef',foreground:'#151015',locations:[roomLocation]},
      {eventId:'floor-event',title:'Encontro no piso',color:'#ad83ef',foreground:'#151015',locations:[floorLocation]},
    ];
    await evaluate(`whereIfMap.setEventMarkers(${JSON.stringify(markerFixture)})`);await pause(100);
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).groups,2,'Exterior groups events by block, not by interior room');
    await evaluate('document.querySelector(".map-event-card").click()');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).expanded,null,'Exterior no longer opens event cards');
    const selectedEvent=await evaluate('messages.filter(m=>m.type==="eventSelected").at(-1)');
    assert.equal(selectedEvent.zoneId,'bloco-didatico');assert.equal(selectedEvent.eventIds.length,3);
    assert.equal(selectedEvent.mode,'exterior');
    // Regression: event travel from 2D must never save the top-view orbit lock
    // as the exterior limits. Exercise both a multi-floor and a curved block.
    for(const [zoneId,floorId] of [['bloco-didatico','didatico-p2'],['bloco-central','central-p1']]){
      const destination={institutionId:'ifpr-pgua',zoneId,floorId,label:'Piso'};
      await evaluate('whereIfMap.setMapViewMode("2d")');await pause(800);
      assert.equal(await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(destination)})`),true);
      await pause(1100);
      assert.equal((await evaluate('whereIfMap.debugSnapshot()')).viewMode,'3d');
      await evaluate(`whereIfMap.setInteriorFloor(${JSON.stringify(zoneId)},null)`);await pause(1100);
      const exteriorCamera=await evaluate('whereIfMap.debugSnapshot()');
      assert.equal(exteriorCamera.cameraProjection,'perspective');assert.equal(exteriorCamera.viewMode,'3d');
      assert.ok(exteriorCamera.polarLimits[0]>.1 && exteriorCamera.polarLimits[1]>.5,'Exterior restores 3D orbit limits, not the 2D polar lock');
      const inclination=state=>Math.atan2(Math.hypot(state.cameraPosition[0]-state.cameraTarget[0],state.cameraPosition[2]-state.cameraTarget[2]),state.cameraPosition[1]-state.cameraTarget[1]);
      assert.ok(inclination(exteriorCamera)>.15,'Exterior pose is not a stuck vertical 2D-like view');
      await restingFrame();await restingFrame();
      assert.ok(inclination(await evaluate('whereIfMap.debugSnapshot()'))>.15,'OrbitControls cannot snap the restored angle back to vertical');
      await evaluate(`whereIfMap.setMapViewMode('2d')`);await pause(800);
      await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(destination)})`);await pause(1100);
      const emptyPoint=await emptyCampusPoint();
      assert.ok(emptyPoint,'Find an actual empty campus point, not a balloon or the floor');
      await call('Input.dispatchMouseEvent',{type:'mousePressed',...emptyPoint,button:'left',clickCount:1});
      await call('Input.dispatchMouseEvent',{type:'mouseReleased',...emptyPoint,button:'left',clickCount:1});
      await pause(650);
      assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,null,'Outside tap exits the entire interior');
      assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.zoneId,null,'Outside tap also deselects the block');
      assert.equal((await evaluate('messages.filter(m=>m.type==="selected").at(-1)')).zoneId,undefined,'Native floor pill receives deselection');
      assert.equal((await evaluate('whereIfMap.debugSnapshot()')).viewMode,'3d');
    }
    console.log('PASS: 2D event-floor travel, exterior return with valid stable 3D limits and outside-tap deselection in Didatico/Central');
    assert.equal(await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify({...roomLocation,spaceNodeName:null,label:'Piso 2'})})`),true);
    await pause(900);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,'didatico-p2');
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,null,'Building event visit opens a whole floor, not an arbitrary room');
    await evaluate('whereIfMap.setMapViewMode("2d")');await pause(800);
    assert.equal(await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(roomLocation)})`),true);
    await pause(1200);
    const eventRoom=await evaluate('({interior:whereIfMap.interiorSnapshot(),debug:whereIfMap.debugSnapshot(),markers:whereIfMap.eventMarkersSnapshot()})');
    assert.equal(eventRoom.interior.floorId,'didatico-p2');assert.equal(eventRoom.interior.selectedSpace,'sala_1_did');
    assert.equal(eventRoom.debug.viewMode,'3d');assert.equal(eventRoom.interior.exportedWindowPresetsVisible,false);
    assert.equal(eventRoom.markers.groups,1,'Interior only shows the events relevant to the current floor');
    assert.deepEqual(eventRoom.markers.modes,['place']);
    assert.equal(eventRoom.markers.photos[0].count,2,'Two events in one room remain one balloon');
    assert.ok(eventRoom.markers.photos[0].loaded,'Bundled event image loads in its circular photo');
    await call('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});
    for(const startsOnPopup of [false,true]){
      const popupPoint=await evaluate(`(()=>{const b=[...document.querySelectorAll('.map-event-anchor:not([data-retiring]) > button')].find(b=>!b.hidden&&!b.inert&&!b.parentElement.hidden&&!b.parentElement.inert);if(!b)return null;const r=b.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
      assert.ok(popupPoint);
      const first=startsOnPopup?{x:popupPoint.x-10,y:popupPoint.y}:await emptyCampusPoint();
      const second={x:popupPoint.x+10,y:popupPoint.y};assert.ok(first);
      const eventCount=await evaluate('messages.filter(m=>m.type==="eventSelected").length');
      await evaluate(`window.pinchEnds=[];window.pinchTrace=[];window.recordPinchTrace=e=>pinchTrace.push({type:e.type,target:e.target.tagName,cls:e.target.className,id:e.pointerId,primary:e.isPrimary});for(const t of ['pointerdown','pointerup','pointercancel'])document.addEventListener(t,recordPinchTrace,true);window.recordPinchEnd=()=>pinchEnds.push({count:whereIfMap.mapTestSnapshot().gesturePointers,multi:whereIfMap.mapTestSnapshot().multiTouchGesture,locked:whereIfMap.eventMarkersSnapshot().cameraGestureActive});document.addEventListener('pointerup',recordPinchEnd);`);
      await call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...first,id:11}]});
      await call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...first,id:11},{...second,id:12}]});
      const during=await evaluate('({count:whereIfMap.mapTestSnapshot().gesturePointers,multi:whereIfMap.mapTestSnapshot().multiTouchGesture,locked:whereIfMap.eventMarkersSnapshot().cameraGestureActive})');
      assert.deepEqual(during,{count:2,multi:true,locked:true},'Both pinch fingers are owned by the map: '+JSON.stringify({startsOnPopup,first,second,trace:await evaluate('pinchTrace'),errors:await evaluate('messages.filter(m=>m.type==="error")')}));
      assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor:not([data-retiring]) > button")).pointerEvents'),'none');
      await call('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:Math.max(4,first.x-8),y:first.y,id:11},{x:second.x+8,y:second.y,id:12}]});await pause(90);
      await call('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await pause(250);
      const ended=await evaluate('({count:whereIfMap.mapTestSnapshot().gesturePointers,multi:whereIfMap.mapTestSnapshot().multiTouchGesture,locked:whereIfMap.eventMarkersSnapshot().cameraGestureActive})');
      assert.deepEqual(ended,{count:0,multi:false,locked:false},'Pinch release restores normal popup interaction');
      const lifts=await evaluate('pinchEnds');assert.equal(lifts.length,2);
      assert.deepEqual(lifts[0],{count:1,multi:true,locked:true},'Lifting one finger cannot turn the remaining pinch into a tap');
      assert.equal(await evaluate('messages.filter(m=>m.type==="eventSelected").length'),eventCount,'Pinch cannot accidentally choose an event');
      assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,'didatico-p2');
      assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,'sala_1_did');
      await evaluate('document.removeEventListener("pointerup",recordPinchEnd);for(const t of ["pointerdown","pointerup","pointercancel"])document.removeEventListener(t,recordPinchTrace,true)');
      await evaluate(`whereIfMap.setPreviewCamera(${JSON.stringify({position:eventRoom.debug.cameraPosition,target:eventRoom.debug.cameraTarget,constrain:false})})`);await pause(300);
    }
    console.log('PASS: real pinch from canvas/popup and popup/popup, independent finger release, no accidental selection and restored hit targets');
    await evaluate('document.querySelector(".map-event-anchor > .map-event-card").click()');
    const fanShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,'room-event-stack.png'),Buffer.from(fanShot.data,'base64'));
    const fanOutsidePoint=await emptyCampusPoint();assert.ok(fanOutsidePoint);
    await call('Input.dispatchMouseEvent',{type:'mousePressed',...fanOutsidePoint,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',...fanOutsidePoint,button:'left',clickCount:1});await pause(250);
    const dismissedFan=await evaluate('({floor:whereIfMap.interiorSnapshot().floorId,space:whereIfMap.interiorSnapshot().selectedSpace,debug:whereIfMap.debugSnapshot(),expanded:whereIfMap.eventMarkersSnapshot().expanded})');
    assert.equal(dismissedFan.expanded,null,'Outside press closes the open event fan');
    assert.equal(dismissedFan.floor,'didatico-p2','Closing the fan cannot leave the floor');
    assert.equal(dismissedFan.space,'sala_1_did','Closing the fan cannot clear the selected room');
    assert.ok(dismissedFan.debug.selection.active,'Closing the fan preserves the block/room outline');
    for(const key of ['cameraPosition','cameraTarget'])dismissedFan.debug[key].forEach((v,i)=>assert.ok(Math.abs(v-eventRoom.debug[key][i])<.001,'Closing the fan preserves the camera'));
    await call('Input.dispatchMouseEvent',{type:'mousePressed',...fanOutsidePoint,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',...fanOutsidePoint,button:'left',clickCount:1});await pause(650);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,null,'A separate second outside tap still leaves the floor');
    // Reopen the same room/stack to retain independent event-choice coverage.
    await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(roomLocation)})`);await pause(1100);
    await evaluate('document.querySelector(".map-event-anchor > .map-event-card").click()');
    await evaluate('document.querySelectorAll(".map-event-fan .map-event-card")[1].click()');
    const secondChoice=await evaluate('messages.filter(m=>m.type==="eventSelected").at(-1)');
    assert.equal(secondChoice.eventId,'second-room-event');assert.equal(secondChoice.mode,'place');
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).expanded,null);
    assert.equal(await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(floorLocation)})`),true);
    await pause(1000);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,'didatico-p1');
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,null,'A floor-wide event does not select an arbitrary room');
    assert.equal(await evaluate(`whereIfMap.navigateToMapLocation(${JSON.stringify(blockLocation)})`),true);await pause(1000);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,null);
    assert.equal((await evaluate('whereIfMap.debugSnapshot()')).selection.zoneId,'quadra');
    assert.equal(await evaluate('whereIfMap.navigateToMapLocation({zoneId:"bloco-didatico",floorId:"gone"})'),false,'Stale destinations fail safely');
    const latestNavigation=await evaluate(`Promise.all([whereIfMap.navigateToMapLocation(${JSON.stringify(roomLocation)}),whereIfMap.navigateToMapLocation(${JSON.stringify(blockLocation)})])`);
    assert.deepEqual(latestNavigation,[false,true],'Rapid event navigation visits only the latest destination');
    await evaluate('whereIfMap.setEventMarkers([])');await pause(50);
    assert.equal((await evaluate('whereIfMap.eventMarkersSnapshot()')).groups,0);
    assert.deepEqual((await evaluate('window.messages')).filter(m=>m.type==='error'),[]);
    console.log('PASS: block balloons, circular photos, stacked events and side-by-side choices, 2D to room, floor-wide/exterior visits and stale/rapid destination safety');
  }
  const shot = await call('Page.captureScreenshot', { format: 'png' });
  await writeFile(resolve(output, 'raw-map.png'), Buffer.from(shot.data, 'base64'));
  console.log(JSON.stringify({ meshes: expectedMeshes, triangles: expectedTriangles, diagnostics }, null, 2));
  console.log(`PASS: ${basicLighting ? 'Lambert + hemisphere + one directional light' : 'unlit raw model'}; full geometry, no sky/shadows/extra material treatment/post-processing/interior setup; rotation works.`);
} finally {
  socket?.close(); chrome.kill(); server.close();
}
