// Reversible measurements in the live Android WebView. Captures the renderer
// from its closure without depending on whether the shipped bundle is minified.
// Temporary feature/resolution comparisons are restored, not adopted as fixes.
import { writeFileSync } from 'node:fs';
const port = Number(process.argv[2] ?? 9234);
const label=process.argv.includes('--label')?process.argv[process.argv.indexOf('--label')+1]:'runtime';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Invalid output label');
const comparisonView=process.argv.includes('--view')?JSON.parse(process.argv[process.argv.indexOf('--view')+1]):null;
const pages = await (await fetch(`http://127.0.0.1:${port}/json`, {signal:AbortSignal.timeout(10000)})).json();
const page = pages.find(p => p.url.includes('/map/viewer/index.html') && JSON.parse(p.description || '{}').attached);
if (!page) throw Error('Open the map in the app first.');
const url = new URL(page.webSocketDebuggerUrl); url.host = `127.0.0.1:${port}`;
const socket = new WebSocket(url);
await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
let sequence=0, onPause, breakpoint; const pending=new Map(), scripts=[];
socket.addEventListener('message',({data})=>{
  const message=JSON.parse(data);
  if(message.method==='Debugger.scriptParsed')scripts.push(message.params);
  if(message.method==='Debugger.paused')onPause?.(message.params);
  const request=pending.get(message.id); if(!request)return;
  pending.delete(message.id);clearTimeout(request.timer);
  message.error?request.reject(message.error):request.resolve(message.result);
});
const call=(method,params={},timeout=15000)=>new Promise((resolve,reject)=>{
  const id=++sequence,timer=setTimeout(()=>{pending.delete(id);reject(Error(method+' timed out'));},timeout);
  pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
});
const evaluate=async expression=>{
  const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true},120000);
  if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;
};
try {
  const sources=await evaluate('({diag:whereIfMap.diagnosticsSnapshot.toString(),debug:whereIfMap.debugSnapshot.toString()})');
  const renderer=sources.diag.match(/pixelRatio:\s*(\w+)\.getPixelRatio/)[1];
  const camera=sources.debug.match(/cameraPosition:\s*(\w+)\.position/)[1];
  const controls=sources.debug.match(/cameraTarget:\s*(\w+)\.target/)[1];
  await call('Debugger.enable');
  const script=scripts.find(s=>s.url.includes('viewer.bundle.js'));
  if(!script)throw Error('Viewer script not found');
  const {scriptSource}=await call('Debugger.getScriptSource',{scriptId:script.scriptId});
  const needle=new RegExp(`${renderer}\\.render\\((\\w+),\\s*${camera}\\)`,'g');
  const renderCalls=[...scriptSource.matchAll(needle)];
  if(!renderCalls.length)throw Error('Scene render not found');
  const finalCall=renderCalls.at(-1), scene=finalCall[1];
  const draw=[...scriptSource.slice(0,finalCall.index).matchAll(/function (\w+)\(/g)].at(-1)[1];
  const {result:fn}=await call('Runtime.evaluate',{expression:'whereIfMap.diagnosticsSnapshot'});
  const paused=new Promise(resolve=>{onPause=resolve;});
  breakpoint=(await call('Debugger.setBreakpointOnFunctionCall',{objectId:fn.objectId})).breakpointId;
  const trigger=call('Runtime.evaluate',{expression:'whereIfMap.diagnosticsSnapshot()',returnByValue:true});
  const pause=await paused;
  const capture=await call('Debugger.evaluateOnCallFrame',{callFrameId:pause.callFrames[0].callFrameId,
    expression:`window.__mapRuntimeProbe={renderer:${renderer},camera:${camera},controls:${controls},scene:${scene},draw:${draw}};true`,returnByValue:true});
  if(capture.exceptionDetails)throw Error(JSON.stringify(capture.exceptionDetails));
  await call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;
  await call('Debugger.resume');await trigger;await call('Debugger.disable');
  const result=await evaluate(`(async()=>{
    const {renderer,camera,controls,scene,draw}=window.__mapRuntimeProbe;
    const comparisonView=${JSON.stringify(comparisonView)};
    if(comparisonView)whereIfMap.setPreviewCamera({...comparisonView,constrain:false});
    const initial=whereIfMap.mapTestSnapshot(),debug=whereIfMap.debugSnapshot();
    const stored=localStorage.getItem('whereif.map.renderSettings.v1');
    const position=camera.position.clone(),target=controls.target.clone();
    const offset=position.clone().sub(target),moving=offset.clone(),axis=offset.clone().set(0,1,0);
    const originalRatio=renderer.getPixelRatio(),originalRender=renderer.render;
    const width=document.documentElement.clientWidth,height=document.documentElement.clientHeight;
    const gl=renderer.getContext(),frame=()=>new Promise(r=>requestAnimationFrame(r));
    const quantile=(a,q)=>[...a].sort((x,y)=>x-y)[Math.floor((a.length-1)*q)];
    const results=[];
    const setBlur=enabled=>{whereIfMap.setInterfaceBlur(false);whereIfMap.setNavBlur(enabled);};
    const move=i=>{moving.copy(offset).applyAxisAngle(axis,Math.sin(i*.035)*.10);camera.position.copy(target).add(moving);camera.lookAt(target);camera.updateMatrixWorld();};
    const setRatio=ratio=>{renderer.setPixelRatio(ratio);renderer.setSize(width,height,false);};
    const row=async(pass,{skip=false}={})=>{
      whereIfMap.setVisible(false);
      renderer.render=skip?function(){}:originalRender;
      for(let i=0;i<15;i++){await frame();move(i);draw();}gl.finish();
      const intervals=[],cpu=[],sync=[];let previous=await frame(),begin=performance.now();
      for(let i=0;i<100;i++){
        const t=await frame();intervals.push(t-previous);previous=t;
        move(i);const start=performance.now();draw();cpu.push(performance.now()-start);
      }
      const elapsed=performance.now()-begin;
      for(let i=0;i<15;i++){await frame();gl.finish();move(i);const t=performance.now();draw();gl.finish();sync.push(performance.now()-t);}
      results.push({pass,fps:Math.round(100000/elapsed*10)/10,
        frameMedianMs:quantile(intervals,.5),frameP90Ms:quantile(intervals,.9),
        cpuSubmitMedianMs:quantile(cpu,.5),cpuPlusGpuSyncMedianMs:quantile(sync,.5),
        dpr:renderer.getPixelRatio(),buffer:[gl.drawingBufferWidth,gl.drawingBufferHeight],
        drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles});
      renderer.render=originalRender;
    };
    try {
      setBlur(false);await row('current-no-blur');
      setBlur(true);await row('current-nav-blur');
      setBlur(false);await row('current-no-blur-repeat');
      await row('no-webgl-draw',{skip:true});
      await whereIfMap.setMapQuality({sharpness:50,antialias:debug.quality.antialias});
      await row('diagnostic-fewer-pixels');
      await whereIfMap.setMapQuality({sharpness:debug.quality.sharpness,antialias:debug.quality.antialias});
      await whereIfMap.setMapTestFeatures({...initial.features,shadows:false});await row('no-shadows');
      await whereIfMap.setMapTestFeatures({...initial.features,shaders:false});await row('no-custom-shaders');
      await whereIfMap.setMapTestFeatures({lighting:true,selection:initial.features.selection});await row('simple-light-only');
      await whereIfMap.setMapTestFeatures({selection:initial.features.selection});await row('raw-materials');
      await whereIfMap.setMapTestFeatures(initial.features);await row('restored-no-blur');
      return {initial,quality:debug.quality,selected:debug.selection.zoneId,camera:position.toArray(),target:target.toArray(),gpu:whereIfMap.diagnosticsSnapshot().gpuName,results};
    }finally{
      renderer.render=originalRender;setRatio(originalRatio);
      await whereIfMap.setMapTestFeatures(initial.features);
      await whereIfMap.setMapQuality({sharpness:debug.quality.sharpness,antialias:debug.quality.antialias});
      whereIfMap.setSelectionOptions(initial.selectionOptions);
      whereIfMap.setInterfaceBlur(initial.interfaceBlurEnabled);whereIfMap.setNavBlur(initial.navBlurEnabled);
      whereIfMap.setPreviewCamera({position:position.toArray(),target:target.toArray(),constrain:false});
      if(stored!==null)localStorage.setItem('whereif.map.renderSettings.v1',stored);
      whereIfMap.setVisible(true);
    }
  })()`);
  writeFileSync('build/a24-map-'+label+'-profile.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
} finally {
  if(breakpoint)await call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  await call('Debugger.resume').catch(()=>{});
  await evaluate('delete window.__mapRuntimeProbe').catch(()=>{});
  await call('Debugger.disable').catch(()=>{});
  for(const entry of pending.values())clearTimeout(entry.timer);
  socket.close();
}
