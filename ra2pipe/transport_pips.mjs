import fs from 'node:fs';
import path from 'node:path';
import {YrSource, sha256} from './lib/yr_source.mjs';
import {decodeShp, decodePal, encodePngIndexed} from './art_lib.mjs';
const [game,out]=process.argv.slice(2);
if(!game || !out || fs.existsSync(out)) throw new Error('Usage: <local YR> <new output>');
const src=new YrSource(game), shp=src.read('pips2.shp'), pal=src.read('palette.pal');
if(!shp || !pal) throw new Error('Missing original pips/palette');
const frames=decodeShp(shp.data).frames, colors=decodePal(pal.data);
const meta={source:{name:'PIPS2.SHP',archive:shp.source,sha256:sha256(shp.data)},palette:{name:'PALETTE.PAL',archive:pal.source,sha256:sha256(pal.data)},reference:'https://github.com/OpenRA/ra2/blob/master/mods/ra2/sequences/misc.yaml',frames:{}};
fs.mkdirSync(out,{recursive:true});
for(const [name,index] of [['empty',0],['green',1],['yellow',2],['white',3],['red',4],['blue',5]]) {
 const f=frames[index]; if(!f || f.w<1 || f.h<1) throw new Error('Invalid frame');
 const png=encodePngIndexed(f.w,f.h,f.data,colors);fs.writeFileSync(path.join(out,name+'.png'),png);
 meta.frames[name]={index,size:[f.w,f.h],offset:[f.x,f.y],sha256:sha256(png)};
}
fs.writeFileSync(path.join(out,'source.json'),JSON.stringify(meta,null,2)+'\n');
console.log(JSON.stringify(meta.frames));
