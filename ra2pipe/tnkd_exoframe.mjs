import {bakePanels,savePanels} from './tnkd_neon_panels.mjs';
import fs from 'node:fs';
import {YrSource} from './lib/yr_source.mjs';
import {parseVxl,parseHva,poseVxl} from './vxl_lib.mjs';
import {renderSurface} from './voxel_surface.mjs';
import {encodePng} from './art_lib.mjs';

// Run with the local Yuri game directory. Each fitting is authored once, in
// model pixels relative to a pin. The fixed gun and casemate share DUMMY01.
const source=new YrSource(process.argv[2]);
const hull=poseVxl(parseVxl(source.read('TNKD.VXL').data),parseHva(source.read('TNKD.HVA').data),0);
const project=new URL('../iron_tide/',import.meta.url);
const art=JSON.parse(fs.readFileSync(new URL('assets/ra2/unitweapon/TNKD.json',project)));
const pins=[
  {part:'panel',section:'DUMMY01',at:[-2,-14.8,9.0],yaw:180},
  {part:'panel',section:'DUMMY01',at:[-2,15.0,9.0],yaw:0},
  {part:'turbine',section:'DUMMY01',at:[-20.0,0,13.5],yaw:0},
  {part:'optics',section:'DUMMY01',at:[-8.0,0.0,21.0],yaw:0},
  {part:'cannon',section:'DUMMY01',at:art.muzzle_model_point,yaw:0},
];
const colors=['37424b','637782','a8b5b6','cc9655','58e2df','1c3039','e2c89b'];
const pal=new Uint8Array(1024);
colors.forEach((s,i)=>pal.set([...Buffer.from(s,'hex'),255],4*i));
const normals=[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[0,0.7,0.7]];
function partVoxel(part,x,y,z){
  if(part==='turbine'){
    const r=Math.hypot(y,z);
    if(x>=-6.0 && x<4.0 && r<6.6){
      if(r>5.4)return x< -4.6 || x>1.8?2:1;
      if(x>=-3.6){
        if(r<1.7)return 3;
        const blade=Math.cos(8*Math.atan2(z,y)+r*0.48);
        return blade>0.05 && x> -3.4?2:5;
      }
    }
  }else{
    const ay=Math.abs(y);
    if(ay<5.0 && Math.abs(x)<3.2 && z>=-1.5 && z<3.4)return z<2.4?0:3;
    if(ay<8.8 && Math.hypot(x,z-4.3)<1.8)return ay>6.8?3:1;
    if(ay>=6.1 && ay<=9.4 && Math.abs(x)<3.9 && Math.abs(z-4.4)<2.15){
      if(x>2.9 && Math.abs(z-4.4)<1.25 && ay>6.6 && ay<8.9)return 4;
      return z>5.7?2:(x>2.6?5:1);
    }
  }
  return -1;
}
function pinnedLimb(pin){
  const parent=hull.limbs.find(l=>l.name===pin.section);
  if(!parent)throw Error('Missing VXL section '+pin.section);
  const a=pin.yaw*Math.PI/180,c=Math.cos(a),s=Math.sin(a);
  const matrix=[];
  for(const row of [0,4,8]){
    const [x,y,z,t]=parent.matrix.slice(row,row+4);
    matrix.push(x*c+y*s,-x*s+y*c,z,t+x*pin.at[0]+y*pin.at[1]+z*pin.at[2]);
  }
  if(pin.part==='panel'||pin.part==='cannon')return {matrix}; // HD folded metal and glass are rendered together.
  const min=[-20,-10,-8],size=[80,40,32],voxels=[];
  for(let iz=0;iz<size[2];iz++)for(let iy=0;iy<size[1];iy++)for(let ix=0;ix<size[0];ix++){
    const x=min[0]+(ix+.5)*.5,y=min[1]+(iy+.5)*.5,z=min[2]+(iz+.5)*.5;
    const colorIndex=partVoxel(pin.part,x,y,z);
    if(colorIndex<0)continue;
    const normalIndex=partVoxel(pin.part,x,y,z+.5)<0?4:(partVoxel(pin.part,x+.5,y,z)<0?0:(y>0?2:3));
    voxels.push({x:ix,y:iy,z:iz,colorIndex,normalIndex});
  }
  return {matrix,normals,voxels,sizeX:size[0],sizeY:size[1],sizeZ:size[2],minBounds:min,maxBounds:min.map((n,i)=>n+size[i]*.5)};
}
const limbs=pins.map(pinnedLimb);
const w=(art.facings*(art.frameW+2)+2)*2,h=(art.frameH+4)*2;
const rgba=new Uint8Array(w*h*4);
let hiddenTotal=0;
for(let i=0;i<art.facings;i++){
  const opts={pal,facing:i,facings:art.facings,keepDepth:true};
  const host=renderSurface(hull,opts), kit=renderSurface({limbs:limbs.filter(l=>l.voxels)},opts);
  bakePanels(i,host,kit,limbs);
  const x0=2*(kit.minX-host.minX),y0=2*(kit.minY-host.minY);
  const [ox,oy]=art.origins[i];
  let visible=0,hidden=0;
  for(let y=0;y<kit.height*2;y++)for(let x=0;x<kit.width*2;x++){
    const k=y*kit.width*2+x;
    if(!kit.detailRgba[k*4+3])continue;
    const hx=x+x0,hy=y+y0;
    if(hx>=0 && hx<host.width*2 && hy>=0 && hy<host.height*2 && host.depth[hy*host.width*2+hx]>kit.depth[k]){hidden++;continue;}
    const px=x+2*(ox+kit.minX-1),py=y+2*(oy+kit.minY-1);
    if(px<0||px>=2*art.frameW||py<0||py>=2*art.frameH)throw Error('Clipped fitting at facing '+i);
    const dst=((py+4)*w+px+4+2*i*(art.frameW+2))*4;
    rgba.set(kit.detailRgba.subarray(k*4,k*4+4),dst);
    visible++;
  }
  if(!visible)throw Error('No visible fittings at facing '+i);
  hiddenTotal+=hidden;
}
if(!hiddenTotal)throw Error('Missing hull occlusion');
fs.writeFileSync(new URL('assets/cosmetics/skins/tnkd_casemate.png',project),encodePng(w,h,rgba));
savePanels(project);
console.log('Facings:',art.facings,'host-occluded samples:',hiddenTotal);
