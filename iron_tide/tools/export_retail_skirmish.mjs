// Extract the retail rules used by skirmish and expedition house controllers.
import fs from 'node:fs';
import {YrSource, sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';

const [game, output] = process.argv.slice(2);
const source = new YrSource(game);
const file = name => source.read(name).data;
const aim = file('aimd.ini'), rules = file('rulesmd.ini');
const ai = parseIni(aim.toString('latin1')), ini = parseIni(rules.toString('latin1'));
const section = (data, key) => data.get(key.toLowerCase()).keys;
const numbered = map => [...map].filter(([k]) => /^\d+$/.test(k)).map(([,v]) => v);
const buildings = [...section(ini,'BuildingTypes').values()];
const rows = {};
for (const [key, trigger, teamId] of [
  ['hunter', null, '0CA48EFC-G'], ['flak','0CA2FEDC-G'], ['patrol_soviet','0A452C6C-G'], ['patrol_allied','0A452E5C-G']
]) {
  const fields = trigger && section(ai,'AITriggerTypes').get(trigger.toLowerCase()).split(',');
  const team = section(ai, teamId || fields[1]);
  const [count, unit] = numbered(section(ai, team.get('taskforce')))[0].split(',');
  const steps = numbered(section(ai,team.get('script'))).map(v => v.split(',').map(Number));
  rows[key] = {team: teamId || fields[1], trigger, unit, count:+count, steps,
    sites:steps.filter(([op])=>op===58).map(([,arg])=>buildings[arg & 65535])};
  if (fields) {
    const check = Buffer.from(fields[6],'hex');
    if (fields[4]!=='0' || check.readUInt32LE(4)!==3) throw Error('Unexpected comparison '+key);
    Object.assign(rows[key],{enemy:fields[5], minimum:check.readUInt32LE(0), difficulties:fields.slice(15,18).map(x=>x==='1')});
  }
}
const base = section(ini,'AI'), general = section(ini,'General');
const missions = Object.fromEntries(['Move','Patrol','Guard','Area Guard','Attack','Harvest','Sleep','Hunt','Capture','Enter'].map(k=>[k,section(ini,k).get('retaliate')!=='no']));
const data={aim_sha256:sha256(aim),rules_sha256:sha256(rules),rows,missions,power_surplus:+base.get('powersurplus'),
  aa_ratio:+base.get('aaratio'),aa_limit:+base.get('aalimit'),safe_distance:+general.get('aisafedistance'),
  scan_delay:{normal:+general.get('normaltargetingdelay'),area_guard:+general.get('guardareatargetingdelay')},
  defenses:Object.fromEntries(['allied','soviet','third'].map(k=>[k==='third'?'yuri':k,base.get(k+'basedefenses').split(',')]))};
// Preserve native IDs and ordered data, including registered but unreferenced teams.
const records = (index, fn) => Object.fromEntries([...section(ai,index).values()].map(raw => {
  const id = raw.toUpperCase();
  return [id,fn(section(ai,id),id)];
}));
const formations = records('TaskForces', map => numbered(map).map(entry => {
  const [count,product] = entry.split(',');
  return {count:Number(count),product};
}));
const scripts = records('ScriptTypes', map => numbered(map).map(step => step.split(',').map(Number)));
const teams = records('TeamTypes', map => ({
  name:map.get('name'), force:map.get('taskforce').toUpperCase(), script:map.get('script').toUpperCase(),
  max:+map.get('max'), recruiter:map.get('recruiter')==='yes', defense:map.get('isbasedefense')==='yes',
  suicide:map.get('suicide')==='yes', transports_return:map.get('transportsreturnonunload')==='yes',
  only_enemy:map.get('onlytargethouseenemy')==='yes'
}));
const rulesById = {};
for(const [rawId,value] of section(ai,'AITriggerTypes')) {
  const a=value.split(','), compare=Buffer.from(a[6],'hex');
  if(a.length!==18 || compare.length!==32) throw Error(rawId);
  const id=rawId.toUpperCase();
  const primary=a[1].toUpperCase(), secondary=a[14]==='<none>'?'':a[14].toUpperCase();
  for(const team of [primary,secondary].filter(Boolean)) {
    if(!teams[team] || !formations[teams[team].force] || !scripts[teams[team].script]) throw Error(id+' unresolved '+team);
  }
  rulesById[id]={name:a[0].trim(),primary,secondary,country:a[2],tech:+a[3],condition:+a[4],object:a[5],
    threshold:compare.readUInt32LE(0),comparison:compare.readUInt32LE(4),weight:+a[7],min:+a[8],max:+a[9],
    skirmish:a[10]==='1',side:['all','allied','soviet','yuri'][+a[12]],difficulty:a.slice(15,18).map(x=>x==='1')};
}
const prefixKeys=['BuildConst','BuildPower','BuildRefinery','BuildBarracks','BuildWeapons','BuildRadar','BuildTech','BuildNavalYard'];
const production=Object.fromEntries(prefixKeys.map(k=>[k,base.get(k.toLowerCase()).split(',')]));
const roles={refinery:'Refinery',barracks:'Barracks',factory:'War',defense:'Defense',aa:'AA',tesla:'Tesla',airfield:'Helipad'};
const quotas=Object.fromEntries(Object.entries(roles).map(([k,v])=>[k,{ratio:+base.get(v.toLowerCase()+'ratio'),limit:+base.get(v.toLowerCase()+'limit')}]));
const list=k=>general.get(k.toLowerCase()).split(',').map(Number);
Object.assign(data,{triggers:rulesById,teams,formations,scripts,buildings,production,quotas,
  team_delays:list('TeamDelays'),team_caps:list('TotalAITeamCap'),defense_caps:list('MaximumAIDefensiveTeams'),
  near_ready:+general.get('aiminorsuperreadypercent'),success_delta:+general.get('aitriggersuccessweightdelta'),
  failure_delta:+general.get('aitriggerfailureweightdelta')});
fs.writeFileSync(output,JSON.stringify(data,null,2)+'\n');
