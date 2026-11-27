// Generate the executable ALL01 AI slice from this map's switches and the verified retail AIMD catalog.
import fs from 'node:fs';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
const [auditPath,rulesPath,game,output,inventory] = process.argv.slice(2);
if (inventory && /(?:^|[\\/])ALL01UMD_AI_RECHECK\.tsv$/i.test(inventory)) throw Error('Use ALL01UMD_GLOBAL_AI_RECHECK.tsv for AIMD. The mission ledger uses export_allied_first_map_ai.mjs.');
const map = JSON.parse(fs.readFileSync(auditPath));
const aimBytes=new YrSource(game).read('aimd.ini').data;
const aim=parseIni(aimBytes.toString('latin1'));
const aimHash=sha256(aimBytes);
const defs=aim.get('aitriggertypes').keys;
const record=id=>Object.fromEntries(aim.get(id.toLowerCase()).keys);
if (map.audit.id!=='yr_all01umd' || map.tables.Basic.ignoreglobalaitriggers!=='no' || aimHash!=='5df41eaec00a78d0760ef5eecdf27d65ae1cd537309c7eac973318266986f89d') throw Error('Unexpected ALL01/AIMD inputs');
const rules = parseIni(fs.readFileSync(rulesPath,'latin1'));
const types = [...rules.get('buildingtypes').keys.values()];
const rooms = Object.fromEntries(Object.entries(map.definitions.Houses).map(([name,h])=>[name,{color:h.color,tech:Number(h.techlevel),country:h.country}]));
const colors = Object.fromEntries([...new Set(Object.values(rooms).map(h=>h.color))].map(key=>[key,rules.get('colors').keys.get(key.toLowerCase()).split(',').map(Number)]));
const ids = Object.keys(map.tables.AITriggerTypesEnable);
if (ids.some(id=>!defs.has(id))) throw Error('Unresolved AI switch');
const supported = ['0c8c2c3c-g','0ca2a04c-g','0ca2b06c-g','0ca2fedc-g'];
const rows = supported.map(id=>{
  const a=defs.get(id).split(','), predicate=Buffer.from(a[6],'hex');
  const team=record(a[1]), r={force:record(team.taskforce),script:record(team.script)};
  const [number,product]=r.force['0'].split(','), [op,index]=r.script['0'].split(',').map(Number);
  if(a[4]==='0'){
    const steps=Object.entries(r.script).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
    const target=types[index & 65535];
    if(a[2]!=='<all>' || a[12]!=='2' || predicate.readUInt32LE(4)!==3 || a[14]!=='<none>' || number!=='6' || product!=='FLAKT' || !['ORCA','BEAG','ZEP'].includes(a[5]) || target!=='NAFLAK' || index>>>16!==2 || JSON.stringify(steps)!=='[[58,131139],[21,0],[11,11]]')throw Error('Unsupported flak team '+id);
    return {id,name:a[0],enabled:map.tables.AITriggerTypesEnable[id]==='yes',tech:Number(a[3]),difficulty:a.slice(15,18).map(v=>v==='1'),threat:a[5],minimum:predicate.readUInt32LE(0),team_max:Number(team.max),quantity:Number(number),requires:rules.get(product.toLowerCase()).keys.get("prerequisite").split(","),weight:Number(a[7]),product,team:a[1],target,steps};
  }
  if(a[2]!=='<all>' || a[4]!=='1' || a[12]!=='2' || predicate.readUInt32LE(4)!==1 || number!=='1' || a[14]!=='<none>' || op!==58 || types[index]!=='NAREFN') throw Error('Unsupported AI semantics '+id);
  return {id,name:a[0],enabled:map.tables.AITriggerTypesEnable[id]==='yes',tech:Number(a[3]),difficulty:a.slice(15,18).map(v=>v==='1'),weight:Number(a[7]),own_type:a[5],maximum:predicate.readUInt32LE(0),team_max:Number(team.max),product,team:a[1],target:types[index]};
});
const team_delays=rules.get('general').keys.get('teamdelays').split(',').map(Number);
fs.writeFileSync(output,JSON.stringify({map_sha:map.audit.sha256,aimd_sha:aimHash,total:ids.length,rooms,colors,team_delays,rows},null,1)+'\n');
if(inventory){
 // ALL01 has a single production owner. Keep source feasibility separate from executable coverage.
 const production = new Set();
 for (const r of Object.values(map.triggers)) {
   const fields = r.actions.split(',');
   for(let i=1;i<fields.length;i+=8) if(fields[i]==='3') production.add(map.tables.Houses[fields[i+2]]);
 }
 const room = map.definitions.Houses.Confederation;
 if(production.size!==1 || !production.has('Confederation') || room.nodecount!=='1' || room['000']!=='YAPPPT,46,69' || room.techlevel!=='2') throw Error('Recheck ALL01 production owner and base plan');
 function retailGate(a){
   if(!['0','2'].includes(a[12]) || !['<all>',room.country.toLowerCase()].includes(a[2].toLowerCase())) return '生产房阵营或国家不适用';
   if(Number(a[3])>Number(room.techlevel)) return '所需科技 '+a[3]+' 高于本房等级 '+room.techlevel;
   const team = record(a[1]);
   const force = Object.entries(record(team.taskforce)).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v).join(' + ');
   const target = a[5]==='<none>' ? '' : '，条件对象 '+a[5];
   return '本房原图无生产设施，基地计划仅 YAPPPT；主队 '+force+target+'。未观测到自然选队';
 }
 const lines=['AI ID\t正式战场状态\t本图开关\t名称\t主队伍\t原始 AIMD 字段\t原图生产房条件'];
 for(const id of ids){const raw=defs.get(id),a=raw.split(',');lines.push([id,supported.includes(id)?'正式接入（生产前置与适用难度受限）':'待接入',map.tables.AITriggerTypesEnable[id],a[0],a[1],raw,retailGate(a)].join('\t'));}
 fs.writeFileSync(inventory,lines.join('\n')+'\n');
}
