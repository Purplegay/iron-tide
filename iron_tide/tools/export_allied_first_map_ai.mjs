// Build the mission-team ledger from ALL01UMD's own TeamTypes, references and orders.
import fs from 'node:fs';
const [indexPath,slicePath,outPath] = process.argv.slice(2);
if(!outPath) throw Error('Expected original map index, runtime slice and output TSV');
const map = JSON.parse(fs.readFileSync(indexPath,'utf8'));
const slice = JSON.parse(fs.readFileSync(slicePath,'utf8')).yr_all01umd;
if(map.audit.id!=='yr_all01umd' || map.audit.sha256!==slice.sha256) throw Error('Map hash mismatch');
const defs = map.definitions;
const references = new Map();
for(const [id,row] of Object.entries(map.triggers)){
  const fields=row.actions.split(',');
  for(let i=1;i<fields.length;i+=8){
    const team=fields[i+2].toUpperCase();
    if(!Object.hasOwn(defs.TeamTypes,team)) continue;
    if(!['4','5','7','80','104','107'].includes(fields[i])) throw Error('Unclassified team action '+id);
    const list=references.get(team)??[];
    list.push({id,name:row.trigger.split(',')[2],op:fields[i],wp:fields[i+7],flags:row.trigger.split(',').slice(4,7).join('')});
    references.set(team,list);
  }
}
const evidence=new Map();
function accept(id,entry){
  if(!references.has(id)||evidence.has(id)) throw Error('Missing or duplicate mission team '+id);
  evidence.set(id,entry);
}
for(const group of Object.values(slice.naval_fleet)) for(const row of group){
  accept(row.id,'原图舰队；RETAIL24 舰队实测，按队登记出场与房号');
}
for(const id of ['0DC53EFC','093DDC8C','093DD7DC','093DD32C','093DFDEC','0925E45C','0925FDEC']){
  if(!slice.teams[id.toLowerCase()]) throw Error('Missing power/armor team '+id);
  accept(id,id==='0DC53EFC'?'核电站工程师；供电主线与到门维修':'装甲小队；按难度出击及装甲主线');
}
const openingRows = new Set(['0b03a5bc','068f288c','0e0f4dcc','0b12eafc','08a0367c','0bb6491c','0bb37f3c','096c466c','06b9c76c','07adf47c','05eff13c','0ab41d9c']);
for(const id of openingRows){
  const row=slice.triggers.find(r=>r.id===id);
  if(!row) throw Error('Missing opening row '+id);
  for(const [op,,team] of row.actions) if(['4','7'].includes(op)){
    accept(team,'开局小队；MAP30 正式出击逐队人数、来源、房号与难度；路线完成度见交接');
  }
}
for(const name of ['Make_Civ_Cars1','Make_Civ_Cars2','Make_People','Create_Kirov']){
  const trigger=slice.triggers.find(row=>row.name===name);
  if(!trigger) throw Error('Missing city team source '+name);
  const teams=new Set(trigger.actions.filter(a=>['7','80'].includes(a[0])).map(a=>a[2]));
  for(const id of teams) accept(id,'MAP40 城区出场；正式出击核对原始队伍、成员、房号、难度与第一条指令；路线验证范围见批次记录');
}
for(const name of ['Make_People2','Make_Alcatraz_Men','Camera_Harriers','Engineer_Check','Enter_Tanya','Death_Reinforce','Start_Sounds2']){
  const row=slice.triggers.find(r=>r.name===name);
  if(!row) throw Error('Missing ALL01 field source '+name);
  for(const [op,,id] of row.actions){
    if(op!=='7') continue;
    accept(id,'MAP50 正式出击；原房号、原编组与出场来源。实际驻军、巡逻、空降、航母及读档证据见本批交接');
  }
}
const assault=JSON.parse(fs.readFileSync(slicePath,'utf8')).yr_all01umd_assault;
if(!assault || assault.sha256!==slice.sha256) throw Error('Assault map hash mismatch');
for(const [id] of Object.entries(assault.teams)){
  const sources=assault.triggers.filter(row=>row.actions.some(a=>['4','7','80'].includes(a[0]) && a[2].toLowerCase()===id));
  if(sources.length!==1) throw Error('Unexpected assault team source '+id);
  accept(id.toUpperCase(),sources[0].name==='Garrison_UT'?'MAP65 原图默认关闭，无启用上游；正式场景受控招募，未计为自然出场。':'MAP65 原图队伍；正式出击、实际房号与难度、动作和复测范围见批次记录。');
}
const closing=JSON.parse(fs.readFileSync(slicePath,'utf8')).yr_all01umd_closing;
if(closing.sha256!==slice.sha256) throw Error('Closing map hash mismatch');
const garrisons=[];
for(const row of closing.triggers){
  for(const [op,,id] of row.actions){
    if(op!=='4') continue;
    const team=closing.teams[id.toLowerCase()];
    if(!row.disabled || team.task_force[0]!=='5,INIT') throw Error('Unexpected garrison definition '+id);
    accept(id,'收尾：原图默认关闭，无启用上游；正式场景受控招募五名场上新兵，并核对脚本目标建筑地基。');
    garrisons.push(id);
  }
}
if(garrisons.sort().join(',')!=='0437F1EC,089CE49C') throw Error('Closing garrison source mismatch');
const numeric = record=>Object.entries(record).filter(([k])=>/^\d+$/.test(k)).sort(([a],[b])=>Number(a)-Number(b)).map(([,v])=>v);
const lines=['TeamType ID\t名称\t房号\t计数范围\t正式战场状态\t创建或招募来源（触发ID/名称/动作/航点/易普难）\t其他动作引用\tTaskForce ID\t队伍组成\tScriptType ID\t原始指令\t验收'];
for(const [id,t] of Object.entries(defs.TeamTypes)){
  const refs=references.get(id)??[];
  const creates=refs.filter(r=>['4','7','80','107'].includes(r.op));
  const refText=r=>[r.id,r.name,r.op,['4','7'].includes(r.op)?t.waypoint:r.wp,r.flags].join('/');
  const state=evidence.has(id)?'已正式接入':creates.length?'待正式接入':'仅定义';
  const note=evidence.get(id)??(['09F3BC1C','08071C8C','0908B07C','088C1A4C'].includes(id)?'已有专用逻辑，待转原表':'');
  lines.push([id,t.name,t.house,creates.length?'本图任务引用':'无创建或招募引用',state,creates.map(refText).join(' | '),refs.filter(r=>!creates.includes(r)).map(refText).join(' | '),t.taskforce,numeric(defs.TaskForces[t.taskforce]).join(' + '),t.script,numeric(defs.ScriptTypes[t.script]).join(' → '),note].join('\t'));
}
fs.writeFileSync(outPath,lines.join('\n')+'\n');
