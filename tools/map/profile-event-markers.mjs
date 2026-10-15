// Reversible native A/B: identical camera path, geometry, effects and DPR.
import { writeFileSync } from 'node:fs';
const port=Number(process.argv[2]??9234),label=process.argv[3]??'before';
const autoComparison=process.argv.includes('--auto');
if(!/^[a-z0-9-]+$/.test(label))throw Error('Invalid output label');
const pages=await(await fetch(`http://127.0.0.1:${port}/json`)).json();
const page=pages.find(p=>p.url.includes('/map/viewer/index.html')&&JSON.parse(p.description||'{}').attached);
if(!page)throw Error('Open the map first');
const url=new URL(page.webSocketDebuggerUrl);url.host=`127.0.0.1:${port}`;
const socket=new WebSocket(url);await new Promise(r=>socket.addEventListener('open',r,{once:true}));
let seq=0,onPause,breakpoint;const pending=new Map();
socket.addEventListener('message',({data})=>{
  const m=JSON.parse(data);if(m.method==='Debugger.paused')onPause?.(m.params);
  const p=pending.get(m.id);if(!p)return;pending.delete(m.id);clearTimeout(p.timer);
  m.error?p.reject(m.error):p.resolve(m.result);
});
const call=(method,params={},timeout=20000)=>new Promise((resolve,reject)=>{
  const id=++seq,timer=setTimeout(()=>{pending.delete(id);reject(Error(method+' timed out'));},timeout);
  pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
});
const evaluate=async expression=>{
  const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true},60000);
  if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;
};
try{
  const initial=await evaluate('({visible:document.visibilityState,markers:whereIfMap.eventMarkersSnapshot(),quality:whereIfMap.debugSnapshot().quality,floor:whereIfMap.interiorSnapshot().floorId,camera:{position:whereIfMap.debugSnapshot().cameraPosition,target:whereIfMap.debugSnapshot().cameraTarget}})');
  if(initial.visible!=='visible')throw Error('Map must be in foreground');
  await call('Debugger.enable');
  const {result:fn}=await call('Runtime.evaluate',{expression:'whereIfMap.diagnosticsSnapshot'});
  const paused=new Promise(r=>{onPause=r;});
  breakpoint=(await call('Debugger.setBreakpointOnFunctionCall',{objectId:fn.objectId})).breakpointId;
  const trigger=call('Runtime.evaluate',{expression:'whereIfMap.diagnosticsSnapshot()'});
  const pause=await paused;
  const captured=await call('Debugger.evaluateOnCallFrame',{callFrameId:pause.callFrames[0].callFrameId,
    expression:'window.__popupProbe={renderer,camera,controls,markers:eventMarkers,draw:renderSceneWithSelection,floor:()=>interiors?.current};true',returnByValue:true});
  if(captured.exceptionDetails)throw Error(JSON.stringify(captured.exceptionDetails));
  await call('Debugger.removeBreakpoint',{breakpointId:breakpoint});breakpoint=null;
  await call('Debugger.resume');await trigger;await call('Debugger.disable');
  await call('Performance.enable');
  await evaluate(`(()=>{
    const p=window.__popupProbe;p.original=whereIfMap.debugSnapshot();p.markerState=p.markers.snapshot();
    p.root=document.querySelector('.map-event-markers');p.rootStyle=p.root.style.cssText;
    p.axis=p.camera.position.clone().set(0,1,0);p.target=p.controls.target.clone();
    p.offset=p.camera.position.clone().sub(p.target);p.moving=p.offset.clone();
    p.variant=document.createElement('style');document.head.append(p.variant);
    whereIfMap.setVisible(false);
    p.row=async(mode)=>{
      p.root.style.cssText=p.rootStyle;
      p.variant.textContent=mode.includes('layers')?'.map-event-anchor{will-change:transform}':
        mode.includes('no-shadows')?'.map-event-card,.map-event-fan{box-shadow:none!important}':'';
      if(mode.includes('hidden'))p.root.style.display='none';
      p.markers.setAutoLayout(mode.startsWith('auto')?true:mode==='normal'?false:p.markerState.autoLayout);
      const frames=[],cpu=[],markers=[],frame=()=>new Promise(r=>requestAnimationFrame(r));
      let last=0;
      for(let i=0;i<150;i++){
        const time=await frame();
        p.moving.copy(p.offset).applyAxisAngle(p.axis,Math.sin(i*.035)*.09);
        p.camera.position.copy(p.target).add(p.moving);p.camera.lookAt(p.target);p.camera.updateMatrixWorld();
        const start=performance.now();p.draw();const markerStart=performance.now();
        if(!mode.includes('frozen'))p.markers.update(p.camera,p.floor());
        if(i>=25){frames.push(time-last);cpu.push(performance.now()-start);markers.push(performance.now()-markerStart);}
        last=time;
      }
      const q=(a,n)=>[...a].sort((x,y)=>x-y)[Math.floor((a.length-1)*n)];
      return {mode,fps:Math.round(1000/(frames.reduce((a,b)=>a+b,0)/frames.length)*10)/10,
        frameMedianMs:q(frames,.5),frameP90Ms:q(frames,.9),submitMedianMs:q(cpu,.5),
        markerMedianMs:q(markers,.5),markerP90Ms:q(markers,.9)};
    };
  })()`);
  const rows=[];
  for(const mode of autoComparison?['auto','auto-layers','auto-no-shadows','auto-hidden','auto-frozen','auto']:['current','hidden','frozen','normal','auto','layers','no-shadows','current']){
    const before=(await call('Performance.getMetrics')).metrics;
    const row=await evaluate(`__popupProbe.row(${JSON.stringify(mode)})`);
    const after=(await call('Performance.getMetrics')).metrics;
    const value=(a,key)=>a.find(m=>m.name===key)?.value??0;
    for(const key of ['LayoutCount','RecalcStyleCount','LayoutDuration','RecalcStyleDuration','ScriptDuration'])row[key]=Math.round((value(after,key)-value(before,key))*100000)/100000;
    rows.push(row);console.log(JSON.stringify(row));
  }
  writeFileSync(`build/popup-${label}-profile.json`,JSON.stringify({initial,rows},null,2));
}finally{
  if(breakpoint)await call('Debugger.removeBreakpoint',{breakpointId:breakpoint}).catch(()=>{});
  await call('Debugger.resume').catch(()=>{});
  await evaluate(`(()=>{const p=window.__popupProbe;if(!p)return;
    p.variant?.remove();if(p.root)p.root.style.cssText=p.rootStyle;
    if(p.markerState)p.markers.setAutoLayout(p.markerState.autoLayout);
    if(p.original)whereIfMap.setPreviewCamera({position:p.original.cameraPosition,target:p.original.cameraTarget,constrain:false});
    whereIfMap.setVisible(true);delete window.__popupProbe;})()`).catch(()=>{});
  await call('Debugger.disable').catch(()=>{});for(const p of pending.values())clearTimeout(p.timer);socket.close();
}
