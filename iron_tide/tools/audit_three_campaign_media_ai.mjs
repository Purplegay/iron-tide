import fs from 'node:fs';
import path from 'node:path';
import { parseIni } from '../../ra2pipe/lib/ini.mjs';
import { YrSource, sha256 } from '../../ra2pipe/lib/yr_source.mjs';
const [game,out,...maps]=process.argv.slice(2);
if(!game||!out||maps.length!==3) throw Error('GAME_DIR OUT SOV01_MAP ALL02_MAP SOV07_MAP');
const src=new YrSource(game);
const ini=name=>parseIni(src.read(name).data.toString('latin1'));
const eva=ini('evamd.ini'), sounds=ini('soundmd.ini'), art=ini('artmd.ini');
const vals=(map,name)=>map.get(name)?.keys??new Map();
const report=maps.map(file=>{
 const raw=fs.readFileSync(file), map=parseIni(raw.toString('latin1'));
 const triggers=vals(map,'triggers'),actions=vals(map,'actions'),events=vals(map,'events'),ai=vals(map,'aitriggertypes'),enable=vals(map,'aitriggertypesenable');
 const media=[];
 for(const [id,line] of actions){const a=line.split(',');for(let i=1;i<a.length;i+=8){const code=Number(a[i]);if(![19,21,100].includes(code))continue;const key=a[i+2];const cue=(code===19?sounds:eva).get(key?.toLowerCase())?.keys;
 media.push({id,name:triggers.get(id)?.split(',')[2],events:events.get(id),code,key,movieIniSameKey:code===100?vals(art,'movies').get(key):undefined,samples:cue?Object.fromEntries(cue):null});}}
 const conditions={}, aiRows=[];
 for(const [id,row] of ai){const a=row.split(','), team=Object.fromEntries(vals(map,a[1].toLowerCase()));const c=a[4];conditions[c]=(conditions[c]??0)+1;
  aiRows.push({id,enabled:enable.get(id)??null,raw:row,team,taskforce:Object.fromEntries(vals(map,team.taskforce?.toLowerCase())),script:Object.fromEntries(vals(map,team.script?.toLowerCase()))});}
 return {file:path.basename(file),sha:sha256(raw),basic:Object.fromEntries(vals(map,'basic')),triggerCount:triggers.size,aiCount:ai.size,aiEnableOverrides:enable.size,conditions,aiRows,media};
});
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'retail-audit.json'),JSON.stringify(report,null,2));
for(const r of report) console.log(r.file,r.triggerCount,r.aiCount,r.aiEnableOverrides,JSON.stringify(r.conditions),r.media.length);
