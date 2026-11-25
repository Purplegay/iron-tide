import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';
const [game,out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw new Error('Usage: <local YR> <new external candidate>');
const source = new YrSource(game), inputs=[];
function read(name) { const h=source.read(name); if(!h)throw new Error(`Missing ${name}`); inputs.push({name,source:h.source,sha256:sha256(h.data)});return h.data; }
const rules=parseIni(read('rulesmd.ini').toString('latin1')), art=parseIni(read('artmd.ini').toString('latin1'));
const general=getSec(rules,'General').keys;
const config={source:inputs[0],general:{},buildings:{}};
for(const key of ['PrismSupportModifier','PrismSupportMax','PrismSupportDelay','PrismSupportDuration','PrismSupportHeight','ChronoDelay','ChronoPlacement','ChronoBlast','ChronoBlastDest','GapRegenInterval'])
 if(general.has(key.toLowerCase()))config.general[key]=general.get(key.toLowerCase());
for(const id of ['GAGAP','GASPYSAT','GADEPT','GAOREP']) config.buildings[id]=Object.fromEntries(getSec(rules,id).keys);
fs.mkdirSync(path.join(out,'fx'),{recursive:true});
fs.writeFileSync(path.join(out,'support_rules.json'),JSON.stringify(config,null,2)+'\n');
const animationPalette=decodePal(read('anim.pal')), unitPalette=decodePal(read('unittem.pal'));
for(const id of ['WCCLOUD1','WCCLOUD2','WCCLOUD3','EXPLOLB']) {
 const raw=read(id+'.shp'), shp=decodeShp(raw), keys=getSec(art,id)?.keys;
 const palette=keys?.get('altpalette')==='yes'?'UNITTEM.PAL':'ANIM.PAL';
 const pal=palette==='UNITTEM.PAL'?unitPalette:animationPalette;
 const rate=Number(keys?.get('rate')||900);
 const frames=shp.frames.slice(0,keys?.get('shadow')==='yes'?shp.frames.length/2:shp.frames.length);
 const left=Math.min(...frames.map(f=>f.x)), top=Math.min(...frames.map(f=>f.y));
 const width=Math.max(...frames.map(f=>f.x+f.w))-left,height=Math.max(...frames.map(f=>f.y+f.h))-top;
 const sheet=montageIndexed({width,height,frames:frames.map(f=>({...f,x:f.x-left,y:f.y-top}))},12);
 fs.writeFileSync(path.join(out,'fx',id+'.png'),encodePngIndexed(sheet.width,sheet.height,sheet.indices,pal));
 fs.writeFileSync(path.join(out,'fx',id+'.json'),JSON.stringify({id,kind:'fx',cell:[width,height],count:frames.length,rects:sheet.rects,fps:rate/60,rate,palette,source:inputs.at(-1),sound:keys?.get('startsound')||null})+'\n');
}
fs.writeFileSync(path.join(out,'source-audit.json'),JSON.stringify({inputs},null,2)+'\n');
console.log(JSON.stringify({out,inputs:inputs.length}));
