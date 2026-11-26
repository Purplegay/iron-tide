import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodePal,decodeShp,frameToRgba,encodePng,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const source=new YrSource(process.argv[2]), theater=theaterReader(source,'TEMPERATE');
const rules=parseIni(source.read('rulesmd.ini').data.toString('latin1')),art=parseIni(source.read('artmd.ini').data.toString('latin1'));
const field=JSON.parse(fs.readFileSync('data/head_games_field.json'));
const directory='assets/maps/yr/head_games';fs.mkdirSync(directory,{recursive:true});
const iso=decodePal(source.read('isotem.pal').data),unit=decodePal(theater.palette().data),cameo=decodePal(source.read('cameo.pal').data);
function first(hit,palette,path){const f=decodeShp(hit.data).frames[0];fs.writeFileSync(path,encodePng(f.w,f.h,frameToRgba(f,palette,{originX:-f.x,originY:-f.y})));}
for(const id of new Set(field.props.map(row=>row[0]))){const file=theater.read(id+'.tem')||theater.read(id+'.shp')||source.read(id+'.shp');if(!file)throw Error(id);first(file,iso,`${directory}/${id}.png`);}
for(const id of Object.keys(JSON.parse(fs.readFileSync('data/maps/yr_sov07.json')).site_types)){
 if(fs.existsSync(`assets/ra2/shp/${id}.png`))continue;
 const rule=getSec(rules,id)?.keys;if(rule?.get('invisibleingame')==='yes')continue;
 const image=rule?.get('image')||id;const file=theater.shape(image)||source.read(image+'.shp');if(!file)throw Error(id);
 const shp=decodeShp(file.data),cols=Math.min(8,shp.frames.length),atlas=montageIndexed(shp,cols),base='assets/ra2/shp/'+id;
 fs.writeFileSync(base+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,unit));fs.writeFileSync(base+'.json',JSON.stringify({id,image:id,source:file.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:Math.min(2,shp.frames.length/2),shadow:true}));
}
const icons={};for(const id of ['BRUTE','VIRUS','YURIPR','MIND','TELE','CAOS','DISK']){const image=getSec(rules,id).keys.get('image')||id,icon=getSec(art,image).keys.get('cameo').split(';')[0];const file=source.read(icon+'.shp');const path=`assets/ra2/cameo/${icon}.png`;first(file,cameo,path);icons[id]={cameo:'res://'+path};}fs.writeFileSync('data/head_games_icons.json',JSON.stringify(icons,null,1)+'\n');
