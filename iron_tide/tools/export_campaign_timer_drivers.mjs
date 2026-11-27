// Extract only supported timers; leave unrelated events/actions to their adapters.
import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [sov,holly,out='data/maps/campaign_timer_drivers.json']=process.argv.slice(2);
const maps=[['sov01',sov,'498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b',['043e763c','0b554afc','0b557e6c']],['all02',holly,'168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303',['094d906c','04627bcc','07ac738c','0618f5cc']]];
const result={};
for(const [name,file,hash,ids] of maps){
 const bytes=fs.readFileSync(file);if(sha256(bytes)!==hash)throw Error('Wrong retail '+name);
 const m=parseIni(bytes.toString('latin1')); const rows={};
 for(const id of ids){
  const e=m.get('events').keys.get(id).split(',').map(Number), a=m.get('actions').keys.get(id).split(',');
  if(e.length!==1+3*e[0]||a.length!==1+8*Number(a[0])||![13,51].includes(e[1]))throw Error(id);
  const row={seconds:e[3],random:e[1]===51};
  for(let i=1;i<a.length;i+=8){if(a[i]==='53')(row.enable??=[]).push(a[i+2].toLowerCase());}
  rows[id]=row;
 }
 result[name]=rows;
}
fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
