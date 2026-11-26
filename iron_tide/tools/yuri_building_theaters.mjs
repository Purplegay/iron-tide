// Run from iron_tide. Bake the mission's theater-sensitive SHPs, sharing identical variants.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {execFileSync} from 'node:child_process';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {theaterNames,theaterReader} from './theater_shapes.mjs';
import {exportAnimations} from './hollywood_animation.mjs';

const game=process.argv[2], source=new YrSource(game);
const catalog=JSON.parse(fs.readFileSync('data/hollywood_yuri.json'));
const buildings=Object.values(catalog.buildings).filter(b=>b.faction==='yuri');
const manifest={}, shared=new Map(), root='assets/ra2/shp';
const detailSheets=new Set();
for(const theater of theaterNames){
 const reader=theaterReader(source,theater), paletteFile=reader.palette();
 if(!paletteFile)throw Error('Missing unit palette for '+theater);
 const palette=decodePal(paletteFile.data), paletteHash=sha256(paletteFile.data);
 for(let i=16;i<32;i++){
  const level=palette[i*4]/252;
  [87,168,255].forEach((value,c)=>palette[i*4+c]=Math.round(value*level));
 }
 const sheets={}, layers={}, counts=new Map();
 function sheet(id,kind){
  if(counts.has(id))return counts.get(id);
  const hit=reader.shape(id);
  if(!hit)throw Error(theater+' is missing '+id);
  const digest=sha256(hit.data), key=[id,kind,digest,paletteHash].join('|');
  const raw=hit.data.readUInt16LE(6);
  if(!raw || raw%2)throw Error('Invalid visible/shadow frame counts for '+id);
  if(!shared.has(key)){
   const name='theaters/'+theater.toLowerCase()+'/'+id;
   const dest=path.join(root,name);
   const shape=decodeShp(hit.data);
   if(kind==='make')shape.frames=shape.frames.slice(0,raw/2);
   const count=shape.frames.length, cols=Math.min(8,count), atlas=montageIndexed(shape,cols);
   const meta={id,image:id,source:hit.source,source_sha256:digest,palette:paletteFile.source,
    cell:[shape.width,shape.height],cols,count,rects:atlas.rects,shadow:kind!=='make',
    buildup:kind==='make',raw_count:raw,dmg:id==='NATBNKBB'?raw/2:kind==='body'?Math.min(2,raw/2):1};
   fs.mkdirSync(path.dirname(dest),{recursive:true});
   fs.writeFileSync(dest+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,palette));
   fs.writeFileSync(dest+'.json',JSON.stringify(meta)+'\n');
   if(fs.existsSync('assets/ra2/detail/'+id+'.json'))detailSheets.add(name);
   shared.set(key,name);
  }
  counts.set(id,raw);sheets[id]=shared.get(key);
  return raw;
 }
 for(const building of buildings)sheet(building.id,'body');
 exportAnimations(game,catalog,{source,sheet,layers});
 sheet('YAREFN','body');
 sheet('YAREFNMK','make');
 const frames=sheet('YAREFN_A','layer')/2;
 const refinery=JSON.parse(fs.readFileSync('assets/ra2/bldanim/YAREFN.json'));
 layers.YAREFN=refinery.layers.map(layer=>({...layer,frames,loopEnd:Math.min(layer.loopEnd,frames-1)}));
 manifest[theater]={sheets,layers};
 console.log(theater+': '+counts.size+' sheets');
}
if(detailSheets.size){
 const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'irontide-theater-detail-'));
 const out=path.join(scratch,'candidate');
 try{
  execFileSync(process.execPath,['../ra2pipe/shp_details.mjs',out,...detailSheets],{stdio:'inherit'});
  fs.cpSync(path.join(out,'assets/ra2/detail/theaters'),'assets/ra2/detail/theaters',{recursive:true});
 }finally{fs.rmSync(scratch,{recursive:true,force:true});}
}
fs.writeFileSync(root+'/theaters/index.json',JSON.stringify(manifest,null,1)+'\n');
console.log('Distinct atlases: '+shared.size);
