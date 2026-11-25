// Small deterministic offline mesh authoring/rasterization library for RA2 skins.
// Coordinates: X forward, Y left, Z up. Runtime receives only PNG sprites.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {encodePng} from './art_lib.mjs';
import {decodePng} from './shp_detail_lib.mjs';
const materialBytes=fs.readFileSync(new URL('materials/hero-tank-armor.png',import.meta.url));
const material=decodePng(materialBytes);
export const hash=b=>createHash('sha256').update(b).digest('hex');
const wrap=x=>x-Math.floor(x);
function metalSample(p,n){
 const axes=Math.abs(n[2])>.55?[0,1]:Math.abs(n[1])>.55?[0,2]:[1,2];
 const x=(.51+.48*wrap((p[axes[0]]+31)/60))*(material.width-2),y=wrap((p[axes[1]]+29)/55)*(material.height-2);
 const ix=Math.floor(x),iy=Math.floor(y),fx=x-ix,fy=y-iy;
 let luminance=0;
 for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++){
  const k=((iy+dy)*material.width+ix+dx)*4,w=(dx?fx:1-fx)*(dy?fy:1-fy);
  luminance+=(material.rgba[k]*.22+material.rgba[k+1]*.7+material.rgba[k+2]*.08)/255*w;
 }
 return luminance;
}
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const unit=a=>{const d=Math.hypot(...a);return a.map(v=>v/d);};
export const mix=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
export class Mesh {
 constructor(){this.faces=[];this.parts=[];}
 tri(a,b,c,material){const n=cross(sub(b,a),sub(c,a));if(Math.hypot(...n)>1e-7)this.faces.push({p:[a,b,c],normal:unit(n),material});}
 poly(points,material){for(let i=1;i<points.length-1;i++)this.tri(points[0],points[i],points[i+1],material);}
 quad(a,b,c,d,m){this.poly([a,b,c,d],m);}
 panel(points,z,depth,m='armor',edge='metal',bevel=.9){
  const center=points.reduce((a,p)=>[a[0]+p[0]/points.length,a[1]+p[1]/points.length],[0,0]);
  const low=points.map(p=>[...p,z]),high=points.map(p=>[center[0]+(p[0]-center[0])*bevel,center[1]+(p[1]-center[1])*bevel,z+depth]);
  this.poly([...low].reverse(),edge);this.poly(high,m);
  for(let i=0;i<points.length;i++){const j=(i+1)%points.length;this.quad(low[i],low[j],high[j],high[i],edge);}
 }
 plate(x,y,z,w,h,depth,m='armor',edge='metal'){
  const b=Math.min(w,h)*.35;
  this.panel([[x-w+b,y-h],[x+w-b,y-h],[x+w,y-h+b],[x+w,y+h-b],[x+w-b,y+h],[x-w+b,y+h],[x-w,y+h-b],[x-w,y-h+b]],z,depth,m,edge);
 }
 tube(a,b,r,m='metal',n=12,rEnd=r){
  const axis=unit(sub(b,a)),u=unit(cross(axis,Math.abs(axis[2])>.9?[0,1,0]:[0,0,1])),v=cross(axis,u);
  const ring=(p,r)=>Array.from({length:n},(_,i)=>p.map((q,k)=>q+r*(u[k]*Math.cos(i*Math.PI*2/n)+v[k]*Math.sin(i*Math.PI*2/n))));
  const A=ring(a,r),B=ring(b,rEnd);
  this.poly([...A].reverse(),m);this.poly(B,m);
  for(let i=0;i<n;i++){const j=(i+1)%n;this.quad(A[i],A[j],B[j],B[i],m);}
 }
 loft(sections,y,m='armor',n=16){
  const rings=sections.map(([x,ry,rz,z])=>Array.from({length:n},(_,i)=>[x,y+Math.cos(i*Math.PI*2/n)*ry,z+Math.sin(i*Math.PI*2/n)*rz]));
  this.poly([...rings[0]].reverse(),m);this.poly(rings.at(-1),m);
  for(let k=1;k<rings.length;k++)for(let i=0;i<n;i++){const j=(i+1)%n;this.quad(rings[k-1][i],rings[k-1][j],rings[k][j],rings[k][i],m);}
 }
 torus(center,r,thickness,m='copper',n=32,k=8){
  const point=(i,j)=>[center[0]+(r+thickness*Math.cos(j*Math.PI*2/k))*Math.cos(i*Math.PI*2/n),center[1]+(r+thickness*Math.cos(j*Math.PI*2/k))*Math.sin(i*Math.PI*2/n),center[2]+thickness*Math.sin(j*Math.PI*2/k)];
  for(let i=0;i<n;i++)for(let j=0;j<k;j++)this.quad(point(i,j),point(i+1,j),point(i+1,j+1),point(i,j+1),m);
 }
 beam(a,b,width,depth,m='armor',edge='metal'){
  const axis=unit(sub(b,a)),u=unit(cross(axis,Math.abs(axis[2])>.9?[0,1,0]:[0,0,1])),v=cross(axis,u);
  const ring=(p,w)=>[[-1,-1],[1,-1],[1,1],[-1,1]].map(([s,t])=>p.map((q,k)=>q+u[k]*w*s+v[k]*depth*t));
  const A=ring(a,width),B=ring(b,width*.6);this.poly(A,edge);this.poly(B,edge);
  for(let i=0;i<4;i++){const j=(i+1)%4;this.quad(A[i],A[j],B[j],B[i],i%2?edge:m);}
 }
}
export function project(p,frame,origin=[64,94],modelScale=1.2){
 const a=frame*Math.PI/16,c=Math.cos(a),s=Math.sin(a);
 return {x:origin[0]+(p[0]*c-p[1]*s)*modelScale,y:origin[1]+((p[0]*s+p[1]*c)*.5-p[2]*Math.sqrt(.75))*modelScale,d:(p[0]*s+p[1]*c)*Math.sqrt(.75)+p[2]*.5};
}
export function render(mesh,frame,tile,palette,origin=[64,94],modelScale=1.2,finish=null){
 const ss=2,size=tile*ss,scale=size/128;
 const rgba=new Uint8Array(size*size*4),depth=new Float32Array(size*size).fill(-Infinity);
 const emissive=new Uint8Array(size*size);
 const edge=(a,b,x,y)=>(b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x);
 const az=frame*Math.PI/16,cs=Math.cos(az),sn=Math.sin(az);
 const lightDirection=unit([-.6,-.8,1.4]),right=unit(cross(lightDirection,[0,0,1])),up=cross(lightDirection,right);
 const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
 const lightPoint=p=>{const q=[p[0]*cs-p[1]*sn,p[0]*sn+p[1]*cs,p[2]];return {x:256+dot(q,right)*3.2,y:256+dot(q,up)*3.2,d:dot(q,lightDirection)};};
 // Self-shadowing is baked once, not evaluated by the game shader.
 const shadow=new Float32Array(512*512).fill(-Infinity);
 for(const face of mesh.faces){
  let [a,b,c]=face.p.map(lightPoint),area=edge(a,b,c.x,c.y);if(area<0){[b,c]=[c,b];area=-area;}if(area<.001)continue;
  for(let y=Math.max(0,Math.floor(Math.min(a.y,b.y,c.y)));y<Math.min(512,Math.ceil(Math.max(a.y,b.y,c.y)));y++)
  for(let x=Math.max(0,Math.floor(Math.min(a.x,b.x,c.x)));x<Math.min(512,Math.ceil(Math.max(a.x,b.x,c.x)));x++){
   const A=edge(b,c,x+.5,y+.5)/area,B=edge(c,a,x+.5,y+.5)/area,C=1-A-B;if(Math.min(A,B,C)<0)continue;
   shadow[y*512+x]=Math.max(shadow[y*512+x],A*a.d+B*b.d+C*c.d);
  }
 }
 for(const f of mesh.faces){
  let [a,b,c]=f.p.map((p,i)=>{const q=project(p,frame,origin,modelScale);return {...q,x:q.x*scale,y:q.y*scale,p,corner:i};});
  let area=edge(a,b,c.x,c.y);if(area<0){[b,c]=[c,b];area=-area;}if(area<.001)continue;
  const n=f.normal,nx=n[0]*cs-n[1]*sn,ny=n[0]*sn+n[1]*cs;
  const normal=[nx,ny,n[2]];if(dot(normal,[0,Math.sqrt(.75),.5])<0)for(let k=0;k<3;k++)normal[k]*=-1;
  const diffuse=Math.max(0,dot(normal,lightDirection));
  const half=unit([lightDirection[0],lightDirection[1]+Math.sqrt(.75),lightDirection[2]+.5]);
  const finishFace=finish?finish(f,[a.corner,b.corner,c.corner],cs,sn,lightDirection,half,metalSample):null;
  const metallic=['metal','silver','copper','gold'].includes(f.material);
  const highlight=Math.pow(Math.max(0,dot(normal,half)),metallic?20:45)*(metallic?65:22);
  const color=palette[f.material];if(!color)throw Error('Missing material '+f.material);
  for(let y=Math.max(0,Math.floor(Math.min(a.y,b.y,c.y)));y<Math.min(size,Math.ceil(Math.max(a.y,b.y,c.y)));y++)
  for(let x=Math.max(0,Math.floor(Math.min(a.x,b.x,c.x)));x<Math.min(size,Math.ceil(Math.max(a.x,b.x,c.x)));x++){
   const A=edge(b,c,x+.5,y+.5)/area,B=edge(c,a,x+.5,y+.5)/area,C=1-A-B;if(Math.min(A,B,C)<0)continue;
   const z=A*a.d+B*b.d+C*c.d,index=y*size+x;if(z<depth[index])continue;depth[index]=z;
   const at=index*4;
   const p=[0,1,2].map(k=>A*a.p[k]+B*b.p[k]+C*c.p[k]),lp=lightPoint(p);
   const inShadow=shadow[Math.floor(lp.y)*512+Math.floor(lp.x)]>lp.d+.65;
   if(finishFace){
    finishFace(rgba,at,color,p,A,B,C,inShadow);emissive[index]=Number(f.material==="lamp"||f.material==="optic");continue;
   }
   const grain=Math.sin(p[0]*37.3+p[1]*51.7+p[2]*19.3)*.026+Math.sin(p[0]*2.7+p[1]*3.1)*.02;
   const brushing=metallic?Math.sin(p[0]*80+p[1]*.3)*.025:0;
   const light=.33+.62*diffuse*(inShadow?.35:1)+.12*Math.abs(normal[2]);
   const lamp=f.material==='lamp'||f.material==='optic';emissive[index]=lamp?1:0;
   const textured=['armor','team','metal','dark'].includes(f.material);
   const tex=textured?metalSample(p,f.normal):.22;
   const wear=textured?Math.max(0,tex-.46)*55:0;
   const detail=textured?.7+tex*1.35:1;
   for(let i=0;i<3;i++)rgba[at+i]=lamp?color[i]:Math.min(255,(color[i]*detail+wear)*(light+grain+brushing)+highlight*(inShadow?.1:1));
   rgba[at+3]=255;
  }
 }
 // Tight crevice darkening gives joints, plates and treads separation at game size.
 for(let y=3;y<size-3;y++)for(let x=3;x<size-3;x++){
  const index=y*size+x;if(!rgba[index*4+3]||emissive[index])continue;
  let occlusion=0;
  for(const [dx,dy] of [[3,0],[-3,0],[0,3],[0,-3]]){
   const delta=depth[(y+dy)*size+x+dx]-depth[index];if(delta>.6&&delta<6)occlusion++;
  }
  if(occlusion)for(let k=0;k<3;k++)rgba[index*4+k]*=1-occlusion*.065;
 }
 const out=new Uint8Array(tile*tile*4);let l=tile,t=tile,r=0,bottom=0;
 for(let y=0;y<tile;y++)for(let x=0;x<tile;x++){
  let count=0;const color=[0,0,0];
  for(let dy=0;dy<ss;dy++)for(let dx=0;dx<ss;dx++){const i=((y*ss+dy)*size+x*ss+dx)*4;if(rgba[i+3]){count++;for(let k=0;k<3;k++)color[k]+=rgba[i+k];}}
  if(!count)continue;
  out.set([...color.map(v=>Math.round(v/count)),Math.round(count/4*255)],(y*tile+x)*4);
  l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);bottom=Math.max(bottom,y);
 }
 if(l<3||t<3||r>tile-4||bottom>tile-4)throw Error('Clipped geometry frame '+frame+': '+[l,t,r,bottom]);
 return {rgba:out,bounds:[l,t,r-l+1,bottom-t+1],hash:hash(out)};
}
export function bake({stem,folder,tile=192,poses,make,palette,origin=[64,94],modelScale=1.2,extraRows=0,metadata={},preview}){
 const width=tile*8,height=tile*(poses.length*4+extraRows),rgba=new Uint8Array(width*height*4);
 const data={facings:32,texture_tile:tile,poses,method:'single articulated mesh; offline depth-buffered 32-facing bake',revision:'model-20261118',material_sha256:hash(materialBytes),bounds:[],pose_anchors:[],frame_hashes:[],...metadata};
 const previews=[];
 for(let pose=0;pose<poses.length;pose++){
  const mesh=make(pose);if(pose===0)data.triangles=mesh.faces.length;
  for(let frame=0;frame<32;frame++){
   const image=render(mesh,frame,tile,palette,origin,modelScale);
   data.bounds.push(image.bounds.map(v=>v*128/tile));data.pose_anchors.push([...origin]);data.frame_hashes.push(image.hash);
   for(let y=0;y<tile;y++)rgba.set(image.rgba.subarray(y*tile*4,(y+1)*tile*4),((pose*4+Math.floor(frame/8))*tile*width+y*width+(frame%8)*tile)*4);
   if(preview&&pose===0&&[0,4,12,20].includes(frame))previews.push(image.rgba);
  }
 }
 data.anchors=data.pose_anchors.slice(0,32);
 if(extraRows){
  // Shared exhaust patch: body and two flame quads use the same GPU texture.
  const y0=height-tile;
  for(let y=0;y<tile;y++)for(let x=0;x<tile*3;x++){
   const u=x/(tile*3),v=(y/tile-.5)/(Math.max(.02,1-u)*.43);
   const a=Math.max(0,1-v*v)*Math.pow(1-u,.7)*220;const k=((y0+y)*width+x)*4;
   rgba.set([255,240,210,a],k);
  }
  data.exhaust_uv=[0,y0/height,3/8,tile/height];
 }
 fs.mkdirSync(folder,{recursive:true});fs.writeFileSync(folder+'/'+stem+'.png',encodePng(width,height,rgba));
 fs.writeFileSync(folder+'/'+stem+'.json',JSON.stringify(data,null,2)+'\n');
 if(preview){
  const previewRgba=new Uint8Array(tile*tile*4*previews.length);
  for(let i=0;i<previews.length;i++)for(let y=0;y<tile;y++)previewRgba.set(previews[i].subarray(y*tile*4,(y+1)*tile*4),(y*tile*previews.length+i*tile)*4);
  fs.writeFileSync(preview,encodePng(tile*previews.length,tile,previewRgba));
 }
 console.log(JSON.stringify({stem,tile,poses:poses.length,triangles:data.triangles,bytes:fs.statSync(folder+'/'+stem+'.png').size}));
 return data;
}
