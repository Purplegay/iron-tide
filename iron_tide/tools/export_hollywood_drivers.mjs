import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [src,out='data/maps/hollywood_drivers.json']=process.argv.slice(2);
const raw=fs.readFileSync(src);if(sha256(raw)!=='168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303')throw Error('Wrong ALL02UMD');
const ini=parseIni(raw.toString('latin1')),sec=k=>ini.get(k.toLowerCase()).keys,get=(s,k)=>sec(s).get(k.toLowerCase());
const actions=id=>{const [n,...a]=get('Actions',id).split(',');if(a.length!==Number(n)*8)throw Error(id);return Array.from({length:Number(n)},(_,i)=>a.slice(i*8,(i+1)*8));};
const events=id=>{const [n,...a]=get('Events',id).split(',');if(a.length!==Number(n)*3)throw Error(id);return Array.from({length:Number(n)},(_,i)=>a.slice(i*3,(i+1)*3).map(Number));};
const find=(rows,op)=>rows.find(a=>Number(a[0])===op);
const num=s=>[...s].reduce((n,c)=>n*26+c.charCodeAt(0)-64,0)-1;
const coords=i=>{const raw=Number(get('Waypoints',String(i)));if(!raw)throw Error('Missing waypoint '+i);return [raw%1000,Math.floor(raw/1000)];};
const team=id=>{const script=get(id,'Script'),force=get(id,'TaskForce'),wp=get(id,'Waypoint');return {id,at:wp&&/^[A-Z]+$/.test(wp)?coords(num(wp)):null,members:[...sec(force)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',')),route:[...sec(script)].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number)).filter(x=>x[0]===3||x[0]===16).map(x=>[...coords(x[1]),x[0]===16])};};
const mask=id=>get('Triggers',id).split(',').slice(4,7).map(Number);
const waves={};const residents={};const ai={};
for(const [key,def] of sec('Triggers')){
 const id=key.toUpperCase(),name=def.split(',')[2];
 if(/^(Lame_Cheese_Tank|Tank_Cheese|Hard_Cheese)\d$/.test(name)){
  const a=actions(id),e=events(id);waves[id]={id,mask:mask(id),delay:find(e,13)[2],team:team(find(a,7)[2]),next:find(a,53)[2],blockedTypeIndex:find(e,57)[2]};
 }
 const g=name.match(/^G([124])_Make_/);
 if(g){
  const a=actions(id), next=find(a,53)[2], change=actions(next), e=events(next), back=find(change,53)[2];
  if(back!==id||!find(e,36)||!find(e,51))throw Error(id);
  const walker=team(find(a,7)[2]);if(walker.members.length!==1||Number(walker.members[0][0])!==1)throw Error(id);
  residents[id]={id,plant:{1:'0',2:'1',4:'3'}[g[1]],change:next,wait:find(e,51)[2],flag:find(e,36)[2],walker};
 }
}
for(const [id,def] of sec('AITriggerTypes')){
 const f=def.split(','),cmp=Buffer.from(f[6],'hex');if(cmp.length!==32)throw Error(id);
 ai[id.toUpperCase()]={enabled:get('AITriggerTypesEnable',id)==='yes',condition:+f[4],entity:f[5],threshold:cmp.readUInt32LE(0),op:cmp.readUInt32LE(4),weight:+f[7],mask:f.slice(15,18).map(Number)};
}
const gate='04F2A9AC',ge=get('Events',gate).split(','),hard=find(actions(gate),53)[2];if(ge[1]!=='60'||ge.at(-1)!=='GAWEAP')throw Error(gate);
const warmupId='045E003C';
const intro={};for(const id of ['045E609C',warmupId])intro[id]={id,delay:find(events(id),13)[2],enable:actions(id).filter(a=>a[0]==='53').map(a=>a[2])};
if(Object.keys(waves).length!==17||Object.keys(residents).length!==21||Object.keys(ai).length!==36)throw Error('Coverage drift');
const sources={}, staged={}, bridges=[], hints={};
const structures=[...sec('Structures').values()].map(v=>v.split(','));
const openRoots=['0C745F3C','0978639C','097FD60C'];
for(let i=0;i<3;i++){
 let id=openRoots[i];const plant=['0','1','3'][i];
 while(id){const a=actions(id),e=events(id),t=team(find(a,4)[2]);
  staged[id]={id,plant,delay:find(e,13)[2],team:t,next:find(a,53)?.[2]??''};id=staged[id].next;
 }
}
for(const [key,def] of sec('Triggers')){
 const id=key.toUpperCase(), name=def.split(',')[2];
 if(/^[IJ][A-Z]_Building_Gone$/.test(name)){
  const route=find(actions(id),54)?.[2];if(!residents[route])continue;
  const tag=[...sec('Tags')].find(([,v])=>v.split(',').at(-1).toUpperCase()===id)?.[0];
  const b=structures.filter(r=>r[6].toLowerCase()===tag);if(b.length!==1)throw Error(id);
  sources[route]={id,type:b[0][1],at:b[0].slice(3,5).map(Number)};
 }
}
for(const id of ['0E69E72C','0E69DB4C','0E69BF3C','0E69CC1C']){
 const tag=[...sec('Tags')].find(([,v])=>v.split(',').at(-1).toUpperCase()===id)[0];
 const packed=Number([...sec('CellTags')].find(([,v])=>v.toLowerCase()===tag)[0]);
 const links=actions(id).filter(x=>x[0]==='53').map(x=>x[2]);
 const fixer=links.find(k=>find(events(k),13)); const fixed=links.find(k=>k!==fixer);
 const t=find(actions(fixer),7)[2], s=get(t,'Script'), order=get(s,'0').split(',');
 const crew=team(t);if(order[0]!=='1'||!actions(fixed).some(a=>a[0]==='54'&&a[2]===fixer))throw Error(id);
 bridges.push({id,fixer,fixed,delay:find(events(fixer),13)[2],section:[packed%1000,Math.floor(packed/1000)],hut:coords(+order[1]),landing:crew.at,crew:crew.members[0]});
}
for(const id of ['0D20AA9C','0C43032C','0D20A85C','08D7EBEC','08D7E3EC','08D7FF3C','0D1FE81C']){
 const a=actions(id),e=events(id);hints[id]={id,delay:find(e,13)?.[2]??0,flag:find(e,37)?.[2]??0,enable:a.filter(x=>x[0]==='53').map(x=>x[2]),disable:a.filter(x=>x[0]==='54').map(x=>x[2]),at:find(a,55)?coords(num(find(a,55)[7])):null,text:find(a,11)?.[2]??''};
}
if(Object.keys(sources).length!==21||Object.keys(staged).length!==21)throw Error('Resident related rows drift');
const special={}, ambience={};
const detail=(id)=>{
 const a=actions(id),e=events(id);return {id,delay:find(e,13)?.[2]??0,mask:mask(id),enable:a.filter(x=>x[0]==='53').map(x=>x[2]),set:a.filter(x=>x[0]==='56').map(x=>+x[2]),clear:a.filter(x=>x[0]==='57'||x[0]==='38').map(x=>+x[2]),events:e};
};
for(const [key,def] of sec('Triggers')){
 const id=key.toUpperCase(), name=def.split(',')[2];
 if(/^(Make_Cheat[AB]|Destroy_Old_Team_[AB]|Create_New_Team_[AB])/.test(name)){
  let row=detail(id), a=actions(id);
  row.spawn=a.filter(x=>['4','7','80'].includes(x[0])).map(x=>{const t=team(x[2]);if(x[0]==='80')t.at=coords(num(x[7]));return t;});
  row.release=a.filter(x=>x[0]==='5').map(x=>x[2]);special[id]=row;
 }
 if(/^(Amb_(Traffic|Beach|Birds)|_Ambient_SlavePens)/.test(name))ambience[id]={...detail(id),points:actions(id).filter(x=>x[0]==='99').map(x=>[x[2],...coords(num(x[7]))])};
}
const lifecycle={};
for(const id of ['0C43BA4C','08D7DCCC','0C43CF3C','08D7D2BC','0D18503C','088703CC','095FE79C','0C89504C','0921C8DC','0BCF2BEC','0CDDD74C','0460D72C'])lifecycle[id]=detail(id);
const cleanup={};
for(const id of ['08FEB28C','08FEA9EC','08FEA69C','08FEDB2C','08FED55C','08FEFB2C','08FEC06C']){
 const a=actions(id);cleanup[id]={...detail(id),retire:a.filter(x=>x[0]==='5').map(x=>x[2]),spawn:a.filter(x=>x[0]==='4').map(x=>team(x[2]))};
}
for(const k of Object.keys(cleanup))cleanup[k].types=[...new Set(cleanup[k].spawn.flatMap(t=>t.members.map(x=>x[1])))];
cleanup['08FEA69C'].enable=[]; // Retail entry has no successor action; do not invent one.
const batch16={};
for(const id of ['0916B4CC','0ABA8C5C','0ABAE7BC','08E32CFC','065C3EDC','06C3CCCC','093C2ADC','0B0F83EC','04EF835C','092C9D5C','07F39F3C','07F31BAC','07F3122C','0B975C7C','097988CC','0ACD381C','08E7FB5C','0B8E13AC','096947BC','0967DE9C']){
 const a=actions(id), tags=[...sec('Tags')].filter(([,v])=>v.split(',').at(-1).toUpperCase()===id).map(([k])=>k);
 const units=[...sec('Units').values()].map(v=>v.split(',')).filter(r=>tags.includes(r[7].toLowerCase())).map(r=>[r[1],+r[3],+r[4]]);
 const objects=units.concat([...sec('Infantry').values()].map(v=>v.split(',')).filter(r=>tags.includes(r[8]?.toLowerCase())).map(r=>[r[1],+r[3],+r[4]]),structures.filter(r=>tags.includes(r[6]?.toLowerCase())).map(r=>[r[1],+r[3],+r[4]]));
 const crews=a.filter(x=>['4','7'].includes(x[0])).map(x=>{const t=team(x[2]);const ops=[...sec(get(t.id,'Script'))].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));return {...t,enter:ops.find(x=>[61,62,63].includes(x[0]))?.[0]??0};});
 batch16[id]={...detail(id),units,objects,crews,cue:find(a,21)?.[2]??'',ping:find(a,55)?coords(num(find(a,55)[7])):null};
}
const briefing={};
for(const id of ['0B97536C','0930F29C','0895FDFC','093093FC','0930CDEC','099AEA1C','099AFF3C','0930C5CC','0932705C','091B6F3C','088509DC','04384E4C','043842DC']){
 const a=actions(id), camera=a.find(x=>['112','48','41'].includes(x[0])),frame=find(a,131);
 briefing[id]={...detail(id),at:camera?coords(num(camera[7])):null,frames:frame?Number(frame[7]):0};
}
const extra={};
for(const id of ['0B975C7C','0B97536C','0895FDFC','0930CDEC','0462733C','0921C8DC','0CDDB12C','097988CC','0464E91C','07F7DACC','0D0983FC']){
 const a=actions(id),shot=ofLocal(a,112)[0];
 extra[id]={...detail(id),reveal:ofLocal(a,17).map(x=>coords(num(x[7]))),at:shot?coords(num(shot[7])):null,teams:ofLocal(a,4).map(x=>team(x[2]))};
}
function ofLocal(a,op){return a.filter(x=>+x[0]===op);}
const voices={};
for(const id of ['0926286C','0926F53C','07BC86EC','07BCF5EC']){
 const a=actions(id),next=find(a,53)[2];
 const tags=[...sec('Tags')].filter(([,v])=>v.split(',').at(-1).toUpperCase()===next).map(([k])=>k);
 if(!actions(next).some(x=>x[0]==='53'&&x[2]===id)||tags.length!==1)throw Error(id);
 const teams=[...sec('TeamTypes').values()].filter(t=>tags.includes(get(t,'Tag')?.toLowerCase())).map(t=>t.toUpperCase());
 if(!teams.length)throw Error(id);
 voices[id]={id,next,teams,cue:find(a,19)[2],delay:find(events(next),13)[2]};
}
const westwood={};
for(const id of ['0916204C','0926703C','0464860C','07A40B2C','09D2968C','05D9EE6C']){
 const a=actions(id),tags=[...sec('Tags')].filter(([,v])=>v.split(',').at(-1).toUpperCase()===id).map(([k])=>k);
 const cells=[...sec('CellTags')].filter(([,v])=>tags.includes(v.toLowerCase())).map(([key])=>[+key%1000,Math.floor(+key/1000)]);
 const points=find(a,17);
 westwood[id]={...detail(id),disable:a.filter(x=>x[0]==='54').map(x=>x[2]),forced:find(a,22)?.[2]??'',reveal:points?coords(num(points[7])):null,cells,flash:find(a,81)!==undefined};
}
const prisoners={};
for(const id of ['095D099C','0958149C','095D033C']){
 const tags=[...sec('Tags')].filter(([,v])=>v.split(',').at(-1).toUpperCase()===id).map(([k])=>k);
 const actors=[...sec('Infantry').values()].map(v=>v.split(',')).filter(r=>tags.includes(r[8].toLowerCase())).map(r=>[r[1],+r[3],+r[4]]);
 const t=find(actions(id),4);
 prisoners[id]={...detail(id),actors,team:t?team(t[2]):null};
}
const closure={};
for(const id of ['0930C39C','0ACD381C','08D5E88C','08E7FF3C','08E7FB5C','0963AA4C','10A9144C','0EB68F3C','07F39F3C','07F31BAC','07F3122C','088F344C']){
 const tags=[...sec('Tags')].filter(([,v])=>v.toUpperCase().endsWith(','+id)).map(([k])=>k);
 if(id==='10A9144C'){
  const linked=[...sec('Triggers')].filter(([,v])=>v.split(',')[1].toUpperCase()===id).map(([k])=>k);
  if(linked.join(',')!=='0eb68f3c')throw Error('Unexpected Easy_Money tag chain');
  for(const [k,v] of sec('Tags'))if(linked.includes(v.split(',').at(-1).toLowerCase()))tags.push(k);
 }
 const sites=[...sec('Structures').values()].map(v=>v.split(',')).filter(v=>tags.includes(v[6].toLowerCase())).map(v=>[v[1],+v[3],+v[4]]);
 const a=actions(id);
 closure[id]={...detail(id),disabled:get('Triggers',id).split(',')[3]==='1',sites,actions:a};
}
fs.writeFileSync(out,JSON.stringify({waves,residents,ai,gate:{id:gate,hard,type:ge.at(-1)},intro,warmup:warmupId,sources,staged,openRoots,bridges,hints,special,ambience,lifecycle,cleanup,briefing,batch16,extra,voices,westwood,prisoners,closure},null,2)+'\n');
