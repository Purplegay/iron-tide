import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Mesh,bake,project,mix,hash} from './mechanical_mesh.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const folder=root+'/iron_tide/assets/cosmetics/night_hunters';
const preview=root+'/.validation/model-skins-20261118';fs.mkdirSync(preview,{recursive:true});
const source_sha256=[hash(fs.readFileSync(fileURLToPath(import.meta.url))),hash(fs.readFileSync(root+'/ra2pipe/mechanical_mesh.mjs'))];
const palette={armor:[54,64,76],metal:[117,127,137],dark:[24,31,41],rubber:[17,22,29],gold:[166,130,77],team:[179,28,28],glass:[42,76,93],lamp:[255,164,42],optic:[58,192,255],silver:[182,195,201]};
function owl(pose){
 const m=new Mesh(),f=pose/4;
 m.loft([[-22,2,2,14],[-14,6,5,14],[0,7,6,14],[14,5.8,5,13],[25,2.3,2,11],[28,.8,.8,10]],0,'armor');
 m.loft([[-42,1.1,1.1,18],[-32,2,2,16],[-18,3,3,14]],0,'metal');
 m.loft([[-41,.7,.7,18.8],[-30,1.2,1.2,17.4],[-18,2,2,16]],0,'armor');
 // One continuous armoured cockpit with independent inset glazing.
 m.loft([[4,3.5,2,19],[10,4.2,3.8,17],[18,2.6,2.6,15],[22,.7,.7,12]],0,'glass',8);
 for(const x of [6,12,18])m.loft([[x-.25,4.5-(x-6)*.13,2.4,18-(x-6)*.25],[x+.25,4.5-(x-6)*.13,2.4,18-(x-6)*.25]],0,'gold',8);
 m.tube([26.7,0,11],[28.2,0,11],1.2,'dark');m.tube([28.2,0,11],[28.3,0,11],.65,'lamp');
 m.tube([24.5,0,13],[25.8,0,13],.75,'metal');m.tube([25.8,0,13],[26,0,13],.45,'optic');
 for(const s of [-1,1]){
  const mirror=p=>p.map(([x,y])=>[x,y*s]);
  m.panel(mirror([[12,4],[2,10],[-12,9],[-17,5],[-6,4]]),17.2,1.4,'armor','gold');
  m.panel(mirror([[8,6],[2,8],[-3,8],[2,6]]),18.7,.15,'team');
  m.poly([[22,s*2.4,12],[13,s*5.4,17],[7,s*5.8,18],[12,s*5.5,12]],'metal');
  m.poly([[20,s*2.8,12.7],[13,s*5.5,16.6],[10,s*5.9,17],[14,s*5.6,13]],'armor');
  for(let vent=0;vent<4;vent++)m.beam([-14+vent*2.2,s*5.8,17],[-14+vent*2.2,s*7,17.7],.35,.18,'dark','silver');
  m.tube([18,s*4.3,12.4],[22,s*3,11.7],.35,'lamp',8);
  m.tube([12,s*4.7,17.1],[14,s*4.2,16.5],.22,'optic',8);
  m.panel(mirror([[4,7],[-1,20],[-9,21],[-12,7]]),12.4,1.6,'armor','metal');
  m.panel(mirror([[1,8],[-2,17],[-8,18],[-10,8]]),14.1,.35,'armor','gold');
  for(const x of [-8,-4,0])for(const y of [9,17])m.tube([x,s*y,14.5],[x,s*y,14.8],.22,'silver',6);
  m.panel(mirror([[-2,15],[-2,20],[-8,20],[-7,16]]),14.1,.15,'team');
  m.panel(mirror([[-1,19],[-1,20.5],[-4,20.5],[-4,19]]),14.3,.15,'lamp');
  for(const y of [12,16]){
   m.tube([-9,s*y,10],[6,s*y,10],1.3,'dark');
   m.tube([5,s*y,10],[8,s*y,10],1.05,'gold',12,.15);
   m.tube([-5,s*y,8],[4,s*y,8],1,'metal');
  }
  m.loft([[-17,2.6,2.7,19],[-10,3.3,3.4,19],[-3,3.3,3.4,19],[1,2.9,3,19]],s*6.8,'armor',12);
  m.tube([1,s*6.8,19],[1.4,s*6.8,19],2.7,'gold');m.tube([1.4,s*6.8,19],[1.5,s*6.8,19],2.05,'dark');
  for(let i=-1;i<=1;i++)m.tube([1.6,s*6.8+i*.9,17.6],[1.6,s*6.8+i*.9,20.4],.18,'metal',6);
  m.tube([-17,s*6.8,19],[-18,s*6.8,19],2.2,'dark');m.tube([-18,s*6.8,19],[-18.1,s*6.8,19],1.4,'lamp');
  for(let j=0;j<5;j++)m.beam([-14+j*1.6,s*7,22.25],[-14+j*1.6,s*9,21.9],.25,.15,'metal','dark');
  for(let j=0;j<6;j++)m.beam([-33+j*2.1,s*1.8,17.5],[-33+j*2.1,s*2.2,18.1],.17,.12,'gold','dark');
  // Four supporting legs articulate outwards and downwards over five poses.
  for(const x of [-11,11]){
   const root=[x,s*5,10],knee=mix([x-3,s*7,9],[x-1,s*16,8],f),foot=mix([x-6,s*7,8],[x+3,s*22,0],f);
   m.beam(root,knee,1.6,.85,'armor','gold');m.tube(root,knee,.55,'silver');
   m.beam(knee,foot,1.2,.6,'armor','metal');
   m.tube(mix(knee,foot,.15),mix(knee,foot,.82),.28,'gold',8);
   m.plate(foot[0],foot[1],foot[2],3,1.7,.65,'dark','gold');
  }
  // Gold spine and side panel fasteners are geometry, consistent in every view.
  for(let i=0;i<5;i++)m.tube([-12+i*5,s*5.7,17],[-12+i*5,s*5.7,17.45],.28,'silver',6);
 }
 m.poly([[-42,-.7,17],[-34,-.7,18],[-39,-.7,32],[-43,-.7,33]],'armor');
 m.poly([[-42,.7,17],[-34,.7,18],[-39,.7,32],[-43,.7,33]],'metal');
 m.poly([[-41,.8,26],[-38,.8,27],[-39.5,.8,31],[-42,.8,31]],'team');
 m.tube([-41,0,32.5],[-41,0,33.2],.6,'lamp',8);
 m.tube([-40,-1,23],[-40,-3,23],1.3,'metal');
 for(let i=0;i<4;i++){const a=i*Math.PI/2;m.beam([-40,-3.1,23],[-40+Math.cos(a)*7,-3.1,23+Math.sin(a)*7],.5,.25,'dark','gold');}
 m.tube([0,0,19],[0,0,27],1.4,'metal');m.tube([0,0,25],[0,0,27],2.9,'dark');
 m.tube([0,0,27],[0,0,27.6],2.4,'gold');
 m.plate(.7,0,27.7,.3,1.6,.12,'lamp','dark');
 return m;
}
function gun(){
 const m=new Mesh();m.plate(0,0,8,7,4,3,'armor','gold');
 m.tube([3,0,9],[14,0,9],2.5,'metal');m.tube([14,0,9],[35,0,9],1.5,'dark');
 for(const x of [10,16,26,32])m.tube([x,0,9],[x+.7,0,9],1.8,'gold');
 m.tube([35,0,9],[38,0,9],2.2,'metal');m.tube([38,0,9],[38.1,0,9],1.3,'dark');
 return m;
}
const owlMeta={source_sha256,rotor_radius_pixels:48,rotor_model:[0,0,27.6],rotor_centers:[],pose_rotor_centers:[],exhaust_roots:[],limb_count:4,deployment:[0,.25,.5,.75,1]};
for(let pose=0;pose<5;pose++)for(let facing=0;facing<32;facing++){
 const hub=project(owlMeta.rotor_model,facing);owlMeta.pose_rotor_centers.push([hub.x,hub.y]);if(pose===0)owlMeta.rotor_centers.push([hub.x,hub.y]);
 owlMeta.exhaust_roots.push([-1,1].map(s=>{const p=project([-18,s*6.8,19],facing);return [p.x,p.y];}));
}
bake({stem:'night_owl_mesh32',folder,tile:256,poses:['flight','deploy_25','deploy_50','deploy_75','deployed'],make:owl,palette,extraRows:1,metadata:owlMeta,preview:preview+'/owl-model.png'});
bake({stem:'night_owl_mesh_gun',folder,poses:['gun'],make:gun,palette,preview:preview+'/owl-gun.png'});

const feet=[];
function drone(pose){
 const m=new Mesh(),phase=pose===0?0:(pose-1)/8;
 m.loft([[-14,1.8,1,10],[-9,8,4,11],[4,9,4.5,10],[12,5,2.5,8],[15,1,1,7]],0,'armor');
 m.loft([[-11,2,1,14],[-6,5.5,2,14],[4,5.5,1.5,14],[10,2.2,.8,11]],0,'dark');
 m.tube([13,0,8],[15.3,0,8],1.35,'metal');m.tube([15.3,0,8],[15.5,0,8],.8,'lamp');
 for(const x of [-6,1,7])m.plate(x,0,17.1-(x+6)*.18,1.1,2.6,.35,'lamp','metal');
 for(const side of [-1,1]){
  for(let i=0;i<3;i++){
   m.panel([[-10+i*6,side*3],[-6+i*6,side*3],[-4+i*6,side*7],[-9+i*6,side*7]],13.5,.8,'armor','metal');
   m.tube([-8+i*6,side*6,14.3],[-8+i*6,side*6,14.65],.28,'silver',8);
  }
  for(let i=0;i<5;i++)m.beam([-9+i*2,side*7.6,11.9],[-9+i*2,side*8.4,12.4],.22,.16,'dark','silver');
  for(const front of [-1,1]){
   const offset=front*side>0?0:.5,cycle=(phase+offset)%1;
   const stride=pose===0?0:Math.cos(cycle*Math.PI*2)*4.2;
   const lift=pose===0?0:Math.max(0,Math.sin(cycle*Math.PI*2))*4;
   const hip=[front*8,side*6.5,9],knee=[front*15+stride*.45,side*16,10.5+lift*.4],foot=[front*23+stride,side*23,lift];
   if(pose>=9){
    knee[0]=front*(pose===9?12:19);knee[1]=side*13;knee[2]=12;
    foot[0]=front*(pose===9?15:29);foot[1]=side*(pose===9?12:16);foot[2]=pose===9?4:8;
   }
   m.parts.push({name:(front>0?'front':'rear')+(side>0?'_left':'_right'),hip,knee,foot});
   m.tube([hip[0],hip[1]-1.5,hip[2]],[hip[0],hip[1]+1.5,hip[2]],2.2,'metal');
   m.beam(hip,knee,2.0,1.0,'dark','metal');m.tube(mix(hip,knee,.15),mix(hip,knee,.8),.45,'silver');
   m.tube([knee[0],knee[1]-1.7,knee[2]],[knee[0],knee[1]+1.7,knee[2]],2.4,'silver');
   for(const edge of [-1,1]){
    m.tube([knee[0],knee[1]+edge*1.7,knee[2]],[knee[0],knee[1]+edge*1.9,knee[2]],1.85,'dark',16);
    m.tube([knee[0],knee[1]+edge*1.9,knee[2]],[knee[0],knee[1]+edge*2,knee[2]],.75,'metal',12);
   }
   m.beam(knee,foot,2.7,1.1,'team','metal');
   const cover=mix(knee,foot,.55);m.beam([knee[0],knee[1],knee[2]+2],[cover[0],cover[1],cover[2]+1.5],3.2,.65,'team','dark');
   m.tube([knee[0]+front*.3,knee[1],knee[2]+2.7],[cover[0],cover[1],cover[2]+2.1],.22,'metal',6);
   m.beam(mix(knee,foot,.62),[foot[0]+front*1.2,foot[1],foot[2]],1.1,.5,'silver','dark');
  }
 }
 m.tube([0,0,5],[0,0,7],3.8,'metal');
 for(let i=0;i<8;i++){const a=i*Math.PI/4;m.tube([Math.cos(a)*3,Math.sin(a)*3,5],[Math.cos(a)*4,Math.sin(a)*4,4.8],.5,'dark',6);}
 if(m.parts.length!==4)throw Error('A drone must have exactly four articulated legs');
 feet.push(m.parts);
 return m;
}
const droneData=bake({stem:'rift_hunter_mesh32',folder,tile:192,poses:['idle',...Array.from({length:8},(_,i)=>'walk_'+i),'pounce_coil','pounce_extend'],make:drone,palette:{...palette,lamp:[255,81,31]},metadata:{source_sha256,limb_count:4,gait_frames:8,stride_world:40,ground_z:0,pounce_poses:[9,10]},preview:preview+'/drone-model.png'});
// Model-space support evidence, independent of image silhouettes/occlusion.
droneData.leg_rig=feet;
fs.writeFileSync(folder+'/rift_hunter_mesh32.json',JSON.stringify(droneData,null,2)+'\n');
