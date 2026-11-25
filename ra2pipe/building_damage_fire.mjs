import fs from 'node:fs';
import path from 'node:path';
import {YrSource,sha256} from './lib/yr_source.mjs';
import {parseIni,getSec} from './lib/ini.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed} from './art_lib.mjs';
const [game,out]=process.argv.slice(2);
if(!game||!out||fs.existsSync(out)) throw Error('Usage: <YR install> <new candidate>');
const source=new YrSource(game), inputs=[];
function read(name){const hit=source.read(name);if(!hit)throw Error('Missing '+name);inputs.push({name,source:hit.source,sha256:sha256(hit.data)});return hit.data;}
const rules=parseIni(read('rulesmd.ini').toString('latin1')), art=parseIni(read('artmd.ini').toString('latin1'));
const general=getSec(rules,'General').keys;
const audioVisual=getSec(rules,'AudioVisual').keys;
const fraction=v=>v.endsWith('%')?Number(v.slice(0,-1))/100:Number(v);
const config={yellow:fraction(audioVisual.get('conditionyellow')),red:fraction(audioVisual.get('conditionred')),types:general.get('damagefiretypes').split(',').map(x=>x.trim()),buildings:{}};
for(const [,section] of rules){
 const image=section.keys.get('image')||section.name;
 const keys=getSec(art,image)?.keys;if(!keys)continue;
 const offsets=[...keys].filter(([k])=>/^damagefireoffset\d+$/.test(k)).sort((a,b)=>Number(a[0].slice(16))-Number(b[0].slice(16))).map(([,v])=>v.split(',').map(Number));
 if(offsets.length)config.buildings[section.name.toUpperCase()]={image,offsets};
}
fs.mkdirSync(path.join(out,'fx'),{recursive:true});
const pal=decodePal(read('anim.pal'));
for(const id of config.types){
 const shp=decodeShp(read(id+'.shp')),keys=getSec(art,id).keys;
 const frames=keys.get('shadow')==='yes'?shp.frames.slice(0,shp.frames.length/2):shp.frames;
 const sheet=montageIndexed({...shp,frames},Math.min(12,frames.length));
 const rate=Number(keys.get('rate')||900);
 fs.writeFileSync(path.join(out,'fx',id+'.png'),encodePngIndexed(sheet.width,sheet.height,sheet.indices,pal));
 fs.writeFileSync(path.join(out,'fx',id+'.json'),JSON.stringify({id,kind:'fx',cell:[shp.width,shp.height],count:frames.length,rects:sheet.rects,fps:rate/60,rate,source:inputs.at(-1),anchor:'original SHP canvas center; no content recentering'})+'\n');
}
config.inputs=inputs;
source.audit();
fs.writeFileSync(path.join(out,'building_damage_fire.json'),JSON.stringify(config,null,2)+'\n');
console.log(JSON.stringify({out,types:config.types,buildings:Object.keys(config.buildings).length,examples:Object.fromEntries(['GAPOWR','GAWEAP','GAREFN','GADEPT','GAAIRC','GACNST','ATESLA','GAPILL','GAFWLL'].map(id=>[id,config.buildings[id]]))}));
