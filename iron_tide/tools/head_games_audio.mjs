import fs from 'node:fs';
import {audioSamples} from './yr_audio_samples.mjs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {getSec,parseIni} from '../../ra2pipe/lib/ini.mjs';
const src=new YrSource(process.argv[2]);
const read=id=>parseIni(src.read(id).data.toString('latin1'));
const sounds=read('soundmd.ini'),rules=read('rulesmd.ini'),pack={units:{},specs:{},entries:{}};
const sample=audioSamples(src,pack,'head_games');
function event(id){
 if(!id)return '';
 const spec=Object.fromEntries(getSec(sounds,id)?.keys||[]);
 if(!spec.sounds)return '';
 pack.specs[id]={sounds:spec.sounds.toLowerCase().split(/\s+/).filter(Boolean).map(name=>sample(name.replace(/^[#$]+/,''))),volume:Number(spec.volume||1),range:Number(spec.range||10)};
 return id;
}
for(const id of ['BRUTE','VIRUS','YURIPR','MIND','TELE','CAOS','DISK']){
 const rule=Object.fromEntries(getSec(rules,id).keys);pack.units[id]={};
 for(const [key,field] of Object.entries({select:'voiceselect',move:'voicemove',attack:'voiceattack',feedback:'voicefeedback',die:'diesound',special:'voicespecialattack'})){const cue=event(rule[field]);if(cue)pack.units[id][key]=cue;}
 for(const key of ['primary','secondary','eliteprimary','elitesecondary'])if(rule[key])event(getSec(rules,rule[key])?.keys.get('report'));
}
for(const id of ['Terrorist-Sov07','DemoTruck-Sov07','NukeSiren'])event(id);
fs.writeFileSync('data/ra2/head_games_audio.json',JSON.stringify(pack,null,1)+'\n');
console.log(Object.keys(pack.entries).length,Object.keys(pack.specs).length);
