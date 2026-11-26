// Run with the retail installation and a directory containing the extracted sov01.map.
import fs from 'node:fs';
import path from 'node:path';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {MixFile,MixEntry,DataStream} from '../../tools/ra2bundle.mjs';
import {getSec,parseIni} from '../../ra2pipe/lib/ini.mjs';
import {decodePal,decodeShp,encodePngIndexed,montageIndexed,frameToRgba,encodePng} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const [game,work]=process.argv.slice(2),source=new YrSource(game),theater=theaterReader(source,'NEWURBAN');
const map=parseIni(fs.readFileSync(path.join(work,'sov01.map'),'latin1'));
const rules=parseIni(source.read('rulesmd.ini').data.toString('latin1')),art=parseIni(source.read('artmd.ini').data.toString('latin1')),eva=parseIni(source.read('evamd.ini').data.toString('latin1'));
const sec=(table,id)=>Object.fromEntries(getSec(table,id)?.keys||[]);
const field=JSON.parse(fs.readFileSync('data/time_shift_field.json'));
const root='assets/ra2/time_shift';fs.mkdirSync(root+'/terrain',{recursive:true});
const pal=decodePal(theater.palette().data),iso=decodePal(source.read('isoubn.pal').data);
for(let i=16;i<32;i++){const shade=pal[i*4]/252;[87,168,255].forEach((v,j)=>pal[i*4+j]=Math.round(v*shade));}
const names={CATIME01:'时光机',CATIME02:'时光机',YAPPPT:'建造中的心灵控制器',CASANF03:'旧金山民居',CAMACH:'科技机械维修厂',CATHOSP:'科技医院'};
const previous=JSON.parse(fs.readFileSync('data/time_shift_assets.json'));
const defs={...previous.defs},voices={};
for(const id of new Set(field.sites.map(r=>r[0]))){
 const r={...sec(rules,id),...sec(map,id)},image=r.image||id,a=sec(art,image);if(r.invisibleingame==='yes')continue;
 const base='assets/ra2/shp/'+id;
 if(!fs.existsSync(base+'.png')){const hit=theater.shape(image)||source.read(image+'.shp');if(!hit){console.log('no art',id,image);continue;}
 const shp=decodeShp(hit.data),cols=Math.min(8,shp.frames.length),at=montageIndexed(shp,cols);fs.writeFileSync(base+'.png',encodePngIndexed(at.width,at.height,at.indices,pal));fs.writeFileSync(base+'.json',JSON.stringify({id,image,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:at.rects,dmg:Math.min(2,shp.frames.length/2),shadow:true}));}
 defs[id]={id,name:previous.defs[id]?.name||names[id]||(id.startsWith('GAPOWR')?'科技发电厂':r.canbeoccupied==='yes'?'可驻军建筑':'旧金山建筑'),ra2:true,role:'structure',faction:'civilian',hp:parseInt(r.strength)||500,armor:'structure',ra2_armor:r.armor||'wood',power:parseInt(r.power)||0,sight:55*(parseInt(r.sight)||5),radius:30,foundation:a.foundation||'1x1',cost:0,tags:['civilian'],builds:[],base_normal:false,capturable:r.capturable==='yes'||r.capturable==='true'};
 if(/^GAPOWR[A-F]$/.test(id))defs[id].unsellable=['yes','true'].includes(r.unsellable);
 if(r.canbeoccupied==='yes')defs[id].garrison_slots=Number(r.maxnumberoccupants)||5;
}
for(const id of new Set(field.scenery.map(r=>r[0]))){const hit=theater.read(id+'.ubn')||theater.read(id+'.shp')||source.read(id+'.shp');if(!hit){console.log('no tree',id);continue;}const f=decodeShp(hit.data).frames[0];if(f.w&&f.h)fs.writeFileSync(`${root}/terrain/${id}.png`,encodePng(f.w,f.h,frameToRgba(f,iso,{originX:-f.x,originY:-f.y})));}
for(const cue of field.voices){const clip=sec(eva,cue).russian?.toLowerCase();if(!clip)continue;const hit=source.read(clip+'.wav');if(!hit)continue;fs.writeFileSync(path.join(work,clip+'.wav'),hit.data);voices[cue]=clip;}
fs.writeFileSync('data/time_shift_assets.json',JSON.stringify({...previous,defs,voices},null,1)+'\n');
const bytes=fs.readFileSync(path.join(game,'movmd03.mix'));const mix=new MixFile(new DataStream(new DataView(bytes.buffer,bytes.byteOffset,bytes.length)));for(const id of ['S01_F00E','S01_P01E','S01_P02E','S01_P03E']){const e=mix.getEntry(MixEntry.hashFilename(id+'.BIK'));if(!e)throw Error(id);fs.writeFileSync(path.join(work,id+'.bik'),bytes.subarray(mix.getDataStart()+e.offset,mix.getDataStart()+e.offset+e.length));}
