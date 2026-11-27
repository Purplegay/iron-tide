// Compile the supported SOV01 sea reinforcement slice from the retail map.
import fs from 'node:fs';
import {triggerBindings} from './retail_trigger_bindings.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [source,out='data/maps/time_shift_fleet.json']=process.argv.slice(2);
const raw=fs.readFileSync(source);
const hash=sha256(raw);
if(hash!=='498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b')throw Error('Wrong SOV01UMD map');
const m=parseIni(raw.toString('latin1'));
function get(s,k){const v=m.get(s.toLowerCase())?.keys.get(k.toLowerCase());if(v===undefined)throw Error(`${s}/${k}`);return v;}
function tuples(s,k,width){const [count,...data]=get(s,k).split(',');if(data.length!==Number(count)*width)throw Error(`Bad tuple size ${s}/${k}`);return Array.from({length:Number(count)},(_,i)=>data.slice(i*width,(i+1)*width));}
const actions=id=>tuples('Actions',id,8), events=id=>tuples('Events',id,3);
const of=(rows,op)=>rows.filter(r=>r[0]===String(op));
function only(rows){if(rows.length!==1)throw Error(JSON.stringify(rows));return rows[0];}
function waypoint(key){const n=[...key].reduce((acc,c)=>acc*26+c.charCodeAt(0)-64,0)-1;get('Waypoints',String(n));return n;}
function timer(id){const [op,,s]=only(events(id));if(op!=='13')throw Error(id);return Number(s);}
function team(id){
 const tag=get(id,'Tag');const detect=get('Tags',tag).split(',').at(-1);
 if(only(events(detect))[0]!=='48')throw Error(detect);
 const script=get(id,'Script'), force=get(id,'TaskForce');
 const [find,set]=[get(script,'0').split(','),get(script,'1').split(',')];
 const [qty,type]=get(force,'0').split(',');
 if(find[0]!=='40'||set[0]!=='3'||qty!=='1'||get(id,'House')!=='Russians')throw Error(id);
 const slot=Number(set[1]);get('Waypoints',String(slot));
 const flag=only([...of(actions(detect),56),...of(actions(detect),53)]);
 return {id,tag,detect,flag:flag[0]==='56'?Number(flag[2]):null,slot,type,ingress:waypoint(get(id,'Waypoint'))};
}
const stop='0B752F3C';
const disarm=only(of(actions(stop),53).filter(a=>a[2]==='0BBB5C6C'))[2];
const groups=['0968EE5C','0966AC6C','0966170C','0968D20C'].map(id=>{
 if(!of(actions(stop),54).some(a=>a[2]===id))throw Error(id);
 const acts=actions(id), ships=of(acts,7).map(a=>team(a[2]));
 const enabled=of(acts,53).map(a=>a[2]);
 const notice=only(enabled.filter(e=>of(actions(e),55).length));
 const rearm=enabled.find(e=>e!==notice);
 const delay=rearm?timer(id):0;
 if(rearm){
  if(only(of(actions(rearm),53))[2]!==only(ships).detect||only(of(actions(ships[0].detect),53))[2]!==id)throw Error(id);
 }else{
  const flags=events(id).map(([op,,v])=>{if(op!=='36')throw Error(id);return Number(v);});
  if(flags.join()!==ships.map(s=>s.flag).join())throw Error('Flag/team mismatch '+id);
 }
 const cue=of(actions(notice),21).map(a=>a[2]);
 return {id,delay,rearm:rearm?timer(rearm):0,notice,notice_delay:timer(notice),cue:cue[0]??'',flash:of(actions(notice),55).map(a=>waypoint(a[7])),ships};
});
const opening=['0B8913EC','0B890BCC','0B8906FC','0B896E6C'].map(id=>({id,delay:timer(id),teams:of(actions(id),7).map(a=>a[2])}));
const detectors=of(actions(disarm),54).map(a=>a[2]);
const fleet=[...m.get('teamtypes').keys.values()].flatMap(id=>{
 const tag=m.get(id.toLowerCase())?.keys.get('tag');
 const detect=tag&&m.get('tags').keys.get(tag.toLowerCase())?.split(',').at(-1);
 return detectors.includes(detect)?[team(id)]:[];
});
if(fleet.length!==13||new Set(fleet.map(s=>s.slot)).size!==13||fleet.map(s=>s.detect).sort().join()!==detectors.sort().join())throw Error('Fleet/disarm mismatch');
const openingTeams=opening.flatMap(r=>r.teams);
if(openingTeams.length!==9||!openingTeams.every(id=>fleet.some(ship=>ship.id===id)))throw Error('Opening action/team mismatch');
const complete=only(of(actions(disarm),53))[2];
const completeActions=actions(complete);
const objective={id:complete,delay:timer(complete),cue:only(of(completeActions,21))[2],text:only(of(completeActions,11))[2]};
const reminderId='094D448C';
if(!of(actions(stop),54).some(a=>a[2]===reminderId)||!of(actions('0D0E096C'),53).some(a=>a[2]===reminderId))throw Error('Reminder links changed');
const reminder={id:reminderId,delay:timer(reminderId),text:only(of(actions(reminderId),11))[2]};
const power=[];
let next='094A4ADC';
for(const group of ['', '', 'Reinforce_Atk Group 1','Reinforce_Cap Group 1','Reinforce_Atk Group 2','Reinforce_Cap Group 2']){
 const id=next, act=actions(id), flags=get('Triggers',id).split(',');
 const enables=of(act,53).map(a=>a[2]);
 const ping=enables.find(k=>get('Triggers',k).split(',')[2].startsWith('Reinforce_Atk Ping'));
 next=enables.find(k=>/^(Audio_YuriCapturePower|Reinforce_(Atk|Cap) Group)/.test(get('Triggers',k).split(',')[2]));
 if(group&&flags[2]!==group)throw Error(id);
 power.push({id,delay:timer(id),difficulty:flags.slice(4,7).map(Number),group,cue:of(act,21)[0]?.[2]??'',ping:ping?{id:ping,delay:timer(ping),slot:waypoint(only(of(actions(ping),55))[7])}:null});
}
const transportReturns={};
const script=(id)=>[...m.get(get(id,'Script').toLowerCase()).keys].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
const flagUses=new Map();
for(const wave of power.filter(p=>p.group))for(const a of of(actions(wave.id),7)){
 const cmds=script(a[2]);const flag=cmds.find(c=>c[0]===39)[1];
 const unload=cmds.findIndex(c=>c[0]===8);
 if(unload<1||cmds[unload-1][0]!==3)throw Error(a[2]);
 const shore=cmds[unload-1][1];
 flagUses.set(`${wave.group}|${shore}`,flag);
}
for(const [key,flag] of flagUses){
 const matches=[...m.get('triggers').keys].filter(([,v])=>/^.*,Create_.*(?:Atk|Cap).*Trans,/i.test(v)).map(([id])=>id.toUpperCase()).filter(id=>{
  const ts=script(only(of(actions(id),4))[2]);return ts[0][0]===40&&ts[0][1]===flag;
 });
 const id=only(matches), a=actions(id), trigger=only(events(id));
 const craft=only(of(a,4))[2], cmds=script(craft), reset=only(of(a,53))[2], clear=only(of(actions(reset),57));
 if(trigger[0]!=='36'||cmds.at(-1)[0]!==37||!of(actions(reset),53).some(a=>a[2]===id))throw Error(id);
 transportReturns[key]={id,flag,event_flag:Number(trigger[2]),reset,clear_flag:Number(clear[2]),delay:timer(reset),route:cmds.filter(c=>c[0]===3).map(c=>c[1])};
}
if(Object.keys(transportReturns).length!==12)throw Error('Expected 12 return lanes');
const engineer={};
for(const [name,id] of Object.entries({sale:'096012AC',initial:'06AF616C',arrival:'077B395C',hint:'0970A63C',rescue:'06A25F3C',rescueArrival:'09FF490C',powerHint:'09577C4C'})){
 const a=actions(id), teamId=of(a,7)[0]?.[2];
 const cargo=teamId?get(get(teamId,'TaskForce'),'0').split(','):null;
 engineer[name]={id,delay:timer(id),cue:of(a,21)[0]?.[2]??'',text:of(a,11)[0]?.[2]??'',flash:of(a,55).map(x=>waypoint(x[7])),count:cargo?Number(cargo[0]):0};
}
const grid={plants:{},loss:[],full:{},warning:{},tech:{}};
for(const [key,value] of m.get('triggers').keys){
 const id=key.toUpperCase(), name=value.split(',')[2];
 if(/^Detect_Plant\d Destroyed$/.test(name)){
  const e=get('Events',id).split(',');if(e[1]!=='61')throw Error(id);
  grid.plants[e.at(-1)]={id,enable:of(actions(id),53).map(a=>a[2])};
 }
 if(/^Detect_[123] PP Gone (True|False)$/.test(name)){
  const e=only(events(id));grid.loss.push({id,op:Number(e[0]),flag:Number(e[2]),enable:of(actions(id),53).map(a=>a[2]),disable:of(actions(id),54).map(a=>a[2])});
 }
 if(/^Detect_Tech Power [A-F]$/.test(name)){
  const e=only(events(id)), type=Number(e[2]);if(e[0]!=='32'||type<402||type>407)throw Error(id);
  grid.tech['GAPOWR'+String.fromCharCode(65+type-402)]={id,enable:of(actions(id),53).map(a=>a[2])};
 }
}
for(const [k,id] of Object.entries({enough:'0951864C',complete:'08E495DC',camera:'0BDE0ADC',effect:'0BDE287C',animation:'0951A8BC'})){
 const a=actions(id);grid.full[k]={id,delay:timer(id),cue:of(a,21)[0]?.[2]??'',text:of(a,11)[0]?.[2]??'',disable:of(a,54).map(x=>x[2]),slot:of(a,112).length?waypoint(only(of(a,112))[7]):null};
}
grid.full.detect={id:'0BDE024C',enable:of(actions('0BDE024C'),53).map(a=>a[2]),disable:of(actions('0BDE024C'),54).map(a=>a[2])};
grid.attackWarnings={};
for(const [key,id] of Object.entries({machine:'06C0F45C',plant:'0951918C'})){
 const a=actions(id),e=only(events(id));if(e[0]!=='44')throw Error(id);
 grid.attackWarnings[key]={id,cue:only(of(a,21))[2],text:only(of(a,11))[2]};
}
grid.warning={id:'04429F3C',delay:timer('04429F3C'),cue:only(of(actions('04429F3C'),21))[2]};
grid.techDisable={id:'0442C90C',delay:timer('0442C90C'),disable:of(actions('0442C90C'),54).map(a=>a[2])};
if(Object.keys(grid.plants).length!==6||grid.loss.length!==6||Object.keys(grid.tech).length!==6)throw Error('Power grid slice drift');
const media={};
for(const id of ['094C722C','0DD8E18C','0D17F50C','0DD8E32C','0DE581DC','091B431C','0D17FAAC','0D17876C','09577E1C','043E7EDC','05BF392C','05BF375C','05BF366C','05BF4E3C','07837A2C','0439CD6C','0439C90C','0439C73C']){
 const a=actions(id),e=only(events(id));const flash=of(a,55)[0],camera=of(a,112)[0],marker=of(a,131)[0];
 media[id]={id,event:Number(e[0]),delay:e[0]==='13'?Number(e[2]):0,cue:of(a,21)[0]?.[2]??'',text:of(a,11)[0]?.[2]??'',enable:of(a,53).map(x=>x[2]),slot:flash?waypoint(flash[7]):null,camera:camera?waypoint(camera[7]):null,frames:marker?Number(marker[7]):0};
}
const ambience={};
for(const [key,value] of m.get('triggers').keys){
 const name=value.split(',')[2];if(!name.startsWith('_Amb_'))continue;
 const id=key.toUpperCase(), a=actions(id);if(!a.every(x=>x[0]==='99'))throw Error(id);
 ambience[id]={id,jurassic:name.startsWith('_Amb_Jur_'),points:a.map(x=>[x[2],waypoint(x[7])])};
}
const late={};
const lateIds=['07A5F24C','0441445C','0441427C','0441436C','0441418C','0441409C','04415F3C','04415E4C','04415D5C','04412A6C','04418C8C','07A190BC','0B63FB2C','0B63F5EC','0905A37C','0905A54C','0905A89C','0905B51C','090D21BC','0919E26C','09198F3C','09198B9C','09198D6C','091992BC','0919965C','09199BCC','0919948C','0919982C','091999FC','09199D9C','090437CC','044163EC','043E7B3C','043E7D0C','07A255BC','043EC4DC','07A256AC','097DB5BC','091696FC','07EF7AEC','097DFABC','0954F76C','097DF8EC','094A4E1C','0DECD98C','06B627BC','095714FC','0439E3FC','0439E05C','0439F31C','0443F8AC','0443FBCC','0443F6DC'];
const readTeam=(id,at)=>{const force=get(id,'TaskForce');const members=[...m.get(force.toLowerCase()).keys].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(','));const commands=script(id);return {at,members,route:of(commands,3).concat(of(commands,16)).map(r=>r[1])};};
for(const id of lateIds){
 const a=actions(id), ev=get('Events',id).split(','), shot=of(a,112)[0]??of(a,48)[0];
 const target=ev[1]==='61'?ev.at(-1):null;
 const tags=[...m.get('tags').keys].filter(([,v])=>v.split(',').at(-1).toUpperCase()===id).map(([key])=>key);
 const tagged=['units','infantry','structures'].flatMap(s=>[...(m.get(s)?.keys.values()??[])].map(v=>v.split(',')).filter(r=>r.some(x=>tags.includes(x.toLowerCase()))).map(r=>[r[1],Number(r[3]),Number(r[4])]));
 late[id]={id,delay:ev[1]==='13'?+ev[3]:0,enable:of(a,53).map(x=>x[2]),disable:of(a,54).map(x=>x[2]),camera:shot?waypoint(shot[7]):null,ping:of(a,55).map(x=>waypoint(x[7])),reveal:of(a,17).map(x=>waypoint(x[7])),cue:of(a,21)[0]?.[2]??'',text:of(a,11)[0]?.[2]??'',hit:of(a,63).map(x=>+x[2]),target,tagged,teams:of(a,80).map(x=>readTeam(x[2],waypoint(x[7]))),buildings:of(a,125).map(x=>[x[2],waypoint(x[7])])};
}
const staging={};
for(const id of ['094B2A9C','094BE2BC','0D0E096C','0D0E024C','06B6F36C','0D9BA33C','0D9BA16C','0D0E418C','088966DC','0B76DF3C','0B8A231C','05D70C3C','094A51CC','094A883C','094A989C','0BDE287C','0951740C','0951A8BC','0999579C','0C4A628C','0C57BA6C','07FA53DC','07EF43CC','0BDC985C','0BDCDD0C','0937049C','0BDCD47C','044286FC','095F1B8C','0885994C','090435FC','09040ADC','0962D87C','094D21AC','09533A5C','0C331D8C','088BEB4C','0970A22C','082C79BC','082C77EC','095183EC','0951A4BC','097DDE6C','06A6663C','0BBEFE3C','094848DC','0948645C','094822CC','0952E0FC','0952C96C','0952ED0C','0439097C']){
 const a=actions(id),e=get('Events',id).split(','),shot=of(a,112)[0]??of(a,48)[0];
 staging[id]={id,delay:Math.max(0,...events(id).filter(x=>x[0]==='13').map(x=>+x[2])),enable:of(a,53).map(x=>x[2]),disable:[...of(a,54),...of(a,12)].map(x=>x[2]),camera:shot?waypoint(shot[7]):null,reveal:of(a,17).map(x=>waypoint(x[7])),pings:[...of(a,55),...of(a,41)].map(x=>waypoint(x[7])),cue:of(a,21)[0]?.[2]??'',sound:of(a,19)[0]?.[2]??'',text:of(a,11)[0]?.[2]??'',film:of(a,100)[0]?.[2]??'',move:of(a,128).map(x=>+x[2]),transfer:of(a,14).map(x=>+x[2]),buildings:of(a,125).map(x=>[x[2],waypoint(x[7])]),fly:of(a,7).map(x=>readTeam(x[2],waypoint(get(x[2],'Waypoint')))).filter(t=>t.members.every(r=>r[1]==='ORCA'))};
}
const batch18={};
for(const id of ['0439013C','096012AC','0E626A2C','05BF138C','0951972C','0961762C','06B5FB2C','06B5F54C','0C55D39C','0439F14C','0439CF3C','0439C2DC','07EF508C','04415AFC','044149EC','079F9B1C','05DB7F3C']){
 const a=actions(id),shot=of(a,112)[0];
 batch18[id]={id,delay:Math.max(0,...events(id).filter(x=>x[0]==='13').map(x=>+x[2])),enable:of(a,53).map(x=>x[2]),cue:of(a,21)[0]?.[2]??'',camera:shot?waypoint(shot[7]):null,teams:[...of(a,7),...of(a,4)].map(x=>readTeam(x[2],get(x[2],'Waypoint')?waypoint(get(x[2],'Waypoint')):null))};
}
const alarmId='0971599C', alarmActions=actions(alarmId), [alarmEvent]=events(alarmId);
const powerAlarm={id:alarmId,kind:+alarmEvent[0],house:+alarmEvent[2],sound:of(alarmActions,19)[0][2],text:of(alarmActions,11)[0][2],cue:of(alarmActions,21)[0][2]};
if(powerAlarm.kind!==58||m.get('houses').keys.get(String(powerAlarm.house))!=='Arabs')throw Error('Wrong full power event');
const encounter={};
for(const id of ['094C5E4C','0D17008C']){
 const t=only(of(actions(id),4))[2], script=get(t,'Script');
 const commands=[...m.get(script.toLowerCase()).keys].filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number));
 encounter[id]={id,delay:timer(id),house:get(t,'House'),...readTeam(t,waypoint(get(t,'Waypoint'))),commands,veterancy:+get(t,'VeteranLevel')};
}
const lossFields=get('Events','05CAF0BC').split(',');
if(lossFields.join(',')!=='3,61,2,0,SAPC,57,0,25,57,0,61')throw Error('Unexpected boat loss condition');
const boatLoss={id:'05CAF0BC',transport:lossFields[4],recovery:['NACNST','NAYARD'],end:only(of(actions('05CAF0BC'),53))[2]};
boatLoss.delay=timer(boatLoss.end);
boatLoss.enable=of(actions('0962D87C'),53).some(x=>x[2]===boatLoss.id);
const phaseLinks={};
for(const id of ['096879AC','097651DC','0CAAF7DC','07F2978C','0937687C','078C97EC','079BB93C','082B950C','082B933C','087D15EC','09601D2C','0441BAAC','0C46AB3C']){
 const e=only(events(id)),a=actions(id);
 const tags=[...m.get('tags').keys].filter(([,v])=>v.toUpperCase().endsWith(','+id)).map(([k])=>k);
 const targets=['units','infantry','structures'].flatMap(k=>[...(m.get(k)?.keys.values()??[])].map(v=>v.split(',')).filter(v=>v.some(x=>tags.includes(x.toLowerCase()))).map(v=>v[1]));
 phaseLinks[id]={id,event:+e[0],argument:+e[2],delay:e[0]==='13'?+e[2]:0,actions:a,targets,enable:of(a,53).map(x=>x[2]),pings:of(a,101).map(x=>{const wp=waypoint(x[7]),p=+get('Waypoints',String(wp));return [p%1000,Math.floor(p/1000)];}),teams:of(a,4).map(x=>readTeam(x[2],waypoint(get(x[2],'Waypoint'))))};
}
const gridTransfer=phaseLinks['0C46AB3C'];
const binding=triggerBindings(m,gridTransfer.id);
if(binding.tags.join()!=='0c46aa5c'||binding.uses.length!==6||!staging['0BDC985C'].enable.includes('0BDCDD0C')||!staging['0BDCDD0C'].enable.includes(gridTransfer.id))throw Error('Grid transfer chain');
gridTransfer.house=get('Houses',only(of(gridTransfer.actions,14))[2]);
gridTransfer.sourceTag=get('Tags',binding.tags[0]).split(',')[1];
gridTransfer.sites={};
for(const {section,fields} of binding.uses){
 const [house,type,,x,y,,tag]=fields;
 if(section!=='structures'||house!=='Alliance'||tag.toLowerCase()!==binding.tags[0]||gridTransfer.sites[type])throw Error('Unexpected grid binding '+type);
 gridTransfer.sites[type]=[190-Number(y)+0.5,Number(x)-10+0.5];
}
if(gridTransfer.house!=='Americans'||Object.keys(gridTransfer.sites).sort().join()!=='GAPOWRA,GAPOWRB,GAPOWRC,GAPOWRD,GAPOWRE,GAPOWRF'||only(of(gridTransfer.actions,54))[2]!==gridTransfer.id)throw Error('Grid transfer definition');
gridTransfer.targets=Object.keys(gridTransfer.sites);
const landingTriggers={};for(const id of ['082C467C','082C44AC'])landingTriggers[id]={delay:timer(id)};
fs.writeFileSync(out,JSON.stringify({hash,stop,disarm,fleet,opening,groups,objective,reminder,power,transportReturns,engineer,grid,media,ambience,late,staging,landingTriggers,batch18,powerAlarm,encounter,boatLoss,phaseLinks},null,2)+'\n');
