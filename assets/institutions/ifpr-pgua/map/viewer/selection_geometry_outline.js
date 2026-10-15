import * as THREE from './vendor/three.module.min.js';

export function collectSelectionWindowMeshes(root) {
  const meshes=[];
  root.traverse(node=>{
    if(!node.isMesh)return;
    const materials=Array.isArray(node.material)?node.material:[node.material];
    if(materials.some(material=>/window|janela/i.test(`${node.name} ${material?.name??''}`)))meshes.push(node);
  });
  return meshes;
}

// Rasterize the selected silhouette into the existing stencil attachment,
// then draw a single batch of narrow edge ribbons outside it. Unlike the
// screen-space outline, camera travel needs no color targets, fullscreen
// texture filtering or framebuffer switches. Window geometry fills the mask
// but its interior edges never pass the stencil test.
export function createGeometrySelectionOutline(renderer, { windowNodesFor = () => [], preparedFor = () => null } = {}) {
  const maskScene = new THREE.Scene();
  maskScene.userData.selectionMask = true;
  const scene = new THREE.Scene();
  scene.userData.selectionComposite = true;
  const maskMaterial = new THREE.MeshBasicMaterial({
    colorWrite: false, depthTest: false, depthWrite: false,
    side: THREE.DoubleSide, toneMapped: false,
    stencilWrite: true, stencilWriteMask: 1,
    stencilFunc: THREE.AlwaysStencilFunc, stencilRef: 1,
    stencilZPass: THREE.ReplaceStencilOp,
  });
  const material = new THREE.ShaderMaterial({
    name: 'SelectionEdgeRibbons', transparent: true, depthTest: false,
    depthWrite: false, toneMapped: false, side: THREE.DoubleSide,
    forceSinglePass: true,
    // bit 1 contains the silhouette; bit 2 prevents overlapping ribbons from
    // making the fade brighter at corners. A passing fragment flips bit 2.
    stencilWrite: true, stencilWriteMask: 2,
    stencilFunc: THREE.EqualStencilFunc, stencilFuncMask: 3, stencilRef: 0,
    stencilZPass: THREE.InvertStencilOp,
    uniforms: {
      outlineColor: { value: new THREE.Color('white') },
      outlineOpacity: { value: 0 }, outlineWidth: { value: 1 },
      viewport: { value: new THREE.Vector2(1,1) },
      selectionViewProjection: { value: new THREE.Matrix4() },
    },
    vertexShader: `
      attribute vec3 edgeStart; attribute vec3 edgeEnd;
      uniform vec2 viewport; uniform float outlineWidth;
      uniform mat4 selectionViewProjection;
      varying vec2 edgeAcross;
      void main(){
        vec4 a=selectionViewProjection*vec4(edgeStart,1.);
        vec4 b=selectionViewProjection*vec4(edgeEnd,1.);
        float nearA=a.z+a.w, nearB=b.z+b.w;
        // Clip crossing edges before dividing by w, so close stairs/rooms do
        // not explode across the screen when an endpoint crosses the camera.
        if(nearA<0.&&nearB<0.){gl_Position=vec4(2.,2.,2.,1.);edgeAcross=vec2(0.,1.);return;}
        if(nearA<0.)a=mix(a,b,clamp(nearA/(nearA-nearB),0.,1.));
        else if(nearB<0.)b=mix(b,a,clamp(nearB/(nearB-nearA),0.,1.));
        if(a.w<=.00001||b.w<=.00001){gl_Position=vec4(2.,2.,2.,1.);edgeAcross=vec2(0.,1.);return;}
        vec2 delta=(b.xy/b.w-a.xy/a.w)*viewport*.5;
        float lengthPixels=length(delta);
        if(lengthPixels<.01){gl_Position=vec4(2.,2.,2.,1.);edgeAcross=vec2(0.,1.);return;}
        vec2 direction=delta/lengthPixels;
        float radius=outlineWidth+.5;
        vec2 offset=(vec2(-direction.y,direction.x)*position.y+direction*position.x)*radius;
        vec4 endpoint=position.x<0.?a:b;
        endpoint.xy+=offset*2./viewport*endpoint.w;
        gl_Position=endpoint;
        // Correct perspective interpolation to retain a constant pixel-width
        // feather even on long edges pointing towards the camera.
        edgeAcross=vec2(position.y*endpoint.w,endpoint.w);
      }`,
    fragmentShader: `
      uniform vec3 outlineColor; uniform float outlineOpacity; uniform float outlineWidth;
      varying vec2 edgeAcross;
      void main(){
        float side=abs(edgeAcross.x/edgeAcross.y);
        float coverage=clamp((1.-side)*(outlineWidth+.5),0.,1.);
        float alpha=coverage*outlineOpacity;
        // No discard/depth writes: allow early stencil rejection to skip the
        // thousands of ribbons hidden inside the selected silhouette.
        gl_FragColor=vec4(outlineColor,alpha);
      }`,
  });
  const edgeCache = new WeakMap();
  let selections = new WeakMap();
  const owned = new Set();
  const edgePoint = new THREE.Vector3();
  const viewProjection = new THREE.Matrix4(), frustum = new THREE.Frustum();
  let selectedNode = null, current = null;
  const counters = { maskRenders: 0, edgeRenders: 0, composites: 0, geometryBuilds: 0, culledFrames: 0 };

  function prepare(node) {
    if (!node) return null;
    if (selections.has(node)) return selections.get(node);
    const baked = preparedFor(node);
    if (baked) {
      const maskGeometry = new THREE.BufferGeometry();
      maskGeometry.setAttribute('position', new THREE.BufferAttribute(baked.maskPositions, 3));
      maskGeometry.setIndex(new THREE.BufferAttribute(baked.maskIndices, 1));
      const maskMesh = new THREE.Mesh(maskGeometry, maskMaterial);
      const geometry = new THREE.InstancedBufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute([-1,-1,0,-1,1,0,1,-1,0,1,1,0],3));
      geometry.setIndex([0,2,1,2,3,1]);
      geometry.setAttribute('edgeStart', new THREE.InstancedBufferAttribute(baked.edgeStart, 3));
      geometry.setAttribute('edgeEnd', new THREE.InstancedBufferAttribute(baked.edgeEnd, 3));
      geometry.instanceCount = baked.edgeStart.length / 3;
      const mesh = new THREE.Mesh(geometry, material); mesh.frustumCulled = false;
      const entry = { proxies: [maskMesh], maskGeometry, geometry, mesh, count: geometry.instanceCount,
        sphere: new THREE.Sphere(new THREE.Vector3().fromArray(baked.sphere), baked.sphere[3]),
        windowRows: baked.windowRows, filledHoles: baked.filledHoles, facadeEnvelopes: baked.facadeEnvelopes };
      selections.set(node, entry); owned.add(entry); counters.geometryBuilds++;
      return entry;
    }
    node.updateWorldMatrix(true,true);
    const positions = [], maskPositions = [], maskIndices = [], windowPlanes = new Map(), facadePlanes = new Map();
    let filledHoles=0, facadeEnvelopes=0;
    const bounds = new THREE.Box3();
    const a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3();
    const normal=new THREE.Vector3(),ab=new THREE.Vector3(),ac=new THREE.Vector3();
    const windowClipBounds=new THREE.Box3();
    function addWindowPlane(a,b,c) {
      ab.subVectors(b,a);ac.subVectors(c,a);normal.crossVectors(ab,ac);
      if(normal.lengthSq()<1e-10)return;normal.normalize();
      if(Math.abs(normal.y)>.5)return;
      if(normal.x<-.001||(Math.abs(normal.x)<=.001&&normal.z<0))normal.negate();
      const distance=normal.dot(a);
      const key=[normal.x,normal.y,normal.z].map(v=>Math.round(v*10000)).join(',')+','+
        Math.round(distance*100)+','+Math.round(Math.min(a.y,b.y,c.y)*100)+','+Math.round(Math.max(a.y,b.y,c.y)*100);
      let plane=windowPlanes.get(key);
      if(!plane) {
        const u=new THREE.Vector3(normal.z,0,-normal.x).normalize();
        const v=new THREE.Vector3().crossVectors(normal,u).normalize();
        plane={origin:normal.clone().multiplyScalar(distance),normal:normal.clone(),distance,u,v,
          minU:Infinity,maxU:-Infinity,minV:Infinity,maxV:-Infinity};
        windowPlanes.set(key,plane);
      }
      for(const p of [a,b,c]) {
        const pu=p.dot(plane.u),pv=p.dot(plane.v);
        plane.minU=Math.min(plane.minU,pu);plane.maxU=Math.max(plane.maxU,pu);
        plane.minV=Math.min(plane.minV,pv);plane.maxV=Math.max(plane.maxV,pv);
      }
    }
    function appendWindowSource(source,attribute) {
      const index=source.geometry.index,indexCount=index?.count??attribute.count;
      const materials=Array.isArray(source.material)?source.material:[source.material];
      const groups=source.geometry.groups.length?source.geometry.groups:[{start:0,count:indexCount,materialIndex:0}];
      const point=i=>new THREE.Vector3().fromBufferAttribute(attribute,index?index.getX(i):i).applyMatrix4(source.matrixWorld);
      // Shared exported window meshes can span several buildings. Clip their
      // triangles in world space, so only this block's apertures fill stencil.
      for(const group of groups) {
        if(!/window|janela/i.test(`${source.name} ${materials[group.materialIndex]?.name??''}`))continue;
        for(let i=group.start;i+2<Math.min(indexCount,group.start+group.count);i+=3) {
          let polygon=[point(i),point(i+1),point(i+2)];
          for(const axis of ['x','y','z'])for(const side of ['min','max']) {
            const limit=windowClipBounds[side][axis],inside=p=>side==='min'?p[axis]>=limit:p[axis]<=limit;
            const clipped=[];
            for(let j=0;j<polygon.length;j++) {
              const start=polygon[j],end=polygon[(j+1)%polygon.length],startIn=inside(start),endIn=inside(end);
              if(startIn)clipped.push(start);
              if(startIn!==endIn)clipped.push(start.clone().lerp(end,(limit-start[axis])/(end[axis]-start[axis])));
            }
            polygon=clipped;
          }
          if(polygon.length<3)continue;
          const base=maskPositions.length/3;
          for(const p of polygon)maskPositions.push(p.x,p.y,p.z);
          for(let j=1;j+1<polygon.length;j++) {
            maskIndices.push(base,base+j,base+j+1);
            addWindowPlane(polygon[0],polygon[j],polygon[j+1]);
          }
        }
      }
    }
    function appendSource(source, includeEdges=true) {
      if(!source.isMesh||!source.geometry||source.userData.interiorSpace?.marker===source)return;
      const attribute=source.geometry.getAttribute('position');if(!attribute)return;
      if(!includeEdges){appendWindowSource(source,attribute);return;}
      const vertexBase=maskPositions.length/3;
      for(let i=0;i<attribute.count;i++) {
        edgePoint.fromBufferAttribute(attribute,i).applyMatrix4(source.matrixWorld);
        maskPositions.push(edgePoint.x,edgePoint.y,edgePoint.z);bounds.expandByPoint(edgePoint);
      }
      const index=source.geometry.index;
      const indexCount=index?.count??attribute.count;
      const indexAt=i=>vertexBase+(index?index.getX(i):i);
      for(let i=0;i<indexCount;i++)maskIndices.push(indexAt(i));
      if(includeEdges)for(let i=0;i+2<indexCount;i+=3) {
        let ia=indexAt(i),ib=indexAt(i+1),ic=indexAt(i+2);
        a.fromArray(maskPositions,ia*3);b.fromArray(maskPositions,ib*3);c.fromArray(maskPositions,ic*3);
        ab.subVectors(b,a);ac.subVectors(c,a);normal.crossVectors(ab,ac);
        if(normal.lengthSq()<1e-10)continue;normal.normalize();
        if(Math.abs(normal.y)>.4)continue;
        if(normal.x<-.001||(Math.abs(normal.x)<=.001&&normal.z<0)) {
          normal.negate();const swap=ib;ib=ic;ic=swap;
        }
        const distance=normal.dot(a);
        const key=[normal.x,normal.y,normal.z].map(v=>Math.round(v*1000)).join(',')+','+Math.round(distance*100);
        let plane=facadePlanes.get(key);
        if(!plane) {
          const u=new THREE.Vector3(normal.z,0,-normal.x).normalize();
          plane={u,v:new THREE.Vector3().crossVectors(normal,u).normalize(),normal:normal.clone(),distance,edges:new Map()};
          facadePlanes.set(key,plane);
        }
        const pointKey=id=>[0,1,2].map(c=>Math.round(maskPositions[id*3+c]*10000)).join(',');
        for(const [from,to] of [[ia,ib],[ib,ic],[ic,ia]]) {
          const start=pointKey(from),end=pointKey(to);if(start===end)continue;
          const reverse=end+'>'+start;
          if(plane.edges.has(reverse))plane.edges.delete(reverse);
          else plane.edges.set(start+'>'+end,{start,end,from,to});
        }
      }
      const materials=Array.isArray(source.material)?source.material:[source.material];
      const groups=source.geometry.groups.length?source.geometry.groups:[{start:0,count:indexCount,materialIndex:0}];
      for(const group of groups) {
        if(!/window|janela/i.test(`${source.name} ${materials[group.materialIndex]?.name??''}`))continue;
        for(let i=group.start;i+2<Math.min(indexCount,group.start+group.count);i+=3) {
          a.fromArray(maskPositions,indexAt(i)*3);b.fromArray(maskPositions,indexAt(i+1)*3);c.fromArray(maskPositions,indexAt(i+2)*3);
          addWindowPlane(a,b,c);
        }
      }
      // Window-only meshes contribute to the silhouette mask, never to the
      // visible ribbons, even when their frame protrudes beyond a facade.
      if(!includeEdges||materials.every(material=>/window|janela/i.test(`${source.name} ${material?.name??''}`)))return;
      let edges=edgeCache.get(source.geometry);
      if(!edges){
        // Include shallow curved edges too; skip only truly coplanar diagonals.
        const lines=new THREE.EdgesGeometry(source.geometry,.01);
        edges=lines.getAttribute('position').array.slice();
        lines.dispose();edgeCache.set(source.geometry,edges);
      }
      for(let i=0;i<edges.length;i+=3){
        edgePoint.fromArray(edges,i).applyMatrix4(source.matrixWorld);
        bounds.expandByPoint(edgePoint);
        positions.push(edgePoint.x,edgePoint.y,edgePoint.z);
      }
    }
    node.traverseVisible(source=>appendSource(source));
    windowClipBounds.copy(bounds).expandByScalar(.85);
    for(const windowNode of windowNodesFor(node)) {
      windowNode.updateWorldMatrix(true,true);
      windowNode.traverse(source=>appendSource(source,false));
    }
    // The exported block also has concrete grilles/vents with no window
    // material. Fill only enclosed holes of each planar facade, not its outer
    // contour or concave campus silhouette. This replaces the old per-pixel
    // hole detector with a one-time topological operation.
    for(const plane of facadePlanes.values()) {
      const outgoing=new Map(),used=new Set();
      const outerPoints=[];let outerLoops=0;
      for(const edge of plane.edges.values()) {
        const list=outgoing.get(edge.start)??[];list.push(edge);outgoing.set(edge.start,list);
      }
      for(const first of plane.edges.values()) {
        if(used.has(first))continue;
        const loop=[];let edge=first,closed=false;
        while(edge&&!used.has(edge)) {
          used.add(edge);loop.push(edge.from);
          if(edge.end===first.start){closed=true;break;}
          edge=outgoing.get(edge.end)?.find(candidate=>!used.has(candidate));
        }
        if(!closed||loop.length<3)continue;
        const contour=loop.map(id=>{
          edgePoint.fromArray(maskPositions,id*3);
          return new THREE.Vector2(edgePoint.dot(plane.u),edgePoint.dot(plane.v));
        });
        if(THREE.ShapeUtils.area(contour)>=-1e-5) {
          outerLoops++;for(let i=0;i<contour.length;i++)outerPoints.push({x:contour[i].x,y:contour[i].y,id:loop[i]});
          continue;
        }
        for(const triangle of THREE.ShapeUtils.triangulateShape(contour,[]))
          maskIndices.push(loop[triangle[0]],loop[triangle[1]],loop[triangle[2]]);
        filledHoles++;
      }
      // Blender joins some grilles as overlapping, disconnected beam meshes
      // instead of a face with topological holes. Their planar facade envelope
      // fills those apertures in stencil only; it does not replace the curved
      // building mesh or its visible materials.
      // A window can be bounded by just two disconnected strips, including
      // narrow panels on a curved facade. Requiring four loops/a large area
      // left those apertures open in stencil and outlined their mullions.
      // A single concave facade keeps its real contour; only disconnected
      // coplanar pieces get an envelope to close their internal apertures.
      if(outerLoops>=2&&outerPoints.length>=3) {
        outerPoints.sort((a,b)=>a.x-b.x||a.y-b.y);
        const cross=(a,b,c)=>(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
        const lower=[],upper=[];
        for(const p of outerPoints){while(lower.length>=2&&cross(lower.at(-2),lower.at(-1),p)<=1e-8)lower.pop();lower.push(p);}
        for(let i=outerPoints.length-1;i>=0;i--){const p=outerPoints[i];while(upper.length>=2&&cross(upper.at(-2),upper.at(-1),p)<=1e-8)upper.pop();upper.push(p);}
        const hull=lower.slice(0,-1).concat(upper.slice(0,-1));
        if(hull.length>=3) {
          const contour=hull.map(p=>new THREE.Vector2(p.x,p.y));
          if(Math.abs(THREE.ShapeUtils.area(contour))>1e-5) {
            for(const triangle of THREE.ShapeUtils.triangulateShape(contour,[]))
              maskIndices.push(hull[triangle[0]].id,hull[triangle[1]].id,hull[triangle[2]].id);
            facadeEnvelopes++;
            plane.envelope=contour;
          }
        }
      }
    }
    // Glass/frame meshes often have tiny lattice openings. Fill their planar
    // rows in stencil only (never in the visible model), keeping the outline
    // on the building rather than drawing every window/vent as a purple grid.
    for(const plane of windowPlanes.values()) {
      const base=maskPositions.length/3;
      for(const [u,v] of [[plane.minU-.1,plane.minV-.1],[plane.maxU+.1,plane.minV-.1],
        [plane.maxU+.1,plane.maxV+.1],[plane.minU-.1,plane.maxV+.1]]) {
        edgePoint.copy(plane.origin).addScaledVector(plane.u,u).addScaledVector(plane.v,v);
        maskPositions.push(edgePoint.x,edgePoint.y,edgePoint.z);
      }
      maskIndices.push(base,base+1,base+2,base,base+2,base+3);
    }
    const maskGeometry=new THREE.BufferGeometry();
    maskGeometry.setAttribute('position',new THREE.Float32BufferAttribute(maskPositions,3));
    maskGeometry.setIndex(maskIndices);
    const maskMesh=new THREE.Mesh(maskGeometry,maskMaterial);
    const filteredPositions=[];
    for(let i=0;i<positions.length;i+=6) {
      a.fromArray(positions,i);b.fromArray(positions,i+3);
      let windowEdge=false;
      for(const plane of windowPlanes.values()) {
        if(Math.abs(plane.normal.dot(a)-plane.distance)>.85||Math.abs(plane.normal.dot(b)-plane.distance)>.85)continue;
        const au=a.dot(plane.u),bu=b.dot(plane.u),av=a.dot(plane.v),bv=b.dot(plane.v);
        if(Math.min(au,bu)>=plane.minU-.2&&Math.max(au,bu)<=plane.maxU+.2&&
          Math.min(av,bv)>=plane.minV-.2&&Math.max(av,bv)<=plane.maxV+.2) {
          windowEdge=true;break;
        }
      }
      if(!windowEdge)for(const plane of facadePlanes.values()) {
        if(!plane.envelope||Math.abs(plane.normal.dot(a)-plane.distance)>.85||
          Math.abs(plane.normal.dot(b)-plane.distance)>.85)continue;
        const au=a.dot(plane.u),av=a.dot(plane.v),bu=b.dot(plane.u),bv=b.dot(plane.v);
        let interior=true;
        for(let j=0;j<plane.envelope.length;j++) {
          const p=plane.envelope[j],q=plane.envelope[(j+1)%plane.envelope.length];
          const du=q.x-p.x,dv=q.y-p.y,length=Math.hypot(du,dv);
          if(length<1e-8)continue;
          // Keep a generous boundary margin for all camera distances and the
          // entrance pulse. Only hidden, deep-interior grille lines are culled.
          if((du*(av-p.y)-dv*(au-p.x))/length<1||
            (du*(bv-p.y)-dv*(bu-p.x))/length<1){interior=false;break;}
        }
        if(interior){windowEdge=true;break;}
      }
      if(!windowEdge)for(let c=0;c<6;c++)filteredPositions.push(positions[i+c]);
    }
    const count=filteredPositions.length/6;
    const geometry=new THREE.InstancedBufferGeometry();
    geometry.setAttribute('position',new THREE.Float32BufferAttribute([-1,-1,0,-1,1,0,1,-1,0,1,1,0],3));
    geometry.setIndex([0,2,1,2,3,1]);
    const starts=new Float32Array(count*3),ends=new Float32Array(count*3);
    for(let i=0;i<count;i++)for(let c=0;c<3;c++){
      starts[i*3+c]=filteredPositions[i*6+c];ends[i*3+c]=filteredPositions[i*6+3+c];
    }
    geometry.setAttribute('edgeStart',new THREE.InstancedBufferAttribute(starts,3));
    geometry.setAttribute('edgeEnd',new THREE.InstancedBufferAttribute(ends,3));
    geometry.instanceCount=count;
    const mesh=new THREE.Mesh(geometry,material);mesh.frustumCulled=false;
    const sphere=bounds.getBoundingSphere(new THREE.Sphere());sphere.radius+=2;
    const entry={proxies:[maskMesh],maskGeometry,geometry,mesh,count,sphere,windowRows:windowPlanes.size,filledHoles,facadeEnvelopes};
    selections.set(node,entry);owned.add(entry);counters.geometryBuilds++;
    return entry;
  }
  function clear({release=false}={}) {
    maskScene.clear();scene.clear();selectedNode=null;current=null;
    if(release){for(const entry of owned){entry.geometry.dispose();entry.maskGeometry.dispose();}owned.clear();selections=new WeakMap();}
  }
  function select(node) {
    clear();selectedNode=node;current=prepare(node);
    if(!current)return;
    maskScene.add(...current.proxies);maskScene.updateMatrixWorld(true);
    scene.add(current.mesh);
  }
  function draw(camera) {
    if(!current||!current.count||material.uniforms.outlineOpacity.value<=.001)return;
    viewProjection.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);
    // Compute this matrix once per draw, not twice for every ribbon vertex.
    material.uniforms.selectionViewProjection.value.copy(viewProjection);
    frustum.setFromProjectionMatrix(viewProjection);
    if(!frustum.intersectsSphere(current.sphere)){counters.culledFrames++;return;}
    const target=renderer.getRenderTarget();
    // Only the completed main framebuffer is outlined, after the optional
    // color pipeline. Its stencil attachment belongs to this renderer.
    if(target!==null)return;
    const autoClear=renderer.autoClear,shadows=renderer.shadowMap.enabled;
    try{
      renderer.shadowMap.enabled=false;renderer.autoClear=false;
      renderer.clearStencil();
      renderer.getDrawingBufferSize(material.uniforms.viewport.value);
      renderer.render(maskScene,camera);counters.maskRenders++;
      renderer.render(scene,camera);counters.edgeRenders++;counters.composites++;
    }finally{
      renderer.autoClear=autoClear;renderer.shadowMap.enabled=shadows;
      renderer.state.buffers.stencil.setTest(false);
    }
  }
  async function warmup(nodes,camera,yieldWork) {
    const target=renderer.getRenderTarget(), shadows=renderer.shadowMap.enabled;
    const warmTarget=new THREE.WebGLRenderTarget(1,1,{depthBuffer:true,stencilBuffer:true});
    try {
      renderer.shadowMap.enabled=false;
      for(const node of nodes) {
        const entry=prepare(node);if(!entry?.count)continue;
        const warmScene=new THREE.Scene();
        const warmMesh=new THREE.Mesh(entry.geometry,material);warmMesh.frustumCulled=false;
        warmScene.add(warmMesh);
        warmScene.add(new THREE.Mesh(entry.maskGeometry,maskMaterial));
        await renderer.compileAsync(warmScene,camera);
        renderer.setRenderTarget(warmTarget);renderer.render(warmScene,camera);
        renderer.setRenderTarget(target);
        await yieldWork?.();
      }
    } finally {
      renderer.setRenderTarget(target);renderer.shadowMap.enabled=shadows;
      renderer.state.buffers.stencil.setTest(false);warmTarget.dispose();
    }
  }
  return { material, scene, maskScene, prepare, select, clear, draw, warmup,
    get selectedNode(){return selectedNode;},
    snapshot:()=>({...counters,mode:'stencil-edge-ribbons',proxies:current?.proxies.length??0,
      edges:current?.count??0,textureTargets:0,textureSamples:0,
      windowRows:current?.windowRows??0,
      filledHoles:current?.filledHoles??0,
      facadeEnvelopes:current?.facadeEnvelopes??0,
      cachedGeometries:owned.size,geometryBytes:[...owned].reduce((total,entry)=>total+entry.count*24+
        entry.maskGeometry.getAttribute('position').array.byteLength+entry.maskGeometry.index.array.byteLength,0)}),
    dispose(){clear({release:true});maskMaterial.dispose();material.dispose();},
  };
}
