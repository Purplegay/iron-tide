// Run from iron_tide: node tools/allied_first_media.mjs STEAM_YR_DIR FFMPEG_EXE
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const [dir, ff] = process.argv.slice(2);
if (!dir || !ff) throw Error('Supply the retail directory and FFmpeg');
const src=new YrSource(dir), mix=src.loose('movmd03.mix');
src.indexMix(mix.data,mix.source,0);
const dest='assets/ra2/allied_first';
fs.mkdirSync(dest,{recursive:true});
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'it-allied-first-'));
const provenance={};
for(const [id,name,out,options] of [
 ['A01_F00E','A01_F00E.bik','A01_F00E.ogv',['-c:v','libtheora','-q:v','6','-c:a','libvorbis']],
 ['A01_P01E','A01_P01E.bik','A01_P01E.ogv',['-c:v','libtheora','-q:v','6','-an']],
 ['A01_P03E','A01_P03E.bik','A01_P03E.ogv',['-c:v','libtheora','-q:v','6','-c:a','libvorbis']],
 ['A01_P02E','A01_P02E.bik','A01_P02E.ogv',['-c:v','libtheora','-q:v','6','-c:a','libvorbis']],
 ...['xa1ev06','xa1ta01','cevau75'].map(id=>[id,id+'.wav',id+'.wav',['-c:a','pcm_s16le']]),
 ['a01_p01','a01_p01.wav','a01_p01.wav',['-c:a','pcm_s16le']],
]){
 const hit=src.read(name);if(!hit)throw Error('Missing '+name);
 const input=path.join(tmp,name);fs.writeFileSync(input,hit.data);
 execFileSync(ff,['-hide_banner','-loglevel','error','-y','-i',input,...options,'-threads','2',`${dest}/${out}`]);
 if(id==='A01_P03E') execFileSync(ff,['-hide_banner','-loglevel','error','-y','-ss','4','-i',input,'-frames:v','1','-vf','scale=320:-2','-c:v','libwebp','assets/ui/cg_gallery/A01_P03E.webp']);
 if(id==='A01_P01E') execFileSync(ff,['-hide_banner','-loglevel','error','-y','-ss','2.75','-i',input,'-frames:v','1','-update','1',`${dest}/A01_P01E_hold.png`]);
 provenance[id]={source:hit.source,sha256:sha256(hit.data)};
}
const theater=theaterReader(src,'NEWURBAN');
const sprite=theater.shape('CAPOWR') || theater.read('capowr.shp');
if(!sprite) throw Error('Missing NEWURBAN CAPOWR; refusing to use other theaters');
const shp=decodeShp(sprite.data), cols=Math.min(8,shp.frames.length), atlas=montageIndexed(shp,cols);
const pal=decodePal(theater.palette().data);
// Runtime house shader expects the same blue ramp as other capturable buildings.
// Leave authored colors outside the 16 house indices untouched, including red warning lights.
for(let i=16;i<32;i++){
 const at=i*4, level=pal[at]/252;
 [87,168,255].forEach((component,j)=>pal[at+j]=Math.round(component*level));
}
const stem='assets/ra2/shp/CAPOWR';
fs.writeFileSync(stem+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,pal));
fs.writeFileSync(stem+'.json',JSON.stringify({id:'CAPOWR',image:'CAPOWR',source:sprite.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:2,shadow:true})+'\n');
fs.writeFileSync('data/ra2/allied_first_media.json',JSON.stringify(provenance,null,2)+'\n');
