// Reconstruct the two hero platforms' muzzle sockets from the same posed
// VXL/HVA surface canvas as their shipped body/turret sprites. No art rewrite.
import fs from 'node:fs';
import {YrSource,sha256} from './lib/yr_source.mjs';
import {parseVxl,parseHva,poseVxl} from './vxl_lib.mjs';
import {renderSurface} from './voxel_surface.mjs';
import {decodePal} from './art_lib.mjs';
import {detailGrizzly} from './grizzly_detail.mjs';
const source=new YrSource(process.argv[2]),root=new URL('../iron_tide/assets/ra2/',import.meta.url);
const pal=decodePal(source.read('unittem.pal').data);
for(const [id,name] of [['MTNK','GTNK'],['HTNK','HTNK']]){
 const inputs={};
 function read(part,detail){const v=source.read(part+'.vxl'),h=source.read(part+'.hva');inputs[part]={vxl:sha256(v.data),hva:sha256(h.data)};const m=parseVxl(v.data);if(id==='MTNK'&&detail)m.limbs=m.limbs.map(l=>detailGrizzly(l,detail));return poseVxl(m,parseHva(h.data),0);}
 const body=read(name,'hull'),turret=read(name+'tur','turret'),barrel=read(name+'barl','barrel');
 const models=[body,{limbs:[...turret.limbs,...barrel.limbs]}];
 const frames=models.map(m=>Array.from({length:32},(_,facing)=>renderSurface(m,{pal,facing,facings:32})));
 const shadows=models.flatMap(m=>Array.from({length:32},(_,facing)=>renderSurface(m,{pal,facing,facings:32,shadow:true,shadowGround:0})));
 const all=[...frames.flat(),...shadows],minX=Math.min(...all.map(f=>f.minX)),minY=Math.min(...all.map(f=>f.minY));
 const frameW=Math.ceil(Math.max(...all.map(f=>f.minX+f.width))-minX)+4,frameH=Math.ceil(Math.max(...all.map(f=>f.minY+f.height))-minY)+4;
 const art=JSON.parse(fs.readFileSync(new URL('vxl/'+id+'.json',root)));
 if(art.frameW!==frameW||art.frameH!==frameH||art.facings!==32)throw Error(id+': shipped canvas differs; refusing misaligned sockets');
 const points=barrel.limbs.flatMap(l=>l.voxels.map(v=>{
  const p=['x','y','z'].map((axis,k)=>l.minBounds[k]+(v[axis]+.5)*(l.maxBounds[k]-l.minBounds[k])/[l.sizeX,l.sizeY,l.sizeZ][k]);
  return [0,4,8].map(r=>l.matrix[r]*p[0]+l.matrix[r+1]*p[1]+l.matrix[r+2]*p[2]+l.matrix[r+3]);
 }));
 const front=Math.max(...points.map(p=>p[0])),face=points.filter(p=>Math.abs(p[0]-front)<.001);
 const point=[0,1,2].map(k=>face.reduce((sum,p)=>sum+p[k],0)/face.length);
 const origins=frames[1].map(f=>[Math.round(f.minX-minX)+1-f.minX,Math.round(f.minY-minY)+1-f.minY]);
 const muzzles=origins.map((o,i)=>{const a=Math.PI/4-i*Math.PI/16;return [o[0]-point[0]*Math.sin(a)+point[1]*Math.cos(a),o[1]+.5*(point[0]*Math.cos(a)+point[1]*Math.sin(a))-point[2]*Math.sqrt(.75)];});
 const path=new URL('unitweapon/'+id+'.json',root),old=fs.existsSync(path)?JSON.parse(fs.readFileSync(path)):{};
 const delta=old.muzzles?Math.max(...muzzles.map((p,i)=>Math.hypot(p[0]-old.muzzles[i][0],p[1]-old.muzzles[i][1]))):null;
 fs.writeFileSync(path,JSON.stringify({...old,id,image:id+'_tur',frameW,frameH,facings:32,facing_axis:'model +X',emitter_face:'front +X',muzzle_model_point:point,muzzle_source:source.read(name+'barl.vxl').source+'/'+name+'barl.VXL',origins,muzzles,source_inputs:inputs},null,2)+'\n');
 console.log(JSON.stringify({id,frameW,frameH,point,origin:origins[0],previous_max_displacement:delta}));
}
