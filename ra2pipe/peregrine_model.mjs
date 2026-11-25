// Polar Peregrine: one authored mechanical mesh, baked through the RA2 camera.
// +X is the nose. No direction interpolation, AI view synthesis or runtime mesh.
import fs from 'node:fs';
import {encodePng} from './art_lib.mjs';
import {YrSource,sha256} from './lib/yr_source.mjs';
import {parseVxl,parseHva,poseVxl} from './vxl_lib.mjs';
import {Mesh,render} from './mechanical_mesh.mjs';

const output=new URL('../iron_tide/assets/cosmetics/heroes/',import.meta.url);
const src=new YrSource(process.argv[2]);
const vxl=src.read('FALC.vxl'),hva=src.read('FALC.hva');
const native=poseVxl(parseVxl(vxl.data),parseHva(hva.data));
if(native.limbs.length!==1)throw Error('Unexpected FALC source');
const matrix=native.limbs[0].matrix;
const S=4,W=96,H=64,OX=48,OY=42,FW=W*S,FH=H*S,AW=FW*8,AH=FH*4;
const triangles=[];
const materials={
 ceramic:[218,229,233],edge:[246,247,231],steel:[62,78,91],dark:[22,32,47],
 gold:[193,151,69],glass:[31,112,159],glassLight:[91,192,224],
 team:[220,220,220],lamp:[102,220,252],rubber:[12,19,25]
};
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const sub=(a,b)=>a.map((n,i)=>n-b[i]);
function triangle(a,b,c,m){
 const n=cross(sub(b,a),sub(c,a)),length=Math.hypot(...n);
 if(length<1e-6)return;
 triangles.push({points:[a,b,c],material:m,normal:n.map(v=>v/length)});
}
function polygon(p,m){for(let i=1;i<p.length-1;i++)triangle(p[0],p[i],p[i+1],m);}
function quad(a,b,c,d,m){polygon([a,b,c,d],m);}
// Convex bevelled shell with a slim gold gasket and a recessed top plate.
function panel(points,z,thickness,m='ceramic',bevel=.94){
 const center=points.reduce((a,p)=>[a[0]+p[0]/points.length,a[1]+p[1]/points.length],[0,0]);
 const lower=points.map(p=>[...p,z]);
 const upper=points.map(p=>[center[0]+(p[0]-center[0])*bevel,center[1]+(p[1]-center[1])*bevel,z+thickness]);
 polygon([...lower].reverse(),'dark');polygon(upper,m);
 for(let i=0;i<points.length;i++){let j=(i+1)%points.length;quad(lower[i],lower[j],upper[j],upper[i],'gold');}
}
function loft(sections,y,m,n=16){
 const rings=sections.map(([x,ry,rz,z])=>Array.from({length:n},(_,i)=>[x,y+Math.cos(i*Math.PI*2/n)*ry,z+Math.sin(i*Math.PI*2/n)*rz]));
 for(let k=1;k<rings.length;k++)for(let i=0;i<n;i++){let j=(i+1)%n;quad(rings[k-1][i],rings[k-1][j],rings[k][j],rings[k][i],m);}
 polygon([...rings[0]].reverse(),m);polygon(rings.at(-1),m);
}
function ring(x,y,z,outer,inner,m,n=24){
 for(let i=0;i<n;i++){
  const p=(r,j)=>[x,y+Math.cos(j*Math.PI*2/n)*r,z+Math.sin(j*Math.PI*2/n)*r];
  quad(p(outer,i),p(outer,i+1),p(inner,i+1),p(inner,i),m);
 }
}
function fin(side){
 const p=[[-21,side*10,9],[-12,side*9,10],[-18,side*13,20],[-23,side*14,19]];
 polygon(p,'ceramic');polygon(p.map(([x,y,z])=>[x,y+side*.55,z]),'steel');
 for(let i=0;i<4;i++)quad(p[i],p[(i+1)%4],p[(i+1)%4].map((n,k)=>n+(k===1?side*.55:0)),p[i].map((n,k)=>n+(k===1?side*.55:0)),'gold');
 polygon([[-20.5,side*12.1,16],[-17.3,side*11.2,16.8],[-18.5,side*12.8,18.7],[-21.6,side*13.4,18.2]],'team');
}
// Continuous tapered fuselage; curved cross-sections avoid the former box shell.
loft([[-25,1.4,1.8,6],[-20,4.4,3.6,7],[-8,6,4,7],[8,4.2,3.2,6.4],[21,2.1,1.7,5],[29,.1,.15,4]],0,'steel');
loft([[-23,1,1,8],[-16,4.5,2.4,9],[-3,4.3,3,9],[12,2.9,2.2,7.7],[24,1.1,.7,5.6],[29,.08,.08,4.3]],0,'ceramic');
// Swept wings, recessed feather panels, team-color identification bars.
for(const side of [-1,1]){
 const mirror=p=>p.map(([x,y])=>[x,y*side]);
 panel(mirror([[10,3],[-6,25],[-18,27],[-16,14],[-24,7],[-12,3]]),6,1.25,'ceramic',.96);
 panel(mirror([[8,5],[-6,22],[-12,23],[-9,16],[-17,9],[-8,6]]),7.35,.25,'edge',.96);
 panel(mirror([[-6,24],[-15,25],[-14,21],[-4,19]]),7.5,.1,'team',1);
 panel(mirror([[3,8],[-5,17],[-9,18],[-5,12],[-10,11]]),7.65,.08,'dark',1);
 // Three narrow chevrons read as a falcon feather, not noise in a tiny texture.
 for(let i=0;i<3;i++)panel(mirror([[-3-i*2,12+i*2],[-4-i*2,15+i*2],[-8-i*2,16+i*2],[-7-i*2,15+i*2]]),7.8,.08,'gold',1);
 panel(mirror([[-14,10],[-22,19],[-27,18],[-24,8]]),5,1,'ceramic');
 fin(side);
 // Four independent underwing rails; slim solid-state missile casings.
 for(const y of [13,19]){
  loft([[-12,1.05,1,3.3],[1,.9,.9,3.3],[7,.08,.08,3.3]],side*y,'steel',12);
  panel(mirror([[-9,y-1],[-9,y+1],[-5,y+1],[-5,y-1]]),4.1,.2,'team');
 }
 const y=side*8;
 // High-mounted turbine nacelles: elliptical fairing, intake rim and vanes.
 loft([[-22,2.7,2.5,10.8],[-18,3.7,3.5,11.3],[-4,3.7,3.5,11.3],[1,3.1,3,11.1]],y,'ceramic',24);
 ring(1.12,y,11.1,3.05,2.45,'gold');ring(1.17,y,11.1,2.45,.01,'dark');
 ring(1.2,y,11.1,2.05,1.7,'lamp');ring(1.24,y,11.1,.7,.01,'steel');
 for(let i=0;i<8;i++){
  const a=i*Math.PI/4;
  triangle([1.23,y+Math.cos(a)*.7,11.1+Math.sin(a)*.7],[1.23,y+Math.cos(a+.28)*1.65,11.1+Math.sin(a+.28)*1.65],[1.23,y+Math.cos(a+.65)*1.6,11.1+Math.sin(a+.65)*1.6],'glassLight');
 }
 ring(-22.1,y,10.8,2.7,2,'steel');ring(-22.15,y,10.8,2,.01,'dark');ring(-22.18,y,10.8,1.75,.65,'lamp');
 for(let i=0;i<4;i++)panel([[-17+i*2,y-1.5],[-16.2+i*2,y-1.5],[-16.2+i*2,y+1.5],[-17+i*2,y+1.5]],14.4,.12,'steel');
}
// Segmented swept cockpit; highlights follow the canopy rather than float above it.
loft([[0,.4,.2,12],[3,2.5,1.2,11.1],[10,2.15,1.5,9.8],[16,1.05,.6,8.1],[19,.1,.1,7.1]],0,'glass',12);
for(const x of [4,8,12]){
 const z=11.7-(x-4)*.2,ry=2.5-(x-4)*.12;
 loft([[x-.16,ry,.85,z],[x+.16,ry,.85,z]],0,'gold',12);
}
quad([3,-.4,12.32],[10,-.34,11.32],[15,.05,8.95],[3,.12,12.33],'glassLight');
panel([[-15,-1.3],[-4,-1.3],[-3,1.3],[-15,1.3]],12.1,.12,'team');
for(let i=0;i<4;i++)panel([[-19+i*1.4,-1],[-18.4+i*1.4,-1],[-18.4+i*1.4,1],[-19+i*1.4,1]],11.2,.2,'steel');

// Small mechanical parts share the same model and depth buffer at every heading.
const detail=new Mesh();
for(const side of [-1,1]){
 const y=side*8;
 // Nacelle access panel, reinforcing collars and inset cooling slots.
 detail.plate(-9,y,14.76,4.7,1.15,.15,'steel','dark');
 for(const x of [-16,-5]){
  loft([[x-.18,3.76,3.56,11.3],[x+.18,3.76,3.56,11.3]],y,'steel',32);
  ring(x+.2,y,11.3,3.5,3.32,'gold',32);
 }
 for(let i=0;i<6;i++)detail.beam([-12+i*1.15,y-.85,14.98],[-12+i*1.15,y+.85,14.98],.18,.09,'dark','dark');
 for(const x of [-13,-5])for(const dy of [-.95,.95])detail.tube([x,y+dy,14.9],[x,y+dy,15.08],.19,'edge',8);
 // Nozzle petals and turbine hub make the engine recognizable from behind.
 for(let i=0;i<16;i++){
  const a=i*Math.PI/8,b=a+.13;
  quad([-22.25,y+Math.cos(a)*2.65,10.8+Math.sin(a)*2.65],[-22.25,y+Math.cos(b)*2.65,10.8+Math.sin(b)*2.65],[-23.1,y+Math.cos(b)*1.95,10.8+Math.sin(b)*1.95],[-23.1,y+Math.cos(a)*1.95,10.8+Math.sin(a)*1.95],'steel');
 }
 loft([[1.28,.55,.55,11.1],[1.9,.1,.1,11.1]],y,'edge',16);
 // Wing service panel, hinge seam and flush rivets; no change to silhouette.
 const P=(x,y,z)=>[x,side*y,z];
 detail.beam(P(-15,21,7.49),P(-9,14,7.49),.09,.05,'dark','dark');
 detail.beam(P(-9,14,7.49),P(-16,9,7.49),.09,.05,'dark','dark');
 detail.plate(-9,side*20,7.72,1.25,.7,.11,'steel','gold');
 for(const [x,dy] of [[-14,23],[-12,22],[-10,21],[-8,20],[-17,11],[-19,9]])
  detail.tube(P(x,dy,7.48),P(x,dy,7.67),.16,'edge',8);
 // Slim raised actuator and underwing rail attachment braces.
 detail.beam(P(-19,11,6.2),P(-23,16,6.2),.3,.22,'steel','dark');
 for(const dy of [13,19])for(const x of [-9,-5])detail.beam(P(x,dy,4.1),P(x,dy,6.2),.28,.25,'steel','dark');
 detail.plate(-15,side*25,7.38,.65,.32,.15,'dark','steel');
 detail.plate(-15,side*25,7.56,.4,.2,.12,'lamp','steel');
 // Shoulder light and forward sensor are independent of owner paint.
 detail.beam(P(2,4.4,8.1),P(7,3.3,7.6),.22,.13,'dark','steel');
 detail.beam(P(2.5,4.35,8.28),P(5.7,3.65,7.98),.10,.05,'lamp','lamp');
}
for(const face of detail.faces)triangles.push({points:face.p,normal:face.normal,material:face.material});
const aliases={ceramic:'armor',edge:'silver',steel:'metal'};
const palette=Object.fromEntries(Object.entries(materials).map(([key,value])=>[aliases[key]||key,value]));
const mesh=new Mesh();
for(const tri of triangles){
 const points=tri.points.map(p=>[0,4,8].map(r=>matrix[r]*p[0]+matrix[r+1]*p[1]+matrix[r+2]*p[2]+matrix[r+3]));
 mesh.tri(...points,aliases[tri.material]||tri.material);
}
const atlas=new Uint8Array(AW*AH*4),mask=new Uint8Array(atlas.length);
const manifest={format:1,facings:32,columns:8,tile:[FW,FH],scale:S,origin:[OX*S,OY*S],
 source:'authored mesh in FALC model coordinates, RA2 orthographic camera',
 revision:'detail-20261118',supersampling:2,
 material_sha256:sha256(fs.readFileSync(new URL('materials/hero-tank-armor.png',import.meta.url))),
 inputs:{vxl:sha256(vxl.data),hva:sha256(hva.data)},triangles:triangles.length,bounds:[],muzzles:[],engines:[],frame_hashes:[]};
const edge=(a,b,x,y)=>(b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x);
for(let facing=0;facing<32;facing++){
 const az=Math.PI/4-facing*Math.PI/16,c=Math.cos(az),s=Math.sin(az),ce=Math.sqrt(.75);
 const project=p=>{
  const [X,Y,Z]=[0,4,8].map(r=>matrix[r]*p[0]+matrix[r+1]*p[1]+matrix[r+2]*p[2]+matrix[r+3]);
  return {x:(OX-X*s+Y*c)*S,y:(OY+(X*c+Y*s)*.5-Z*ce)*S,d:(X*c+Y*s)*ce+Z*.5};
 };
 // Generic camera frame 12-facing exactly matches the native RA2 FALC projection.
 const square=render(mesh,(12-facing+32)%32,128*S,palette,[OX,OY],1);
 const tile=new Uint8Array(FW*FH*4),localMask=new Uint8Array(tile.length);
 for(let y=0;y<FH;y++)tile.set(square.rgba.subarray(y*128*S*4,(y*128*S+FW)*4),y*FW*4);
 const MW=FW*2,MH=FH*2,maskHi=new Uint8Array(MW*MH*4),depth=new Float32Array(MW*MH).fill(-Infinity);
 for(const tri of triangles){
  let [a,b,d]=tri.points.map(p=>{const q=project(p);return {...q,x:q.x*2,y:q.y*2};});let area=edge(a,b,d.x,d.y);if(area<0){[b,d]=[d,b];area=-area;}
  if(area<.001)continue;
  const emission=tri.material==='lamp',team=tri.material==='team';
  for(let y=Math.max(0,Math.floor(Math.min(a.y,b.y,d.y)));y<Math.min(MH,Math.ceil(Math.max(a.y,b.y,d.y)));y++)
  for(let x=Math.max(0,Math.floor(Math.min(a.x,b.x,d.x)));x<Math.min(MW,Math.ceil(Math.max(a.x,b.x,d.x)));x++){
   const A=edge(b,d,x+.5,y+.5)/area,B=edge(d,a,x+.5,y+.5)/area,C=1-A-B;
   if(Math.min(A,B,C)<0)continue;
   const z=A*a.d+B*b.d+C*d.d,k=y*MW+x;if(z<depth[k])continue;depth[k]=z;
   maskHi.set([team?255:0,0,emission?255:0,255],k*4);
  }
 }
 for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){
  let covered=0,team=0,emission=0;
  for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++){
   const k=((y*2+dy)*MW+x*2+dx)*4;
   if(maskHi[k+3]){covered++;team+=maskHi[k];emission+=maskHi[k+2];}
  }
  if(covered)localMask.set([Math.round(team/covered),0,Math.round(emission/covered),Math.round(covered/4*255)],(y*FW+x)*4);
 }
 let minX=FW,minY=FH,maxX=0,maxY=0;
 for(let y=0;y<FH;y++)for(let x=0;x<FW;x++){
  const i=(y*FW+x)*4;if(tile[i+3]){minX=Math.min(x,minX);minY=Math.min(y,minY);maxX=Math.max(x,maxX);maxY=Math.max(y,maxY);}
  const dest=((Math.floor(facing/8)*FH+y)*AW+(facing%8)*FW+x)*4;
  atlas.set(tile.subarray(i,i+4),dest);mask.set(localMask.subarray(i,i+4),dest);
 }
 if(minX<=1||minY<=1||maxX>=FW-2||maxY>=FH-2)throw Error('Clipped frame '+facing);
 manifest.bounds.push([minX,minY,maxX-minX+1,maxY-minY+1]);
 const point=p=>{const v=project(p);return [v.x,v.y];};
 manifest.muzzles.push(point([29,0,4]));manifest.engines.push([-1,1].map(side=>point([-9,side*8,6])));
 manifest.frame_hashes.push(sha256(tile));
}
if(new Set(manifest.frame_hashes).size!==32)throw Error('Duplicate directions');
fs.mkdirSync(output,{recursive:true});
for(const [suffix,rgba] of [['',atlas],['_mask',mask]])fs.writeFileSync(new URL('peregrine_polar_32'+suffix+'.png',output),encodePng(AW,AH,rgba));
fs.writeFileSync(new URL('peregrine_polar_32.json',output),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({triangles:triangles.length,facings:32,atlas:[AW,AH],bounds:manifest.bounds[0]}));
