// Run from project: node tools/allied_voice_extras.mjs STEAM_YR_DIR FFmpeg
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
const [install,ffmpeg]=process.argv.slice(2);
if(!install||!ffmpeg) throw Error('Need Steam YR folder and FFmpeg');
const src=new YrSource(install);
const eva=parseIni(src.read('evamd.ini').data.toString('latin1'));
const folder='assets/ra2/sfx/allied_finale';
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'it-a7-extra-'));
const result={};
for(const key of ['EVA_PsychicDominatorDetected','EVA_GeneticMutatorDetected','Mis_xA7_EvaBuildUpQuickly','Mis_xA7_EvaUnholyAlliance','Mis_xA7_YuriTaunt','Mis_xA7_EvaBoomerThreat','Mis_xA7_EvaBriefing01','Mis_xA7_EvaProtectSovietBase','Mis_xS4_YuriTacticsTaunt']){
 const row=eva.get(key.toLowerCase()).keys;
 const name=row.get('allied').toLowerCase();
 const hit=src.read(name+'.wav');if(!hit)throw Error('Missing '+name);
 const input=path.join(tmp,name+'.wav');fs.writeFileSync(input,hit.data);
 const target=`${folder}/${name}.wav`;
 execFileSync(ffmpeg,['-v','error','-y','-i',input,'-c:a','pcm_s16le',target]);
 result[key]={sample:name,source:hit.source,sha256:sha256(hit.data),text:row.get('text')||''};
}
fs.writeFileSync('data/ra2/allied_finale_voice_extras.json',JSON.stringify(result,null,1)+'\n');
