import fs from 'node:fs';
import path from 'node:path';
import {YrSource,sha256} from './lib/yr_source.mjs';
import {decodeShp,decodePal,encodePngIndexed} from './art_lib.mjs';
const [game,out]=process.argv.slice(2);
if(!game || !out || fs.existsSync(out)) throw new Error('Usage: <local YR> <new output>');
const src=new YrSource(game), shape=src.read('wrench.shp'), pal=src.read('palette.pal');
if(!shape || !pal) throw new Error('Missing WRENCH.SHP/PALETTE.PAL');
const shp=decodeShp(shape.data), palette=decodePal(pal.data);
fs.mkdirSync(out,{recursive:true});
const meta={source:{name:'WRENCH.SHP',archive:shape.source,sha256:sha256(shape.data)},palette:{name:'PALETTE.PAL',archive:pal.source,sha256:sha256(pal.data)},frames:[]};
for(let i=0;i<shp.frames.length;i++) {
 const f=shp.frames[i];if(f.w<1 || f.h<1) throw new Error('Empty frame');
 const png=encodePngIndexed(f.w,f.h,f.data,palette);fs.writeFileSync(path.join(out,`${i}.png`),png);
 meta.frames.push({file:`${i}.png`,size:[f.w,f.h],offset:[f.x,f.y],sha256:sha256(png)});
}
fs.writeFileSync(path.join(out,'source.json'),JSON.stringify(meta,null,2)+'\n');
console.log(JSON.stringify(meta.frames));
