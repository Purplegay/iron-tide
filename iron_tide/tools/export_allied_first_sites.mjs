// Run after the retail ALL01 audit. Only missing NEWURBAN building sprites are materialized.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed,frameToRgba,encodePng} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const [source,game,out]=process.argv.slice(2);
const ini=file=>parseIni(fs.readFileSync(path.join(source,file),'latin1'));
const map=ini('all01umd.map.map'),rules=ini('rulesmd.ini'),art=ini('artmd.ini');
const hash=createHash('sha256').update(fs.readFileSync(path.join(source,'all01umd.map.map'))).digest('hex');
if(hash!=='dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0')throw Error('Wrong ALL01');
const section=(doc,id)=>Object.fromEntries(doc.get(id.toLowerCase())?.keys??[]);
const types={}, theater=theaterReader(new YrSource(game),'NEWURBAN');
const neutralTypes=new Set([...map.get('structures').keys.values()].map(line=>line.split(',')).filter(r=>r[0]==='Neutral').map(r=>r[1]));
const palette=decodePal(theater.palette().data);
for(let i=16;i<32;i++){let shade=palette[i*4]/252;[87,168,255].forEach((v,j)=>palette[i*4+j]=Math.round(v*shade));}
for(const line of map.get('structures').keys.values()){
 const [,id]=line.split(',');if(types[id])continue;
 const r={...section(rules,id),...section(map,id)}, image=r.image||id;
 const a=section(art,image);
 const v={foundation:(a.foundation||'1x1').toLowerCase(),hp:Number(r.strength)||0,slots:/^(true|yes)$/i.test(r.canbeoccupied)?Number(r.maxnumberoccupants)||0:0,capturable:/^(true|yes)$/i.test(r.capturable),neutral:neutralTypes.has(id),armor:r.armor||'wood',sight:Number(r.sight)||0};
 if((v.neutral || id==='CALAB') && !fs.existsSync('assets/ra2/shp/'+id+'.png')){
  if(fs.existsSync('assets/ra2/hollywood/city/'+id+'.png'))v.hollywood_art=true;
  else{
   const hit=theater.shape(image)||theater.read(image+'.shp');if(!hit)throw Error('Missing NEWURBAN '+image);
   const shp=decodeShp(hit.data), cols=Math.min(8,shp.frames.length), atlas=montageIndexed(shp,cols);
   v.art_id='ALL01_'+id;
   const base='assets/ra2/shp/'+v.art_id;
   fs.writeFileSync(base+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,palette));
   fs.writeFileSync(base+'.json',JSON.stringify({id:v.art_id,image,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:Math.min(2,shp.frames.length/2),shadow:true})+'\n');
  }
 }
 types[id]=v;
}
const layout=JSON.parse(fs.readFileSync('data/maps/yr_all01umd.json'));
if(layout.sha256!==hash)throw Error('Wrong layout');
const cells=new Set(layout.cells.map(([u,v])=>u+','+v));
const [x0,y0]=layout.retail_origin;
const paletteIso=decodePal(new YrSource(game).read('isoubn.pal').data);
const props=[],textures={};
let outside=0;
for(const [packed,id] of map.get('terrain').keys){
 const u=y0-Math.floor(Number(packed)/1000),v=Number(packed)%1000-x0;
 if(!cells.has(u+','+v)){outside++;continue;}
 props.push([id,u+.5,v+.5]);
 if(id.startsWith('TIBTRE') || textures[id])continue;
 const hit=theater.read(id+'.ubn')||theater.read(id+'.shp');
 if(!hit)throw Error('Missing NEWURBAN terrain '+id);
 const f=decodeShp(hit.data).frames[0];
 const png=Buffer.from(encodePng(f.w,f.h,frameToRgba(f,paletteIso,{originX:-f.x,originY:-f.y})));
 const shared='assets/ra2/time_shift/terrain/'+id+'.png';
 let file=shared;
 if(!fs.existsSync(shared) || !png.equals(fs.readFileSync(shared))){
  const dir='assets/maps/yr/allied_first';
  fs.mkdirSync(dir,{recursive:true});
  file=dir+'/'+id+'.png';
  fs.writeFileSync(file,png);
 }
 textures[id]='res://'+file;
}
fs.writeFileSync(out,JSON.stringify({hash,types,props,textures,outside},null,1)+'\n');