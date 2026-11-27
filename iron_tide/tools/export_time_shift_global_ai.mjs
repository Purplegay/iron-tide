import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [game,mapFile,out]=process.argv.slice(2);
const src=new YrSource(game);
const raw=fs.readFileSync(mapFile), aim=src.read('aimd.ini').data;
if(sha256(raw)!=='498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b')throw Error('Not retail SOV01');
const map=parseIni(raw.toString('latin1')), ai=parseIni(aim.toString('latin1'));
const entries=(id)=>Object.fromEntries(ai.get(id.toLowerCase())?.keys??[]);
const rows=[...map.get('aitriggertypesenable').keys].map(([id,enabled])=>{
 const raw=ai.get('aitriggertypes').keys.get(id); if(!raw)throw Error(id);
 const a=raw.split(','), team=entries(a[1]);
 const secondary=a[14]==='<none>'?null:entries(a[14]);
 return {id,enabled:enabled==='yes',raw,team,force:entries(team.taskforce),script:entries(team.script),secondary,
  secondary_force:secondary?entries(secondary.taskforce):null,secondary_script:secondary?entries(secondary.script):null};
});
const rules=parseIni(src.read('rulesmd.ini').data.toString('latin1'));
const types=[...rules.get('buildingtypes').keys.values()];
const houses={};
const sides=['gdi','nod','thirdside'];
for(const house of map.get('houses').keys.values()){
 const h=map.get(house.toLowerCase()).keys;
 const country=h.get('country')??house;
 const techLevel=Number(h.get('techlevel'));
 if(!Number.isInteger(techLevel)||!h.has('techlevel'))throw Error('Missing retail TechLevel for '+house);
 const national=rules.get(country.toLowerCase())?.keys;
 const local=map.get(country.toLowerCase())?.keys;
 const sideName=local?.get('side')??national?.get('side');
 if(!sideName)throw Error('Missing retail Side for '+country);
 const passive=/^(yes|true|1)$/i.test(local?.get('multiplaypassive')??national?.get('multiplaypassive')??'no');
 houses[house]={country,techLevel,passive,side:sides.indexOf(sideName.toLowerCase())+1,iq:+(h.get('iq')??0),player:h.get('playercontrol')==='yes',credits:+(h.get('credits')??0)*100,allies:(h.get('allies')??'').split(',').map(x=>x.trim())};
}
if(houses.Americans.side!==1||houses.Arabs.side!==2||houses.YuriCountry.side!==3||!houses.Russians.player)throw Error('Bad retail house registry');
const structureTargets={};
for(const r of rows)for(const script of [r.script,r.secondary_script??{}])for(const [key,value] of Object.entries(script)){
 if(!/^\d+$/.test(key))continue;
 const [op,num]=value.split(',').map(Number);
 if([46,58].includes(op)&&types[num&65535])structureTargets[num&65535]=types[num&65535];
}
const minorReady=+rules.get('general').keys.get('aiminorsuperreadypercent');
if(!(minorReady>0&&minorReady<=1))throw Error('Missing minor super threshold');
fs.writeFileSync(out,JSON.stringify({source_sha:sha256(aim),houses,minorReady,structureTargets,rows},null,2)+'\n');
