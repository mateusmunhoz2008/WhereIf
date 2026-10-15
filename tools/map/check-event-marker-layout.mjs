import assert from 'node:assert/strict';
import {layoutEventMarkers} from '../../assets/institutions/ifpr-pgua/map/viewer/event_marker_layout.js';

const viewport={width:412,height:892};
const item=(key,x,y,scale=1)=>({key,x,y,scale,width:88*scale,height:112*scale,
  pointerGap:8*scale,minHeight:112*scale});
const intersection=(a,b)=>Math.max(0,Math.min(a.right,b.right)-Math.max(a.left,b.left))
  * Math.max(0,Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top));
for(const size of [70,100,130,160])for(const width of [320,412,768]){
  const scale=.9*size/100;
  const items=[0,1,2].map((v)=>item(String(v),width/2+(v-1)*32,440,scale));
  const placed=layoutEventMarkers(items,{...viewport,width});
  assert.equal(placed.size,3,'All crowded events remain available');
  const values=[...placed.values()];
  assert.ok(new Set(values.map(v=>v.side)).size===2,'Close balloons alternate above/below');
  for(const a of values){
    assert.ok(a.rect.left>=8 && a.rect.right<=width-8);
    assert.ok(a.rect.top>=112 && a.rect.bottom<=782);
    for(const b of values)if(a!==b)assert.ok(intersection(a.rect,b.rect)/Math.min(a.rect.width*a.rect.height,b.rect.width*b.rect.height)<.3,'No extreme overlap after placement');
  }
  const moved=layoutEventMarkers(items.map(v=>({...v,x:v.x+.1,previous:placed.get(v.key)})),{...viewport,width});
  for(const [key,value] of placed)assert.equal(moved.get(key).side,value.side,'Sub-pixel camera motion cannot flip placements repeatedly');
  const normal=layoutEventMarkers(items.map(v=>({...v,avoidCollisions:false,previous:placed.get(v.key)})),{...viewport,width});
  assert.ok([...normal.values()].every(v=>v.side==='above'&&v.dx===0),'Normal mode restores original positions, even after automatic placement');
  assert.ok(intersection(normal.get('0').rect,normal.get('1').rect)>0,'Normal mode permits overlapping markers');
}
const isolated=layoutEventMarkers([item('alone',206,440)],viewport).get('alone');
assert.equal(isolated.side,'above');assert.equal(isolated.offset,0);
assert.equal(layoutEventMarkers([item('header',206,150)],viewport).get('header').side,'below','A label near the header uses the space beneath its anchor');
assert.equal(layoutEventMarkers([item('bottom',206,740)],viewport).get('bottom').side,'above');
const stack={...item('stack',206,440),width:193,height:234,minHeight:42,expanded:true};
const priority=layoutEventMarkers([item('other',210,440),stack],viewport);
assert.equal(priority.get('stack').side,'above','Expanded events take priority over closed labels');
assert.ok(priority.has('other'));
const dense=layoutEventMarkers(Array.from({length:6},(_,i)=>item(String(i),206,440,1.44)),viewport);
assert.equal(dense.size,6);
for(const [key,a] of dense)for(const [other,b] of dense)if(key!==other)
  assert.equal(a.offset,0,'No detached rows or connector lines');
for(const size of [70,160]){
  let previous=null;
  for(const x of [12,25,206,390,360,206]){
    const sample=item('roundtrip',x,440,size/100);
    const value=layoutEventMarkers([{...sample,previous}],viewport).get(sample.key);
    const expected=Math.max(8+sample.width/2,Math.min(404-sample.width/2,x))-x;
    assert.ok(Math.abs(value.dx-expected)<.001,'The pointer follows current edge clamping, not the remembered displacement');
    if(x===206)assert.equal(value.dx,0,'Returning from either edge recenters the cavity');
    previous=value;
  }
}
const lockedItems=[{...item('a',206,440),previous:{side:'above',dx:80,offset:200}},
  {...item('b',210,440),previous:{side:'above',dx:-90,offset:100}}];
const locked=layoutEventMarkers(lockedItems,{...viewport,lockSides:true});
for(const v of locked.values()){assert.equal(v.side,'above');assert.equal(v.dx,0);assert.equal(v.offset,0);}
assert.equal(layoutEventMarkers([{...item('a',206,440),avoidCollisions:false,previous:{side:'below',dx:90}}],viewport).get('a').side,'above','Exterior keeps its old edge-only behavior');
console.log('PASS: responsive above/below, edge→center round trips, no detached rows/lines, stable gesture sides and expanded-stack priority');
