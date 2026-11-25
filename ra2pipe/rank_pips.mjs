// Extract original veteran/elite markers from the locally installed game.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { decodeShp, decodePal, encodePngIndexed } from './art_lib.mjs';
const [game, out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw new Error('Usage: <local YR> <new output folder>');
const source = new YrSource(game);
const shape = source.read('pips.shp'), palette = source.read('palette.pal');
if (!shape || !palette) throw new Error('Missing PIPS.SHP or PALETTE.PAL');
const shp = decodeShp(shape.data);
fs.mkdirSync(out, {recursive:true});
const metadata = {source:{name:'PIPS.SHP',archive:shape.source,sha256:sha256(shape.data)},palette:{name:'PALETTE.PAL',archive:palette.source,sha256:sha256(palette.data)},ranks:{}};
for (const [name,index] of [['veteran',14],['elite',15]]) {
  const f = shp.frames[index];
  if (!f || f.w < 1 || f.h < 1) throw new Error('Missing rank frame');
  const png = encodePngIndexed(f.w,f.h,f.data,decodePal(palette.data));
  fs.writeFileSync(path.join(out,name+'.png'),png);
  metadata.ranks[name]={frame:index,size:[f.w,f.h],offset:[f.x,f.y],png_sha256:sha256(png)};
}
fs.writeFileSync(path.join(out,'ranks.json'),JSON.stringify(metadata,null,2)+'\n');
console.log(JSON.stringify(metadata));
