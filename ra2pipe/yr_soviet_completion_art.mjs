import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, encodePng, frameToRgba, montageIndexed, encodePngIndexed } from './art_lib.mjs';

import { buildingAnimationRange, separateBuildingHealthRanges } from './building_animation_ranges.mjs';
const [game, out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw new Error('Expected local YR directory and a new asset output directory');
const src = new YrSource(game);
const rules = parseIni(src.read('rulesmd.ini').data.toString('latin1'));
const art = parseIni(src.read('artmd.ini').data.toString('latin1'));
function save(name, content) {
  const file = path.join(out, name);
  fs.mkdirSync(path.dirname(file), {recursive:true});
  fs.writeFileSync(file, content);
}
const cameos = decodePal(src.read('cameo.pal').data);
for (const id of ['NANRCT','NAINDP','NAIRON','NAMISL','IVAN','CIVAN','TERROR','DESO','BORIS','TTNK','DTRUCK','SAPC','SQD','DRED']) {
  const image = getSec(rules,id).keys.get('image') || id;
  const name = getSec(art,image).keys.get('cameo').toUpperCase();
  const frame = decodeShp(src.read(name + '.shp').data).frames[0];
  save('cameo/' + name + '.png', encodePng(frame.w, frame.h, frameToRgba(frame,cameos,{canvasW:frame.w,canvasH:frame.h})));
}

const palette = decodePal(src.read('unittem.pal').data);
for (let i=16; i<32; i++) {
  const shade = palette[i*4]/252;
  for(const [c,value] of [87,168,255].entries()) palette[i*4+c]=Math.round(shade*value);
}
const counts = new Map();
// NAMISL is a permanent apron. Some super frames repeat the apron and
// its shadow while others omit it. Combine indexed pixels before scaling.
function completeSiloFrames(shp, apron) {
  if (shp.width !== apron.width || shp.height !== apron.height || apron.frames.length !== 6 || shp.frames.length % 4)
    throw Error('Unexpected silo SHP layout');
  const quarter = shp.frames.length / 4;
  shp.frames = shp.frames.map((overlay, i) => {
    const shadow = i >= quarter * 2;
    const damaged = Math.floor(i / quarter) % 2;
    const data = new Uint8Array(shp.width * shp.height);
    for (const f of [apron.frames[(shadow ? 3 : 0) + damaged], overlay]) {
      for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) {
        const index = f.data[y * f.w + x];
        if (index) data[(f.y + y) * shp.width + f.x + x] = index;
      }
    }
    return {x:0,y:0,w:shp.width,h:shp.height,data};
  });
}
function shape(id, name, category) {
  if (counts.has(id)) return counts.get(id);
  const original = src.read(name + '.shp') || (['anim', 'buildup'].includes(category) && src.read(name[0]+'U'+name.slice(2)+'.shp'));
  if (!original) throw Error('Missing SHP '+name);
  const shp = decodeShp(original.data);
  if (/^NAMISL_[EFGH]$/.test(id)) completeSiloFrames(shp, decodeShp(src.read('namisl.shp').data));
  const rawCount = shp.frames.length;
  const buildup = category === 'buildup';
  if (buildup) {
    // Native make sprites append a matching strip of index-1 shadow masks.
    const half = rawCount / 2;
    if (!Number.isInteger(half) || shp.frames.slice(half).some(frame => frame.data.some(pixel => pixel > 1)))
      throw Error('Unexpected buildup shadow layout: ' + name);
    shp.frames = shp.frames.slice(0, half);
  }
  const count = shp.frames.length, cols = Math.min(category === 'building' ? 8 : 16, count);
  const sheet=montageIndexed(shp,cols);
  save('shp/'+id+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
  save('shp/'+id+'.json',JSON.stringify({id,image:name,source:original.source,source_sha256:sha256(original.data),palette:'UNITTEM.PAL',cell:[shp.width,shp.height],cols,count,rects:sheet.rects,dmg:category==='building'?Math.min(3,Math.floor(count/2)):1,shadow:category==='building'||category==='anim',...(buildup ? {buildup:true, raw_count:rawCount} : {})})+'\n');
  counts.set(id,count);
  return count;
}
const allArt=src.read('artmd.ini').data.toString('latin1');
for (const id of ['BORIS','IVAN','CIVAN','TERROR','DESO','SQD']) {
  const image=getSec(rules,id).keys.get('image')||id, definition=getSec(art,image).keys;
  shape(id,image,'unit');
  const name=definition.get('sequence');
  let seq={};
  if(name){
    const section=allArt.match(new RegExp('^\\['+name+'\\][^\\n]*\\n([\\s\\S]*?)(?=^\\[)','mi'))[1];
    for(const line of section.split(/\r?\n/)){
      const m=line.match(/^([A-Za-z0-9]+)\s*=\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
      if(m)seq[m[1]]={start:Number(m[2]),per:Number(m[3]),facings:Number(m[4])?8:1,stride:Number(m[4])};
    }
  } else if (id==='SQD'){
    const walk=Number(definition.get('walkframes')),fire=Number(definition.get('firingframes'));
    seq={Guard:{start:0,per:1,facings:8,stride:walk},Walk:{start:0,per:walk,facings:8},FireUp:{start:8*walk,per:fire,facings:8}};
  }
  save('shp/'+id+'.seq.json',JSON.stringify({image,source:name||image,seq})+'\n');
}
for(const id of ['NAINDP','NANRCT','NAIRON','NAMISL']){
  const def=getSec(art,id).keys;
  shape(id,id,'building');shape(def.get('buildup'),def.get('buildup'),'buildup');
  const layers=[];
  for(const key of def.keys()){
    if(!/^(?:(?:active|idle|production|super)anim)(?:two|three|four)?$/.test(key))continue;
    function layer(name){
      const a=getSec(art,name).keys,image=a.get('image')||name;
      const count=shape(image,image,'anim');
      const shadow=a.get('shadow')?.toLowerCase()!=='no';
      const range=buildingAnimationRange(image,Object.fromEntries(a),Math.max(1, Math.floor(count/(shadow?2:1))));
      return {image,...range,shadow,rate:Number(a.get('rate')||900)};
    }
    const row={kind:key,...layer(def.get(key)),x:Number(def.get(key+'x')||0),y:Number(def.get(key+'y')||0)};
    if(def.has(key+'damaged'))row.dmg=layer(def.get(key+'damaged'));
    separateBuildingHealthRanges(row);layers.push(row);
  }
  save('bldanim/'+id+'.json',JSON.stringify({id,image:id,layers})+'\n');
}

const animPalette=decodePal(src.read('anim.pal').data);
for(const id of ['IRONBLST','NUKETO','NKMSLDN','V3TRAIL']){
 const original=src.read(id+'.shp'), shp=decodeShp(original.data), cols=Math.min(12,shp.frames.length), sheet=montageIndexed(shp,cols);
 save('fx/'+id+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,animPalette));
 save('fx/'+id+'.json',JSON.stringify({id,source:original.source,palette:'ANIM.PAL',cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:sheet.rects,fps:['V3TRAIL','IRONBLST'].includes(id) ? Number(getSec(art,id).keys.get('rate')) / 60 : 15,...(id==='IRONBLST'||id==='NUKETO' ? {translucent:true,sound:getSec(art,id).keys.get('report')||getSec(art,id).keys.get('startsound')} : {})})+'\n');
}
