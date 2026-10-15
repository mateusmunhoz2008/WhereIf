import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, mkdtemp } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';

const root = resolve('.');
const base = '/assets/institutions/ifpr-pgua/map/';
const output = resolve('build/interior-preview');
await mkdir(output, { recursive: true });
const profile = await mkdtemp(resolve(output, 'chrome-'));
const server = createServer(async (req, res) => {
  try {
    if (req.url === '/') {
      res.setHeader('Content-Type', 'text/html');
      res.end(`<meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,canvas{margin:0;width:100%;height:100%;overflow:hidden}canvas{display:block}</style>
        <script>window.messages=[];window.MapBridge={postMessage:m=>messages.push(JSON.parse(m))}</script>
        <script src="${base}viewer/viewer_config.js"></script>
        <script type="module">import '${base}viewer/viewer.js';
        const metadata=await(await fetch('${base}campus_map.json')).json();
        window.whereIfMap.configure({...metadata,modelUrl:'${base}campus_exterior_standard.glb.gz',
        modelCompression:'gzip',localTimeMinutes:720,accentColor:'#a64cff',diagnosticsEnabled:true});</script>`);
      return;
    }
    const path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
    if (!path.startsWith(root + '\\') && !path.startsWith(root + '/')) throw new Error('Path');
    res.setHeader('Content-Type', ({'.js':'text/javascript','.json':'application/json'})[extname(path)] ?? 'application/octet-stream');
    res.end(await readFile(path));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', '--remote-debugging-port=9247', `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding', '--window-size=412,892', `http://127.0.0.1:${port}/`,
], { windowsHide: true, stdio: 'ignore' });
const pause = ms => new Promise(r => setTimeout(r, ms));
let socket;
try {
  let pages;
  for (let i=0;i<50;i++) {
    try { pages=await(await fetch('http://127.0.0.1:9247/json')).json(); if(pages.length) break; } catch {}
    await pause(200);
  }
  socket = new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
  await new Promise(r=>socket.addEventListener('open',r,{once:true}));
  let id=0;
  const pending=new Map();
  socket.addEventListener('message',({data})=>{const m=JSON.parse(data); if(m.id) {
    const p=pending.get(m.id); pending.delete(m.id); m.error?p?.reject(m.error):p?.resolve(m.result);
  }});
  const call=(method,params={})=>new Promise((resolve,reject)=>{
    const seq=++id;pending.set(seq,{resolve,reject});socket.send(JSON.stringify({id:seq,method,params}));
  });
  const evaluate=async expression=>{
    const result=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    if(result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  await call('Emulation.setDeviceMetricsOverride',{width:412,height:892,deviceScaleFactor:1,mobile:true});
  let ready=false;
  for(let i=0;i<150;i++) {
    const state=await evaluate('({ready:window.messages?.some(m=>m.type==="ready"), errors:window.messages?.filter(m=>m.type==="error")})');
    assert.equal(state.errors?.length??0,0,JSON.stringify(state.errors));
    if(state.ready) { ready=true;break; } await pause(200);
  }
  assert.ok(ready,'Viewer loads');
  for (const minute of [360,720,1080,1260]) {
    await evaluate(`whereIfMap.setPreviewTimeMinutes(${minute})`);
    const lighting=await evaluate('whereIfMap.debugSnapshot()');
    assert.ok(lighting.ambientIntensity>=0.025 && lighting.hemisphereIntensity>=0.04,
      'Every climate keeps the small visibility lift');
  }
  await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
  const before=await evaluate('whereIfMap.interiorSnapshot()');
  assert.equal(before.floors.length,3);
  assert.deepEqual(before.activeFloorIds,[]);
  assert.ok(before.floors.every(f=>!f.gpuReady),'Interior GPU setup is deferred');
  const metadata=JSON.parse(await readFile(resolve(root, '.' + base + 'campus_map.json')));
  const exteriorFocus=metadata.zones.find(zone=>zone.id==='bloco-didatico').focus;
  const exteriorDirection=exteriorFocus.position.map((value,index)=>value-exteriorFocus.target[index]);
  const normalize=vector=>{const size=Math.hypot(...vector);return vector.map(value=>value/size);};
  const matchesExteriorAngle=snapshot=>{
    const direction=normalize(snapshot.cameraPosition.map((value,index)=>value-snapshot.cameraTarget[index]));
    const expected=normalize(exteriorDirection);
    return direction.reduce((sum,value,index)=>sum+value*expected[index],0)>0.999;
  };
  for (const floor of before.floors.filter(f=>f.id.startsWith('didatico-')).reverse()) {
    await evaluate(`whereIfMap.setInteriorFloor('bloco-didatico',${JSON.stringify(floor.id)})`);
    await pause(1100);
    const state=await evaluate('whereIfMap.interiorSnapshot()');
    console.log(`${floor.id}: ${state.visibleSpaces.length} espaços carregados`);
    assert.equal(state.floorId,floor.id);
    assert.equal(state.busy,false);
    assert.deepEqual(state.activeFloorIds,
      floor.id==='didatico-p2' ? ['didatico-p1','didatico-p2'] : ['didatico-p1'],
      'The first floor remains visible below the second floor');
    if (floor.id==='didatico-p2') {
      assert.ok(state.floors.filter(entry=>entry.id.startsWith('didatico-')).every(entry=>entry.gpuReady),
        'Opening the second floor prepares both visible floors');
    }
    assert.equal(state.campusVisible,true,'The rest of the campus stays visible');
    assert.equal(state.exteriorVisible,false,'The exterior shell is hidden');
    assert.equal(state.windowPresetsVisible,false,'Window presets are hidden');
    assert.ok(state.visibleSpaces.length>10);
    assert.ok(matchesExteriorAngle(await evaluate('whereIfMap.debugSnapshot()')),
      'Floor keeps the saved exterior viewing angle');
    assert.ok((await evaluate('whereIfMap.debugSnapshot()')).selection.selectedMeshes>0,
      'The selected floor uses the outline effect');
    const screenshot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,`${floor.id}.png`),Buffer.from(screenshot.data,'base64'));
    const space=state.visibleSpaces.find(s=>s.nodeName.startsWith('sala_'));
    await call('Input.dispatchMouseEvent',{type:'mousePressed',x:space.x,y:space.y,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:space.x,y:space.y,button:'left',clickCount:1});
    assert.equal(await evaluate('document.querySelector("canvas").getAnimations().length'),0,
      'Object transitions do not fade the screen');
    await pause(900);
    const selected=await evaluate('whereIfMap.interiorSnapshot()');
    assert.equal(selected.selectedSpace,space.nodeName,'Room is selectable through actual pointer input');
    assert.ok((await evaluate('whereIfMap.debugSnapshot()')).selection.selectedMeshes>0,
      'The selected room uses the outline effect');
    assert.ok(matchesExteriorAngle(await evaluate('whereIfMap.debugSnapshot()')),
      'Room focus keeps the saved exterior viewing angle');
    const roomCamera=await evaluate('whereIfMap.debugSnapshot()');
    const roomTargetY=(space.bounds[0][1]+space.bounds[1][1])/2;
    assert.ok(Math.abs(roomCamera.cameraTarget[1]-roomTargetY)<0.01,
      'Room focus is not snapped to the floor height when the animation ends');
    assert.ok(roomCamera.selection.outlineWidth>=2.8,
      'Room contours remain thicker than building contours');
    const roomShot=await call('Page.captureScreenshot',{format:'png'});
    await writeFile(resolve(output,`${floor.id}-selected.png`),Buffer.from(roomShot.data,'base64'));
    const focusedSpaces=(await evaluate('whereIfMap.interiorSnapshot()')).visibleSpaces;
    const neighbor=focusedSpaces.find(s=>s.nodeName!==space.nodeName &&
      s.nodeName.startsWith('sala_') && s.x>20 && s.x<392 && s.y>20 && s.y<872);
    assert.ok(neighbor,'Another room is reachable from the selected room');
    await call('Input.dispatchMouseEvent',{type:'mousePressed',x:neighbor.x,y:neighbor.y,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:neighbor.x,y:neighbor.y,button:'left',clickCount:1});
    await pause(750);
    const roomSwitch=await evaluate('whereIfMap.debugSnapshot()');
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,neighbor.nodeName);
    assert.ok(matchesExteriorAngle(roomSwitch),'Room-to-room focus preserves the viewing angle');
    assert.ok(Math.abs(roomSwitch.cameraTarget[1]-(neighbor.bounds[0][1]+neighbor.bounds[1][1])/2)<0.01,
      'Room-to-room animation keeps its target height without a final snap');
    if (floor.id==='didatico-p2') {
      for (const [minute,climate] of [[1080,'sunset'],[1260,'night']]) {
        await evaluate(`whereIfMap.setPreviewTimeMinutes(${minute})`);
        await pause(250);
        const climateShot=await call('Page.captureScreenshot',{format:'png'});
        await writeFile(resolve(output,`${floor.id}-${climate}.png`),Buffer.from(climateShot.data,'base64'));
      }
      await evaluate('whereIfMap.setPreviewTimeMinutes(720)');
    }
    const interiorTriangles=await evaluate('whereIfMap.diagnosticsSnapshot().triangles');
    assert.ok(interiorTriangles>0,'Campus and interior geometry are rendered');
    for (const prefix of ['lab_', 'wc_']) {
      await evaluate(`whereIfMap.setInteriorFloor('bloco-didatico',${JSON.stringify(floor.id)})`);
      await pause(800);
      const snapshot=await evaluate('whereIfMap.interiorSnapshot()');
      const target=snapshot.visibleSpaces.find(s=>s.nodeName.startsWith(prefix));
      await call('Input.dispatchMouseEvent',{type:'mousePressed',x:target.x,y:target.y,button:'left',clickCount:1});
      await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:target.x,y:target.y,button:'left',clickCount:1});
      await pause(800);
      assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,target.nodeName);
    }
    await pause(950);
    const idleStart=await evaluate('whereIfMap.diagnosticsSnapshot().framesRendered');
    await pause(600);
    assert.equal(await evaluate('whereIfMap.diagnosticsSnapshot().framesRendered'),idleStart,
      'Idle interiors do not continuously redraw');
    await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:200,y:450,deltaX:0,deltaY:6000});
    await pause(1000);
    const zoom=await evaluate('whereIfMap.interiorSnapshot()');
    assert.ok(zoom.distance<=zoom.distanceLimits[1]+0.01,'Zoom out is bounded');
    await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:200,y:450,deltaX:0,deltaY:-6000});
    await pause(1000);
    const closeZoom=await evaluate('whereIfMap.interiorSnapshot()');
    assert.ok(closeZoom.distance>=closeZoom.distanceLimits[0]-0.01,'Zoom in is bounded');
    console.log(`${floor.id}: ${interiorTriangles} triângulos; salas, laboratórios, banheiros e limites OK`);
  }
  await evaluate("whereIfMap.setInteriorFloor('bloco-didatico',null)");
  await pause(800);
  assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,null);
  assert.deepEqual((await evaluate('whereIfMap.interiorSnapshot()')).activeFloorIds,[]);
  assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).exteriorVisible,true);
  await evaluate("whereIfMap.setInteriorFloor('bloco-central','central-p1')");
  await pause(1100);
  const central=await evaluate('whereIfMap.interiorSnapshot()');
  assert.equal(central.floorId,'central-p1');
  assert.deepEqual(central.activeFloorIds,['central-p1']);
  assert.equal(central.visibleSpaces.length,7);
  assert.ok(central.visibleSpaces.some(space=>space.nodeName==='incubadora'));
  for (const room of central.visibleSpaces) {
    await evaluate("whereIfMap.setInteriorFloor('bloco-central','central-p1')");
    await pause(800);
    const point=(await evaluate('whereIfMap.interiorSnapshot()')).visibleSpaces.find(space=>space.nodeName===room.nodeName);
    assert.ok(point.x>0 && point.x<412 && point.y>0 && point.y<892,room.nodeName);
    await call('Input.dispatchMouseEvent',{type:'mousePressed',x:point.x,y:point.y,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:point.x,y:point.y,button:'left',clickCount:1});
    await pause(800);
    assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,room.nodeName,
      `${room.nodeName}: room center tap selects that exact space`);
  }
  await evaluate("whereIfMap.setInteriorFloor('bloco-central','central-p1')");
  await pause(800);
  const centralRoom=central.visibleSpaces.find(space=>space.nodeName==='sala_3_central');
  assert.ok(centralRoom.x>0 && centralRoom.x<412 && centralRoom.y>0 && centralRoom.y<892);
  await call('Input.dispatchMouseEvent',{type:'mousePressed',x:centralRoom.x,y:centralRoom.y,button:'left',clickCount:1});
  await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:centralRoom.x,y:centralRoom.y,button:'left',clickCount:1});
  await pause(900);
  const pickedCentralRoom=(await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace;
  assert.equal(pickedCentralRoom,centralRoom.nodeName,
    'Central room taps must select the exact room, not an overlapping bounding rectangle');
  const centralCamera=await evaluate('whereIfMap.debugSnapshot()');
  const delta=centralCamera.cameraPosition.map((value,index)=>value-centralCamera.cameraTarget[index]);
  const roomElevation=Math.atan2(delta[1],Math.hypot(delta[0],delta[2]))*180/Math.PI;
  assert.ok(roomElevation>=49.99,`Central room elevation: ${roomElevation}`);
  const centralShot=await call('Page.captureScreenshot',{format:'png'});
  await writeFile(resolve(output,'central-p1.png'),Buffer.from(centralShot.data,'base64'));
  // Hold a new tap while the previous room flight is still moving. The view
  // must stop on press so it cannot change the hit target before release.
  await evaluate("whereIfMap.setInteriorFloor('bloco-central','central-p1')");
  await pause(800);
  const quickRoom=(await evaluate('whereIfMap.interiorSnapshot()')).visibleSpaces.find(space=>space.nodeName==='sala_1_central');
  await call('Input.dispatchMouseEvent',{type:'mousePressed',x:quickRoom.x,y:quickRoom.y,button:'left',clickCount:1});
  await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:quickRoom.x,y:quickRoom.y,button:'left',clickCount:1});
  await pause(100);
  const nextRoom=(await evaluate('whereIfMap.interiorSnapshot()')).visibleSpaces.find(space=>space.nodeName==='sala_2_central');
  await call('Input.dispatchMouseEvent',{type:'mousePressed',x:nextRoom.x,y:nextRoom.y,button:'left',clickCount:1});
  const heldCamera=await evaluate('({position:whereIfMap.debugSnapshot().cameraPosition,target:whereIfMap.debugSnapshot().cameraTarget})');
  await pause(180);
  const heldEnd=await evaluate('({position:whereIfMap.debugSnapshot().cameraPosition,target:whereIfMap.debugSnapshot().cameraTarget})');
  for (const key of ['position','target']) assert.ok(Math.hypot(...heldCamera[key].map((value,index)=>value-heldEnd[key][index]))<0.01,
    'A quick second touch freezes the moving camera until the target is picked');
  await call('Input.dispatchMouseEvent',{type:'mouseReleased',x:nextRoom.x,y:nextRoom.y,button:'left',clickCount:1});
  await pause(800);
  assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).selectedSpace,nextRoom.nodeName);
  await evaluate("whereIfMap.setInteriorFloor('bloco-central',null)");
  await pause(800);
  assert.deepEqual((await evaluate('whereIfMap.interiorSnapshot()')).activeFloorIds,[]);
  await evaluate("whereIfMap.setMapViewMode('2d')");
  await pause(800);
  await evaluate("whereIfMap.setInteriorFloor('bloco-didatico','didatico-p1')");
  for(let i=0;i<20;i++) {
    if((await evaluate('whereIfMap.debugSnapshot()')).cameraProjection==='perspective') break;
    await pause(150);
  }
  assert.equal((await evaluate('whereIfMap.debugSnapshot()')).cameraProjection,'perspective');
  await evaluate('whereIfMap.resetCamera()');
  await pause(900);
  assert.equal((await evaluate('whereIfMap.interiorSnapshot()')).floorId,null);
  assert.equal((await evaluate('whereIfMap.debugSnapshot()')).cameraProjection,'perspective');
  console.log('PASS: lazy GPU setup, both floors, room picking and exterior reset');
  console.log(output);
} finally {
  socket?.close(); chrome.kill(); server.close();
}
