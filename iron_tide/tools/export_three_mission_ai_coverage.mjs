import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [out,...files]=process.argv.slice(2);
if(files.length!==3)throw Error('OUT.tsv SOV01 ALL02 SOV07');
const read=p=>JSON.parse(fs.readFileSync(new URL('../data/'+p,import.meta.url)));
const global=read('maps/time_shift_global_ai.json'), hollywood=read('maps/hollywood_retail_ai.json'), head=read('head_games_orders.json').rules;
const maps=[['SOV01UMD','498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b','no'],['ALL02UMD','168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303','yes'],['SOV07UMD','eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4','yes']];
const s07Drivers=read('maps/head_games_drivers.json');
const h13=read('maps/hollywood_drivers.json').ai;
const s07Defense=s07Drivers.ai;
const rally16=r=>Object.values(r.script).some(x=>/^(53|54|61),/.test(x));
const rows=[['关卡','来源','AI ID','启用覆盖','零售AI条件','TeamType','TaskForce','ScriptType','正式状态','逐ID验证或限制']];
for(let n=0;n<3;n++){
 const [mission,hash,ignore]=maps[n], raw=fs.readFileSync(files[n]);
 if(sha256(raw)!==hash)throw Error('Wrong '+mission);
 const ini=parseIni(raw.toString('latin1')), get=k=>ini.get(k.toLowerCase())?.keys??new Map();
 if(get('Basic').get('ignoreglobalaitriggers')!==ignore)throw Error('Global policy drift '+mission);
 const overrides=get('AITriggerTypesEnable'), local=get('AITriggerTypes');
 if(overrides.size!==[165,201,240][n]||local.size!==[0,36,74][n])throw Error(mission);
 if(n===0){
  if(global.rows.length!==overrides.size)throw Error('Missing global association');
  // Enable overrides are per-rule filters, not actions that start a campaign house AI.
  const aiStarts=[...get('Actions')].flatMap(([id,raw])=>{
   const fields=raw.split(',').slice(1);
   return fields.filter((v,i)=>i%8===0&&['3','13','74'].includes(v)).map(type=>`${id}:${type}`);
  });
  if(aiStarts.length)throw Error('Reaudit explicit AI starts: '+aiStarts.join(','));
  for(const r of global.rows){
   if(overrides.get(r.id)!==(r.enabled?'yes':'no'))throw Error(r.id);
   const a=r.raw.split(',');
   const eligible=r.enabled&&a[12]==='3'&&a[2]==='<all>'&&[0,1,4].includes(+a[4])&&['00000000','01000000','02000000','03000000','04000000','05000000'].includes(a[6].slice(8,16))&&a.slice(15,18).some(Number)&&Object.keys(r.force).some(k=>/^\d+$/.test(k));
   const techCapture=r.enabled&&a[12]==='3'&&a[2]==='<all>'&&a[4]==='7'&&['CAAIRP','CAOILD','CAMACH','CATHOSP'].includes(a[5]);
   const houses=Object.entries(global.houses).filter(([h,v])=>!v.player&&!v.passive&&v.iq>0&&!v.allies.includes('Russians')&&v.side===+a[12]&&(a[2]==='<all>'||a[2]===h||a[2]===v.country)).map(([h])=>h);
   rows.push([mission,'全局 aimd',r.id.toUpperCase(),overrides.get(r.id),r.raw,a[1],r.team.taskforce,r.team.script,eligible||techCapture?'部分接线：静态可进入评估':'不进入现有选择分支',techCapture?'第19批：中立设施条件与工程师到门后原房归属；夹具核对四条条件，未逐ID证实原场有目标或自然出厂':eligible?(['0611a33c-g','043f521c-g'].includes(r.id)?'第7批 --naval-reminder 实测零售比较边界；正式候选，未验原场出厂': 'phase4 接管后受资金、单位、招募/真实工厂门槛；未逐ID证实原场可达'):'第19批静态审计：原房/IQ/阵营候选 '+(houses.join('/')||'无')+'；条件码 '+a[4]+'；未证明原版不可达']);
   if(eligible&&rally16(r))rows.at(-1)[9]+='；第16批归队/前方集结进入正式队伍指令，按ID验证下令；未新增选队规则';
   rows.at(-1)[9]+='；第22批返城开局逐ID检查三档，未满足有效候选的全部门槛；无自然出厂证据';
   if(!eligible&&!techCapture)rows.at(-1)[9]+='；第24批：SOV01 零售 Actions 无生产/自动编队/AI 触发启动动作（3/13/74）；不凭 Enable 覆盖提前启动其它房';
   if(!eligible&&!techCapture){
    const matching=houses.filter(h=>global.houses[h].techLevel>=Number(a[3]));
    rows.at(-1)[9]+='；第25批：原规则要求科技 '+a[3]+'，符合阵营/所属国/IQ/初始科技的敌房 '+(matching.join('/')||'无')+'；正式选队已比较房科技；尚无原场启动证据';
    if(!matching.length)rows.at(-1)[9]+=houses.length?'；匹配国家的敌房初始科技不足':'；无匹配国家的作战房';
    rows.at(-1)[9]+='；retail-inherited-houses 按原 ID 检查三档房筛选';
    if(r.id==='0cdf8edc-g')rows.at(-1)[9]+='；隔离激活房经正式选队、兵营扣款出两只警犬及冷读续训；非原场自然出厂';
    if(Object.values(r.force).some(x=>/^\d+,(ADOG|DOG)$/.test(x)))rows.at(-1)[9]+='；由原警犬编号解析为本阵营生产单位';
   }
   if(r.id==='043f521c-g')rows.at(-1)[9]+='；第20批困难脚本展开已可执行，战场夹具验证原房建造厂与恢复条件关闭，未验原场出厂';
  }
 }else{
  const guardIds=new Set(['0B0615AC','0B08899C','0B08884C','0B08830C','0F7CBAEC','0F7CB99C','0F7CB84C','0C887AEC','0C88799C']);
  const seen=new Set();
  for(const [id,def] of local){
   const a=def.split(','), team=get(a[1]), force=team.get('taskforce'), script=team.get('script');
   const compiled=n===1?hollywood.find(r=>r[0].toLowerCase()===id):head.find(r=>r.id===id);
   if(!compiled||!force||!script||seen.has(id))throw Error(id);
   seen.add(id);
   const rawCommands=[...get(script)].filter(([key])=>/^\d+$/.test(key)).map(([,v])=>v);
   const guard=n===1&&guardIds.has(id.toUpperCase());
   if(guard&&(rawCommands.join('|')!=='11,11|49,0'||JSON.stringify(rawCommands.map(s=>s.split(',').map(Number)))!==JSON.stringify(compiled[10])))throw Error('Guard script drift '+id);
   const empty=![...get(force).keys()].some(k=>/^\d+$/.test(k));
   const move=n===1&&rawCommands.some(s=>/^(3|16),/.test(s));
   if(move&&JSON.stringify(rawCommands.map(s=>s.split(',').map(Number)))!==JSON.stringify(compiled[10]))throw Error('Movement script drift '+id);
   const quarry=n===1&&rawCommands.some(s=>/^0,/.test(s));
   if(quarry&&JSON.stringify(rawCommands.map(s=>s.split(',').map(Number)))!==JSON.stringify(compiled[10]))throw Error('Quarry script drift '+id);
   const evidence=n===2&&s07Defense[id]?'第10批 --retail-defense-routes，逐ID验证移动、警戒等待及下一航点；自然出厂和交火未逐条验':quarry?'第9批逐ID实测目标类别下令；未逐队验抵达交火'+(id==='0f7cb6fc'?'；另有本房扣费齐员实测':'')+(move?'；第8批另验路线':''):move?'第8批 --retail-movement-ai 逐ID验移动/巡逻顺序下令；未全程抵达和交火':guard?'第6批 --retail-guard-ai 覆盖前置、扣费、齐员、区域警戒；逐条自然交火未验':n===1&&id==='0f7cb6fc'?'--retail-ai 本房步兵生产、扣费、齐员出击；交火未逐ID验':empty?'零售原编组无成员，运行排除':'进入共享调度；本表未逐ID记录实测，勿当成完整';
   rows.push([mission,'本图',id.toUpperCase(),overrides.get(id)??'',def,a[1],force,script,empty?'空编组：不接为可造队':'部分接线：正式候选',evidence+(n===2&&s07Drivers.production[id]?'；第18批原版启用、TeamType 所属房及 TaskForce 编组进入正式选队和排产；逐ID校对，未逐队自然交火':'')+(n===2&&s07Drivers.production[id]?'；第21批逐ID夹具验证本房资金差一/足额与可用产线；不计自然排产或逐队出厂':'')+(n===1&&id==='0ba16edc'?'；第21批完整生产名单触发原局部15，进入 0963AA4C 分支':'')+(n===2&&s07Drivers.weightFeedback.rules[id]?'；第17批脚本49成功及队伍退出反馈调整选队权重；按ID结算测试':'')+(n===2&&s07Drivers.assaults[id]?'；第15批原队伍攻击顺序/航点/集结进入出厂后正式流程；逐ID下令测试':'')+(n===1&&rawCommands.some(s=>/^(53|54),/.test(s))?'；第14批集结/重新编队与航点顺序进入正式出厂流程；逐ID下令测试':'')+(n===1&&h13[id.toUpperCase()]?'；第13批原启用开关、条件、阈值、难度和起始权重进入正式选队；逐ID比较测试':'')+(n===2&&s07Drivers.forceCount[id]?'；第12批原玩家兵力目标、比较符和阈值；逐ID边界实测':'')+(n===2&&s07Drivers.credit[id]?'；第11批敌方余额条件按玩家钱包、原比较符，逐ID边界验证':'')]);
  }
  if(seen.size!==(n===1?hollywood:head).length)throw Error('Data/raw count drift '+mission);
 }
}
if(rows.length!==276)throw Error('Expected 275 AI rows');
fs.writeFileSync(out,rows.map(r=>r.join('\t')).join('\n')+'\n');
