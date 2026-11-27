import fs from 'node:fs';
import path from 'node:path';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [src,out='data/maps/head_games_drivers.json']=process.argv.slice(2);
const raw=fs.readFileSync(src);if(sha256(raw)!=='eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4')throw Error('Wrong SOV07 map');
const ini=parseIni(raw.toString('latin1'));const sec=k=>ini.get(k.toLowerCase()).keys;
const get=(s,k)=>sec(s).get(k.toLowerCase());
const actions=id=>{const [n,...a]=get('Actions',id).split(',');const width=a.length/+n;if(![7,8].includes(width))throw Error(id);return Array.from({length:+n},(_,i)=>a.slice(i*width,(i+1)*width));};
const trig=id=>{const e=get('Events',id).split(',');return {id,delay:+e[3],mask:get('Triggers',id).split(',').slice(4,7).map(Number),enable:actions(id).filter(a=>a[0]==='53').map(a=>a[2]),disable:actions(id).filter(a=>a[0]==='54').map(a=>a[2])};};
const ids=['07C1C26C','07C1E3CC','08B932FC','07C1D25C','07C1DE6C','07BEBCEC','07BEABEC','07BE91BC','07BEA0FC'];
const kills=['084615BC','084613EC','0846197C','084887CC','08461B4C','08461D1C','08461EEC','0846962C','084697FC'];
const routes=ids.map((id,i)=>({...trig(id),sourceDeath:trig(kills[i])}));
const point=n=>{const packed=Number(get('Waypoints',String(n)));if(!packed)throw Error('No waypoint '+n);return [201.5-Math.floor(packed/1000),packed%1000-10.5];};
const rawRoutes=JSON.parse(fs.readFileSync(new URL('../data/head_games_orders.json',import.meta.url))).routes;
for(let i=0;i<ids.length;i++){
 const a=actions(ids[i])[0], letters=a.at(-1);const wp=[...letters].reduce((n,c)=>n*26+c.charCodeAt(0)-64,0)-1;
 if(a[0]!=='80'||point(wp).join()!==rawRoutes[i].origin.join()||!routes[i].sourceDeath.disable.includes(ids[i]))throw Error(ids[i]);
}
const attack=['0BD6041C','0BED4ABC','0BD60BFC','0CBE5C3C','05D9A29C','05D9A0CC','096653CC','0B66ECBC'].map(trig);
attack[2].delay=+get('Events',attack[2].id).split(',').at(-1);
const ai={}, assaults={};
const rules=parseIni(fs.readFileSync(path.join(path.dirname(src),'rulesmd.ini'),'latin1'));
const types=[...rules.get('buildingtypes').keys.values()];
const weightFeedback={rules:{},success:+rules.get('general').keys.get('aitriggersuccessweightdelta'),failure:+rules.get('general').keys.get('aitriggerfailureweightdelta')};
if(types[9]!=='NAPOWR'||types[25]!=='NACNST')throw Error('Wrong BuildingTypes order');
for(const [id,row] of sec('AITriggerTypes')){
 const team=row.split(',')[1], sid=get(team,'Script');if(!sid)continue;
 const script=[...sec(sid)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
 const hasMembers=[...sec(get(team,'TaskForce'))].some(([k])=>/^\d+$/.test(k));
 if(hasMembers&&script.some(r=>r[0]===0)&&script.every(r=>[0,11,16,46,49,53,54].includes(r[0])))assaults[id]=script.map(([op,arg])=>op===16?[op,point(arg)]:op===46?[op,types[arg&65535],arg>>>16]:[op,arg]);
 if(script[0]?.[0]!==49||!script.some(r=>r[0]===5)||!script.every(r=>[49,3,5,6].includes(r[0])))continue;
 ai[id]=script.map(([op,arg])=>op===3?[op,point(arg)]:[op,arg]);
}
const yards={};
for(const [wing,id] of [['-1','0CBDC94C'],['0','0CBD8ABC'],['1','0CBD825C']]){
 const e=get('Events',id).split(',');if(e[1]!=='57')throw Error(id);
 yards[wing]=trig(id);
}
const combo={};
for(const [id,def] of sec('Triggers'))if(/^(Combine |Combo Teams)/.test(def.split(',')[2])){
 const key=id.toUpperCase(), e=get('Events',key).split(',');
 combo[key]={...trig(key),delay:e[1]==='37'?+e.at(-1):+e[3],events:e.slice(1),flags:actions(key).filter(a=>a[0]==='57').map(a=>+a[2])};
}
const finish=['0B0A52BC','0B0A72AC','0B0A4B9C','094320DC'].map(trig);
const briefing=['0947BC0C','092D8F3C','0947B21C','0947CB9C','0947C79C'].map(trig);
const credit={};
for(const [id,def] of sec('AITriggerTypes')){
 const fields=def.split(',');if(fields[4]!=='4')continue;
 const force=get(fields[1],'TaskForce');if(!force||![...sec(force).keys()].some(k=>/^\d+$/.test(k)))continue;
 const cmp=Buffer.from(fields[6],'hex');if(cmp.length!==32||cmp.readUInt32LE(4)>5)throw Error(id);
 credit[id]={threshold:cmp.readUInt32LE(0),op:cmp.readUInt32LE(4)};
}
const forceCount={};
for(const [id,def] of sec('AITriggerTypes')){
 const f=def.split(',');if(f[4]!=='0')continue;
 const cmp=Buffer.from(f[6],'hex');if(cmp.length!==32||cmp.readUInt32LE(4)>5)throw Error(id);
 forceCount[id]={entity:f[5],threshold:cmp.readUInt32LE(0),op:cmp.readUInt32LE(4)};
}
const superRows={};
for(const id of ['0D06808C','0D06981C','07F2570C','0CF90E6C','0D06925C','0B5A3C8C','0B5A7A8C','07F26E0C','0DB0041C','0DB01CAC','0DB018CC','0DB01E6C','095CB76C','0DB011BC','07F1BF3C']){
 const e=get('Events',id).split(',').slice(1), a=actions(id), timer=e.findIndex((x,i)=>i%3===0&&x==='13');
 superRows[id]={...trig(id),delay:timer<0?0:+e[timer+2],conditions:Array.from({length:e.length/3},(_,i)=>e.slice(i*3,i*3+3).map(Number)),unit:a.find(x=>x[0]==='125')?.[2]??'',cue:a.find(x=>x[0]==='21')?.[2]??''};
}
const opening={};
const openingIds=['09389BBC','093A68FC','093A633C','043B17DC','0DAFC42C','0A49703C','0DB094AC','094512EC'];
const landingIds=['0939307C','093A04FC'];
const landing={};
for(const id of landingIds){
 const members=actions(id).filter(a=>a[0]==='7').flatMap(a=>{
  const team=a[2],force=get(team,'TaskForce'), ops=[...sec(get(team,'Script'))].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
  const move=ops.find(x=>x[0]===3);if(!move)throw Error(team);
  return [...sec(force)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>{const [count,type]=v.split(',');return [type,...point(move[1]),+count];});
 });
 landing[id]={...trig(id),members};
}
const wpNumber=k=>[...k].reduce((n,c)=>n*26+c.charCodeAt(0)-64,0)-1;
for(const id of openingIds){
 const teams=actions(id).map(a=>{
  if(!['7','4','80'].includes(a[0]))throw Error(id);
  const team=a[2], house=get(team,'House'), script=get(team,'Script'), force=get(team,'TaskForce');
  const ops=[...sec(script)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
  const members=[...sec(force)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(','));
  return {team,wing:{BadGuy1:-1,BadGuy2:0,BadGuy3:1}[house],at:pointOrEmpty(a[0]==='80'?a.at(-1):get(team,'Waypoint')),members,target:ops.find(x=>[59,61,62].includes(x[0]))?.[0]??0};
 });
 opening[id]={...trig(id),teams};
}
for(const id of Object.keys(assaults)){
 const f=get('AITriggerTypes',id).split(',');
 if(assaults[id].some(c=>c[0]===49))weightFeedback.rules[id]=f.slice(7,10).map(Number);
}
const extra={};
for(const id of ['0947BC0C','092D8F3C','05FD863C','0965013C','0965263C','0965230C']){
 const a=actions(id);extra[id]={...trig(id),cue:a.find(x=>x[0]==='21')?.[2]??'',lose:a.some(x=>x[0]==='2'),clear:a.filter(x=>x[0]==='38').map(x=>+x[2]),at:a.filter(x=>x[0]==='17').map(x=>point(+x[2]))};
}
const production={};
for(const [id,raw] of sec('AITriggerTypes')){
 const f=raw.split(','),owner=get(f[1],'House'),force=get(f[1],'TaskForce');
 const members=Object.fromEntries([...sec(force)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>{const [n,type]=v.split(',');return [type,+n];}));
 if(!Object.keys(members).length)continue;
 const wing={BadGuy1:-1,BadGuy2:0,BadGuy3:1}[owner];if(wing===undefined)throw Error(id);
 production[id]={wing,members,enabled:get('AITriggerTypesEnable',id)==='yes'};
}
for(const id of ['0965013C','0965263C','0965230C']){
 const tags=[...sec('Tags')].filter(([,v])=>v.split(',').at(-1).toUpperCase()===id).map(([k])=>k);
 extra[id].cells=[...sec('CellTags')].filter(([,v])=>tags.includes(v.toLowerCase())).map(([k])=>[201-Math.floor(+k/1000),+k%1000-11]);
 if(!extra[id].cells.length)throw Error(id);
}
const grinder={};
for(const id of ['0CBE9A3C','0CC9415C','0CC9453C','0CBEE55C','0AA4409C','0CBF5A9C','0CBE799C','06B1C55C']){
 const a=actions(id);
 grinder[id]={...trig(id),teams:a.filter(x=>['4','7'].includes(x[0])).map(x=>{
  const team=x[2], house=get(team,'House'),script=get(team,'Script');
  const at=pointOrEmpty(get(team,'Waypoint'));
  const move=[...sec(script)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number)).find(x=>x[0]===3||x[0]===16);
  return {wing:{BadGuy1:-1,BadGuy2:0,BadGuy3:1}[house]??-1,at:at.length?at:move?point(move[1]):[],members:[...sec(get(team,'TaskForce'))].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(','))};
 }),flags:a.filter(x=>x[0]==='56').map(x=>+x[2])};
}
function pointOrEmpty(wp){return wp&&/^[A-Z]+$/.test(wp)?point(wpNumber(wp)):[];}
fs.writeFileSync(out,JSON.stringify({routes,start:trig('08408E8C'),attack,yards,ai,assaults,combo,finish,briefing,credit,forceCount,superRows,opening,landing,grinder,weightFeedback,extra,production},null,2)+'\n');
