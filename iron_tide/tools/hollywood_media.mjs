import {audioSamples} from './yr_audio_samples.mjs';
// Run from the project root with the installed YR directory.
import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
const src=new YrSource(process.argv[2]);
const section=(ini,id)=>Object.fromEntries(getSec(ini,id)?.keys||[]);
const ini=name=>parseIni(src.read(name).data.toString('latin1'));
const sounds=ini('soundmd.ini'),rules=ini('rulesmd.ini'),map=ini('all02umd.map');
const raw=id=>({...section(rules,id),...section(map,id)});
const pack={units:{},specs:{},entries:{}};
const sample=audioSamples(src,pack,'hollywood');
function sound(id){const a=section(sounds,id);if(!a.sounds)return '';pack.specs[id]={sounds:a.sounds.toLowerCase().split(/\s+/).map(s=>sample(s.replace(/^[#$]+/,''))),volume:Number(a.volume??1),range:Number(a.range??10)};return id;}
for(const [id,prefix] of Object.entries({CLNT:'Clint',ARND:'Arnold',STLN:'Sly'})){pack.units[id]={};for(const [k,s] of Object.entries({select:'Select',move:'Move',attack:'AttackCommand',special:'AttackCommand',feedback:'Fear',die:'Die'}))pack.units[id][k]=sound(prefix+s);}
for(const id of ['TrexFoot','TrexRoar','TrexDie','SlaveAttack','SlaveWorkerLiberated','SlaveMinerDeploy','SlaveMinerUndeploy','YuriMindControl','MindCleared'])sound(id);
for(const id of ['CLNT','ARND','STLN','DNOA','SMIN','YTNK','YURI','SLAV']) {
 const r=raw(id);
 for(const key of ['primary','secondary','eliteprimary','weapon1','weapon2','weapon3','weapon4','weapon5','weapon6']) {
  if(!r[key])continue;
  const report=raw(r[key]).report;
  if(report)sound(report);
 }
}
fs.writeFileSync('data/ra2/hollywood_audio.json',JSON.stringify(pack,null,1)+'\n');
