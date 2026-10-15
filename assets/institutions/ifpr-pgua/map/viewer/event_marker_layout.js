// Edge clamping always follows the CURRENT anchor, never a remembered dx.
const gap=6;
function overlap(a,b){
  const w=Math.min(a.right,b.right+gap)-Math.max(a.left,b.left-gap);
  const h=Math.min(a.bottom,b.bottom+gap)-Math.max(a.top,b.top-gap);
  return w>0&&h>0?w*h/Math.min(a.width*a.height,b.width*b.height):0;
}
export function layoutEventMarkers(items,viewport){
  const left=8,right=viewport.width-8,top=viewport.top??112,bottom=viewport.bottom??viewport.height-110;
  const result=new Map(),placed=[];
  const solveCollisions=!viewport.lockSides&&items.some(item=>item.avoidCollisions!==false);
  const ordered=solveCollisions?[...items].sort((a,b)=>Number(Boolean(b.expanded))-Number(Boolean(a.expanded))||a.key.localeCompare(b.key)):items;
  for(const item of ordered){
    const scoreCollisions=solveCollisions&&item.avoidCollisions!==false;
    const reach=Math.max(0,item.width/2-14*item.scale);
    function candidate(side,nudge=0){
      const available=side==='above'?item.y-item.pointerGap-top:bottom-item.y-item.pointerGap;
      const height=item.expanded?Math.min(item.height,available):item.height;
      if(height<(item.minHeight??item.height)||available<height||item.width>right-left)return null;
      const center=Math.max(left+item.width/2,Math.min(right-item.width/2,item.x+nudge));
      const y=side==='above'?item.y-item.pointerGap-height:item.y+item.pointerGap;
      const rect={left:center-item.width/2,right:center+item.width/2,top:y,bottom:y+height,width:item.width,height};
      let worst=0,total=0;
      if(scoreCollisions)for(const other of placed){const value=overlap(rect,other);worst=Math.max(worst,value);total+=value;}
      return {key:item.key,side,dx:center-item.x,offset:0,rect,worst,
        score:worst*100+total*10+Math.abs(nudge)/Math.max(1,item.width)*.1};
    }
    const above=candidate('above'),below=candidate('below');
    const previousSide=item.previous?.side??'above';
    let best=above??below;
    if(viewport.lockSides){
      best=(previousSide==='below'?below:above)??best;
    }else if(scoreCollisions){
      // Only keep the side in a hysteresis band; discard stale translations.
      if(previousSide==='below'&&below&&(!above||above.worst>.16))best=below;
      if(!best||best.worst>.28){
        const slots=new Set([0,-reach,reach]);
        for(const rect of placed){
          slots.add(Math.max(-reach,Math.min(reach,rect.left-gap-item.width/2-item.x)));
          slots.add(Math.max(-reach,Math.min(reach,rect.right+gap+item.width/2-item.x)));
        }
        for(const side of ['above','below'])for(const dx of slots){
          const next=candidate(side,dx);
          if(next&&(!best||next.score<best.score))best=next;
        }
      }
    }
    if(best){if(solveCollisions)placed.push(best.rect);result.set(item.key,best);}
  }
  return result;
}
