import {cannonSkin,drawCannon} from './tnkd_cannon.mjs';
import fs from 'node:fs';
import {decodePng} from './shp_detail_lib.mjs';
import {encodePng} from './art_lib.mjs';

// Metal and unlit glass share a static sheet. Each tube has its own emission masks.
const panelMetal=decodePng(fs.readFileSync(new URL('./materials/tnkd-neon-armor.png',import.meta.url)));
const hardware=decodePng(fs.readFileSync(new URL('./materials/tnkd-turbine-optics.png',import.meta.url)));
const scale=8, tileW=80*scale, tileH=56*scale, width=8*tileW, atlasHeight=4*tileH;
const atlas=new Uint8Array(width*atlasHeight*4);
// Smooth light spill needs only two samples per model pixel. Each mask is
// generated from visible glass after the hull, both pipes and all clasps resolve.
const shrink=4, glowW=tileW/shrink, glowH=tileH/shrink, glowWidth=glowW*8;
const glowHeight=glowH*4*16;
const glowAtlas=new Uint8Array(glowWidth*glowHeight*4);
const cross=(a,b,x,y)=>(b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x);
function depthAt(frame,x,y){
  const u=Math.floor((x-frame.minX+1)*2), v=Math.floor((y-frame.minY+1)*2);
  return u<0||v<0||u>=frame.width*2||v>=frame.height*2?-Infinity:frame.depth[v*frame.width*2+u];
}
function shade(u,v,light,material,at){
  if(material>=6){
    // v wraps around the convex lens. Shade the glass body and a narrow
    // longitudinal reflection separately so the pipes read as round at small scale.
    const radial=2*Math.PI*v;
    const body=.54+.46*Math.max(0,Math.cos(radial-.68));
    const sheen=Math.pow(Math.max(0,Math.cos(radial-.83)),16);
    // Fine seams divide the inner light guide into short cells. Their
    // silver lips, dark seals and diagonal winding live in cylinder UVs.
    const seamDistance=Math.abs((u*8)%1-.5);
    const seal=Math.max(0,1-seamDistance/.085);
    const winding=Math.pow(.5+.5*Math.cos(2*Math.PI*(u*13-v)),5);
    const glass=(20*body+110*sheen+26*winding)*(1-.8*seal)+45*seal*body;
    atlas.set([glass,glass+5,glass+12,255],at);
    // A slender central filament and its glass reflection catch the beat.
    return (0.8*sheen+0.20*winding)*(1-seal);
  }
  const image=material===5?cannonSkin:(material===4?panelMetal:hardware);
  // Area sampling retains narrow clips and gaskets even in oblique views.
  let red=0,green=0,blue=0;
  for(const dx of [-2,0,2])for(const dy of [-2,0,2]){
    const x=Math.min(image.width-1,Math.max(0,Math.floor(u*(image.width-1))+dx));
    const y=Math.min(image.height-1,Math.max(0,Math.floor(v*(image.height-1))+dy));
    const j=(y*image.width+x)*4;
    red+=image.rgba[j];green+=image.rgba[j+1];blue+=image.rgba[j+2];
  }
  red/=9;green/=9;blue/=9;
  atlas.set([red*light,green*light,blue*light,255],at);
}
export function bakePanels(index,host,kit,limbs){
  const az=Math.PI/4-index*Math.PI/16,c=Math.cos(az),s=Math.sin(az),ce=Math.sqrt(.75);
  const depths=new Float32Array(tileW*tileH).fill(-Infinity);
  const emitters=new Uint8Array(tileW*tileH);
  const filament=new Uint8Array(tileW*tileH);
  for(const [side,limb] of limbs.entries()){
    const m=limb.matrix;
    const project=(localX,y,z,u,v)=>{
      const world=[0,4,8].map(r=>m[r]*localX+m[r+1]*y+m[r+2]*z+m[r+3]);
      const [X,Y,Z]=world;
      return {x:(40-X*s+Y*c)*scale,y:(38+(X*c+Y*s)*.5-Z*ce)*scale,
              d:(X*c+Y*s)*ce+Z*.5,u,v};
    };
    function quad(a,b,d,e,light,material=side){
      // Front-facing skin only; backing and undersides are the baked voxel mount.
      if(cross(a,b,d.x,d.y)>=0){
        [b,e]=[e,b]; // Closed instrument meshes resolve visibility by depth.
      }
      for(const [p,q,r] of [[a,d,b],[a,e,d]]){
        const area=cross(p,q,r.x,r.y);
        if(area<0.01)continue;
        for(let y=Math.max(0,Math.floor(Math.min(p.y,q.y,r.y)));y<=Math.min(tileH-1,Math.ceil(Math.max(p.y,q.y,r.y)));y++){
          for(let x=Math.max(0,Math.floor(Math.min(p.x,q.x,r.x)));x<=Math.min(tileW-1,Math.ceil(Math.max(p.x,q.x,r.x)));x++){
            const i=cross(q,r,x+.5,y+.5)/area,k=cross(p,q,x+.5,y+.5)/area,h=1-i-k;
            if(Math.min(i,h,k)<-1e-6)continue;
            const z=i*p.d+h*q.d+k*r.d, px=(x+.5)/scale-40,py=(y+.5)/scale-38;
            if(z<depths[y*tileW+x] || z<Math.max(depthAt(host,px,py),depthAt(kit,px,py))-0.02)continue;
            depths[y*tileW+x]=z;
            emitters[y*tileW+x]=material>=6?material-5:0;
            const dest=((Math.floor(index/8)*tileH+y)*width+(index%8)*tileW+x)*4;
            const core=shade(i*p.u+h*q.u+k*r.u,i*p.v+h*q.v+k*r.v,light,material,dest);
            if(material>=6)filament[y*tileW+x]=Math.round(core*255);
          }
        }
      }
    }
    if(side===4){
      drawCannon(project,quad);
      continue;
    }
    if(side>=2){
      drawInstrument(side===2,project,quad);
      continue;
    }
    // The inner lip penetrates the tread cover; the outer face is only 2.1
    // model units out from its pin. Sample unlit steel so all four lamps are actual tubes.
    const rows=[[-.95,5.0,16.0],[1.0,4.55,17.5],[2.1,3.5,18.0],
                [2.1,-2.8,18.0],[.95,-3.8,16.5],[-.95,-3.8,16.0]];
    const rimPoint=(end,row,u,v)=>project((end?1:-1)*row[2],row[0],row[1],u,v);
    for(let j=1;j<rows.length;j++){
      const lo=rows[j-1],hi=rows[j];
      // Main face uses the vented metal between the donor's two original lamps.
      const v0=j===3?.54:.06,v1=j===3?.83:.22;
      quad(rimPoint(0,lo,.012,v0),rimPoint(1,lo,.988,v0),rimPoint(1,hi,.988,v1),rimPoint(0,hi,.012,v1),j===3?.88:1,4);
      for(const end of [0,1]){
        const inner=row=>project((end?1:-1)*row[2],-1.05,row[1],.29,.81);
        quad(rimPoint(end,lo,.2,.59),rimPoint(end,hi,.2,.81),inner(hi),inner(lo),.74,4);
      }
    }
    for(let tube=0;tube<2;tube++){
      const lamp=side*2+tube;
      const z=tube===0?2.15:-1.30;
      const sections=[[-16.85,.08],[-16.65,.61],[-16.1,1.10],[16.1,1.10],[16.65,.61],[16.85,.08]];
      const ring=(section,a)=>project(section[0],2.48+section[1]*Math.cos(a),z+section[1]*Math.sin(a),
                                      (section[0]+17)/34,a/(2*Math.PI));
      for(let j=1;j<sections.length;j++)for(let face=0;face<24;face++){
        const a=face*Math.PI/12,b=(face+1)*Math.PI/12;
        quad(ring(sections[j-1],a),ring(sections[j],a),ring(sections[j],b),ring(sections[j-1],b),1,6+lamp);
      }
      for(const x of [-12,0,12])drawPipeClamp(project,quad,x,z);
      // Viewed straight onto either flank, each clamp must cover the glass
      // in both color states while the glass immediately beside it still swaps.
      if((index===12 && side===0)||(index===28 && side===1)){
        for(const x of [-12,0,12])for(const covered of [true,false]){
          const radius=covered?1.42:1.10;
          const point=project(x+(covered?0:2.3),2.48+radius*ce,z+radius*.5,0,0);
          const pixel=((Math.floor(index/8)*tileH+Math.floor(point.y))*width+(index%8)*tileW+Math.floor(point.x))*4;
          const visible=emitters[Math.floor(point.y)*tileW+Math.floor(point.x)]===lamp+1;
          if(!atlas[pixel+3] || visible===covered)
            throw Error('Invalid clamp/glass occlusion at facing '+index+', tube '+tube+', x '+x);
        }
      }
    }
  }
  // In profile, sample the gun above the tracks, independently of the four side lights.
  if(index===12||index===28){
    for(const [lo,hi] of [[8,14],[18,23],[27,32]]){
      const counts=[0,0];
      for(let x=0;x<tileW;x++){
        const modelX=(x/scale-40)/(-s);
        if(modelX<lo||modelX>hi)continue;
        for(let y=0;y<tileH;y++){
          if(Math.abs(y/scale-38+19.58*ce)>7.5)continue;
          const id=emitters[y*tileW+x];
          if(id>=5)counts[(id-5)%2]++;
        }
      }
      if(Math.min(...counts)<4)throw Error('Missing crossed cannon feed at '+index+' / '+lo);
    }
  }
  bakeGlow(index,emitters,filament);
}
function blur(field,sigma){
  const radius=Math.ceil(sigma*3),weights=[];
  let total=0;
  for(let i=-radius;i<=radius;i++){const w=Math.exp(-i*i/(2*sigma*sigma));weights.push(w);total+=w;}
  const tmp=new Float32Array(field.length),out=new Float32Array(field.length);
  for(let y=0;y<glowH;y++)for(let x=0;x<glowW;x++){
    for(let i=Math.max(-radius,-x);i<=Math.min(radius,glowW-1-x);i++)tmp[y*glowW+x]+=field[y*glowW+x+i]*weights[i+radius]/total;
  }
  for(let y=0;y<glowH;y++)for(let x=0;x<glowW;x++){
    for(let i=Math.max(-radius,-y);i<=Math.min(radius,glowH-1-y);i++)out[y*glowW+x]+=tmp[(y+i)*glowW+x]*weights[i+radius]/total;
  }
  return out;
}
function bakeGlow(index,emitters,filament){
  // Preserve each glass core's own colour even when the neighbouring halo
  // reaches it. Only the intervening metal and air mix both reflections.
  const glassCoverage=new Float32Array(glowW*glowH);
  for(let y=0;y<tileH;y++)for(let x=0;x<tileW;x++){
    if(emitters[y*tileW+x]>0)glassCoverage[Math.floor(y/shrink)*glowW+Math.floor(x/shrink)]+=1/(shrink*shrink);
  }
  // Side lamps 0..3, cannon feeds 4..7; the second half contains their filaments.
  for(let bank=0;bank<8;bank++){
    const field=new Float32Array(glowW*glowH);
    const hot=new Float32Array(glowW*glowH);
    for(let y=0;y<tileH;y++)for(let x=0;x<tileW;x++){
      const source=y*tileW+x;
      if(emitters[source]!==bank+1)continue;
      const dest=Math.floor(y/shrink)*glowW+Math.floor(x/shrink);
      field[dest]+=1/(shrink*shrink);
      hot[dest]+=filament[source]/(255*shrink*shrink);
    }
    const inner=blur(field,2.3),outer=blur(field,7.0);
    const halo=blur(field,12.0);
    for(let y=0;y<glowH;y++)for(let x=0;x<glowW;x++){
      const i=y*glowW+x;
      // The close reflection hugs the glass. The two wider lobes fade across
      // the plate and out into transparency. No threshold on the outer halo.
      const soft=(1-Math.exp(-1.2*inner[i]-1.35*outer[i]-1.2*halo[i]))*(1-glassCoverage[i]+field[i]);
      const alpha=soft+(1-soft)*0.96*field[i];
      const dest=(((Math.floor(index/8)+4*bank)*glowH+y)*glowWidth+(index%8)*glowW+x)*4;
      glowAtlas.set([255,255,255,Math.round(alpha*255)],dest);
      const highlight=dest+8*4*glowH*glowWidth*4;
      glowAtlas.set([255,255,255,Math.round(255*hot[i])],highlight);
    }
  }
}
// A formed band wraps around the outside of the glass and ends in two
// bolted tabs. The tabs run into the structural plate at local Y=2.1.
function drawPipeClamp(project,quad,x,z){
  const half=.92, radius=1.42;
  const band=(edge,angle,r)=>project(x+edge*half,2.48+r*Math.cos(angle),z+r*Math.sin(angle),
                                     .436+edge*.010,.34-angle*.042);
  for(let i=0;i<18;i++){
    const a=-1.90+i*3.8/18,b=a+3.8/18;
    const light=.87+.23*Math.max(0,Math.cos(a-.58));
    quad(band(-1,a,radius),band(1,a,radius),band(1,b,radius),band(-1,b,radius),light,4);
    for(const edge of [-1,1])
      quad(band(edge,a,1.13),band(edge,a,radius),band(edge,b,radius),band(edge,b,1.13),.65,4);
  }
  for(const sign of [-1,1]){
    const footZ=z+sign*1.42;
    const tab=(dx,y,dz)=>project(x+dx,y,footZ+dz,.43+.007*dx,.26+.02*dz);
    quad(tab(-1.08,2.42,-.31),tab(1.08,2.42,-.31),tab(1.08,2.42,.31),tab(-1.08,2.42,.31),1.08,4);
    for(const dz of [-.31,.31])
      quad(tab(-1.08,1.89,dz),tab(1.08,1.89,dz),tab(1.08,2.42,dz),tab(-1.08,2.42,dz),.78,4);
    const bolt=(angle,r,y)=>project(x+r*Math.cos(angle),y,footZ+r*Math.sin(angle),.413+.006*Math.cos(angle),.21+.006*Math.sin(angle));
    const center=bolt(0,0,2.62);
    for(let i=0;i<6;i++){
      const a=i*Math.PI/3,b=(i+1)*Math.PI/3;
      quad(bolt(a,.31,2.42),bolt(b,.31,2.42),bolt(b,.24,2.62),bolt(a,.24,2.62),.78,4);
      quad(center,bolt(a,.24,2.62),bolt(b,.24,2.62),center,1.20,4);
    }
  }
}
// Hardware uses the existing pins. Each surface has its own UV island; lens
// glass never slides across the housing and neon-bank colors do not touch it.
function drawInstrument(turbine,project,quad){
  const point=(x,y,z,tile,u,v)=>project(x,y,z,(tile%2+.01+.96*u)*.5,
                                        (Math.floor(tile/2)+.01+.96*v)*.5);
  function cylinder(cy,cz,x0,x1,r,capTile,wallTile,capAtFront){
    const segments=32;
    for(let i=0;i<segments;i++){
      const a=i*2*Math.PI/segments,b=(i+1)*2*Math.PI/segments;
      const ring=(x,t,tile,u,v)=>point(x,cy+r*Math.cos(t),cz+r*Math.sin(t),tile,u,v);
      const light=.82+.18*Math.max(0,Math.sin((a+b)*.5));
      quad(ring(x0,a,wallTile,0,i/segments),ring(x1,a,wallTile,1,i/segments),
           ring(x1,b,wallTile,1,(i+1)/segments),ring(x0,b,wallTile,0,(i+1)/segments),light);
      for(const front of [false,true]){
        const x=front?x1:x0,tile=front===capAtFront?capTile:3;
        const edge=t=>ring(x,t,tile,.5+.50*Math.cos(t),.5-.50*Math.sin(t));
        const center=point(x,cy,cz,tile,.5,.5);
        quad(center,edge(a),edge(b),center,1);
      }
    }
  }
  function housing(x0,x1,y0,y1,z0,z1){
    const box=(v,u,w,tx,ty)=>point(v?x1:x0,u?y1:y0,w?z1:z0,3,tx,ty);
    for(const y of [0,1])
      quad(box(0,y,1,0,0),box(1,y,1,1,0),box(1,y,0,1,1),box(0,y,0,0,1),.89);
    for(const x of [0,1])
      quad(box(x,0,1,0,0),box(x,1,1,1,0),box(x,1,0,1,1),box(x,0,0,0,1),.96);
    quad(box(0,0,1,0,0),box(1,0,1,1,0),box(1,1,1,1,1),box(0,1,1,0,1),1);
  }
  if(turbine){
    cylinder(0,0,-6.37,4.12,6.85,0,1,false);
  }else{
    housing(-3.3,3.3,-5.1,5.1,-1.4,3.5);
    housing(-1.8,1.8,-7.0,7.0,2.9,6.25);
    for(const cy of [-7.8,7.8]){
      housing(-4.05,3.8,cy-2.22,cy+2.22,2.10,6.70);
      cylinder(cy,4.4,3.65,4.65,2.13,2,3,true);
    }
  }
}
export function savePanels(project){
  fs.writeFileSync(new URL('assets/cosmetics/skins/tnkd_glow.png',project),encodePng(glowWidth,glowHeight,glowAtlas));
  fs.writeFileSync(new URL('assets/cosmetics/skins/tnkd_neon_hd.png',project),encodePng(width,atlasHeight,atlas));
}
