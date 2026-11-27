// ALL01 retail Smudge overlay, kept separate because trigger action 118 removes it.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {decodeShp,decodePal,encodePng} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const [dir,game,output]=process.argv.slice(2);
const raw=fs.readFileSync(path.join(dir,'all01umd.map.map'));
const layout=JSON.parse(fs.readFileSync('data/maps/yr_all01umd.json'));
if(createHash('sha256').update(raw).digest('hex')!==layout.sha256) throw Error('Unexpected ALL01 map');
const map=parseIni(raw.toString('latin1'));
const src=new YrSource(game),theater=theaterReader(src,'NEWURBAN');
const pal=decodePal(src.read('isoubn.pal').data);
const cell=24,width=layout.side*cell, pixels=Buffer.alloc(width*width*4);
const tiles=new Map(layout.cells.map(([u,v,,z])=>[u+','+v,z]));
const cache=new Map(),lighting=Object.fromEntries(map.get('lighting').keys);
let drawn=0;
for(const entry of map.get('smudge').keys.values()){
  const [type,x,y,frame]=entry.split(',');
  const u=layout.retail_origin[1]-Number(y),v=Number(x)-layout.retail_origin[0];
  if(!tiles.has(u+','+v)) continue;
  if(!cache.has(type)){
    const shp=theater.read(type+'.ubn')??theater.read(type+'.shp')??src.read(type+'.shp');
    if(!shp) throw Error('Missing NEWURBAN smudge '+type);
    cache.set(type,decodeShp(shp.data));
  }
  const shp=cache.get(type),f=shp.frames[Number(frame)];
  if(!f) throw Error('Invalid smudge frame '+entry);
  for(let dy=-2*cell;dy<2*cell;dy++) for(let dx=-2*cell;dx<2*cell;dx++){
    const sx=Math.floor(shp.width/2+30*(dx+dy+1)/cell)-f.x;
    const sy=Math.floor(shp.height/2+15+15*(dy-dx)/cell)-f.y;
    if(sx<0||sy<0||sx>=f.w||sy>=f.h) continue;
    const col=f.data[sy*f.w+sx]; if(!col) continue;
    const px=(u+.5)*cell+dx,py=(v+.5)*cell+dy;
    if(px<0||py<0||px>=width||py>=width) continue;
    const z=tiles.get(Math.floor(px/cell)+','+Math.floor(py/cell))??0;
    const light=Number(lighting.ambient)+Number(lighting.ground)+(z-1)*Number(lighting.level);
    const offset=(py*width+px)*4;
    for(const [i,key] of ['red','green','blue'].entries()) pixels[offset+i]=Math.min(255,Math.round(pal[col*4+i]*Number(lighting[key])*light));
    pixels[offset+3]=255;
  }
  drawn++;
}
fs.writeFileSync(output,encodePng(width,width,pixels));console.log('ALL01 smudges',drawn,'shapes',cache.size);
