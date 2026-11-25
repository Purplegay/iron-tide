import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {YrSource,sha256} from './lib/yr_source.mjs';import {decodePal,encodePng} from './art_lib.mjs';
import {parseVxl} from './vxl_lib.mjs';import {renderSurface,parseVpl} from './voxel_surface.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),project=path.join(root,'iron_tide');
const [game,output]=process.argv.slice(2),out=path.resolve(output||'');
if(!game||!output||out===root||out.startsWith(root+path.sep)||fs.existsSync(out))throw Error('Use YR directory and new external candidate');
const source=new YrSource(game),audit={inputs:{},files:[]},writes=[];
function read(name){const hit=source.read(name);if(!hit)throw Error('Missing '+name);audit.inputs[name]={source:hit.source,sha256:sha256(hit.data)};return hit.data;}
const pal=decodePal(read('unittem.pal')),vpl=parseVpl(read('voxels.vpl'));
for(let i=16;i<32;i++){const level=pal[i*4]/252;[87,168,255].forEach((v,k)=>pal[i*4+k]=Math.round(v*level));}
for(const [id,names] of [['GTGCAN',['GTGCANTUR','GTGCANBARL']],['NASAM',['SAM']]]){
 const descriptor=JSON.parse(fs.readFileSync(path.join(project,'assets/ra2/bldturret/'+id+'.json')));
 const meta=JSON.parse(fs.readFileSync(path.join(project,'assets/ra2/vxl/'+descriptor.image+'.json')));
 // Keep the established building turret pose/model-space origin; only its
 // rasterizer changes. Existing barrel timing and emitter positions are retained.
 const models=names.map(n=>parseVxl(read(n+'.vxl'))),cw=meta.frameW,ch=meta.frameH,fac=meta.facings;
 function bake(recoil){
  const steps=recoil?descriptor.recoil.steps:1,W=fac*(cw+2)+2,H=steps*(ch+2)+2;
  if(W*2>16384||H*2>16384)throw Error('Oversized defense detail');
  const native=new Uint8Array(W*H*4),detail=new Uint8Array(W*H*16);
  for(let pose=0;pose<steps;pose++){
   const distance=recoil?descriptor.recoil.travel*(pose+1)/steps:0;
   const model={limbs:models.flatMap((m,i)=>m.limbs.map(l=>{const matrix=[...l.matrix];if(i===1)matrix[3]-=distance;return {...l,matrix};}))};
   const origins=recoil?descriptor.recoil.poses[pose].origins:descriptor.origins;
   for(let facing=0;facing<fac;facing++){
    const im=renderSurface(model,{pal,vpl,facing,facings:fac});
    const x=Math.round(origins[facing][0]+im.minX-1),y=Math.round(origins[facing][1]+im.minY-1);
    if(x<0||y<0||x+im.width>cw||y+im.height>ch)throw Error(`${id}: surface exceeds existing pose canvas ${pose}/${facing} (${x},${y},${im.width},${im.height})`);
    const ox=2+facing*(cw+2)+x,oy=2+pose*(ch+2)+y;
    for(let row=0;row<im.height;row++)native.set(im.rgba.subarray(row*im.width*4,(row+1)*im.width*4),((oy+row)*W+ox)*4);
    for(let row=0;row<im.height*2;row++)detail.set(im.detailRgba.subarray(row*im.width*8,(row+1)*im.width*8),((oy*2+row)*W*2+ox*2)*4);
   }
  }
  const name=recoil?'bldturret/'+id+'_recoil':'vxl/'+descriptor.image;
  writes.push(['assets/ra2/'+name+'.png',encodePng(W,H,native)],['assets/ra2/'+name+'_detail.png',encodePng(W*2,H*2,detail)]);
 }
 bake(false);if(descriptor.recoil)bake(true);
 writes.push(['assets/ra2/vxl/'+descriptor.image+'.json',JSON.stringify({...meta,detail_scale:2,surface_render:'surface-vpl-2x'})]);
 if(descriptor.recoil){descriptor.recoil.detail_image=descriptor.recoil.image.replace('.png','_detail.png');descriptor.recoil.detail_scale=2;writes.push(['assets/ra2/bldturret/'+id+'.json',JSON.stringify(descriptor)]);}
 console.log(id+': surface body and all recoil directions complete');
}
for(const [name,bytes] of writes){const p=path.join(out,name);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes);audit.files.push({name,sha256:sha256(bytes)});}
fs.writeFileSync(path.join(out,'source-audit.json'),JSON.stringify(audit,null,2));
