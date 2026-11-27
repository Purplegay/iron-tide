// Export only the retail records explicitly covered by the first runtime slice.
// Usage: node tools/export_allied_script_slice.mjs AUDIT_DIR OUTPUT_JSON
import fs from 'node:fs';
import path from 'node:path';

const [audit, output] = process.argv.slice(2);
if (!audit || !output) throw Error('Expected AUDIT_DIR and OUTPUT_JSON');
const selections = {
  yr_all01umd_closing: '067dd9fc 085159ec 06a4918c 080e410c 043808cc 043772bc 04378f3c 0438076c 0437c23c 089cf54c 043bb08c 0a992f3c 0b7c0aec 0e0ea53c 07a89e6c 07a89c0c 079b8bbc 079bae6c 061ff03c 07ec78ac'.split(' '),
  yr_all01umd_assault: '08134e0c 0813427c 08136abc 08135c1c 06a0a20c 0bb731dc 06a0a03c 0b16029c 0bb74dfc 06a0cc6c 0895c19c 0b160e5c 08b5892c 0bb74afc 0b7d4bcc 0895d88c 089fc90c 0b1613dc 0b7d615c 089d698c 089fc3dc 0bdf7bbc 0a81149c 069b22fc 0a81491c 068f215c 08a868ec 0a815afc 089627fc 08a8953c 089f2aac 08a8fbcc 08a8e55c 0b025f3c 087f3e6c 0b022dec 087f124c 087f198c 0b7d6aac 08a2318c 0b1612ec 0b7d315c 0b024e1c 0b0246cc 0885de3c 06c7108c 08a77a5c 0437e7ec 0611babc 096d092c'.split(' '),
  yr_all01umd: ['0691357c','0be0b26c','0a8e573c','0a8ea21c','0a8e0e9c','08a3e03c','089ec19c','089ecdec','089ec79c','0bd650ac','0bd6117c','045cef3c','06178d0c',
    '089ae11c','089ae71c','089afc3c','0d87303c','0930139c','0930470c','067dd4bc','0cf0864c',
    '0693bf3c','08ae3e3c','0bbc1e3c','0bbced7c','05e9106c','0790df3c','05ee7c8c','05ee7b9c','087c0e4c','087c0f3c','087c0d5c','07a8917c','07a8ccbc','07a8d3ec','0835813c','0935a09c','0b8a090c'],
  yr_all07smd: ['0b2eb76c','0f823b7c','0967d33c','0964b13c','0460bdbc','098db96c','09000cdc','0900786c','07ca72bc','0c8d4f3c','06b9b43c','0a57f46c','0a57b28c','08ed7a3c','0908b62c','078bff3c','0908b71c','098dc46c','078bf6ac','078c04bc','078c00bc','0988e66c','0780a03c','0ba8052c','0901606c','0ba8312c','08cb932c','08cbabbc','08cbef3c','08cba88c','0462be5c','0b8152bc','078f6e5c','078f692c','078f71ec','0930a91c','093138dc','08cba40c','04f0aacc','0901213c','0901648c','08f6724c','08f9a04c','0f22154c','0c028afc','0960df3c','046336ec','0be87edc','08e89b1c','0be87b9c','079b37cc','0bdca03c','0464d1bc','0b7a95fc','0b2bd0fc','096a485c','0b7f91ac','0b7fe1ac','0b84b0fc','0b7f92fc','0960d93c','0464c5fc','0b7ae1ec','0b2e9edc','0b829cac','09713f3c','0b8000cc','0b80c2bc','0b82737c','0b807b1c','0de26e5c','0de1124c','06c3397c','0de086ac','094e805c','0bb2e0fc','0e6533ec','08e97bec','08e9757c','04e8103c','0960ee5c','04f32afc','090ad17c','0955dd2c','0ee0857c','078f61fc','061bd4ec','09197edc']
};
const fieldNames = new Set(["WindSounds1_Pre","WindSounds2_Pre","Crickets1","Wind3","Water_Sounds1","Kill_Sounds1","Kill_Sounds2","Kill_Sounds3","Start_New_Sounds","Start_Sounds2","Traffic_Sounds1","Traffic_Sounds2","Traffic_Sounds3","Traffic_Sounds4","Traffic_Sounds5","Bird_Sounds1","Bird_Sounds2","Bird_Sounds3","Make_People2","Make_Alcatraz_Men","Camera_Bridge","Camera_HarrierStart","Camera_Harriers","Barracks_Gone","Engineer_Check","Engineers_Arrived","Apocs_Gone","Enter_Tanya","Tanya_Death","Death_Reinforce","Send_Carriers","Ping_Carriers","Carriers_Killed","Reveal_Gatt1","Reveal_Gatt2","Reveal_Gatt3","Reveal_Gatt4","TurnOff_Gatt1","TurnOff_Gatt2","TurnOff_Gatt4","TurnOn_Gatt1","TurnOn_Gatt2","TurnOn_Gatt4","Gatt_Brief","Check_BridgePiece02","Stop_Rebuild","Kill_Pipes","Time_Machine_Hit","Time_Machine_Attacked","Find_Hospital"]);
const result = {};
for (const [id, selectionsForMap] of Object.entries(selections)) {
  const sourceMap = id.startsWith('yr_all01umd_') ? 'yr_all01umd' : id;
  const src = JSON.parse(fs.readFileSync(path.join(audit, `${sourceMap}_index.json`), 'utf8'));
  const included = new Set(selectionsForMap);
  if (id === 'yr_all01umd') {
    for (const [key, row] of Object.entries(src.triggers)) {
      const name = row.trigger.split(',')[2];
      if (fieldNames.has(name)) included.add(key);
      if (/^PP[1-8]_(Is|Not)_(America|Neutral)$/.test(name) || ["Create_Stuff2","Play_Movies","Make_Civ_Cars1","Make_Civ_Cars2","Make_People","Create_Kirov","Mission1_Text","Mission2_Text"].includes(name)) included.add(key);
      if (["Deploy_Start_GI","Deploy_Start_GGI","Deploy_GGI_Group2","Start_AA_AB_Patrol","Start_AF_AH_Patrol","Start_RD_U_Patrol","Start_RHRL_Patrol","Start_CityP","Start_AD_GD_Patrol","Start_ZC_EE_Patrol","Start_AB_GX_Patrol","Camera_GGI","GGI_GuineaPig_Start","Damage_Reactor"].includes(name) || /^(GivePower|TakePower)[1-8]$/.test(name)) included.add(key);
      if (/^(Player_Has_Plant[1-8]|Obj01_Complete_Text|Center_On_TimeMachine|Time_Machine_Boom2|PP[1-8]_(Destroyed|Check_Easy|Entered)|(Losing|Lost)_Power_[1-5]|(Losing|Lost)PP[1-7]_Easy|Enable_EasyPP_Check|PP[1-4]_Group_Done_(True|FalseA|FalseB)|Check_PP[2-4]_(True|False)|Ping_PP_(One|Three|Four)|Good_Job_1|Sell_Psychic|Cannon[1-4]_Gone|Rebuild_Cannon[1-4]|Start_PP[3-6]_Checks?|Change_House_PP[12]|PP[1-8]_PlayerAttack|PowerAttacked)$/.test(name)) included.add(key);
    }
  }
  const rows = Object.entries(src.triggers).filter(([key]) => included.has(key));
  if (rows.length !== included.size || src.audit.id !== sourceMap) throw Error(`Missing retail records for ${id}`);
  const ids = new Set(Object.keys(src.triggers));
  const external = new Set();
  const triggers = rows.map(([key, record]) => {
    const [house, linked, name, disabled, easy, normal, hard, transfer] = record.trigger.split(',');
    if (![disabled,easy,normal,hard,transfer].every(v => ['0','1'].includes(v))) throw Error(`Invalid flags in ${key}`);
    const events = record.events.split(',');
    const actions = record.actions.split(',');
    const ev = [];
    const ac = [];
    let i = 1;
    for (let n = 0; n < Number(events[0]); ++n) {
      const width = events[i+1] === '2' ? 4 : 3;
      ev.push(events.slice(i, i+width));
      i += width;
    }
    if (i !== events.length || actions.length !== 1+Number(actions[0])*8) throw Error(`Invalid record width in ${key}`);
    for (let a = 1; a < actions.length; a += 8) {
      const fields = actions.slice(a,a+8);
      if (['53','54'].includes(fields[0])) {
        const target = fields[2].toLowerCase();
        if (!ids.has(target)) throw Error(`Unresolved target ${target} in ${key}`);
        if (!included.has(target)) external.add(target);
      }
      ac.push(fields);
    }
    return {id:key, name, house, linked:linked.toLowerCase(), transfer:transfer==='1', disabled:disabled==='1',
      difficulty:[easy,normal,hard].map(v => v==='1'), events:ev, actions:ac, tags:record.tags};
  });
  const teams = {};
  for (const row of triggers) for (const [op,,param] of row.actions) {
    if (!['4','7','80','107'].includes(op) || teams[param.toLowerCase()]) continue;
    const lookup = (name,key) => Object.entries(src.definitions[name]).find(([k]) => k.toLowerCase()===key.toLowerCase())?.[1];
    const team = lookup('TeamTypes',param);
    const task_force = team && lookup('TaskForces',team.taskforce);
    const script = team && lookup('ScriptTypes',team.script);
    if (!team || !task_force || !script) throw Error(`Unresolved reinforcement ${param} in ${row.id}`);
    teams[param.toLowerCase()] = {team, task_force, script};
  }
  const waypoints = {};
  for (const row of triggers) for (const action of row.actions) {
    if (!['4','7','80','107','108','125'].includes(action[0])) continue;
    const code = ['4','7'].includes(action[0]) ? teams[action[2].toLowerCase()].team.waypoint : action[7];
    if (id === 'yr_all07smd' && action[0] === '4' && !code) continue;
    if (!/^[A-Z]+$/.test(code)) throw Error(`Invalid waypoint ${code} in ${row.id}`);
    const number = [...code].reduce((value, letter) => 26*value + letter.charCodeAt(0)-64, 0)-1;
    const packed = Number(src.tables.Waypoints[number]);
    if (!Number.isSafeInteger(packed)) throw Error(`Missing waypoint ${code} (${number}) in ${row.id}`);
    const [minX,maxY] = src.audit.retail_origin;
    waypoints[code] = {id:number, xy:[packed%1000, Math.floor(packed/1000)], uv:[maxY-Math.floor(packed/1000)+0.5, packed%1000-minX+0.5]};
  }
  if (id === 'yr_all01umd') {
    // These map-created ships enter independently of the global AIMD production switches.
    const fleet = {};
    for (const key of ['085159ec','067dd9fc','089d5a8c','04c24a8c']) {
      fleet[key] = [];
      const fields = src.triggers[key].actions.split(',');
      const lookup = (kind, name) => src.definitions[kind][name.toLowerCase()] ?? src.definitions[kind][name];
      for (let i = 1; i < fields.length; i += 8) {
        if (!['7','80'].includes(fields[i])) continue;
        const teamId = fields[i+2], team = lookup('TeamTypes',teamId);
        const task = lookup('TaskForces',team.taskforce), script = lookup('ScriptTypes',team.script);
        const members = Object.entries(task).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(','));
        if (members.length !== 1 || members[0][0] !== '1') throw Error('Unexpected naval force '+teamId);
        const code = fields[i] === '7' ? team.waypoint : fields[i+7];
        const waypoint = [...code].reduce((n,c)=>26*n+c.charCodeAt(0)-64,0)-1;
        const steps = Object.entries(script).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
        if (!src.tables.Waypoints[waypoint] || !steps.length || !steps.every(([op,arg])=>[1,3,6,11,42,46,59].includes(op) && (![1,3,59].includes(op) || src.tables.Waypoints[arg]))) throw Error('Unresolved naval script '+teamId);
        fleet[key].push({id:teamId,house:team.house,unit:members[0][1],waypoint,script:team.script,steps});
      }
    }
    src.naval_fleet = fleet;
  }
  result[id] = {sha256:src.audit.sha256, locals:Object.fromEntries(Object.entries(src.tables.VariableNames).map(([k,v])=>[k,v.split(',')[1]==='1'])),
    external:[...external].sort(), triggers, teams, waypoints};
  if (id === 'yr_all01umd') {
    const fieldRows = triggers.filter(r=>fieldNames.has(r.name));
    if(fieldRows.length!==fieldNames.size) throw Error('Missing ALL01 field records');
    const cells={};
    for(const row of fieldRows.filter(r=>r.events.some(e=>['59','1'].includes(e[0])))){
      const linked=new Set([row.id]);
      for(let size=-1;size!==linked.size;){
        size=linked.size;
        for(const [id,r] of Object.entries(src.triggers)) if(linked.has(r.trigger.split(',')[1].toLowerCase())) linked.add(id);
      }
      const tags=new Set(Object.entries(src.tables.Tags).filter(([,v])=>linked.has(v.split(',')[2].toLowerCase())).map(([id])=>id));
      cells[row.id]=Object.entries(src.tables.CellTags).filter(([,v])=>tags.has(v.toLowerCase())).map(([key])=>Number(key));
      if(!cells[row.id].length) throw Error('Missing cell tags '+row.name);
    }
    result[id].field_rows=Object.fromEntries(fieldRows.map(r=>[r.id,r.name]));
    result[id].field_cells=cells;
    const aux = {};
    for (const [tag, value] of Object.entries(src.tables.Tags)) {
      const name = value.split(',')[1];
      const number = /^GivePower([1-8])$/.exec(name)?.[1];
      if (!number) continue;
      const matches = Object.entries(src.tables.Structures).filter(([,v])=>v.split(',')[6].toLowerCase()===tag);
      if (matches.length!==1) throw Error('Missing tagged auxiliary plant '+name);
      const [index, raw] = matches[0], [house,kind] = raw.split(',');
      if (house!=='PowerHouse' || kind!=='GAPOWR') throw Error('Unexpected auxiliary plant '+index);
      aux[number] = {index,house,kind};
    }
    if(Object.keys(aux).length!==8) throw Error('Expected eight tagged power plants');
    result[id].auxiliary_plants = aux;
  }
  if (id==='yr_all01umd_closing') {
    const attached={};
    for(const row of triggers){
      const chain=new Set([row.id]);
      for(let count=-1;count!==chain.size;){
        count=chain.size;
        for(const [key,r] of Object.entries(src.triggers)) if(chain.has(r.trigger.split(',')[1].toLowerCase())) chain.add(key);
      }
      const tags=new Set(Object.entries(src.tables.Tags).filter(([,v])=>chain.has(v.split(',')[2].toLowerCase())).map(([k])=>k));
      attached[row.id]=Object.entries(src.tables.Structures).filter(([,v])=>tags.has(v.split(',')[6].toLowerCase())).map(([k])=>k);
    }
    const sites={};
    for(const [wp,type,width,height] of [[34,'CASANF02',3,3],[36,'CAGAS01',3,3]]){
      const cell=Number(src.tables.Waypoints[wp]);
      const matches=Object.entries(src.tables.Structures).filter(([,v])=>{
        const [,kind,,x,y]=v.split(',');
        return type===kind && cell%1000>=+x && cell%1000<+x+width && Math.floor(cell/1000)>=+y && Math.floor(cell/1000)<+y+height;
      });
      if(matches.length!==1) throw Error('Missing garrison site at '+wp);
      sites[wp]=matches[0][0];
    }
    Object.assign(result[id],{houses:src.tables.Houses,attached,assault_sites:sites});
  }
  if (id==='yr_all01umd_assault') {
    const harriers = triggers.find(r=>r.name==='Kill_Harriers');
    const cells = Object.values(harriers.tags).flat();
    if(cells.length!==1 || triggers.length!==50 || Object.keys(teams).length!==15) throw Error('ALL01 assault source count');
    // Zero-based source cells use raw map X/Y and the building's NW origin.
    // Foundations are CASANF01=2x3 and CASANF02=3x3 in retail artmd.ini.
    const assaultSites={};
    for(const [wp,type,width,height] of [[19,'CASANF01',2,3],[77,'CASANF02',3,3]]){
      const cell=Number(src.tables.Waypoints[wp]);
      const match=Object.entries(src.tables.Structures).filter(([,value])=>{
        const [,kind,,x,y]=value.split(',');
        const dx=cell%1000-Number(x),dy=Math.floor(cell/1000)-Number(y);
        return kind===type && dx>=0 && dx<width && dy>=0 && dy<height;
      });
      if(match.length!==1) throw Error('Unresolved assault site at '+wp);
      assaultSites[wp]=match[0][0];
    }
    Object.assign(result[id],{houses:src.tables.Houses, harrier_cell:cells[0],assault_sites:assaultSites});
  }
  if (id==='yr_all01umd') Object.assign(result[id],{houses:src.tables.Houses,naval_fleet:src.naval_fleet});
}
fs.writeFileSync(output, JSON.stringify(result,null,1)+'\n');
