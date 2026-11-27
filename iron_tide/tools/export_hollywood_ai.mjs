// Export ALL02UMD map AI definitions from a locally extracted retail map.
import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [input,output]=process.argv.slice(2);
const raw=fs.readFileSync(input);
if(sha256(raw)!=='168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303')throw Error('Wrong retail map');
const map=parseIni(raw.toString('latin1'));
const sec=k=>map.get(k.toLowerCase()).keys;
const keyOrder=['0c6c0edc','0c6c0d8c','0c6c0c3c','0973075c','0f7cb6fc','05d5239c'];
const ids=[...new Set([...keyOrder,...sec('AITriggerTypes').keys()])];
const rows=ids.filter(id=>sec('AITriggerTypesEnable').get(id)==='yes').map(id=>{
 const a=sec('AITriggerTypes').get(id).split(',');
 const team=sec(a[1]);
 const list=k=>[...sec(team.get(k))].filter(([n])=>/^\d+$/.test(n)).map(([,v])=>v.split(','));
 const tf=list('taskforce');
 const commands=list('script').map(r=>r.map(Number));
 const waypoints=commands.filter(([c])=>c===3||c===16).map(([,w])=>Number(sec('Waypoints').get(String(w))));
 if(waypoints.some(v=>!Number.isFinite(v)))throw Error(id+' waypoint');
 const condition=Buffer.from(a[6],'hex');
 return [id.toUpperCase(),team.get('house').replace(/^Yuri2Country$/,'Yuri2'),Number(a[4]),a[5],Number(a[7]),
 tf.flatMap(([n,t])=>Array(Number(n)).fill(t==='ENGINEER'?'YENGINEER':t)),waypoints,condition.readUInt32LE(0),condition.readUInt32LE(4),a.slice(15,18).map(Number),commands];
});
fs.writeFileSync(output,'[\n'+rows.map(r=>'  '+JSON.stringify(r)).join(',\n')+'\n]\n');
