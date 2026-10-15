// Real GLB facade regression and visual previews, independent of app effects.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, mkdtemp, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { spawn } from 'node:child_process';
import { inflateRawSync, gunzipSync } from 'node:zlib';

const root=resolve('.'),output=resolve('build/window-contour-preview');
let previousCache=null;
const previousIndex=process.argv.indexOf('--previous-apk');
if(previousIndex>=0) {
  const zip=await readFile(resolve(process.argv[previousIndex+1]));
  const end=zip.lastIndexOf(Buffer.from([0x50,0x4b,0x05,0x06]));assert.ok(end>=0);
  let offset=zip.readUInt32LE(end+16);
  while(zip.readUInt32LE(offset)===0x02014b50) {
    const nameLength=zip.readUInt16LE(offset+28),extra=zip.readUInt16LE(offset+30),comment=zip.readUInt16LE(offset+32);
    const name=zip.subarray(offset+46,offset+46+nameLength).toString();
    if(name==='assets/flutter_assets/assets/institutions/ifpr-pgua/map/viewer/selection_cache_data.js'||
       name==='assets/flutter_assets/assets/institutions/ifpr-pgua/map/viewer/viewer.bundle.js') {
      const local=zip.readUInt32LE(offset+42),start=local+30+zip.readUInt16LE(local+26)+zip.readUInt16LE(local+28);
      const bytes=zip.subarray(start,start+zip.readUInt32LE(offset+20));
      const source=(zip.readUInt16LE(offset+10)===8?inflateRawSync(bytes):bytes).toString();
      const payload=JSON.parse(source.match(/selectionCachePayload = ("[^"]+")/)[1]);
      previousCache=JSON.parse(gunzipSync(Buffer.from(payload,'base64')));break;
    }
    offset+=46+nameLength+extra+comment;
  }
  assert.ok(previousCache,'Previous APK contains the actual old outline cache');
}
await mkdir(output,{recursive:true});
const profile=await mkdtemp(resolve(output,'chrome-'));
const server=createServer(async(req,res)=>{
  try{
    if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end('<body style="margin:0;background:#171717"></body>');return;}
    if(req.url==='/outline-before.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(previousCache));return;}
    const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
    assert.ok(path.startsWith(root+'\\')||path.startsWith(root+'/'));
    res.setHeader('Content-Type',({'.js':'text/javascript','.json':'application/json'})[extname(path)]??'application/octet-stream');
    res.end(await readFile(path));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',[
  '--headless=new','--remote-debugging-port=9251',`--user-data-dir=${profile}`,
  '--no-first-run','--no-default-browser-check','--disable-background-timer-throttling',
  '--disable-renderer-backgrounding','--window-size=432,936',`http://127.0.0.1:${server.address().port}/`,
],{windowsHide:true,stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
let socket;
try{
  let page;
  for(let i=0;i<50;i++){
    try{page=(await(await fetch('http://127.0.0.1:9251/json')).json()).find(p=>p.type==='page'&&p.url.startsWith(`http://127.0.0.1:${server.address().port}/`));if(page)break;}catch{}
    await pause(100);
  }
  assert.ok(page);socket=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r=>socket.addEventListener('open',r,{once:true}));
  let sequence=0;const pending=new Map();
  socket.addEventListener('message',({data})=>{
    const m=JSON.parse(data),p=pending.get(m.id);if(!p)return;pending.delete(m.id);clearTimeout(p.timer);
    m.error?p.reject(m.error):p.resolve(m.result);
  });
  const call=(method,params={})=>new Promise((resolve,reject)=>{
    const id=++sequence,timer=setTimeout(()=>{pending.delete(id);reject(Error(`${method} timed out`));},60000);
    pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
  });
  let documentReady=false;
  for(let i=0;i<50;i++){
    const r=await call('Runtime.evaluate',{expression:'({url:location.href,ready:document.readyState})',returnByValue:true});
    if(r.result.value?.url===`http://127.0.0.1:${server.address().port}/`&&r.result.value.ready==='complete'){documentReady=true;break;}
    await pause(100);
  }
  assert.ok(documentReady,'Preview document is loaded before imports');
  const result=await call('Runtime.evaluate',{awaitPromise:true,returnByValue:true,expression:`(async()=>{
    const base='/assets/institutions/ifpr-pgua/map/';
    const THREE=await import(base+'viewer/vendor/three.module.min.js');
    const {GLTFLoader}=await import(base+'viewer/vendor/loaders/GLTFLoader.js');
    const {createGeometrySelectionOutline}=await import(base+'viewer/selection_geometry_outline.js');
    const {loadSelectionCache}=await import(base+'viewer/selection_cache.js');
    const metadata=await(await fetch(base+'campus_map.json')).json();
    const response=await fetch(base+'campus_exterior_standard.glb.gz');
    const bytes=await new Response(response.body.pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
    const {scene:model}=await new GLTFLoader().parseAsync(bytes,'');
    const decode=await loadSelectionCache(bytes,metadata.zones),cache=await decode();
    const previous=await(await fetch('/outline-before.json')).json();
    const renderer=new THREE.WebGLRenderer({stencil:true,preserveDrawingBuffer:true});renderer.setSize(432,936);
    document.body.appendChild(renderer.domElement);
    const camera=new THREE.PerspectiveCamera(42,432/936,.1,5000);
    const scene=new THREE.Scene();scene.background=new THREE.Color('#171717');scene.add(model);
    const gray=new THREE.MeshBasicMaterial({color:'#888888',side:THREE.DoubleSide});
    model.traverse(n=>{if(n.isMesh)n.material=gray;});model.updateMatrixWorld(true);
    const outline=createGeometrySelectionOutline(renderer,{preparedFor:n=>cache[n.name]});
    outline.material.uniforms.outlineColor.value.set('red');outline.material.uniforms.outlineOpacity.value=1;
    outline.material.uniforms.outlineWidth.value=1.5;
    const views=[];
    for(const id of ['bloco-central','bloco-didatico','bloco-administrativo','bloco-tecnologico','portaria']){
      const zone=metadata.zones.find(z=>z.id===id),node=model.getObjectByName(zone.nodeName);
      model.traverse(n=>{if(n.isMesh)n.visible=false;});node.traverse(n=>{n.visible=true;});
      const bounds=new THREE.Box3().setFromObject(node),target=bounds.getCenter(new THREE.Vector3());
      if(zone.focus.position){camera.position.fromArray(zone.focus.position);target.fromArray(zone.focus.target);}
      else{const d=new THREE.Vector3(...(zone.focus.direction??[.8,.55,-.5])).normalize();camera.position.copy(target).addScaledVector(d,bounds.getSize(new THREE.Vector3()).length()*1.6);}
      camera.lookAt(target);camera.updateMatrixWorld(true);outline.select(node);
      renderer.render(scene,camera);outline.draw(camera);
      let windowContourPixels=0,previousWindowContourPixels=null;const windowContourSamples=[];
      if(id==='bloco-central') {
        const gl=renderer.getContext(),p=new Uint8Array(432*936*4);
        const countWindowPixels=(recordSamples=true)=>{
        gl.readPixels(0,0,432,936,gl.RGBA,gl.UNSIGNED_BYTE,p);let count=0;
        // Real exported facade apertures that previously showed a colored
        // lattice. Fixed camera/viewport, away from the exterior silhouette.
        // The lower sill/exterior boundary is below these inner window bands.
        for(const [x0,y0,x1,y1] of [[0,282,134,308],[345,393,431,415]])
          for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++) {
            const i=((935-y)*432+x)*4;if(p[i]>p[i+1]+20&&p[i]>p[i+2]+20){count++;if(recordSamples&&windowContourSamples.length<20)windowContourSamples.push([x,y]);}
          }
        return count;};
        windowContourPixels=countWindowPixels();
        if(previous) {
          for(const e of Object.values(previous)) {
            const typed=(encoded,Type)=>{const s=atob(encoded),b=new Uint8Array(s.length);for(let i=0;i<s.length;i++)b[i]=s.charCodeAt(i);return new Type(b.buffer);};
            for(const key of ['maskPositions','edgeStart','edgeEnd'])if(typeof e[key]==='string')e[key]=typed(e[key],Float32Array);
            if(typeof e.maskIndices==='string')e.maskIndices=typed(e.maskIndices,Uint32Array);
          }
          const old=createGeometrySelectionOutline(renderer,{preparedFor:n=>previous[n.name]});
          old.material.uniforms.outlineColor.value.set('red');old.material.uniforms.outlineOpacity.value=1;old.material.uniforms.outlineWidth.value=1.5;
          old.select(node);renderer.render(scene,camera);old.draw(camera);previousWindowContourPixels=countWindowPixels(false);old.dispose();
          renderer.render(scene,camera);outline.draw(camera);
        }
      }
      views.push({id,snapshot:outline.snapshot(),windowContourPixels,previousWindowContourPixels,windowContourSamples,image:renderer.domElement.toDataURL('image/png').split(',')[1]});
    }
    // Two disconnected strips are enough to form a window aperture. Small
    // curved-facade panels must not require four strips or six square metres.
    const fixture=new THREE.Group(),left=new THREE.Mesh(new THREE.BoxGeometry(.05,.8,.08),gray),right=left.clone();
    left.position.x=-.4;right.position.x=.4;fixture.add(left,right);scene.remove(model);scene.add(fixture);
    const ortho=new THREE.OrthographicCamera(-1,1,1,-1,.1,10);ortho.position.z=3;ortho.updateMatrixWorld();
    renderer.setSize(80,80);outline.select(fixture);const gl=renderer.getContext();
    const pixels=()=>{const p=new Uint8Array(80*80*4);gl.readPixels(0,0,80,80,gl.RGBA,gl.UNSIGNED_BYTE,p);return p;};
    renderer.render(scene,ortho);const before=pixels();outline.draw(ortho);const after=pixels();let middle=0,changed=0;
    for(let y=0;y<80;y++)for(let x=0;x<80;x++){const i=(y*80+x)*4,d=Math.max(...[0,1,2].map(c=>Math.abs(before[i+c]-after[i+c])));if(d>2)changed++;if(x>=25&&x<55&&y>=25&&y<55)middle=Math.max(middle,d);}
    const apertures=outline.snapshot();scene.remove(fixture);
    const shape=new THREE.Shape();shape.moveTo(-.7,-.7);shape.lineTo(.7,-.7);shape.lineTo(.7,-.1);shape.lineTo(-.1,-.1);shape.lineTo(-.1,.7);shape.lineTo(-.7,.7);shape.closePath();
    const concave=new THREE.Mesh(new THREE.ExtrudeGeometry(shape,{depth:.08,bevelEnabled:false}),gray);scene.add(concave);
    outline.select(concave);renderer.render(scene,ortho);const concaveBase=pixels();outline.draw(ortho);const concaveAfter=pixels();let notchDifference=0;
    for(let y=45;y<60;y++)for(let x=45;x<60;x++){const i=(y*80+x)*4;for(let c=0;c<3;c++)notchDifference=Math.max(notchDifference,Math.abs(concaveBase[i+c]-concaveAfter[i+c]));}
    const singleConcaveEnvelopes=outline.snapshot().facadeEnvelopes;outline.dispose();renderer.dispose();
    return {views,middle,changed,apertures,notchDifference,singleConcaveEnvelopes,error:gl.getError()};
  })()`});
  assert.equal(result.exceptionDetails,undefined,JSON.stringify(result.exceptionDetails));
  const data=result.result.value;
  for(const view of data.views){await writeFile(resolve(output,view.id+'.png'),Buffer.from(view.image,'base64'));delete view.image;assert.ok(view.snapshot.edges>0);assert.equal(view.snapshot.textureTargets,0);}
  const central=data.views.find(v=>v.id==='bloco-central');
  assert.equal(central.windowContourPixels,0,'Real Central window bands have no colored grid: '+JSON.stringify(central.windowContourSamples));
  if(previousCache)assert.ok(central.previousWindowContourPixels>0,'The same pixel check reproduces the old APK window grid');
  assert.equal(data.error,0);assert.equal(data.middle,0,'Small two-strip window aperture has no inner outline');assert.ok(data.changed>0,'The outer building contour remains visible');
  assert.ok(data.apertures.facadeEnvelopes>0);
  assert.equal(data.notchDifference,0,'Single concave building notch remains empty');
  assert.equal(data.singleConcaveEnvelopes,0,'Single concave facades are not replaced by convex boxes');
  console.log(JSON.stringify(data,null,2));console.log('PASS: small facade apertures excluded; real GLB exterior previews generated without texture passes');
}finally{socket?.close();chrome.kill();server.close();}
