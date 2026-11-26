import fs from 'node:fs';
import {renderSurface} from '../../ra2pipe/voxel_surface.mjs';
import {parseVxl,parseHva,poseVxl} from '../../ra2pipe/vxl_lib.mjs';
import {encodePng} from '../../ra2pipe/art_lib.mjs';
const save=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,1)+'\n');
export function writeVoxelUnit(id, image, source, vpl, voxelPalette) {
 const turret = source.read(image+'tur.vxl');
 const parts = [[id,image,source.read(image+'.vxl')]];
 if (turret) parts.push([id+'_turret',image+'tur',turret]);
 const facings = 32;
 const layers = parts.map(([name, stem, hit]) => {
  const model = poseVxl(parseVxl(hit.data),parseHva(source.read(stem+'.hva').data),0);
  const frames = Array.from({length:facings}, (_,facing) => renderSurface(model,{facing,facings,pal:voxelPalette,vpl,yrVoxelLight:true}));
  return {name,frames};
 });
 const all = layers.flatMap(layer => layer.frames);
 const left = Math.min(...all.map(f => f.minX)), top = Math.min(...all.map(f => f.minY));
 const frameW = Math.ceil(Math.max(...all.map(f => f.minX+f.width))-left)+4;
 const frameH = Math.ceil(Math.max(...all.map(f => f.minY+f.height))-top)+4;
 for (const {name,frames} of layers) {
  const base = 'assets/ra2/vxl/'+name;
  for (const scale of [1,2]) {
   const width = (facings*(frameW+2)+2)*scale, height = (frameH+4)*scale;
   const pixels = new Uint8Array(width*height*4);
   frames.forEach((f,i) => {
    const x = (2+i*(frameW+2)+Math.round(f.minX-left))*scale;
    const y = (2+Math.round(f.minY-top))*scale;
    const data = scale===2 ? f.detailRgba : f.rgba;
    const stride = f.width*scale*4;
    for(let row=0; row<f.height*scale; row++) pixels.set(data.subarray(row*stride,(row+1)*stride),((y+row)*width+x)*4);
   });
   fs.writeFileSync(base+(scale===2?'_detail':'')+'.png',encodePng(width,height,pixels));
  }
  save(base+'.json',{frameW,frameH,facings,turret:name===id && turret?id+'_turret':'',facing_offset:16,detail_scale:2,palette_lit:true,surface_render:'surface-vpl-2x'});
 }
}
