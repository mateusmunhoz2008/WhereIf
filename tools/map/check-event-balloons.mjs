import {createServer} from 'node:http';
import {readFile,mkdir,writeFile,mkdtemp} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {eventMarkerScale,markerImageSource,eventMarkerFadeMs,eventMarkerPalette,normalizedInteriorEventSize} from '../../assets/institutions/ifpr-pgua/map/viewer/map_event_markers.js';

assert.equal(eventMarkerScale(20,false),1.08);
assert.equal(eventMarkerScale(1000,true),.72);
assert.ok(eventMarkerScale(100,true)>eventMarkerScale(200,true));
assert.equal(eventMarkerFadeMs,180);
assert.equal(eventMarkerPalette.length,6);
for(const [input,expected] of [[undefined,100],[null,100],[NaN,100],[-20,70],[500,160],[127,125]])assert.equal(normalizedInteriorEventSize(input),expected);
assert.equal(markerImageSource('assets/photo.jpg','file:///android_asset/flutter_assets/assets/institutions/ifpr-pgua/map/viewer/index.html'),'file:///android_asset/flutter_assets/assets/photo.jpg');
assert.equal(markerImageSource('assets/photo.jpg','https://localhost/assets/institutions/ifpr-pgua/map/viewer/index.html'),'https://localhost/assets/photo.jpg');
for(const source of ['javascript:alert(1)','file:///private.jpg','assets/../private.jpg','assets/%2e%2e/private.jpg','assets/%2fprivate.jpg','bad-url'])assert.equal(markerImageSource(source,'https://localhost/'),null);

const root=resolve('.'),output=resolve('build/event-balloon-preview');await mkdir(output,{recursive:true});
const base='/assets/institutions/ifpr-pgua/map/viewer/';
const server=createServer(async(req,res)=>{
  try{
    const path=new URL(req.url,'http://localhost').pathname;
    if(path==='/'){
      res.setHeader('Content-Type','text/html');res.end(`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>body{margin:0;background:#d8e1d8;font-family:system-ui}h1{margin:35px;font-size:24px;color:#303630}</style><h1>Campus</h1><script type="module">
        import * as THREE from '${base}vendor/three.module.min.js';
        import {createMapEventMarkers} from '${base}map_event_markers.js';
        window.chosen=[];window.camera=new THREE.PerspectiveCamera(42,innerWidth/innerHeight,.1,2000);camera.position.z=190;camera.updateMatrixWorld();
        window.anchorOffsets={};
        window.balloon=createMapEventMarkers({anchorFor:location=>new THREE.Vector3(...(anchorOffsets[location.spaceNodeName??location.zoneId]??[0,0,0])),onSelected:p=>chosen.push(p)});
        window.floor={id:'p2',zoneId:'didatico'};
        window.fixture=[{eventId:'one',title:'Mostra de projetos dos estudantes do campus',color:'#ae86e8',foreground:'#19141e',locations:[{zoneId:'didatico',floorId:'p2',spaceNodeName:'sala1'}],imageUrl:'assets/institutions/ifpr-pgua/event_banners/arts_culture.png'},
        {eventId:'two',title:'Oficina de desenho',color:'#ae86e8',foreground:'#19141e',locations:[{zoneId:'didatico',floorId:'p2',spaceNodeName:'sala1'}]}];
        window.animationChecks={};balloon.setEvents(fixture);balloon.update(camera,null);
        animationChecks.entryStart=Number(getComputedStyle(document.querySelector('.map-event-anchor')).opacity);window.ready=true;
      </script>`);return;
    }
    const file=resolve(root,'.'+path);assert.ok(file.startsWith(root+'\\')||file.startsWith(root+'/'));
    res.setHeader('Content-Type',({'.js':'text/javascript','.png':'image/png','.jpg':'image/jpeg'})[extname(file)]??'application/octet-stream');res.end(await readFile(file));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const profile=await mkdtemp(resolve(output,'chrome-'));
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--remote-debugging-port=9252',`--user-data-dir=${profile}`,'--no-first-run','--no-default-browser-check',`http://127.0.0.1:${server.address().port}/`],{windowsHide:true,stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let socket;
try{
  let page;for(let i=0;i<50;i++){try{page=(await(await fetch('http://127.0.0.1:9252/json')).json()).find(p=>p.type==='page');if(page)break;}catch{}await pause(200);}
  assert.ok(page);socket=new WebSocket(page.webSocketDebuggerUrl);await new Promise(r=>socket.addEventListener('open',r,{once:true}));
  let id=0;const pending=new Map();socket.addEventListener('message',({data})=>{const m=JSON.parse(data);if(!m.id)return;const p=pending.get(m.id);pending.delete(m.id);m.error?p?.reject(m.error):p?.resolve(m.result);});
  const call=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject});socket.send(JSON.stringify({id:key,method,params}));});
  const evaluate=async expression=>{const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});assert.equal(r.exceptionDetails,undefined,JSON.stringify(r.exceptionDetails));return r.result.value;};
  // Real touch input exercises press/release, unlike a programmatic button.click().
  async function checkTouchFeedback(selector,activate=false){
    const target=JSON.stringify(selector);
    const read=()=>evaluate(`(()=>{const b=document.querySelector(${target}),s=getComputedStyle(b),m=new DOMMatrixReadOnly(s.transform);return {pressed:b.dataset.pressed==='true',scale:m.a,blue:s.webkitTapHighlightColor,color:s.backgroundColor,filter:s.filter};})()`);
    const rest=await read();
    const point=await evaluate(`(()=>{const r=document.querySelector(${target}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
    await call('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point]});await pause(140);
    const down=await read();assert.equal(down.pressed,true,JSON.stringify({point,down}));assert.ok(Math.abs(down.scale-.96)<.002,'Every popup compresses slightly on touch');
    assert.equal(down.blue,'rgba(0, 0, 0, 0)','Press feedback never uses the native blue overlay');
    assert.notEqual(down.color,rest.color,'Each popup changes color slightly while pressed');
    assert.equal(down.filter,'none','Press tint does not use a GPU filter');
    await call('Input.dispatchTouchEvent',{type:activate?'touchEnd':'touchCancel',touchPoints:[]});await pause(140);
    const up=await read();assert.equal(up.pressed,false);assert.ok(Math.abs(up.scale-1)<.002,'Release/cancel returns to normal without a stuck pressed state');
    assert.equal(up.color,rest.color,'The original color returns after release/cancel');
  }
  for(let i=0;i<50;i++){if(await evaluate('window.ready'))break;await pause(100);}
  assert.ok(await evaluate('animationChecks.entryStart<.2'),'Balloon entry begins with a real opacity fade');
  await pause(210);
  const idleWork=await evaluate('(()=>{const before=balloon.snapshot().work;for(let i=0;i<1000;i++)balloon.update(camera,null);return {before,after:balloon.snapshot().work};})()');
  assert.equal(idleWork.after.projections,idleWork.before.projections,'A stationary camera performs no repeated projections');
  assert.equal(idleWork.after.layouts,idleWork.before.layouts,'Selection animation alone performs no marker layout');
  assert.equal(idleWork.after.styleWrites,idleWork.before.styleWrites,'Stationary markers do not mutate DOM styles');
  for(const width of [320,412,768]){
    await call('Emulation.setDeviceMetricsOverride',{width,height:800,deviceScaleFactor:1,mobile:true});
    await call('Emulation.setTouchEmulationEnabled',{enabled:true});
    await evaluate('camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();balloon.update(camera,null)');
    for(const cameraX of [0,1,-1,0]){
      await evaluate(`camera.position.x=${cameraX}*(innerWidth/2-12)*2*Math.tan(camera.fov*Math.PI/360)*190/innerHeight;camera.updateMatrixWorld();balloon.update(camera,null)`);
      if(cameraX===0){
        assert.equal((await evaluate('balloon.snapshot()')).placements[0].dx,0,'Cavity recenters after returning from either screen edge');
        assert.equal(await evaluate('document.querySelector(".map-event-anchor:not([data-retiring]) > button").style.left'),'0px');
      }
    }
    await evaluate('balloon.setCameraGestureActive(true)');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).pointerEvents'),'none','A second pinch finger cannot be intercepted by a moving popup');
    await evaluate('balloon.setCameraGestureActive(false)');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).pointerEvents'),'auto');
    assert.equal(await evaluate('document.querySelectorAll(".map-event-leader").length'),0,'Detached connector lines are removed');
    assert.equal((await evaluate('balloon.snapshot()')).groups,1);
    assert.equal(await evaluate('document.querySelector(".map-event-anchor > button").textContent'),'Evento+1');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button"),"::after").height'),'8px');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).minWidth'),'132px','Exterior is narrower');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).minHeight'),'48px','Exterior height is unchanged');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).webkitTapHighlightColor'),'rgba(0, 0, 0, 0)','No Android blue tap highlight');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).appearance'),'none');
    const color=await evaluate('balloon.snapshot().colors[0]');assert.ok(eventMarkerPalette.some(pair=>pair[0]===color));
    const exteriorScale=(await evaluate('balloon.snapshot()')).scales[0];
    for(const size of [70,160,100]){
      await evaluate(`balloon.setInteriorSize(${size});balloon.update(camera,null)`);
      assert.equal((await evaluate('balloon.snapshot()')).scales[0],exteriorScale,'Internal size never changes exterior balloons');
    }
    assert.equal(await evaluate('(()=>{balloon.update(camera,null);return balloon.snapshot().colors[0];})()'),color,'Panning/rendering cannot reshuffle colors');
    await checkTouchFeedback('.map-event-anchor > button');
    assert.equal(await evaluate('chosen.length'),0,'Canceling a touch must not visit the block');
    await checkTouchFeedback('.map-event-anchor > button',true);
    await evaluate('balloon.update(camera,null)');
    assert.equal(await evaluate('chosen.length'),1,'A physical touch visits the block exactly once');
    const exterior=await evaluate('chosen.at(-1)');
    assert.equal(exterior.zoneId,'didatico');assert.equal(exterior.mode,'exterior');assert.equal(exterior.eventIds.length,2);
    assert.equal((await evaluate('balloon.snapshot()')).expanded,null,'Exterior sends a building visit, never opens event choices');
    assert.equal(await evaluate('document.querySelectorAll(".map-event-fan button").length'),0,'Exterior allocates no hidden photo cards');
    await evaluate('chosen=[];balloon.update(camera,floor)');
    assert.ok(await evaluate('document.querySelectorAll(".map-event-anchor[data-retiring]").length>0'),'Old floor balloons fade out instead of disappearing instantly');
    for(let i=0;i<12;i++){
      if(await evaluate('document.querySelectorAll(".map-event-anchor[data-retiring]").length')===0)break;
      await pause(80);
    }
    assert.equal(await evaluate('document.querySelectorAll(".map-event-anchor[data-retiring]").length'),0,'Retiring balloons are released after the fade');
    assert.deepEqual((await evaluate('balloon.snapshot()')).modes,['place']);
    assert.equal(await evaluate('document.querySelectorAll(".map-event-fan button").length'),0,'Closed stacks allocate no hidden photo cards');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).width'),'88px','Card logical size does not balloon on tablets');
    assert.equal(await evaluate('getComputedStyle(document.querySelector(".map-event-anchor > button")).webkitTapHighlightColor'),'rgba(0, 0, 0, 0)','Room cards also have no blue tap overlay');
    await checkTouchFeedback('.map-event-anchor > button');
    assert.equal((await evaluate('balloon.snapshot()')).expanded,null,'Canceled room touch cannot open the stack');
    await evaluate('document.querySelector(".map-event-anchor > button").click();balloon.update(camera,floor)');
    const expanding=await evaluate('({opacity:Number(getComputedStyle(document.querySelector(".map-event-fan")).opacity),animations:document.querySelector(".map-event-fan").getAnimations().length})');
    assert.ok(expanding.opacity<1&&expanding.animations>0,'Interior choices keep their fade');
    await pause(210);
    assert.equal(await evaluate('chosen.length'),0,'A room stack does not choose an arbitrary event');
    const layout=await evaluate('(()=>{const cards=[...document.querySelectorAll(".map-event-fan button")].map(b=>{const r=b.getBoundingClientRect();return {x:r.x,y:r.y,right:r.right,width:r.width};});return {cards,fan:getComputedStyle(document.querySelector(".map-event-fan")).backdropFilter};})()');
    assert.equal(layout.cards.length,2);assert.equal(layout.cards[0].y,layout.cards[1].y);
    assert.ok(layout.cards[0].right<=layout.cards[1].x);assert.ok(layout.cards[0].x>=0&&layout.cards[1].right<=width);
    assert.equal(layout.fan,'none');
    const initialSize=await evaluate('balloon.snapshot()');
    for(const size of [70,160,100]){
      await evaluate(`balloon.setInteriorSize(${size});balloon.update(camera,floor)`);
      const sized=await evaluate('balloon.snapshot()');
      assert.equal(sized.interiorSize,size);assert.equal(sized.expanded,initialSize.expanded,'Live size preserves the open stack');
      assert.ok(Math.abs(sized.scales[0]-initialSize.scales[0]*size/100)<.001,'Photo, text, hit area and cards scale together');
      assert.ok(await evaluate('[...document.querySelectorAll(".map-event-fan button")].every(b=>{const r=b.getBoundingClientRect();return r.left>=0&&r.right<=innerWidth;})'),'Resized choices stay within narrow screens');
    }
    assert.equal(await evaluate('balloon.dismissOutsideTap(document.querySelector(".map-event-fan button"))'),false,'An inside press cannot dismiss the fan');
    await checkTouchFeedback('.map-event-fan button');
    assert.equal(await evaluate('chosen.length'),0,'Canceled event-card touch cannot choose an event');
    if(width===412){const shot=await call('Page.captureScreenshot',{format:'png'});await writeFile(resolve(output,'stack-light.png'),Buffer.from(shot.data,'base64'));}
    assert.equal(await evaluate('balloon.dismissOutsideTap(document.body)'),true,'First outside gesture is consumed to close the fan');
    assert.equal(await evaluate('balloon.dismissOutsideTap(document.body)'),false,'The next outside gesture is not consumed');
    assert.equal((await evaluate('balloon.snapshot()')).expanded,null);
    assert.ok(await evaluate('!document.querySelector(".map-event-fan").hidden'),'Closing keeps the fan visible during its exit fade');
    await pause(210);
    assert.equal(await evaluate('document.querySelector(".map-event-fan").hidden'),true);
    await evaluate('document.querySelector(".map-event-anchor > button").click();document.querySelectorAll(".map-event-fan button")[1].click()');
    assert.equal((await evaluate('chosen.at(-1)')).eventId,'two');assert.equal((await evaluate('chosen.at(-1)')).mode,'place');
    const before=(await evaluate('balloon.snapshot()')).scales[0];
    await evaluate('camera.position.z=100;camera.updateMatrixWorld();balloon.update(camera,floor)');
    assert.ok((await evaluate('balloon.snapshot()')).scales[0]>before);
    await evaluate('camera.position.z=190;camera.updateMatrixWorld();balloon.setEvents([{...fixture[0],dark:true,surface:"#29272b",onSurface:"#f5f3f7"}]);balloon.update(camera,floor)');await pause(220);
    const darkColor=await evaluate('balloon.snapshot().colors[0]');
    assert.ok(eventMarkerPalette.some(pair=>pair[1]===darkColor));
    const photo=await evaluate('balloon.snapshot().photos[0]');assert.equal(photo.loaded,true);
    if(width===412){const shot=await call('Page.captureScreenshot',{format:'png'});await writeFile(resolve(output,'single-dark.png'),Buffer.from(shot.data,'base64'));}
    await checkTouchFeedback('.map-event-anchor > button');
    await evaluate('document.querySelector(".map-event-anchor > button").click()');
    assert.equal((await evaluate('chosen.at(-1)')).mode,'place');
    await evaluate('chosen=[];balloon.setEvents(fixture);balloon.update(camera,null)');
    await pause(210);
  }
  await evaluate('balloon.setEvents([fixture[0]]);balloon.update(camera,null)');await pause(210);
  await evaluate('document.querySelector(".map-event-anchor > button").click()');
  assert.equal(await evaluate('chosen.length'),1,'A single exterior event also visits the building');
  assert.equal((await evaluate('balloon.snapshot()')).expanded,null);
  for(const width of [320,412,768])for(const size of [70,100,160]){
    await call('Emulation.setDeviceMetricsOverride',{width,height:800,deviceScaleFactor:1,mobile:true});
    await evaluate(`(()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();camera.position.z=190;camera.updateMatrixWorld();anchorOffsets={near0:[-5,0,0],near1:[0,0,0],near2:[5,0,0]};balloon.setInteriorSize(${size});balloon.setEvents(Array.from({length:3},(_,i)=>({...fixture[0],eventId:'near'+i,locations:[{zoneId:'didatico',floorId:'p2',spaceNodeName:'near'+i}]})));balloon.update(camera,floor);})()`);
    await pause(210);
    const crowded=await evaluate(`(()=>{const roots=[...document.querySelectorAll('.map-event-anchor:not([data-retiring])')];return {sides:roots.map(r=>r.dataset.side),rects:roots.map(r=>{const b=r.querySelector('button'),q=b.getBoundingClientRect();return {left:q.left,right:q.right,top:q.top,bottom:q.bottom,area:q.width*q.height};}),tips:roots.map(r=>getComputedStyle(r.querySelector('button'),'::after').clipPath)};})()`);
    assert.equal(crowded.rects.length,3);assert.equal(new Set(crowded.sides).size,2,'Crowded markers flip above/below at every test size');
    for(let i=0;i<3;i++){
      const a=crowded.rects[i];assert.ok(a.left>=7&&a.right<=width-7&&a.top>=111&&a.bottom<=691,'Reorganized cards stay clear of header/footer');
      for(let j=i+1;j<3;j++){const b=crowded.rects[j],area=Math.max(0,Math.min(a.right,b.right)-Math.max(a.left,b.left))*Math.max(0,Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top));assert.ok(area/Math.min(a.area,b.area)<.3,'Actual rendered cards are not extremely overlapped');}
      if(crowded.sides[i]==='below')assert.ok(crowded.tips[i].includes('50% 0'),'The downward card has its pointer on top');
    }
    await evaluate("chosen=[];document.querySelectorAll('.map-event-anchor:not([data-retiring]) > button')[1].click()");
    assert.equal(await evaluate('chosen[0].eventId'),'near1','Reorganization keeps the correct room event clickable');
    const belowKey=await evaluate('balloon.snapshot().placements.find(p=>p.side==="below").key.split("/").at(-1)');
    await checkTouchFeedback('.map-event-anchor:not([data-retiring])[data-side=below] > button',true);
    assert.equal(await evaluate('chosen.at(-1).eventId'),belowKey,'A real touch on the inverted card still chooses the correct event');
    const before=await evaluate('balloon.snapshot().placements');await evaluate('balloon.update(camera,floor)');
    assert.deepEqual(await evaluate('balloon.snapshot().placements'),before,'A stationary frame cannot shuffle sides');
    if(width===412&&size===160){const shot=await call('Page.captureScreenshot',{format:'png'});await writeFile(resolve(output,'crowded-alternating-large.png'),Buffer.from(shot.data,'base64'));}
    await evaluate('balloon.setAutoLayout(false)');
    const normal=await evaluate('balloon.snapshot()');
    assert.equal(normal.autoLayout,false);
    assert.ok(normal.placements.every(p=>p.side==='above'&&p.dx===0),'Normal mode immediately restores the original overlapping positions');
    await evaluate('balloon.setCameraGestureActive(true);balloon.setAutoLayout(true)');
    assert.equal((await evaluate('balloon.snapshot()')).autoLayout,true);
    await evaluate('balloon.setCameraGestureActive(false)');
    assert.equal(new Set((await evaluate('balloon.snapshot()')).placements.map(p=>p.side)).size,2,'Automatic mode resumes after the gesture');
    await evaluate('balloon.setAutoLayout(false)');
    const writes=await evaluate(`(()=>{const before=balloon.snapshot().work,changes=[];
      const observer=new MutationObserver(records=>changes.push(...records.map(r=>r.target.className)));
      observer.observe(document.querySelector('.map-event-markers'),{attributes:true,subtree:true,attributeFilter:['style']});
      camera.position.x=.25;camera.updateMatrixWorld();balloon.update(camera,floor);
      changes.push(...observer.takeRecords().map(r=>r.target.className));observer.disconnect();
      camera.position.x=0;camera.updateMatrixWorld();balloon.update(camera,floor);
      return {changes,writes:balloon.snapshot().work.styleWrites-before.styleWrites};})()`);
    assert.ok(writes.changes.every(cls=>cls==='map-event-anchor'),'Ordinary pan changes only composited anchor transforms, never closed-card layout');
    assert.ok(writes.writes<=6,'Two pan updates write at most one transform per visible marker');
    await evaluate('balloon.setAutoLayout(true)');
  }
  await evaluate('balloon.setInteriorSize(100);anchorOffsets={};chosen=[];balloon.setEvents(fixture);balloon.update(camera,floor)');await pause(210);
  await evaluate('document.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape"}))');
  assert.equal((await evaluate('balloon.snapshot()')).expanded,null);
  await evaluate('balloon.setEvents(fixture);balloon.update(camera,floor)');await pause(210);
  await evaluate('(()=>{const b=document.querySelector(".map-event-anchor > button");b.click();document.body.dispatchEvent(new PointerEvent("pointerdown",{bubbles:true}));b.click();})()');
  await pause(210);
  assert.ok((await evaluate('balloon.snapshot()')).expanded,'Rapid open/close/open ends open, without a stale fade hiding it');
  await evaluate('balloon.setEvents(Array.from({length:12},(_,i)=>({...fixture[0],eventId:"palette-"+i,locations:[{zoneId:"group-"+Math.floor(i/2)}]})));balloon.update(camera,null)');
  assert.equal(new Set((await evaluate('balloon.snapshot()')).colors).size,6,'Six group leaders use all six richer colors, even with pairs in every block');
  await call('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
  await evaluate('balloon.setEvents(fixture);balloon.update(camera,floor)');
  await evaluate('document.querySelector(".map-event-anchor:not([data-retiring]) > button").click()');
  assert.equal(await evaluate('document.querySelector(".map-event-anchor[data-expanded=true] .map-event-fan").getAnimations()[0]?.effect.getTiming().duration??0'),0,'Reduced-motion preference is respected');
  await evaluate('balloon.dispose()');assert.equal(await evaluate('document.querySelector(".map-event-markers")'),null);
  console.log('PASS: 132x48 exterior balloons, direct building visit, richer stable colors, interior-only stacks, touch press/release/cancel, fades, 320/412/768px screens and cleanup');
}finally{socket?.close();chrome.kill();server.close();}
