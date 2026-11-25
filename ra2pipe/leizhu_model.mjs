import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Mesh,bake,project} from './mechanical_mesh.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const folder=root+'/iron_tide/assets/cosmetics/heroes';
const palette={armor:[80,88,96],metal:[126,133,138],dark:[29,35,41],rubber:[22,26,30],copper:[188,113,65],gold:[175,141,84],team:[176,29,29],ceramic:[211,205,180],lamp:[255,153,23],optic:[65,195,255],silver:[190,197,200]};
function tank(){
 const m=new Mesh();m.plate(0,0,3,23,13,5,'dark','metal');m.plate(0,0,8,22,12,3,'armor');
 // Separate road wheels, track loop, shoes, guards and front glacis.
 for(const side of [-1,1]){
  m.loft([[-25,1,1.2,5],[-22,4.3,4.7,5],[20,4.3,4.7,5],[25,1,1.2,5]],side*15,'rubber',12);
  for(let i=0;i<6;i++){
   const x=-19+i*7.5;
   m.tube([x,side*16.9,5],[x,side*19.4,5],3.2,'metal',16);
   m.tube([x,side*19.4,5],[x,side*19.6,5],2.5,'dark',16);
   m.tube([x,side*19.6,5],[x,side*19.7,5],.9,'gold');
  }
  for(let i=0;i<30;i++){
   const a=i*Math.PI*2/30,x=Math.cos(a)*24,z=5+Math.sin(a)*4.9;
   m.beam([x-.7,side*11.1,z],[x-.7,side*19,z],.62,.4,'metal','dark');
  }
  for(let i=0;i<4;i++){
   const x=-17+i*11;
   m.plate(x,side*15,10,5,4.6,1.8,'team','metal');
   m.plate(x,side*15,12,3.9,3.6,.3,'team','gold');
   for(const dx of [-3,3])m.tube([x+dx,side*17.4,12.2],[x+dx,side*17.4,12.6],.36,'silver',8);
  }
  m.beam([20,side*10,9],[26,side*10,5],1.1,.5,'metal','gold');
  m.tube([22,side*12,10],[23,side*12,10],.85,'dark');m.tube([23,side*12,10],[23.1,side*12,10],.55,'lamp');
  for(let i=0;i<5;i++)m.plate(-19+i*1.1,side*8,12,.3,2,.3,'dark','metal');
 }
 m.panel([[15,-10],[24,-8],[26,8],[15,10]],10,1.2,'team','metal');
 // Central copper crown with exposed porcelain insulators and amber furnace.
 m.tube([0,0,10],[0,0,12],11,'dark',24);
 m.tube([0,0,12],[0,0,13],10,'metal',24);
 m.tube([0,0,13],[0,0,22],4.7,'lamp',20);
 m.tube([0,0,12.5],[0,0,14],5.2,'dark',20);
 m.tube([0,0,22],[0,0,23.5],5.1,'metal',20,3.7);
 for(let i=0;i<8;i++){
  const a=i*Math.PI/4,x=Math.cos(a)*4.8,y=Math.sin(a)*4.8;
  m.beam([x,y,13.5],[x,y,22.7],.38,.35,'dark','gold');
 }
 m.torus([0,0,16],11.5,.9,'copper',48);
 m.torus([0,0,24],11.5,1.05,'copper',48);
 for(let i=0;i<64;i++){
  const a=i*Math.PI*2/64,c=Math.cos(a),s=Math.sin(a);
  // Narrow copper winding grooves remain geometry, not painted diagonal stripes.
  m.tube([c*10.7,s*10.7,24.72],[c*12.2,s*12.2,24.72],.09,'gold',6);
 }
 for(let i=0;i<6;i++){
  const a=i*Math.PI/3,x=Math.cos(a)*11.5,y=Math.sin(a)*11.5;
  m.tube([x,y,12],[x,y,27],.8,'dark');
  for(let j=0;j<5;j++)m.tube([x,y,17+j],[x,y,17.45+j],1.7,'ceramic',16);
  m.tube([x,y,24.2],[x,y,26],1.2,'gold');
  m.tube([x,y,26],[x,y,26.4],.65,'optic');
 }
 // Two rear induction drums, mechanically distinct from the central furnace.
 for(const y of [-5,5]){
  m.tube([-18,y,14],[-18,y,20],2.6,'dark');
  for(let j=0;j<7;j++)m.tube([-21+j*.8,y,17],[-20.6+j*.8,y,17],3.1,'copper',20);
  m.tube([-22,y,17],[-21.4,y,17],3.5,'metal',20);
  m.tube([-14.5,y,17],[-14,y,17],3.5,'metal',20);
 }
 return m;
}
const data=bake({stem:'leizhu_copper_model32',folder,tile:256,poses:['body'],make:tank,palette,modelScale:1.28,preview:root+'/.validation/model-skins-20261118/leizhu-model.png'});
data.tile=256;
data.anchors=data.anchors.map(p=>p.map(v=>v*2));
data.bounds=data.bounds.map(p=>p.map(v=>v*2));
data.coils=[];data.reactors=[];data.coil_radius=11.5*1.28*2;
for(let frame=0;frame<32;frame++)for(const [name,p] of [['coils',[0,0,24]],['reactors',[0,0,18]]]){
 const q=project(p,frame,[64,94],1.28);data[name].push([q.x*2,q.y*2]);
}
data.preview_width=data.bounds.reduce((a,b)=>a+b[2]/32,0);
fs.writeFileSync(folder+'/leizhu_copper_model32.json',JSON.stringify(data,null,2)+'\n');
