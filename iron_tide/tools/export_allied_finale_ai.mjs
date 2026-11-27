// Export supported retail AITrigger/Team/TaskForce/Script rows from the audited ALL07SMD index.
import fs from 'node:fs';
const [input,output] = process.argv.slice(2);
const source = JSON.parse(fs.readFileSync(input,'utf8'));
if (source.audit.id !== 'yr_all07smd') throw Error('Wrong mission');
const get = (kind,id) => source.definitions[kind][id];
function team(id) {
 const t=get('TeamTypes',id), f=get('TaskForces',t.taskforce), s=get('ScriptTypes',t.script);
 return {id, house:t.house, entry:t.waypoint, units:Object.entries(f).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>{const [n,type]=v.split(',');return [type,+n];}), script:Object.entries(s).filter(([k])=>/^\d+$/.test(k)).map(([,v])=>v.split(',').map(Number))};
}
const rules=[];
for(const id of ['08da8edc','04f45edc','0970ac3c','08da437c','04f45d8c','08da5aec','0e6056ac','092fec4c','092feafc','092fe9ac','092fe77c','092fcedc','092fc9bc','092fc86c','092fc71c','092fe62c','092fe4dc','092fe38c','092fe23c','0461114c','04612edc','04612d8c','0951918c','0c22299c','0e60594c','0e6057fc','0e5fd30c','0961666c','0958630c','095861bc','09580edc','09688aec','09586c6c','095a4d8c','095a4c3c','095f7dac','0e6041fc','06c708cc','09689edc','0970845c','0961504c','095afcac','08da399c','095af68c','0931e30c','0931e1bc','0931cedc','0931cd8c','09592b4c','095929fc','0931e6fc','0931e5ac','0931e45c','0931cc3c','0931caec','0931c99c','0931c84c','0931c6fc','0931c5ac','09fa77cc','0931c1bc','087ad90c','087ab06c','087ae07c','087cd83c','087cd63c','087cf0bc','087cf34c','087cfbbc','0968b30c','091a884c','091ada5c','091ad90c','079ceedc','0a6b550c','09505c9c','0950e05c','0950d05c','0c576c3c','13525d8c','095192dc','0a5a71bc','05ed315c','05ed772c']){
 const a=source.tables.AITriggerTypes[id].split(',');
 const bytes=Buffer.from(a[6],'hex');
 if(source.tables.AITriggerTypesEnable[id]!=='yes'||bytes.readUInt32LE(4)!==3)throw Error(id);
 const room=({YuriCountry:'YuriCountry',Yuri2Country:'Yuri2',Yuri3Country:'Yuri3'})[a[2]];
 if(!room)throw Error('Unknown trigger owner '+id);
 rules.push({id,room,condition:+a[4],name:a[0],related:a[5],count:bytes.readUInt32LE(0),weight:+a[7],difficulty:a.slice(-3).map(Number),team:team(a[1])});
}
const raids = rows => rows.map(([id,t])=>({id,trigger:source.triggers[id],team:team(t)}));
fs.writeFileSync(output,JSON.stringify({hash:source.audit.sha256,raids:raids([['0960d93c','08D5D5FC'],['0464c5fc','08D686CC'],['0b7ae1ec','08D680EC'],['0b2e9edc','08D6945C'],['0b829cac','08D6A1CC']]),armor_raids:raids([['09713f3c','08D57B5C'],['0b8000cc','08D6BA4C'],['0b80c2bc','08D6CB7C'],['0b82737c','08D6DC8C'],['0b807b1c','08D6D18C']]),rules},null,1)+'\n');
