// Reversible A/B diagnosis in an already-open Android WebView. No APK changes.
// Captures the existing renderer through a one-shot debugger breakpoint, keeps
// camera/materials/DPR fixed, and restores the render function after each run.
const port = Number(process.argv[2] ?? 9234);
const motion = process.argv.includes('--motion');
const bloomMode = process.argv.includes('--bloom');
const compareOutlines = process.argv.includes('--compare-outlines');
const profileSelectionUi = process.argv.includes('--selection-ui');
const profileEdgeDetail = process.argv.includes('--edge-detail');
const viewIndex = process.argv.indexOf('--view');
const comparisonView = viewIndex >= 0 ? JSON.parse(process.argv[viewIndex + 1]) : null;
const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html') &&
  JSON.parse(p.description || '{}').attached);
if (!page) throw new Error('Open the map and select a building first.');
const url = new URL(page.webSocketDebuggerUrl);
url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let seq = 0;
const pending = new Map();
const scripts = [];
let onPause;
socket.addEventListener('message', ({ data }) => {
  const m = JSON.parse(data);
  if (m.method === 'Debugger.scriptParsed') scripts.push(m.params);
  if (m.method === 'Debugger.paused') onPause?.(m.params);
  if (m.id) {
    const entry = pending.get(m.id);
    pending.delete(m.id);
    m.error ? entry?.reject(m.error) : entry?.resolve(m.result);
  }
});
const call = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++seq;
  pending.set(id, { resolve, reject });
  socket.send(JSON.stringify({ id, method, params }));
});
const evaluate = async expression => {
  const r = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
};
let breakpoint;
try {
  const initial = await evaluate('whereIfMap.debugSnapshot()');
  if (!bloomMode && !initial.selection.active) throw new Error('A building must already be selected.');
  if (compareOutlines && initial.selection.outline?.mode !== 'stencil-edge-ribbons') {
    throw new Error('Install the geometry-outline version before comparing it with the legacy path.');
  }
  if (bloomMode && (!initial.features?.bloom || initial.features.grading)) {
    throw new Error('Enable only bloom post-processing before its A/B profile.');
  }
  await call('Debugger.enable');
  const script = scripts.find(s => s.url.includes('viewer.bundle.js'));
  if (!script) throw new Error('Viewer bundle not found.');
  const { scriptSource } = await call('Debugger.getScriptSource', { scriptId: script.scriptId });
  const edgeConstructor=scriptSource.match(/const lines = new (\w+)\(source\.geometry/)?.[1];
  if(profileEdgeDetail&&!edgeConstructor)throw new Error('Cannot identify the bundled edge geometry class.');
  const needle = 'function renderSceneWithSelection() {';
  const offset = scriptSource.indexOf(needle);
  if (offset < 0) throw new Error('Render function not found.');
  const lineNumber = scriptSource.slice(0, offset).split('\n').length;
  const paused = new Promise(resolve => { onPause = resolve; });
  breakpoint = (await call('Debugger.setBreakpoint', {
    location: { scriptId: script.scriptId, lineNumber },
  })).breakpointId;
  const trigger = evaluate('whereIfMap.setVisible(true)');
  const pause = await paused;
  const capture = await call('Debugger.evaluateOnCallFrame', {
    callFrameId: pause.callFrames[0].callFrameId,
    expression: `window.__selectionCostProbe = async function () {
      const comparisonView = ${JSON.stringify(comparisonView)};
      if (comparisonView) {
        camera.position.fromArray(comparisonView.position);
        controls.target.fromArray(comparisonView.target);
        camera.lookAt(controls.target); camera.updateMatrixWorld();
        cameraFocus=null;resettingCamera=null;navigationSpring=null;
        if (bloomPass && activeDaylightProfile) updateDaylightBloom(activeDaylightProfile);
      }
      const originalRender = renderer.render;
      const originalOutlineDraw = selectionOutline.draw;
      const featureReference = testFeatures;
      const selectionReference = selectionState;
      const savedUiZone = selectedZoneId;
      let legacyOutline = null;
      const ribbonMesh=${profileEdgeDetail}?selectionOutline.scene.children[0]:null;
      const originalRibbonGeometry=ribbonMesh?.geometry;
      const detailGeometries=new Map();
      if(${profileEdgeDetail})for(const angle of [1,15,30]) {
        const segments=[];const point=new (camera.position.constructor)();
        selectionOutline.selectedNode.traverseVisible(source=>{
          if(!source.isMesh||source.userData.interiorSpace?.marker===source)return;
          const edges=new ${edgeConstructor??'Object'}(source.geometry,angle),a=edges.getAttribute('position');
          for(let i=0;i<a.count;i++){point.fromBufferAttribute(a,i).applyMatrix4(source.matrixWorld);segments.push(point.x,point.y,point.z);}
          edges.dispose();
        });
        const count=segments.length/6,g=new (originalRibbonGeometry.constructor)();
        g.setAttribute('position',originalRibbonGeometry.getAttribute('position').clone());g.setIndex(originalRibbonGeometry.index.clone());
        const starts=new Float32Array(count*3),ends=new Float32Array(count*3);
        for(let i=0;i<count;i++)for(let c=0;c<3;c++){starts[i*3+c]=segments[i*6+c];ends[i*3+c]=segments[i*6+3+c];}
        const Attribute=originalRibbonGeometry.getAttribute('edgeStart').constructor;
        g.setAttribute('edgeStart',new Attribute(starts,3));g.setAttribute('edgeEnd',new Attribute(ends,3));
        g.instanceCount=count;detailGeometries.set('detail-'+angle,g);
      }
      if (${compareOutlines}) {
        legacyOutline=createTextureSelectionOutline(renderer);
        legacyOutline.select(selectionOutline.selectedNode);
        for (const key of ['outlineColor','outlineOpacity','outlineWidth']) {
          legacyOutline.material.uniforms[key]=selectionOutline.material.uniforms[key];
        }
      }
      const overlayScene = typeof selectionOutline !== 'undefined' ? selectionOutline.scene : outlineScene;
      const originalAutoReset = renderer.info.autoReset;
      const savedBloomFlag = testFeatures.bloom;
      const savedBloomEnabled = bloomPass?.enabled;
      if (${bloomMode} && bloomPass) bloomPass.enabled = true;
      const gl = renderer.getContext();
      const timerExtension=gl.getExtension('EXT_disjoint_timer_query_webgl2');
      const results = [];
      const savedPosition = camera.position.clone();
      const savedTarget = controls.target.clone();
      const offset = savedPosition.clone().sub(savedTarget);
      const movingOffset = offset.clone();
      const up = offset.clone().set(0,1,0);
      let frameIndex = 0;
      const move = () => {
        if (!${motion}) return;
        movingOffset.copy(offset).applyAxisAngle(up, Math.sin(frameIndex++ * .031) * .10);
        camera.position.copy(savedTarget).add(movingOffset);
        camera.lookAt(savedTarget); camera.updateMatrixWorld();
      };
      let stage = 'full';
      let calls = [];
      const frame = () => new Promise(resolve => requestAnimationFrame(resolve));
      const quantile = (values, q) => [...values].sort((a,b)=>a-b)[Math.floor((values.length-1)*q)];
      setVisible(false);
      renderer.info.autoReset = false;
      renderer.render = function (s,c) {
        if (!${bloomMode} && (stage==='without-outline'||stage.startsWith('without-mask-or-outline')) &&
          (s === overlayScene || s.userData.selectionComposite)) return;
        if (stage.startsWith('without-mask-or-outline') &&
          (s.userData.selectionMask || c.layers.mask === 2)) return;
        originalRender.call(this,s,c);
      };
      try {
        const before = { camera: camera.position.toArray(), target: controls.target.toArray(),
          bloomSettings: bloomPass ? {strength:bloomPass.strength,radius:bloomPass.radius,threshold:bloomPass.threshold} : null,
          dpr: renderer.getPixelRatio(),
          width: gl.drawingBufferWidth, height: gl.drawingBufferHeight,
          selectedMeshes: selectedMeshes.length, fades: objectFades.size,
          activeFades: [...objectFades].filter(f=>Number.isFinite(f.startedAt)).length,
          zone: selectedZoneId, floor: interiors?.current?.id ?? null,
          motion: ${motion},
          shadows: renderer.shadowMap.enabled, composer: !!effectComposer,
          features: {...testFeatures} };
        for (const pass of ${JSON.stringify(profileEdgeDetail ? ['full','detail-1','detail-15','detail-30','detail-30','full']
          : profileSelectionUi ? ['full','without-flutter-ui','without-mask-or-outline-and-flutter-ui','without-mask-or-outline-and-flutter-ui','without-flutter-ui','full']
          : compareOutlines ? ['legacy','full','without-mask-or-outline','without-mask-or-outline','full','legacy']
          : bloomMode ? ['without-bloom','full','full','without-bloom']
          : ['full','without-outline','without-mask-or-outline','without-mask-or-outline','without-outline','full'])}) {
          stage = pass;
          if(ribbonMesh)ribbonMesh.geometry=detailGeometries.get(pass)??originalRibbonGeometry;
          if (${profileSelectionUi}) {
            send('selected',pass==='full'?{zoneId:savedUiZone}:{});
          }
          if(legacyOutline)selectionOutline.draw=pass==='legacy'?legacyOutline.draw:originalOutlineDraw;
          if (${bloomMode}) testFeatures.bloom = pass !== 'without-bloom';
          frameIndex = 0;
          for (let i=0;i<${profileSelectionUi ? 42 : 12};i++) { await frame(); move(); renderSceneWithSelection(); }
          gl.finish();
          const intervals=[], submission=[], gpuQueries=[];
          calls=[];
          let previous = await frame();
          const start = performance.now();
          const sampleCount = ${bloomMode ? 300 : compareOutlines || profileSelectionUi || profileEdgeDetail ? 180 : 100};
          for (let i=0;i<sampleCount;i++) {
            const timestamp = await frame();
            if(testFeatures!==featureReference||selectionState!==selectionReference)
              throw new Error('Controls changed during the profile; this measurement is invalid.');
            intervals.push(timestamp-previous); previous=timestamp;
            renderer.info.reset();
            move();
            const query=timerExtension && i%12===0 ? gl.createQuery() : null;
            if(query)gl.beginQuery(timerExtension.TIME_ELAPSED_EXT,query);
            const t=performance.now(); renderSceneWithSelection();
            submission.push(performance.now()-t);
            if(query){gl.endQuery(timerExtension.TIME_ELAPSED_EXT);gpuQueries.push(query);}
            calls.push(renderer.info.render.calls);
          }
          gl.finish();
          const elapsed=performance.now()-start;
          const gpuTimes=[];
          const disjoint=timerExtension && gl.getParameter(timerExtension.GPU_DISJOINT_EXT);
          for(const query of gpuQueries){
            if(!disjoint&&gl.getQueryParameter(query,gl.QUERY_RESULT_AVAILABLE))
              gpuTimes.push(gl.getQueryParameter(query,gl.QUERY_RESULT)/1e6);
            gl.deleteQuery(query);
          }
          const synchronized=[];
          for (let i=0;i<30;i++) {
            await frame();
            gl.finish();
            move();
            const t=performance.now(); renderSceneWithSelection(); gl.finish();
            synchronized.push(performance.now()-t);
          }
          const row={pass, fps:Math.round(sampleCount*1000/elapsed*10)/10,
            ribbonInstances:ribbonMesh?.geometry.instanceCount,
            frameMedianMs:quantile(intervals,.5), frameP90Ms:quantile(intervals,.9),
            cpuSubmissionMedianMs:quantile(submission,.5),
            cpuPlusGpuSyncMedianMs:quantile(synchronized,.5),
            gpuMedianMs:gpuTimes.length?quantile(gpuTimes,.5):null,
            drawCalls:quantile(calls,.5)};
          results.push(row);
        }
        camera.position.copy(savedPosition); camera.lookAt(savedTarget); camera.updateMatrixWorld();
        return {before,results,bloom:typeof mobileBloom!=='undefined'?mobileBloom?.snapshot():null,
          outline:typeof selectionOutline!=='undefined'?selectionOutline.snapshot():null,
          legacyOutline:legacyOutline?.snapshot(),
          after:{camera:camera.position.toArray(),dpr:renderer.getPixelRatio()}};
      } finally {
        camera.position.copy(savedPosition); camera.lookAt(savedTarget); camera.updateMatrixWorld();
        renderer.render=originalRender;
        selectionOutline.draw=originalOutlineDraw;
        legacyOutline?.dispose();
        if(ribbonMesh)ribbonMesh.geometry=originalRibbonGeometry;
        for(const g of detailGeometries.values())g.dispose();
        if (${profileSelectionUi} && selectionState===selectionReference && savedUiZone)
          send('selected',{zoneId:savedUiZone});
        renderer.info.autoReset=originalAutoReset;
        if (${bloomMode} && testFeatures===featureReference) {
          testFeatures.bloom=savedBloomFlag;
          if (bloomPass) bloomPass.enabled=savedBloomEnabled;
        }
        setVisible(true);
      }
    }; true`, returnByValue: true,
  });
  if (capture.exceptionDetails) throw new Error(JSON.stringify(capture.exceptionDetails));
  await call('Debugger.removeBreakpoint', { breakpointId: breakpoint });
  breakpoint = null;
  await call('Debugger.resume');
  await trigger;
  await call('Debugger.disable');
  console.log(JSON.stringify(await evaluate('window.__selectionCostProbe()'), null, 2));
} finally {
  if (breakpoint) await call('Debugger.removeBreakpoint', { breakpointId: breakpoint }).catch(()=>{});
  await call('Debugger.resume').catch(()=>{});
  await evaluate('delete window.__selectionCostProbe').catch(()=>{});
  await call('Debugger.disable').catch(()=>{});
  socket.close();
}
