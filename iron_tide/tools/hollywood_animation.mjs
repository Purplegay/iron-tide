// Run from iron_tide with the installed game directory as the argument.
import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {buildingAnimationRange,separateBuildingHealthRanges} from '../../ra2pipe/building_animation_ranges.mjs';
import {theaterReader} from './theater_shapes.mjs';

export function hollywoodShapeReader(source){
 return theaterReader(source,'NEWURBAN').shape;
}

export function exportAnimations(game, catalog, variants){
 const source=variants?.source ?? new YrSource(game), art=parseIni(source.read('artmd.ini').data.toString('latin1'));
 const readShape=variants?null:hollywoodShapeReader(source);
 const section=id=>Object.fromEntries(getSec(art,id)?.keys||[]);
 const palette=decodePal(source.read('unittem.pal').data);
 for(let i=16;i<32;i++){const shade=palette[i*4]/252;[87,168,255].forEach((c,k)=>palette[i*4+k]=Math.round(c*shade));}
 const save=(path,data)=>fs.writeFileSync(path,JSON.stringify(data,null,1)+'\n');
 const cache=new Map();
 function sheet(image,make){
  if(variants)return variants.sheet(image,make?'make':'layer');
  if(cache.has(image))return cache.get(image);
  const hit=readShape(image);
  if(!hit)throw Error('Missing '+image);
  const shp=decodeShp(hit.data),raw=shp.frames.length;
  if(make)shp.frames=shp.frames.slice(0,raw/2);
  const cols=Math.min(8,shp.frames.length), atlas=montageIndexed(shp,cols), dest='assets/ra2/shp/'+image;
  fs.writeFileSync(dest+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,palette));
  save(dest+'.json',{id:image,image,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:image==='NATBNKBB'?raw/2:1,shadow:!make,buildup:make,raw_count:raw});
  cache.set(image,raw);return raw;
 }
 function layer(ref){const a=section(ref),image=a.image||ref,raw=sheet(image,false),shadow=true;
  const frames=shadow?raw/2:raw;
  return {image,shadow,...buildingAnimationRange(image,a,frames),rate:Number(a.rate||300),loopCount:Number(a.loopcount??-1)};
 }
 for(const [id,b] of Object.entries(catalog.buildings)){
  if(b.faction!=='yuri')continue;
  const a=section(id);b.buildup=a.buildup;if(variants || b.buildup!=='NAPSISMK')sheet(b.buildup,true);
  const layers=[];
  if(id==='NATBNK')sheet(a.bibshape,false);
  for(const kind of ['underdooranim','underroofdooranim','idleanim','idleanimtwo','activeanim','activeanimtwo','productionanim','specialanim','specialanimtwo','specialanimthree','specialanimfour','deployinganim','roofdeployinganim']){
   if(!a[kind])continue;
   const l={kind,...layer(a[kind])};if(a[kind+'damaged'])l.dmg=layer(a[kind+'damaged']);
   if(id==='YAPOWR'){const half=l.frames/2;Object.assign(l,{loopStart:0,loopEnd:half-1});Object.assign(l.dmg,{loopStart:half,loopEnd:l.frames-1});}
   if(['YACNST_B','YAGRND_B'].includes(l.image) && ['productionanim','specialanim'].includes(kind)){const half=l.frames/2;Object.assign(l,{loopStart:0,loopEnd:half-1});Object.assign(l.dmg,{loopStart:half,loopEnd:l.frames-1});}
   if(id==='YAWEAP' && kind.includes('door') || id==='YAWEAP' && kind.includes('deploying')){l.dmg={...l,loopStart:1,loopEnd:1};}
   if(id==='NATBNK'&&l.dmg){for(const st of [l,l.dmg]){const start=Number(section(st===l?a[kind]:a[kind+'damaged']).start||0);st.loopStart=start;st.loopEnd=Math.min(st.frames-1,start+9);}}
   separateBuildingHealthRanges(l);layers.push(l);
  }
  if(id==='YAPOWR')layers.push(layers.shift());
  if(layers.length){
   if(variants)variants.layers[id]=layers;
   else save('assets/ra2/bldanim/'+id+'.json',{id,layers});
  }
 }
}
if(process.argv[1]?.endsWith('hollywood_animation.mjs')){const file='data/hollywood_yuri.json',catalog=JSON.parse(fs.readFileSync(file));exportAnimations(process.argv[2],catalog);fs.writeFileSync(file,JSON.stringify(catalog,null,1)+'\n');}
