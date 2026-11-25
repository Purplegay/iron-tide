// Hero fittings authored in each original VXL's coordinates; texture is AI-made.
// Offline 32-facing mesh bake: original hull/turret depth clips hidden surfaces.
import fs from 'node:fs';
import {YrSource,sha256} from './lib/yr_source.mjs';
import {parseVxl,parseHva,poseVxl} from './vxl_lib.mjs';
import {renderSurface} from './voxel_surface.mjs';
import {decodePal,encodePng} from './art_lib.mjs';
import {decodePng} from './shp_detail_lib.mjs';
const src=new YrSource(process.argv[2]);
const textureBytes=fs.readFileSync(new URL('materials/hero-tank-armor.png',import.meta.url));
const tex=decodePng(textureBytes), pal=decodePal(src.read('unittem.pal').data);
const out=new URL('../iron_tide/assets/cosmetics/skins/',import.meta.url);
const scale=4,W=96,H=64,ox=48,oy=42;
const edge=(a,b,x,y)=>(b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x);
const manifest={material_sha256:sha256(textureBytes),facings:32,scale,tile:[W,H],origin:[ox,oy],units:{}};
for(const [id,name] of [['MTNK','GTNK'],['HTNK','HTNK']]){
 const inputs={};
 function load(n){const v=src.read(n+'.vxl'),h=src.read(n+'.hva');inputs[n]={vxl:sha256(v.data),hva:sha256(h.data)};return poseVxl(parseVxl(v.data),parseHva(h.data),0);}
 const body=load(name),tur=load(name+'tur'),bar=load(name+'barl');
 const turret={limbs:[...tur.limbs,...bar.limbs]},models=[body,turret];
 const sockets=JSON.parse(fs.readFileSync(new URL('../iron_tide/assets/ra2/unitweapon/'+id+'.json',import.meta.url)));
 // Runtime sprites use the surface-render atlas, not the old renderVxl canvas.
 manifest.units[id]={inputs,anchor:sockets.origins[0],layers:[]};
 for(const [layer,host] of models.entries()){
  const atlasW=W*scale*8,atlasH=H*scale*4,rgba=new Uint8Array(atlasW*atlasH*4),glow=new Uint8Array(rgba.length);
  let visible=0,clipped=0;
  // x is forward, y is lateral, z is height; preserve central team-color armor.
  const lightTank=id==='MTNK';
  const matrix=(layer===0?body:tur).limbs[0].matrix;
  for(let facing=0;facing<32;facing++){
   const image=renderSurface(host,{pal,facing,facings:32,keepDepth:true});
   const az=Math.PI/4-facing*Math.PI/16,c=Math.cos(az),s=Math.sin(az),ce=Math.sqrt(.75),depth=new Float32Array(W*H*scale*scale).fill(-Infinity);
   const project=(p,u,v)=>{const [X,Y,Z]=[0,4,8].map(r=>matrix[r]*p[0]+matrix[r+1]*p[1]+matrix[r+2]*p[2]+matrix[r+3]);return {x:(ox-X*s+Y*c)*scale,y:(oy+(X*c+Y*s)*.5-Z*ce)*scale,d:(X*c+Y*s)*ce+Z*.5,u,v};};
   function quad(points,light,material='armor'){
    const q=points.map((p,i)=>project(p,[0,1,1,0][i],[0,0,1,1][i]));
    for(let inds of [[0,1,2],[0,2,3]]){
     let [a,b,d]=inds.map(i=>q[i]);let area=edge(a,b,d.x,d.y);if(area<0){[b,d]=[d,b];area=-area;}
     if(area<.001)continue;
     for(let y=Math.max(0,Math.floor(Math.min(a.y,b.y,d.y)));y<Math.min(H*scale,Math.ceil(Math.max(a.y,b.y,d.y)));y++)for(let x=Math.max(0,Math.floor(Math.min(a.x,b.x,d.x)));x<Math.min(W*scale,Math.ceil(Math.max(a.x,b.x,d.x)));x++){
      const A=edge(b,d,x+.5,y+.5)/area,B=edge(d,a,x+.5,y+.5)/area,C=1-A-B;if(Math.min(A,B,C)<0)continue;
      const z=A*a.d+B*b.d+C*d.d,k=y*W*scale+x;
      const hx=Math.floor(((x+.5)/scale-ox-image.minX+1)*2),hy=Math.floor(((y+.5)/scale-oy-image.minY+1)*2);
      if(z<depth[k])continue;
      if(hx>=0&&hy>=0&&hx<image.width*2&&hy<image.height*2&&z<image.depth[hy*image.width*2+hx]-.03){clipped++;continue;}
      depth[k]=z;
      const u=A*a.u+B*b.u+C*d.u,v=A*a.v+B*b.v+C*d.v;
      const tx=Math.floor((id==='MTNK'?.03+.36*u:.59+.37*u)*(tex.width-1)),ty=Math.floor((.08+.85*v)*(tex.height-1)),t=(ty*tex.width+tx)*4;
      const dest=((Math.floor(facing/8)*H*scale+y)*atlasW+(facing%8)*W*scale+x)*4;
      const colors={steel:[76,94,108],silver:[182,207,212],dark:[28,37,43],core:lightTank?[70,217,242]:[255,88,39],brass:[163,126,76]};
      // Fine material detail complements the silhouette; it must not turn
      // every small plate into a compressed full-atlas noisy postage stamp.
      const baseMetal=lightTank?[173,197,207]:[80,91,102];
      const color=colors[material]||baseMetal.map((n,i)=>n*.72+tex.rgba[t+i]*.28);
      rgba.set([...color.map(v=>v*light),255],dest);
      const luminous=material==='core';
      if(luminous)glow.set([255,255,255,180],dest);else glow.fill(0,dest,dest+4);
      visible++;
     }
    }
   }
   // Chamfered, tapered octagonal armor pods, with exposed structural gaps.
   function plate(X,Y,Z,x,y,z,material='armor',taper=.72){
    const cut=Math.min(x,y)*.52;
    const ring=[[-x+cut,-y],[x-cut,-y],[x,-y+cut],[x,y-cut],[x-cut,y],[-x+cut,y],[-x,y-cut],[-x,-y+cut]];
    const lo=ring.map(([a,b])=>[X+a,Y+b,Z-z]),hi=ring.map(([a,b])=>[X+a*taper,Y+b*taper,Z+z]);
    for(let i=0;i<8;i++){
     const j=(i+1)%8;
     quad([lo[i],lo[j],hi[j],hi[i]],.56+.28*(1+Math.sin(i*Math.PI/4))/2,material);
     quad([[X,Y,Z+z],hi[i],hi[j],[X,Y,Z+z]],1,material);
    }
   }
   function cylinder(a,b,r,material='silver',n=12){
    let axis=b.map((v,i)=>v-a[i]),len=Math.hypot(...axis);axis=axis.map(v=>v/len);
    const cross=(p,q)=>[p[1]*q[2]-p[2]*q[1],p[2]*q[0]-p[0]*q[2],p[0]*q[1]-p[1]*q[0]];
    let u=cross(axis,Math.abs(axis[2])>.9?[0,1,0]:[0,0,1]),ul=Math.hypot(...u);u=u.map(v=>v/ul);const v=cross(axis,u);
    const ring=(p,t)=>p.map((x,k)=>x+r*(u[k]*Math.cos(t)+v[k]*Math.sin(t)));
    for(let i=0;i<n;i++){const t=i*2*Math.PI/n,tn=(i+1)*2*Math.PI/n;const A=ring(a,t),B=ring(a,tn),C=ring(b,tn),D=ring(b,t);
     quad([A,B,C,D],.5+.5*Math.max(0,Math.cos(t-.6)),material);quad([b,D,C,b],.90,material);}
   }
   if(layer===0){
    const lateral=lightTank?15.4:17.4;
    for(const side of [-1,1]){
     // Three discrete bolted track guards rather than one rectangular block.
     for(let j=0;j<3;j++){
      const x=(lightTank?-15:-10)+j*(lightTank?10:12);
      plate(x,side*lateral,10.7,lightTank?5.8:6.4,2.7,.95);
      plate(x,side*(lateral+1.2),11.1,3.5,.7,.6,'steel');
      cylinder([x-3,side*(lateral+1.9),11.5],[x+3,side*(lateral+1.9),11.5],.35,'core',8);
      for(const dx of [-3.4,3.4])cylinder([x+dx,side*lateral,11.5],[x+dx,side*lateral,12.5],.48,'silver',8);
     }
     // Two exposed chrome piston rods attach the track guards to the hull.
     cylinder([-12,side*10,9],[-7,side*lateral,10.4],.85,'steel');
     cylinder([-10,side*11.5,9.4],[-6,side*lateral,10.4],.42,'silver');
     cylinder([6,side*10,9],[10,side*lateral,10.4],.70,'steel');
    }
    const rear=lightTank?-21:-17;
    for(const side of [-1,1]){
     cylinder([rear+2,side*6,11.2],[rear-2,side*6,11.2],2.1,'steel');
     cylinder([rear-2,side*6,11.2],[rear-2.3,side*6,11.2],1.3,'core');
     for(let fin=0;fin<3;fin++)plate(rear+fin,side*6,13.0,.3,2.5,.35,'silver');
    }
   }else{
    const y=lightTank?8.5:10.0;
    for(const side of [-1,1]){
     plate(-5,side*y,18.2,9,2.1,.75,'steel',.66);
     // Raised layered shoulder, sloped foreplate and inset energy rail.
     plate(-6,side*y,19.3,7.5,2.8,.65,'armor',.72);
     plate(2,side*y,17.5,2.9,2.2,.75,'armor',.65);
     cylinder([-11,side*(y+1.8),18.8],[-1,side*(y+1.8),18.8],.65,'dark');
     cylinder([-10.4,side*(y+2.0),19.0],[-1.8,side*(y+2.0),19.0],.37,'core');
     cylinder([-6,side*6,15],[-10,side*y,21.3],.68,'steel');
     cylinder([-8,side*7,18],[-10,side*y,21.3],.35,'silver');
     // Slim rear cooling vanes give a mechanical silhouette, not a solid crate.
     for(let k=0;k<3;k++)plate(-11.5+k*1.9,side*(y-.5),22.0,.45,1.7,1.7,'silver',.40);
     if(lightTank){
      // Swept ceramic stabilizer fin with a cyan inset, not a solid cuboid.
      quad([[-12,side*(y+1),19],[-6,side*(y+1),19],[-12,side*(y+3.5),23],[-14,side*(y+3.5),23]],.96,'silver');
      quad([[-12,side*(y+1.1),19.6],[-11,side*(y+1.1),19.6],[-12.5,side*(y+3.3),22.8],[-13,side*(y+3.3),22.8]],1,'core');
     }else{
      // Rhino has exposed shoulder hydraulics and twin furnace exhaust crowns.
      cylinder([-13,side*(y+1),18],[-14,side*(y+1),23.5],1.25,'steel');
      cylinder([-14,side*(y+1),23.5],[-14,side*(y+1),23.9],.76,'core');
     }
    }
    plate(-12,0,20,3.0,3.8,1.2,'steel');
    cylinder([-12,0,20],[-12,0,23],2.3,'steel');
    cylinder([-12,0,23],[-12,0,23.3],1.65,'core');
    // Twin collar bands and a narrow rail brace the original barrel.
    const gunZ=(bar.limbs[0].minBounds[2]+bar.limbs[0].maxBounds[2])*.5;
    for(const X of [15,20])cylinder([X,0,gunZ],[X+1,0,gunZ],1.75,'silver');
    for(const side of [-1,1])cylinder([11,side*1.3,gunZ+.7],[24,side*1.3,gunZ+.7],.26,'core',8);
   }
  }
  if(!visible||!clipped)throw Error('Missing visible or depth-clipped fitting '+id+layer);
  const stem=id.toLowerCase()+'_hero_'+(layer?'turret':'hull');
  fs.writeFileSync(new URL(stem+'.png',out),encodePng(atlasW,atlasH,rgba));
  fs.writeFileSync(new URL(stem+'_glow.png',out),encodePng(atlasW,atlasH,glow));
  manifest.units[id].layers.push({stem,visible,clipped,geometry:'chamfered segmented armor, pistons, rails, cooling fins and emissive reactor'});
  console.log(stem,visible,clipped);
 }
}
fs.writeFileSync(new URL('tank_hero_armor.json',out),JSON.stringify(manifest,null,2)+'\n');
