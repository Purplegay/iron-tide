import {unpackOverlay} from './head_games_overlays.mjs';
import {buildingAnimationRange} from '../../ra2pipe/building_animation_ranges.mjs';
import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const source=new YrSource(process.argv[2]), theater=theaterReader(source,'TEMPERATE');
const map=parseIni(fs.readFileSync(process.argv[3],'latin1')),rules=parseIni(source.read('rulesmd.ini').data.toString('latin1')),art=parseIni(source.read('artmd.ini').data.toString('latin1'));
const section=(table,id)=>Object.fromEntries(getSec(table,id)?.keys||[]);
const save=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,1)+'\n');
const rows=Object.values(section(map,'Structures')).map(line=>line.split(','));
const lights=[],sites=[],plan=[],powers={};
for(const [house,id,health,x,y] of rows){
 const pos=[201.5-y,x-10.5];
 if(section(rules,id).invisibleingame==='yes'){const r={...section(rules,id),...section(map,id)};lights.push([id,...pos,+r.lightvisibility,+r.lightintensity,+r.lightredtint,+r.lightgreentint,+r.lightbluetint]);}
 else sites.push([id,...pos,+health,house]);
}
for(const [key,line] of Object.entries(section(map,'BadGuy3 House'))){if(!/^\d{3}$/.test(key))continue; const [id,x,y]=line.split(',');if(id==='GAWALL')plan.push([id,201.5-y,x-10.5]);}
const extractPack=name=>unpackOverlay(fs.readFileSync(process.argv[3],'latin1').split('['+name+']')[1].split('[')[0].trim().split(/\r?\n/).map(s=>s.slice(s.indexOf('=')+1).trim()).join(''));
const overlay=extractPack('OverlayPack'), frames=extractPack('OverlayDataPack'), types=[...getSec(rules,'OverlayTypes').keys.values()], overlaySites=[],counts={};
for(const [u,v] of JSON.parse(fs.readFileSync('data/maps/yr_sov07.json')).cells){const at=v+11+(201-u)*512,id=types[overlay[at]];counts[id]=(counts[id]||0)+1;if(/WALL|CAFNC|FENC|GARD|FARM|HAY|BARL|DRUM|CRAT/i.test(id||''))overlaySites.push([id,u+.5,v+.5,frames[at]]);}
console.log(counts);
const palette=decodePal(theater.palette().data);
function sheet(id,image,remap){const hit=theater.shape(image)||source.read(image+'.shp');const shp=decodeShp(hit.data),cols=Math.min(8,shp.frames.length),atlas=montageIndexed(shp,cols),stem='assets/ra2/shp/'+id;const pal=palette.slice();if(remap)for(let i=16;i<32;i++){let v=pal[i*4]/252;[87,168,255].forEach((c,j)=>pal[i*4+j]=Math.round(c*v));}fs.writeFileSync(stem+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,pal));save(stem+'.json',{id,image,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:2,shadow:true});}
for(const [id,name] of [['YAPPET','心灵控制器'],['YAGNTC','基因突变器']]){const r=section(rules,id),a=section(art,id);sheet(id,id,true);const layer=a.superanim;sheet(layer,section(art,layer).image||layer,true);const make=(key)=>({image:key,...buildingAnimationRange(key,section(art,key),JSON.parse(fs.readFileSync('assets/ra2/shp/'+key+'.json')).count/(section(art,key).shadow==='yes'?2:1)),rate:Number(section(art,key).rate||200),shadow:section(art,key).shadow==='yes',loopCount:-1});const idle=make(layer);if(a.superanimdamaged){const key=a.superanimdamaged;sheet(key,section(art,key).image||key,true);idle.dmg=make(key);}save('assets/ra2/bldanim/'+id+'.json',{id,layers:[{kind:'superanim',...idle}]});powers[id]={id,name,ra2:true,faction:'yuri',hp:+r.strength,ra2_armor:r.armor,sight:+r.sight*55,cost:+r.cost,role:'structure',role_name:'建筑',tags:['structure'],armor:'structure',foundation:a.foundation,radius:35,builds:[],capturable:r.capturable==='true',power:+r.power,powered:r.powered==='yes'};}
for(const [id,name] of [['CAFNCB','黑色木栅栏'],['CAFNCW','白色木栅栏']]){
 sheet(id,id,false);
 const file='assets/ra2/shp/'+id+'.json',body=JSON.parse(fs.readFileSync(file));
 console.log(id,body.count);
 body.wall_layout={variants:16,damage_levels:Math.max(1,Math.floor(body.count/32)),shadow_start:body.count/2};save(file,body);
 powers[id]={id,name,hp:100,ra2:true,faction:'civilian',ra2_armor:'wood',role:'structure',role_name:'围栏',tags:['civilian','wall'],armor:'structure',foundation:'1x1',radius:20,builds:[],power:0,sight:0,cost:0};
}
sheet('CAFARM01','CAFARM01',false);
save('data/head_games_sites.json',{sites,lights,plan,powers,overlaySites});
console.log({sites:sites.length,lights:lights.length,plan:plan.length});