// FV optical carriage and HARV weighbridge. X points forward, Z points up.
// Turret poses share the hull atlas and rotate around their own live mount.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {Mesh,render,project} from './mechanical_mesh.mjs';
import {encodePng} from './art_lib.mjs';
import {smoothCorners,finish} from './convoy_surface.mjs';

const folder=fileURLToPath(new URL('../iron_tide/assets/cosmetics/heroes/',import.meta.url));
const palette={armor:[81,110,132],metal:[106,120,131],dark:[34,44,54],rubber:[32,34,38],
 silver:[203,217,222],gold:[202,161,89],copper:[170,104,65],team:[202,23,27],
 ivory:[225,233,222],blue:[38,79,119],glass:[30,89,109],optic:[140,242,248],
 oxide:[164,79,49],ochre:[231,166,66],lamp:[255,184,67],ore:[131,110,79]};
const plates=(m,points,z,h,top,edge)=>m.panel(points,z,h,top,edge);
function lens(m,x,y,z,r,light){
 for(const [offset,radius,material] of [[0,r,'dark'],[.7,r*.97,'gold'],[1.1,r*.81,'glass'],[1.45,r*.53,light]]){
  m.tube([x+offset,y,z],[x+offset+.24,y,z],radius,material,20);
 }
}
function rivetRow(m,a,b,count,r=.22){
 for(let i=0;i<count;i++){
  const t=i/(count-1),p=a.map((v,k)=>v*(1-t)+b[k]*t);
  m.tube(p,[p[0],p[1],p[2]+.17],r,'silver',8);
 }
}
function hub(m,x,y,z,r,side){
 m.tube([x,y,z],[x,y+side*2.7,z],r,'rubber',24);
 m.tube([x,y+side*2.71,z],[x,y+side*3,z],r*.76,'metal',20);
 m.tube([x,y+side*3.01,z],[x,y+side*3.4,z],r*.48,'blue',12);
 m.tube([x,y+side*3.42,z],[x,y+side*3.65,z],r*.18,'gold',8);
 // Raised herringbone lugs cross the rounded tyre shoulder.
 if(r>4)for(let j=0;j<28;j++){
  const a=j*Math.PI/14,ca=Math.cos(a),sa=Math.sin(a);
  m.beam([x+(r+.06)*ca,y+side*.2,z+(r+.06)*sa],[x+(r+.06)*Math.cos(a+.105),y+side*2.7,z+(r+.06)*Math.sin(a+.105)],.37,.22,'rubber','dark');
 }
 for(let n=0;n<5;n++){
  const a=n*2*Math.PI/5,dx=Math.cos(a)*r*.46,dz=Math.sin(a)*r*.46;
  m.tube([x+dx,y+side*3.4,z+dz],[x+dx,y+side*3.6,z+dz],.33,'silver',6);
 }
}
function fvBody(open){
 const m=new Mesh();
 m.plate(-1,0,5,23,10,5,'dark','metal');
 plates(m,[[-23,-10],[-16,-14],[11,-13],[26,-6],[26,6],[11,13],[-16,14],[-23,10]],9,4,'blue','metal');
 plates(m,[[-21,-9],[-16,-12],[9,-12],[26,-5],[26,5],[9,12],[-16,12],[-21,9]],13,1.4,'ivory','gold');
 // A glazed wedge cockpit, six exposed wheel hubs and shingled rain deflectors.
 m.loft([[8,5,1,15],[12,7,3,16],[18,6,2.3,15],[23,3,.5,14.8]],0,'glass',8);
 m.beam([11,0,18.7],[23,0,15.4],.44,.38,'ivory','gold');
 for(const s of [-1,1]){
  for(const x of [-16,-1,15]) hub(m,x,s*11.4,5.4,5.6,s);
  for(const x of [-15,-1,13]){
   m.plate(x,s*11.6,10.1,5.9,3,2,'ivory','blue');
   m.plate(x-.6,s*12.4,12.2,3.6,1.25,.3,'team','gold');
  }
  m.beam([20,s*7,12],[25,s*5,10.2],1.2,.8,'dark','silver');lens(m,24,s*5.7,11,1,'optic');
  // Segmented clinker plating, access latches and a recessed cooling grille.
  for(const x of [-14,-4,6]){
   m.plate(x,s*8.8,14.35,4.3,2.05,.36,'ivory','metal');
   rivetRow(m,[x-3.1,s*9.95,14.75],[x+3.1,s*9.95,14.75],3);
   m.plate(x,s*7.7,14.74,1.12,.26,.21,'metal','dark');
  }
  m.plate(-15,s*4.2,14.5,4.1,1.95,.32,'dark','metal');
  for(let j=0;j<7;j++)m.plate(-18+j*.96,s*4.2,14.83,.2,1.45,.26,'silver','metal');
  // Each side carries a backed film magazine and a folding optical boom.
  const y=s*7.3;
  m.tube([-14,y,15],[-14,y,17],4.6,'dark',20);
  m.tube([-14,y,17],[-14,y,18.9],4.2,'gold',24);
  m.tube([-14,y,18.9],[-14,y,19.2],3.7,'blue',20);
  for(let k=0;k<5;k++){
   const a=k*2*Math.PI/5;
   m.tube([-14+2.25*Math.cos(a),y+2.25*Math.sin(a),19.2],[-14+2.25*Math.cos(a),y+2.25*Math.sin(a),19.4],.84,'dark',8);
  }
  const spread=11.4+open*5.6, lift=22+open*3;
  m.beam([-12,y,17],[-6,s*spread,lift],1.65,1.4,'ivory','metal');
  m.tube([-12,y+s*.9,16],[-6,s*(spread+.9),lift-1],.72,'gold',10);
  m.loft([[-10,2.4,2.1,lift],[-8,3.1,3.1,lift],[-2.6,3.4,3.2,lift]],s*spread,'blue',12);
  lens(m,-2.5,s*spread,lift,3.35,'optic');
  // Chamfered silver-glass shutter. The two sails make a V above the hull.
  const at=(u,v)=>[-12+u*9-v*3.4,s*(7.0+open*3.5+v*(6.2+open*2.2)),20+v*(9.0+open*3.0)];
  const corners=[[0,.1],[.84,0],[1,.7],[.88,1],[.08,1]];
  m.poly(corners.map(([u,v])=>at(u,v)),'glass');
  m.poly([[.12,.23],[.75,.17],[.9,.7],[.8,.88],[.2,.88]].map(([u,v])=>at(u,v).map((n,k)=>n+(k===2?.12:0))),'silver');
  m.poly([[.18,.27],[.72,.23],[.81,.65],[.73,.80],[.24,.8]].map(([u,v])=>at(u,v).map((n,k)=>n+(k===2?.23:0))),'glass');
  for(let j=0;j<corners.length;j++)m.beam(at(...corners[j]),at(...corners[(j+1)%corners.length]),.38,.31,'ivory','gold');
  m.beam(at(.22,.65),at(.77,.4),.15,.11,'optic','silver');
  for(const [u,v] of [[.12,.16],[.74,.14],[.82,.86],[.16,.87]]){
   const p=at(u,v);m.tube(p,[p[0],p[1],p[2]+.3],.26,'gold',8);
  }
  // An optical retaining ring, short engraved index lines and an off-axis glint.
  for(let j=0;j<12;j++){const a=j*Math.PI/6;
   m.tube([-1.96,s*spread+3.12*Math.cos(a),lift+3.12*Math.sin(a)],[-1.67,s*spread+3.12*Math.cos(a),lift+3.12*Math.sin(a)],.16,'silver',6);}
  m.tube([-.72,s*spread-.6,lift+.6],[-.58,s*spread-.6,lift+.6],.46,'ivory',12);
  m.tube(at(.18,.04),at(.76,.04),.85,'copper',12);
  for(const dx of [-8.5,-6.5])m.tube([dx,s*spread,lift],[dx+.45,s*spread,lift],3.15,'silver',16);
  for(let i=0;i<4;i++)m.plate(-18+i*1.45,s*3.2,14.6,.38,1.5,.4,'metal','dark');
 }
 // Stowage hatch, bonnet seams and twin windscreen wipers.
 for(const s of [-1,1]){
  m.beam([12,s*6.5,17.3],[18,s*2,17.3],.24,.25,'silver','metal');
  for(let j=0;j<7;j++){const x=-21+j*5;m.tube([x,s*10.6,14.9],[x,s*10.6,15.2],.36,"silver",8);}
  for(const x of [-20,-17,-14])m.plate(x,s*9.1,15.2,.65,1.1,.35,'metal','dark');
  m.beam([17,s*7.4,14.6],[24,s*4.9,13.9],.42,.39,'gold','ivory');
 }
 m.tube([1,0,14],[1,0,15.4],6,'metal',24);
 return m;
}
function fvHead(kind){
 const m=new Mesh();
 m.tube([0,0,0],[0,0,1.3],5.1,'dark',24);
 m.loft([[-5,3.4,1.8,3],[-2,4.6,2.7,3],[4,3.2,2,3]],0,'ivory',10);
 if(kind==='repair'){
  for(const s of [-1,1]){m.beam([0,s*2,3],[8,s*3,4],.8,.9,'gold','metal');lens(m,8,s*3,4,1.2,'optic');}
  m.tube([2,0,3],[9,0,3],1.3,'blue',12);
 }else if(kind==='rack'){
  for(const s of [-1,1]){m.loft([[-4,2.2,2,4.6],[5,2.3,2,4.6],[7,1.9,1.8,4.6]],s*3.15,'blue',8);
   for(const dz of [-.8,.8])for(const dy of [-.82,.82])m.tube([7,s*3.15+dy,4.6+dz],[7.3,s*3.15+dy,4.6+dz],.61,'dark',8);}
 }else{
  m.tube([2,0,4],[12,0,4],1.3,'metal',12);m.tube([10.7,0,4],[13.8,0,4],1.7,'dark',10);
  m.plate(-2,0,5,2.3,1.6,1,'team','gold');
 }
 return m;
}
function tracked(m,s){
 m.loft([[-29,1,1.4,5.8],[-26,4.1,5.2,5.8],[22,4.1,5.6,6],[28,2.6,2,6]],s*14,'rubber',12);
 for(const x of [-22,-13,-4,5,14,23])hub(m,x,s*15,6,3.8,s);
 for(let i=0;i<25;i++){
  const x=-24+i*2;m.plate(x,s*14,10.5,.78,4,.6,'metal','dark');
 }
 for(const x of [-20,-7,6,19]){
  m.plate(x,s*14,10.9,5.8,4.5,2.7,'oxide','metal');
  m.plate(x,s*15,13.6,4.5,2.7,.45,'ochre','copper');
  m.plate(x+1.8,s*15,14.1,1.1,2.6,.15,'dark','dark');
 }
}
function harvBody(pose){
 const loaded=[1,2,6,7].includes(pose), pressing=[2,5,7,8].includes(pose),kick=[3,6].includes(pose);
 const m=new Mesh();m.plate(0,0,5,26,13,5.8,'dark','metal');
 for(const s of [-1,1])tracked(m,s);
 // Deep open bucket. Sloped inner walls remain visible around the ore.
 m.plate(-8,0,10,16,10,1.4,'dark','oxide');
 for(const s of [-1,1]){
  m.quad([-25,s*11,11],[6,s*11,11],[7,s*14.4,19],[-27,s*14.4,19],'oxide');
  m.beam([-27,s*14.4,19],[7,s*14.4,19],.85,.8,'ochre','metal');
  for(const x of [-21,-11,-1])m.beam([x,s*11.5,12],[x+1,s*14.4,19],.75,.7,'metal','copper');
 }
 m.quad([-25,-11,11],[-25,11,11],[-27,14,19],[-27,-14,19],'oxide');
 if(loaded)for(const [x,y,h] of [[-19,-5,6],[-16,5,7],[-11,-2,7],[-7,6,5],[-4,-5,6],[0,2,4]]){
  m.tube([x,y,12],[x-.8,y+.3,12+h],4,'ore',5,1.6);m.tube([x-1,y+.8,12+h],[x-1.3,y+.9,13+h],1.6,'gold',4,.5);
 }
 // Offset driver's cab and slanted windscreen, separate from the crusher.
 m.plate(17,-5.6,10.5,8,5.8,5,'oxide','dark');
 m.loft([[8,4.6,1,17],[12,5.8,4.1,17.4],[18,5.4,4,17],[23,3.4,1.3,15]],-5.6,'glass',8);
 m.plate(14,-5.6,20.7,5.8,5.5,1.1,'ochre','metal');
 m.tube([23,-8,14],[24,-8,14],1.5,'lamp',12);
 for(const s of [-1,1]){
  // Two forked load-bearing uprights, diagonal webs and hydraulic rams.
  m.beam([7,s*13,13],[-1,s*12,30],1.9,1.8,'oxide','copper');
  m.beam([-12,s*13,14],[-1,s*12,30],1.5,1.4,'ochre','metal');
  m.tube([-9,s*13,15],[-6,s*12.5,22],1.3,'dark',12);
  m.tube([-6,s*12.5,22],[-1,s*12,29],.68,'silver',12);
 }
 m.beam([-1,-13,30],[-1,13,30],2.3,2.1,'oxide','ochre');
 const slid=kick?-4:0;
 m.beam([-3,0,29],[16+slid,0,26],2.4,1.9,'ochre','metal');
 // Vent slats with inset cooling gaps and the driver's divided safety glass.
 for(let j=0;j<7;j++)m.plate(10.2+j*1.15,-5.6,21.86,.19,3,.16,'metal','dark');
 for(const y of [-9,-5.7,-2.5])m.beam([19,y,19.9],[23.3,y,16],.26,.25,'ochre','metal');
 for(const side of [-1,1]){
  for(const x of [-22,-13,-4,5])m.tube([x,side*14.5,18.5],[x,side*14.85,18.5],.52,'silver',8);
  for(const j of [0,1,2])m.plate(-21+j*2.4,side*12.1,19.05,.7,1.0,.18,'ochre','dark');
 }
 const gap=pose>=7?2.95:pressing?1.7:4.1;
 for(const s of [-1,1]){
  m.beam([10+slid,s*3.1,26],[17+slid,s*gap,22],1.2,1.4,'metal','gold');
  m.beam([17+slid,s*gap,22],[21+slid,s*gap,20],1.55,1.05,'oxide','silver');
 }
 // Double-sided brass scale housing, enamel dial, indexed graduations and needle.
 for(const s of [-1,1]){
  const x=-1,y=12.6*s,z=28.5;
  m.tube([x,y,z],[x,y+1.3*s,z],4.45,'gold',24);
  m.tube([x,y+1.31*s,z],[x,y+1.51*s,z],3.67,'ivory',24);
  const face=y+1.6*s;
  for(let k=0;k<19;k++){
   const a=Math.PI*k/18,major=k%3===0,r=major?2.45:2.9;
   m.beam([x+r*Math.cos(a),face,z+r*Math.sin(a)],[x+3.29*Math.cos(a),face,z+3.29*Math.sin(a)],major?.13:.08,.14,'dark','dark');
  }
  // Enamel IX stamp in the lower half; the needle sits above the printing.
  for(const [a,b] of [[[-1.2,-.5],[-1.2,-1.6]],[[-.6,-.45],[.45,-1.6]],[[-.55,-1.6],[.5,-.45]]])
   m.beam([x+a[0],face,z+a[1]],[x+b[0],face,z+b[1]],.11,.10,'oxide','dark');
  const angle=loaded?.61:2.60;m.beam([x,face+.1*s,z],[x+2.8*Math.cos(angle),face+.1*s,z+2.8*Math.sin(angle)],.3,.16,'oxide','dark');
  m.plate(-20,s*15,14.6,2.6,2,.3,'team','gold');
 }
 // Overhead box-girder and ram: lattice sides frame the opening rather than filling the bin.
 for(const s of [-1,1]){
  m.beam([-2,s*3.1,30.5],[16+slid,s*3.1,27.7],.85,.7,'oxide','ochre');
  m.beam([-2,s*3.1,26.8],[16+slid,s*3.1,24],.75,.7,'oxide','metal');
  for(let j=0;j<4;j++){
   const x=-1+j*4,z=30-j*.62;
   m.beam([x,s*3.1,z],[x+3.7,s*3.1,z-3.4],.5,.45,'copper','ochre');
  }
  m.tube([-7,s*2,31],[5+slid*.5,s*2,30],1.5,'oxide',16);
  m.tube([5+slid*.5,s*2,30],[14+slid,s*2,28.9],.72,'silver',16);
  // Deep jaw cheeks with a segmented incandescent liner.
  m.plate(19.4+slid,s*(gap+1),20.5,4.6,1.6,3.3,'oxide','dark');
  for(let j=0;j<4;j++){
   m.plate(16.6+slid+j*1.8,s*(gap+1.15),23.8,.48,1.35,.25,'ochre','metal');
   m.tube([22.8+slid,s*(gap+.5+j*.42),21],[23.7+slid,s*(gap+.5+j*.42),21],.38,pressing?'lamp':'copper',8);
  }
  // Boarding rail and steps alongside the cab.
  for(const x of [10,17,23])m.beam([x,s*13,13],[x,s*13,17],.24,.27,'gold','metal');
  m.beam([10,s*13,17],[23,s*13,17],.32,.32,'ochre','gold');
 }
 for(const s of [-1,1]){
  const side=s*14.55;
  for(let j=0;j<4;j++){
   const x=-23+j*7.3;
   m.beam([x,side,18.9],[x+2.6,side,15.3],.34,.25,'metal','copper');
   m.tube([x,side,18.1],[x,side+s*.24,18.1],.38,'silver',8);
  }
  // Paired insulated hydraulic lines bend around each pivot.
  for(const dy of [0,.65]){
   const points=[[-8,s*(12+dy),14],[-6,s*(13+dy),16],[-4,s*(13+dy),20],[-1,s*(13+dy),25]];
   for(let j=1;j<points.length;j++)m.tube(points[j-1],points[j],.29,'rubber',8);
  }
  rivetRow(m,[16+slid,s*(gap+.6),24.15],[22.7+slid,s*(gap+.6),24.15],5,.27);
 }
 // Recessed grille, bumper guards and two towing eyes under the cab.
 m.plate(23,-4.8,13.0,2.35,3.8,1.2,'dark','metal');
 for(let j=0;j<6;j++)m.plate(23,-7.6+j*1.02,14.25,1.7,.19,.24,'silver','dark');
 for(const y of [-9,8])m.tube([24,y,8.8],[27,y,8.8],.8,'gold',10);
 m.plate(16+slid,0,25.4,4,4.7,1.65,'oxide','copper');
 for(let i=0;i<4;i++)m.plate(14.3+slid+i*1.05,0,27.1,.27,3.5,.22,pressing?'lamp':'copper','dark');
 m.tube([15,6.3,12],[15,6.3,14],4.5,'dark',20);
 return m;
}
function harvGun(){
 const m=new Mesh();m.tube([0,0,0],[0,0,2],4,'metal',20);
 m.plate(-.2,0,2,4.6,3.2,3,'oxide','dark');
 m.tube([2,0,4],[13,0,4],1.25,'metal',12);
 for(let i=0;i<5;i++)m.tube([4+i*1.4,0,4],[4.55+i*1.4,0,4],1.75,'copper',12);
 m.tube([13,0,4],[15,0,4],1.5,'dark',12);m.tube([15,0,4],[15.2,0,4],.58,'lamp',8);
 return m;
}
const models={
 FV:{stem:'yinpian_rain',poses:['cruise','projection','rack','gun','repair','half_open'],make:i=>i===5?fvBody(.5):i<2?fvBody(i):fvHead(['rack','gun','repair'][i-2]),mount:[1,0,15.3],tips:[7,14,9]},
 HARV:{stem:'laocheng_weighbridge',poses:['empty','laden','press','recoil','gun','cold_press','laden_recoil','half_press','cold_half_press'],make:i=>i===4?harvGun():harvBody(i),mount:[15,6.3,14],tips:[15]}
};
for(const [id,model] of Object.entries(models)){
 if(process.argv[2] && process.argv[2]!==id)continue;
 const {stem,poses,make,mount,tips}=model,tile=512,origin=[64,77],scale=1.45;
 const frames=[],bounds=[],atlasWidth=4096,gutter=8;
 let x=gutter,y=gutter,rowHeight=0;
 for(let pose=0;pose<poses.length;pose++){
  const mesh=make(pose);smoothCorners(mesh);
  for(let frame=0;frame<32;frame++){
   const sample=render(mesh,frame,tile,palette,origin,scale,finish);
   const [left,top,w,h]=sample.bounds;
   if(x+w+gutter>atlasWidth){x=gutter;y+=rowHeight+2*gutter;rowHeight=0;}
   const crop=new Uint8Array(w*h*4);
   for(let j=0;j<h;j++)crop.set(sample.rgba.subarray(((j+top)*tile+left)*4,((j+top)*tile+left+w)*4),j*w*4);
   frames.push({crop,rect:[x,y,w,h]});
   bounds.push(sample.bounds.map(v=>v*128/tile));
   x+=w+2*gutter;rowHeight=Math.max(rowHeight,h);
  }
 }
 const height=Math.ceil((y+rowHeight+gutter)/4)*4;
 if(height>8192)throw Error('Atlas exceeds the target texture size');
 const atlas=new Uint8Array(atlasWidth*height*4);
 for(const {crop,rect:[left,top,w,h]} of frames)
  for(let j=0;j<h;j++)atlas.set(crop.subarray(j*w*4,(j+1)*w*4),((top+j)*atlasWidth+left)*4);
 fs.writeFileSync(folder+'/'+stem+'.png',encodePng(atlasWidth,height,atlas));
 console.log(id,frames.length,'frames',atlasWidth,'x',height);

 const coord=(p,f)=>{const v=project(p,f,origin,scale);return [v.x-origin[0],v.y-origin[1]];};
 const packed={tile,poses,origin,frames:frames.map(f=>f.rect),bounds,mounts:Array.from({length:32},(_,f)=>coord(mount,f)),
  muzzles:tips.map(x=>Array.from({length:32},(_,f)=>coord([x,0,4],f)))};
 fs.writeFileSync(folder+'/'+stem+'.json',JSON.stringify(packed)+'\n');
}
