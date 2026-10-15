import * as THREE from './vendor/three.module.min.js';
import { layoutEventMarkers } from './event_marker_layout.js';

export const eventMarkerFadeMs=180;
export const eventMarkerPalette=[
  ['#e17078','#ad505b'],['#aa7bc7','#8053a8'],['#d77fa8','#ac557e'],
  ['#769cc8','#4c78a8'],['#62aaa3','#3e817a'],['#cc9e60','#926b38'],
];

function darkSurface(event){
  if(typeof event.dark==='boolean')return event.dark;
  const color=event.surface?.match(/^#([0-9a-f]{6})$/i)?.[1];
  return color?parseInt(color.slice(0,2),16)+parseInt(color.slice(2,4),16)+parseInt(color.slice(4,6),16)<384:false;
}

export function eventMarkerScale(distance,interior) {
  return THREE.MathUtils.clamp((interior?90:190)/Math.max(1,distance),.72,1.08);
}

export function normalizedInteriorEventSize(percent) {
  return Number.isFinite(percent)?Math.round(THREE.MathUtils.clamp(percent,70,160)/5)*5:100;
}

export function markerImageSource(source,baseURI) {
  if(typeof source!=='string' || !source)return null;
  try {
    const base=new URL(baseURI);
    if(source.startsWith('assets/') && !source.includes('\\') &&
      source.split('/').every(part=>part && decodeURIComponent(part)!=='..' && !decodeURIComponent(part).includes('/'))) {
      const assetRoot=base.pathname.indexOf('/assets/');
      const path=assetRoot>=0?base.pathname.slice(0,assetRoot+1)+source:'/'+source;
      return new URL(path,base).href;
    }
    const url=new URL(source);
    return ['https:','http:'].includes(url.protocol)?url.href:null;
  }catch{return null;}
}

// Small DOM balloons: no blur, 3D meshes, lights, targets or separate loop.
export function createMapEventMarkers({anchorFor,onSelected,onPointerDown,onPointerEnd,interiorSize=100,autoLayout=true}) {
  let currentInteriorSize=normalizedInteriorEventSize(interiorSize);
  let currentAutoLayout=autoLayout!==false;
  const style=document.createElement('style');
  style.textContent=`
    .map-event-markers{position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:3;contain:layout style;
      -webkit-tap-highlight-color:transparent}
    .map-event-markers[data-camera-gesture=true] .map-event-card,
    .map-event-markers[data-camera-gesture=true] .map-event-fan{pointer-events:none}
    .map-event-anchor{position:absolute;left:0;top:0;width:0;height:0;transform-origin:0 0;will-change:transform;contain:layout style}
    .map-event-anchor[hidden]{display:none}
    .map-event-card{position:absolute;left:0;bottom:calc(8px + var(--bubble-offset,0px));transform:translateX(-50%);
      pointer-events:auto;border:0;border-radius:13px;padding:7px 10px;
      font:700 11px/1.2 system-ui;cursor:pointer;box-shadow:0 2px 5px #0003;
      background-color:var(--bubble-bg);color:var(--bubble-fg);display:flex;align-items:center;gap:5px;
      appearance:none;-webkit-appearance:none;outline:none;user-select:none;-webkit-user-select:none;
      transform-origin:50% 100%;transition:transform 100ms cubic-bezier(.2,0,.2,1),background-color 100ms ease-out}
    .map-event-card[data-pressed=true]{transform:translateX(-50%) scale(.96);background-color:var(--bubble-pressed)}
    .map-event-card:focus-visible{outline:2px solid var(--bubble-fg);outline-offset:3px}
    .map-event-card::after,.map-event-fan::after{content:'';position:absolute;top:100%;
      left:var(--pointer-offset,50%);transform:translateX(-50%);width:13px;height:8px;background:var(--bubble-bg);
      clip-path:polygon(0 0,100% 0,50% 100%);pointer-events:none;transition:background-color 100ms ease-out}
    .map-event-card[data-pressed=true]::after{background-color:var(--bubble-pressed)}
    .map-event-card[data-stacked=true]{box-shadow:3px -3px 0 var(--bubble-stack),
      6px -6px 0 var(--bubble-stack-back),0 2px 5px #0003}
    .map-event-title{overflow:hidden;text-overflow:ellipsis}
    .map-event-exterior{box-sizing:border-box;min-width:132px;min-height:48px;padding:12px 14px;
      justify-content:center;gap:8px;font-size:13px;border-radius:16px}
    .map-event-exterior .map-event-title{white-space:nowrap}
    .map-event-exterior .map-event-count{font-size:11px;padding:3px 5px}
    .map-event-count{font-size:9px;border-radius:7px;background:#0002;padding:2px 4px;flex-shrink:0}
    .map-event-place{box-sizing:border-box;width:88px;min-height:94px;padding:8px;
      border-radius:16px;flex-direction:column;gap:6px;text-align:center}
    .map-event-place .map-event-title{display:-webkit-box;-webkit-line-clamp:2;
      -webkit-box-orient:vertical;line-height:1.2;max-height:27px;width:72px}
    .map-event-photo{width:44px;height:44px;flex-shrink:0;border-radius:50%;overflow:hidden;
      display:grid;place-items:center;background:var(--photo-bg,#bf8de8);font-size:18px;color:var(--photo-fg,#fff)}
    .map-event-photo img{width:100%;height:100%;object-fit:cover;grid-area:1/1}
    .map-event-photo span{grid-area:1/1}
    .map-event-place .map-event-count{position:absolute;right:3px;top:3px;background:var(--photo-bg);color:var(--photo-fg)}
    .map-event-fan{position:absolute;left:0;bottom:calc(8px + var(--bubble-offset,0px));transform:translateX(-50%);
      pointer-events:auto;background:var(--bubble-bg);padding:5px;
      border-radius:18px;box-shadow:0 3px 9px #0003}
    .map-event-choices{display:grid;gap:7px;max-height:340px;overflow-y:auto;overflow-x:hidden;border-radius:13px}
    .map-event-fan[hidden],.map-event-card[hidden]{display:none}
    .map-event-fan .map-event-card{position:relative;left:auto;bottom:auto;transform:none;box-shadow:none}
    .map-event-fan .map-event-card[data-pressed=true]{transform:scale(.96)}
    .map-event-fan .map-event-card::after{display:none}
    .map-event-anchor[data-side=below] > .map-event-card,
    .map-event-anchor[data-side=below] > .map-event-fan{top:calc(8px + var(--bubble-offset,0px));bottom:auto;transform-origin:50% 0}
    .map-event-anchor[data-side=below] > .map-event-card::after,
    .map-event-anchor[data-side=below] > .map-event-fan::after{top:auto;bottom:100%;clip-path:polygon(0 100%,100% 100%,50% 0)}
    @media(prefers-reduced-motion:reduce){.map-event-card,.map-event-card::after{transition:none}}
  `;
  document.head.appendChild(style);
  const container=document.createElement('div');container.className='map-event-markers';
  document.body.appendChild(container);
  const projected=new THREE.Vector3();
  let events=[],groups=[],floorSignature=null,expandedKey=null,disposed=false,layoutDirty=true;
  let lastCamera=null,lastFloor=null;
  let lastWidth=0,lastHeight=0,lastMoving=false;
  const lastWorld=new Float64Array(16),lastProjection=new Float64Array(16),items=[];
  const stats={updates:0,skipped:0,projections:0,layouts:0,styleWrites:0};
  const appliedStyles=new WeakMap();
  function writeStyle(element,property,value){
    let applied=appliedStyles.get(element);
    if(!applied){applied={};appliedStyles.set(element,applied);}
    if(applied[property]===value)return;
    applied[property]=value;stats.styleWrites++;
    if(property.startsWith('--'))element.style.setProperty(property,value);
    else element.style[property]=value;
  }
  let cameraGestureActive=false;
  const refreshLayout=()=>{if(lastCamera&&!disposed)api.update(lastCamera,lastFloor,{moving:lastMoving});};
  const paletteOrder=eventMarkerPalette.map((_,index)=>index);
  for(let i=paletteOrder.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[paletteOrder[i],paletteOrder[j]]=[paletteOrder[j],paletteOrder[i]];}
  const eventColors=new Map(),animations=new Map();let colorSequence=0;
  const reducedMotion=window.matchMedia('(prefers-reduced-motion:reduce)');
  function colorFor(event){
    if(!eventColors.has(event.eventId))eventColors.set(event.eventId,paletteOrder[colorSequence++%paletteOrder.length]);
    return eventColors.get(event.eventId);
  }
  function fade(element,visible,done){
    const previous=animations.get(element);
    // Settled opacity is ours: only an interrupted fade needs a style read.
    const from=element.hidden?0:previous?Number(getComputedStyle(element).opacity):Number(element.style.opacity||1);
    if(previous){previous.onfinish=null;previous.cancel();animations.delete(element);}
    if(!visible){delete element.dataset.pressed;
      for(const card of element.querySelectorAll('[data-pressed]'))delete card.dataset.pressed;}
    element.hidden=false;element.inert=!visible;element.style.opacity=visible?'1':'0';
    const duration=reducedMotion.matches?0:eventMarkerFadeMs;
    if(!duration||from===(visible?1:0)){element.hidden=!visible;done?.();return;}
    const animation=element.animate([{opacity:from},{opacity:visible?1:0}],{duration,easing:'cubic-bezier(.4,0,.2,1)'});
    animations.set(element,animation);
    animation.onfinish=()=>{animations.delete(element);element.hidden=!visible;done?.();};
  }
  function setColors(element,event,place) {
    const index=colorFor(event),dark=darkSurface(event),palette=eventMarkerPalette[index];
    element.style.setProperty('--bubble-bg',palette[dark?1:0]);
    // Precompute a small same-hue tint once; no filter, blur or work per frame.
    const rgb=palette[dark?1:0].slice(1).match(/../g).map(part=>parseInt(part,16));
    const pressed=rgb.map(value=>Math.round(dark?value+(255-value)*.14:value*.88)
      .toString(16).padStart(2,'0')).join('');
    element.style.setProperty('--bubble-pressed','#'+pressed);
    element.style.setProperty('--bubble-fg',dark?'#ffffff':'#241e28');
    element.style.setProperty('--bubble-stack',palette[dark?0:1]);
    element.style.setProperty('--bubble-stack-back',dark?'#29312d':'#e6e7e0');
    element.style.setProperty('--photo-bg',palette[dark?0:1]);
    element.style.setProperty('--photo-fg',dark?'#242b29':'#f5f2ec');
  }
  function photoFor(event) {
    const photo=document.createElement('span');photo.className='map-event-photo';photo.setAttribute('aria-hidden','true');
    const fallback=document.createElement('span');fallback.textContent=Array.from(event.title??'E')[0]??'E';photo.append(fallback);
    const source=markerImageSource(event.imageUrl,document.baseURI);
    if(source){
      const image=document.createElement('img');image.alt='';image.decoding='async';
      image.referrerPolicy='no-referrer';image.loading='lazy';image.width=44;image.height=44;
      image.addEventListener('error',()=>image.remove(),{once:true});image.src=source;photo.append(image);
    }
    return photo;
  }
  function cardFor(event,place) {
    const card=document.createElement('button');card.type='button';
    card.className='map-event-card '+(place?'map-event-place':'map-event-exterior');
    // Pointer feedback starts immediately, without waiting for Android's click.
    card.addEventListener('pointerdown',event=>{
      if(event.isPrimary && event.button===0)card.dataset.pressed='true';
      onPointerDown?.(event,card);
    });
    const release=event=>{delete card.dataset.pressed;onPointerEnd?.(event,card);};
    for(const type of ['pointerup','pointercancel','pointerleave','lostpointercapture','blur','keyup'])
      card.addEventListener(type,release);
    card.addEventListener('keydown',event=>{
      if(event.key===' ' || event.key==='Enter')card.dataset.pressed='true';
    });
    setColors(card,event,place);
    if(place)card.append(photoFor(event));
    const title=document.createElement('span');title.className='map-event-title';
    title.textContent=place?event.title:(event.exteriorLabel??'Evento');card.append(title);
    card.title=event.title;card.setAttribute('aria-label',event.title);
    return card;
  }
  function rebuild(floor) {
    for(const group of groups){group.root.dataset.retiring='true';group.root.inert=true;
      fade(group.root,false,()=>group.root.remove());}
    groups=[];expandedKey=null;layoutDirty=true;
    const index=new Map();
    for(const event of events)for(const location of event.locations??[]) {
      if(floor && (location.zoneId!==floor.zoneId || (location.floorId && location.floorId!==floor.id)))continue;
      const key=floor?floor.id+'/'+(location.spaceNodeName??''):location.zoneId;
      let group=index.get(key);
      if(!group){group={key,location,entries:[],anchor:anchorFor(location,floor)};index.set(key,group);}
      const existing=group.entries.findIndex(entry=>entry.eventId===event.eventId);
      if(existing<0)group.entries.push({...event,location});
      else if(location.spaceNodeName && !group.entries[existing].location.spaceNodeName)
        group.entries[existing]={...event,location};
    }
    // Give visible group leaders the full palette before coloring hidden choices.
    // Otherwise pairs of events would make every other block repeat a color.
    for(const group of index.values())if(group.entries.length)colorFor(group.entries[0]);
    for(const group of index.values()) {
      if(!group.anchor || !group.entries.length)continue;
      const place=Boolean(floor),active=group.entries[0];
      const root=document.createElement('div');root.className='map-event-anchor';root.hidden=true;root.dataset.mode=place?'place':'exterior';
      const button=cardFor(active,place);button.dataset.stacked=String(group.entries.length>1);
      const count=document.createElement('span');count.className='map-event-count';
      count.hidden=group.entries.length<2;count.textContent='+'+(group.entries.length-1);button.append(count);
      const fan=document.createElement('div');fan.className='map-event-fan';fan.hidden=true;
      setColors(fan,active,true);
      fan.style.setProperty('--bubble-bg',active.surface??(darkSurface(active)?'#222725':'#eeefea'));
      const choices=document.createElement('div');choices.className='map-event-choices';
      choices.style.gridTemplateColumns='repeat('+Math.min(3,group.entries.length)+',88px)';fan.append(choices);
      const choose=entry=>onSelected({eventId:entry.eventId,location:entry.location,
        mode:place?'place':'exterior',eventIds:group.entries.map(entry=>entry.eventId)});
      let choicesReady=false;
      const ensureChoices=()=>{
        if(choicesReady)return;choicesReady=true;
        for(const entry of group.entries){const card=cardFor(entry,true);
          card.addEventListener('click',event=>{event.stopPropagation();if(cameraGestureActive)return;collapse();choose(entry);});choices.append(card);}
      };
      button.setAttribute('aria-expanded','false');
      button.addEventListener('click',event=>{
        event.stopPropagation();
        if(cameraGestureActive)return;
        if(!place){collapse();onSelected({mode:'exterior',zoneId:group.location.zoneId,
          eventIds:group.entries.map(entry=>entry.eventId)});return;}
        if(place&&group.entries.length===1){choose(active);return;}
        const opening=expandedKey!==group.key;collapse(false);
        if(opening){ensureChoices();expandedKey=group.key;root.dataset.expanded='true';root.style.zIndex='5';
          button.setAttribute('aria-expanded','true');fade(button,false);fade(fan,true);layoutDirty=true;refreshLayout();}
        else refreshLayout();
      });
      root.addEventListener('pointerdown',event=>event.stopPropagation());
      root.append(button,fan);container.append(root);
      const item={key:group.key,x:NaN,y:NaN,scale:0,expanded:false,columns:0};
      groups.push({...group,root,button,fan,choices,place,item,scale:1,visible:false,layout:null});
    }
  }
  function collapse(refresh=true){
    if(expandedKey===null)return;
    const group=groups.find(entry=>entry.key===expandedKey);expandedKey=null;
    if(group){fade(group.fan,false);fade(group.button,true);
      group.root.dataset.expanded='false';group.root.style.zIndex='';group.button.setAttribute('aria-expanded','false');}
    layoutDirty=true;if(refresh)refreshLayout();}
  function dismissOutsideTap(target){
    if(expandedKey===null || container.contains(target))return false;
    collapse();return true;
  }
  const outside=event=>{dismissOutsideTap(event.target);};
  const keydown=event=>{if(event.key==='Escape')collapse();};
  document.addEventListener('pointerdown',outside,{passive:true});
  document.addEventListener('keydown',keydown);
  const api={
    dismissOutsideTap,
    setCameraGestureActive(active){
      if(cameraGestureActive===active||disposed)return;
      cameraGestureActive=active;container.dataset.cameraGesture=String(active);layoutDirty=true;refreshLayout();
    },
    setInteriorSize(percent){currentInteriorSize=normalizedInteriorEventSize(percent);layoutDirty=true;return currentInteriorSize;},
    setAutoLayout(enabled){
      currentAutoLayout=enabled!==false;layoutDirty=true;refreshLayout();return currentAutoLayout;
    },
    setEvents(next){events=Array.isArray(next)?next:[];floorSignature=null;
      const ids=new Set(events.map(event=>event.eventId));for(const id of eventColors.keys())if(!ids.has(id))eventColors.delete(id);},
    update(camera,floor,{moving=false}={}){
      if(disposed)return;
      stats.updates++;
      const signature=floor?.id??'exterior';
      if(signature!==floorSignature){rebuild(floor);floorSignature=signature;}
      // Viewport fields and matrices do not force layout after DOM writes.
      const width=window.innerWidth,height=window.innerHeight;
      let changed=layoutDirty||lastCamera!==camera||lastWidth!==width||lastHeight!==height||lastMoving!==moving;
      const world=camera.matrixWorld.elements,projection=camera.projectionMatrix.elements;
      if(!changed)for(let i=0;i<16;i++)if(world[i]!==lastWorld[i]||projection[i]!==lastProjection[i]){changed=true;break;}
      lastCamera=camera;lastFloor=floor;
      if(!changed){stats.skipped++;return;}
      let geometryChanged=layoutDirty||lastWidth!==width||lastHeight!==height||lastMoving!==moving;
      lastWorld.set(world);lastProjection.set(projection);lastWidth=width;lastHeight=height;lastMoving=moving;
      items.length=0;
      for(const group of groups){
        stats.projections++;
        projected.copy(group.anchor).project(camera);
        const x=Math.round((projected.x+1)*width/2),y=Math.round((1-projected.y)*height/2);
        group.scale=eventMarkerScale(camera.position.distanceTo(group.anchor),group.place)
          * (group.place?currentInteriorSize/100:1);
        group.scale=Math.round(group.scale*1000)/1000;
        const cardHeight=group.place?94:48;
        if(projected.z<-1 || projected.z>1 || x<0 || x>width || y<0 || y>height){
          if(group.visible){group.visible=false;geometryChanged=true;fade(group.root,false);}group.item.onScreen=false;continue;
        }
        const expanded=group.key===expandedKey;
        const columns=Math.min(3,group.entries.length,Math.max(1,Math.floor(((width-16)/group.scale-3)/95)));
        const rows=Math.ceil(group.entries.length/columns);
        const item=group.item;
        if(!item.onScreen||item.x!==x||item.y!==y||item.scale!==group.scale||item.expanded!==expanded||item.columns!==columns)geometryChanged=true;
        item.onScreen=true;item.x=x;item.y=y;item.scale=group.scale;item.expanded=expanded;item.columns=columns;
        item.width=(expanded?columns*95+3:group.place?88:132)*group.scale;
        item.height=(expanded?Math.min(340,rows*112+(rows-1)*7)+10:cardHeight)*group.scale;
        item.minHeight=expanded?42*group.scale:cardHeight*group.scale;
        item.pointerGap=8*group.scale;item.previous=group.layout;
        item.avoidCollisions=group.place&&currentAutoLayout;item.group=group;
        items.push(item);
      }
      if(!geometryChanged){stats.skipped++;return;}
      layoutDirty=false;stats.layouts++;
      const layout=layoutEventMarkers(items,{width,height,lockSides:(cameraGestureActive||moving)&&currentAutoLayout});
      for(const item of items){
        const group=item.group,placement=layout.get(item.key),visible=Boolean(placement);
        if(group.visible!==visible){group.visible=visible;fade(group.root,visible);}
        if(!placement)continue;
        placement.expanded=item.expanded;
        if(group.layout?.side!==placement.side)group.root.dataset.side=placement.side;
        group.layout=placement;
        writeStyle(group.root,'transform','translate3d('+item.x+'px,'+item.y+'px,0) scale('+item.scale+')');
        const pointerX=THREE.MathUtils.clamp(-placement.dx,-placement.rect.width/2+14*item.scale,
          placement.rect.width/2-14*item.scale);
        for(const element of [group.button,group.fan]){
          writeStyle(element,'left',placement.dx/item.scale+'px');
          writeStyle(element,'--pointer-offset','calc(50% + '+pointerX/item.scale+'px)');
        }
        if(group.place&&item.expanded){
          writeStyle(group.choices,'gridTemplateColumns','repeat('+item.columns+',88px)');
          const contentHeight=placement.side==='above'?item.y-placement.offset-112:height-110-item.y-placement.offset;
          writeStyle(group.choices,'maxHeight',Math.min(340,Math.max(32,Math.round(contentHeight/item.scale-18)))+'px');
        }
      }
    },
    snapshot(){return {interiorSize:currentInteriorSize,autoLayout:currentAutoLayout,eventCount:events.length,groups:groups.length,visible:groups.filter(group=>group.visible).length,
      expanded:expandedKey,titles:groups.map(group=>group.button.title),
      colors:groups.map(group=>group.button.style.getPropertyValue('--bubble-bg')),fadeMs:eventMarkerFadeMs,
      modes:groups.map(group=>group.place?'place':'exterior'),scales:groups.map(group=>group.scale),
      cameraGestureActive,
      work:{...stats},
      placements:groups.map(group=>({key:group.key,side:group.layout?.side??null,dx:group.layout?.dx??0,offset:0})),
      photos:groups.filter(group=>group.place).map(group=>({loaded:group.button.querySelector('img')?.naturalWidth>0,
        count:group.entries.length}))};},
    dispose(){disposed=true;document.removeEventListener('pointerdown',outside);document.removeEventListener('keydown',keydown);
      for(const animation of animations.values()){animation.onfinish=null;animation.cancel();}animations.clear();
      container.remove();style.remove();events=[];groups=[];items.length=0;eventColors.clear();lastCamera=null;lastFloor=null;},
  };
  return api;
}
