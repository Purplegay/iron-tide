import fs from 'node:fs';
import {parseVxl,parseHva,poseVxl,loadNormals} from '../../ra2pipe/vxl_lib.mjs';
import {renderSurface,parseVpl} from '../../ra2pipe/voxel_surface.mjs';
import {encodePng} from '../../ra2pipe/art_lib.mjs';
import {getSec,parseIni} from '../../ra2pipe/lib/ini.mjs';

// All layers share the same projected model origin. Emitters are sampled from the
// transformed barrel itself, so the flash follows the HVA pose as well as the facing.
const facings=32, root='assets/ra2/';
const json=(name,value)=>fs.writeFileSync(root+name+'.json',JSON.stringify(value,null,1)+'\n');
function muzzle(limb){
 const dims=[limb.sizeX,limb.sizeY,limb.sizeZ];
 const points=limb.voxels.map(v=>{
  const p=['x','y','z'].map((axis,i)=>limb.minBounds[i]+(v[axis]+.5)*(limb.maxBounds[i]-limb.minBounds[i])/dims[i]);
  return [0,4,8].map(i=>limb.matrix[i]*p[0]+limb.matrix[i+1]*p[1]+limb.matrix[i+2]*p[2]+limb.matrix[i+3]);
 });
 const front=Math.max(...points.map(p=>p[0])),face=points.filter(p=>front-p[0]<.51);
 return [0,1,2].map(i=>face.reduce((n,p)=>n+p[i],0)/face.length);
}
function paint(name,frames,cw,ch,left,top,shadow){
 const width=facings*(cw+2)+2,height=frames.length/facings*(ch+2)+2;
 for(const scale of shadow?[1]:[1,2]){
  const pixels=new Uint8Array(width*height*4*scale*scale);
  frames.forEach((f,i)=>{
   const x=(2+i%facings*(cw+2)+Math.round(f.minX-left))*scale;
   const y=(2+Math.floor(i/facings)*(ch+2)+Math.round(f.minY-top))*scale;
   const data=scale===1?f.rgba:f.detailRgba,stride=f.width*scale*4;
   for(let j=0;j<f.height*scale;j++)pixels.set(data.subarray(j*stride,(j+1)*stride),((y+j)*width*scale+x)*4);
  });
  fs.writeFileSync(root+'vxl/'+name+(scale===2?'_detail':'')+'.png',encodePng(width*scale,height*scale,pixels));
 }
}
export function exportTurret(src,pal,id){
 loadNormals('../refs/ts-ra2/src/data/vxl/normals.ts');
 const building=id==='YAGGUN',lasher=id==='LTNK',miner=id==='SMIN';
 const turretName=lasher?'LTNK_tur':id+'_turret';
 const vpl=parseVpl(src.read('voxels.vpl').data);
 const model=name=>{
  const v=src.read(name+'.vxl'),h=src.read(name+'.hva');
  return {vxl:parseVxl(v.data),hva:parseHva(h.data),source:v.source};
 };
 const gun=model(building?id:id+'tur');
 const groups=[[turretName,[gun,...(lasher?[model(id+'barl')]:[])]]];
 if(!building)groups.push([id,[model(id)]]);
 const layers=[], tips=[];
 for(const [name,parts] of groups){
  const count=Math.max(...parts.map(p=>p.hva.frameCount));
  for(const shadow of building?[false]:[false,true]){
   const frames=[];
   for(let pose=0;pose<count;pose++){
    const limbs=parts.flatMap(p=>poseVxl(p.vxl,p.hva,pose).limbs);
    // Both Gatlings have two barrel sections. Pick the one on the positive
    // lateral side, matching the retail positive lateral weapon offset.
    if(name===turretName && !shadow && !miner)tips.push(muzzle(limbs[building||lasher?0:1]));
    for(let facing=0;facing<facings;facing++)frames.push(renderSurface({limbs},{facing,facings,pal,vpl,shadow,shadowGround:0,yrVoxelLight:!shadow}));
   }
   layers.push({name:name+(shadow?'_shd':''),frames,shadow,count,source:parts[0].source});
  }
 }
 const all=layers.flatMap(l=>l.frames),left=Math.min(...all.map(f=>f.minX)),top=Math.min(...all.map(f=>f.minY));
 const cw=Math.ceil(Math.max(...all.map(f=>f.minX+f.width))-left)+4;
 const ch=Math.ceil(Math.max(...all.map(f=>f.minY+f.height))-top)+4;
 for(const {name,frames,shadow,count,source} of layers){
  paint(name,frames,cw,ch,left,top,shadow);
  const meta={id:name,image:id,source,frameW:cw,frameH:ch,facings,facing_offset:16,poses:count,detail_scale:shadow?1:2,surface_render:'surface-vpl-2x',pose_source:'local VXL + HVA'};
  if(!building)meta.shadow_projection='ground-plane-v2';
  if(!shadow)meta.palette_lit=true;
  if(!shadow)meta.vxl=building||name===id?id+'.VXL':lasher?'LTNKtur+LTNKbarl.VXL':id+'tur.VXL';
  if(shadow||name!==id)meta.of=id;
  if(!building && name===id)Object.assign(meta,{turret:turretName,split_shadow:true});
  json('vxl/'+name,meta);
 }
 const origins=[],muzzles=[];
 for(const [i,f] of layers[0].frames.entries()){
  const origin=[Math.round(f.minX-left)+1-f.minX,Math.round(f.minY-top)+1-f.minY];
  origins.push(origin);
  if(miner)continue;
  const [x,y,z]=tips[Math.floor(i/facings)],a=Math.PI/4-i%facings*Math.PI*2/facings;
  muzzles.push([origin[0]-x*Math.sin(a)+y*Math.cos(a),origin[1]+.5*(x*Math.cos(a)+y*Math.sin(a))-z*Math.sqrt(3)/2]);
 }
 const rules=getSec(parseIni(src.read('rulesmd.ini').data.toString('latin1')),miner?'YAREFN':id).keys;
 if(miner){
  // The stationary refinery uses the very same SMINTUR atlas at its SHP socket.
  json('bldturret/YAREFN',{image:turretName,origins,offset:[+rules.get('turretanimx'),+rules.get('turretanimy')],facing_offset:16});
  return;
 }
 const descriptor={image:turretName,facings,origins,muzzles};
 if(building)Object.assign(descriptor,{offset:[+rules.get('turretanimx'),+rules.get('turretanimy')],facing_offset:16,
  stages:[1,2,3].map(i=>+rules.get('stage'+i)),rate_up:+rules.get('rateup'),rate_down:+rules.get('ratedown'),rot_units:+rules.get('rot')});
 json((building?'bldturret/':'unitweapon/')+id,descriptor);
}
