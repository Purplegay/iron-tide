// Read original parameters; independent Godot implementations consume this manifest.
import fs from 'node:fs';
import path from 'node:path';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: <local YR directory> <output json>');
const source = new YrSource(game);
const raw = source.read('rulesmd.ini'), artRaw = source.read('artmd.ini');
const rules = parseIni(raw.data.toString('latin1')), art = parseIni(artRaw.data.toString('latin1'));
const row = (ini,id) => Object.fromEntries(getSec(ini,id)?.keys || []);
const result = {source:{rules:sha256(raw.data),art:sha256(artRaw.data)}, general:row(rules,'General'), lighting:row(rules,'AudioVisual'), buildings:{}, clouds:{}, weapons:{}};
for (const id of ['GAAIRC','AMRADR','GASPYSAT','GACSPH','GAWEAT','GAPOWR','GAREFN','GAPILE','GAWEAP','GATECH','ATESLA','TESLA','CAHSE01','CABHUT']) result.buildings[id]=row(rules,id);
for (const section of rules.values()) if (/^(yes|true|1)$/i.test(section.keys.get('lightningrod')||'')) result.buildings[section.name]=row(rules,section.name);
for (const id of ['WCCLOUD1','WCCLOUD2','WCCLOUD3']) result.clouds[id]=row(art,id);
for (const id of ['GoodTeeth','BadTeeth','UCPara','UCElitePara']) result.weapons[id]=row(rules,id);
result.site_art=[];
const pal=decodePal(source.read('unittem.pal').data);
for(const id of ['CAHSE01','CABHUT']) {
 const input=source.read(id[0]+'T'+id.slice(2)+'.shp')||source.read(id[0]+'U'+id.slice(2)+'.shp')||source.read(id+'.shp'); if(!input)throw new Error('Missing '+id);
 const shp=decodeShp(input.data), sheet=montageIndexed(shp,8);
 const folder=path.join(path.dirname(output),'shp');fs.mkdirSync(folder,{recursive:true});
 fs.writeFileSync(path.join(folder,id+'.png'),encodePngIndexed(sheet.width,sheet.height,sheet.indices,pal));
 fs.writeFileSync(path.join(folder,id+'.json'),JSON.stringify({id,image:id,source:input.source,palette:'UNITTEM.PAL',cell:[shp.width,shp.height],cols:8,count:shp.frames.length,rects:sheet.rects,dmg:id === "CAHSE01" ? shp.frames.length / 2 : Math.floor(shp.frames.length / 4),shadow:true})+'\n');
 result.site_art.push({id,source:input.source,sha256:sha256(input.data)});
}
result.inputs=source.audit();
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output,source:result.source,clouds:result.clouds,storm:Object.fromEntries(Object.entries(result.general).filter(([k])=>k.startsWith('lightning')))}));
