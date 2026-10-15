import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../../assets/institutions/ifpr-pgua/map/viewer/vendor/three.module.min.js';
import { createNavigationOffsetCache } from '../../assets/institutions/ifpr-pgua/map/viewer/navigation_cache.js';

const source = readFileSync(new URL('../../assets/institutions/ifpr-pgua/map/viewer/viewer.js', import.meta.url), 'utf8');
const names = ['convexHull', 'clipNavigationPolygon', 'navigationPolygonForOffsets',
  'feasibleNavigationPolygon', 'closestPointInPolygon', 'constrainNavigationPoint',
  'viewportNavigationOffsets', 'constrainedNavigationTarget'];
const functions = names.map(name => source.match(new RegExp(`^function ${name}\\([^]*?^}`, 'm'))[0]).join('\n');
const hull = [new THREE.Vector2(-100,-80),new THREE.Vector2(100,-80),new THREE.Vector2(100,80),new THREE.Vector2(-100,80)];
const edges = hull.map((origin, index) => {
  const delta = hull[(index+1)%hull.length].clone().sub(origin);
  return { origin, inward: new THREE.Vector2(-delta.y,delta.x).normalize() };
});
const make = cached => {
  const context = vm.createContext({ THREE, navigationBounds: new THREE.Box3(new THREE.Vector3(-100,0,-80),new THREE.Vector3(100,10,80)),
    navigationHull:hull, navigationEdges:edges, navigationInset:1, navigationTargetHeight:4,
    cameraTuning:{topView:{initialTarget:[0,4,0]}}, interiors:null, controls:{target:new THREE.Vector3(0,4,0)},
    navigationOffsetCache: cached ? createNavigationOffsetCache() : {get:()=>null,set:(c,t,h,v,offsets)=>offsets},
    navigationPolygonCache: cached ? new WeakMap() : {get:()=>null,set(){}}, emptyNavigationOffsets:[] });
  vm.runInContext(functions, context); return context;
};
const fast = make(true), reference = make(false);
let rayCalls=0;
const oldRay = THREE.Raycaster.prototype.setFromCamera;
THREE.Raycaster.prototype.setFromCamera = function(...args){rayCalls++;return oldRay.apply(this,args);};
try {
  for (const kind of ['perspective','orthographic']) {
    const camera = kind === 'perspective' ? new THREE.PerspectiveCamera(42,.45,.1,5000)
      : new THREE.OrthographicCamera(-80,80,120,-120,.1,5000);
    fast.camera=reference.camera=camera;
    const target=fast.controls.target;
    reference.controls.target=target;
    target.set(0,4,0); camera.position.set(130,170,120);camera.lookAt(target);
    // Identical relative pose during panning must not recast the viewport.
    fast.viewportNavigationOffsets(camera,target);
    const casts = rayCalls;
    camera.position.x+=12;camera.position.z-=8;target.x+=12;target.z-=8;
    fast.viewportNavigationOffsets(camera,target);
    assert.equal(rayCalls,casts,'Panning reuses the same ground-ray offsets');
    camera.zoom=1.2;camera.updateProjectionMatrix();
    fast.viewportNavigationOffsets(camera,target);
    assert.ok(rayCalls>casts,'Zoom changes invalidate the ray cache');
    for(let index=0;index<120;index++) {
      target.set(Math.sin(index*.17)*140,4,Math.cos(index*.11)*100);
      if(index%12===0)camera.zoom=1+index/300;
      camera.updateProjectionMatrix();
      const angle=index*.03;
      camera.position.copy(target).add(new THREE.Vector3(Math.sin(angle)*180,140+index%9,Math.cos(angle)*180));
      camera.lookAt(target);
      for(const ctx of [fast,reference])ctx.navigationInset=index%7;
      const expected=reference.constrainedNavigationTarget(camera,target);
      const actual=fast.constrainedNavigationTarget(camera,target);
      assert.ok(actual.distanceTo(expected)<1e-8,`${kind}: cached boundary must match uncached boundary`);
      const again=fast.constrainedNavigationTarget(camera,target);
      assert.ok(again.distanceTo(expected)<1e-8,'Repeated constraint keeps the same result');
    }
  }
  fast.navigationEdges=[];fast.navigationHull=[];
  const before=rayCalls;
  const constrained=fast.constrainedNavigationTarget(fast.camera,new THREE.Vector3(140,4,-120));
  assert.equal(rayCalls,before,'Interior rectangular bounds need no viewport raycasting');
  assert.equal(constrained.x,100);assert.equal(constrained.z,-80);
} finally { THREE.Raycaster.prototype.setFromCamera=oldRay; }
console.log('PASS: identical 2D/3D bounds, pan cache reuse, zoom/rotation/inset invalidation and no interior ground rays');
