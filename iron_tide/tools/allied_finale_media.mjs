// Run from the project: node tools/allied_finale_media.mjs STEAM_YR_DIR FFmpeg
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [dir,ffmpeg]=process.argv.slice(2);
if(!dir||!ffmpeg) throw Error('Supply retail game directory and FFmpeg executable');
const src=new YrSource(dir), archive=src.loose('movmd03.mix');
src.indexMix(archive.data,archive.source,0);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'it-allied-media-'));
const out='assets/ra2/allied_finale';fs.mkdirSync(out,{recursive:true});
const result={};
for(const id of ['A07_F00E','A07_P01E','A08_F00E']){
  const hit=src.read(id+'.bik');if(!hit)throw Error('Missing '+id);
  const input=path.join(temp,id+'.bik');fs.writeFileSync(input,hit.data);
  const args=['-hide_banner','-loglevel','error','-y','-i',input,'-map','0:v:0'];
  if(id==='A07_P01E')args.push('-an');else args.push('-map','0:a:0','-c:a','libvorbis','-q:a','4');
  execFileSync(ffmpeg,[...args,'-threads','2','-c:v','libtheora','-q:v','6',`${out}/${id}.ogv`]);
  result[id]={source:hit.source,sha256:sha256(hit.data)};
}
const voices={};const audioOut='assets/ra2/sfx/allied_finale';fs.mkdirSync(audioOut,{recursive:true});
for(const name of ['a07_p01','xa7ev04','macev02','ceva021','ceva120']){
  const file=name+'.wav';const hit=src.read(file);if(!hit)throw Error('Missing '+file);
  const input=path.join(temp,file);fs.writeFileSync(input,hit.data);
  execFileSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-i',input,'-c:a','pcm_s16le',`${audioOut}/${file}`]);
  voices[name]={source:hit.source,sha256:sha256(hit.data)};
}
fs.writeFileSync('data/ra2/allied_finale_media.json',JSON.stringify({clips:result,voices},null,2)+'\n');
