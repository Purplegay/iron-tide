// Run from the project with the local game directory and extracted ALL02UMD.MAP.
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {exportTurret} from './hollywood_turrets.mjs';
import {hollywoodShapeReader,exportAnimations} from './hollywood_animation.mjs';
const [game,mapFile]=process.argv.slice(2);
const src=new YrSource(game), map=parseIni(fs.readFileSync(mapFile,'latin1'));
const ini=name=>parseIni(src.read(name).data.toString('latin1'));
const rules=ini('rulesmd.ini'), art=ini('artmd.ini');
const section=(ini,id)=>Object.fromEntries(getSec(ini,id)?.keys || []);
const json=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,1)+'\n');
const root='assets/ra2/', pal=decodePal(src.read('unittem.pal').data);
for(let i=16;i<32;i++) {const shade=pal[i*4]/252;[87,168,255].forEach((c,k)=>pal[i*4+k]=Math.round(c*shade));}
const names={YAGRND:'部队回收厂',YAGGUN:'盖特机炮',YABRCK:'尤里兵营',YAPOWR:'生物反应炉',YAWEAP:'尤里战车工厂',YACNST:'尤里建造场',NATBNK:'坦克碉堡',NAPSIS:'心灵感应器',CAOILD:'科技钻油井'};
const desc={YAGRND:'摧毁或渗透回收厂，救下正在赶往厂门的居民。',YAGGUN:'持续射击逼近的地面部队或飞机。断电时停止射击。',YABRCK:'尤里新兵在兵营附近守卫基地。',YAPOWR:'满血时提供 300 电力。选中己方步兵右键进入，每人增加 100 电力，最多 5 人。点击炉内头像可撤出。',YAWEAP:'尤里基地的装甲车辆工厂。',YACNST:'尤里主基地的建造中心。',NATBNK:'容纳一辆坦克。驻车可以在掩体内开火。',NAPSIS:'尤里的心灵侦察设施。',CAOILD:'定期为控制它的一方提供资金。'};
const shapes=new Map();
const readShape=hollywoodShapeReader(src);
function sheet(id,image,body=false){
 if(shapes.has(id))return shapes.get(id);
 const source=readShape(image);
 if(!source)throw Error('Missing '+image);
 const shp=decodeShp(source.data),count=shp.frames.length,cols=Math.min(count,8),atlas=montageIndexed(shp,cols);
 fs.writeFileSync(root+'shp/'+id+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,pal));
 json(root+'shp/'+id+'.json',{id,image,source:source.source,source_sha256:sha256(source.data),cell:[shp.width,shp.height],cols,count,rects:atlas.rects,dmg:body?Math.min(2,count/2):1,shadow:true});
 shapes.set(id,count);return count;
}
function layer(id){const a=section(art,id),image=a.image||id,count=sheet(image,image)/2;
 return {image,frames:count,shadow:true,loopStart:Number(a.loopstart||0),loopEnd:Number(a.loopend||count-1),rate:Number(a.rate||300),loopCount:-1};}
function gun(id){const r=section(rules,id);return {name:id,ra2_weapon_id:"YR_HOL_"+id,...(r.burst ? {burst:Number(r.burst)} : {}),damage:+r.damage,range:+r.range*55,cooldown:+r.rof/15,attack_type:id.startsWith('ATGUN')?'cannon':'bullet',ra2_projectile:r.projectile,ra2_warhead:"YR_HOL_"+r.warhead,ra2_aa:/^AA/.test(id),projectile_speed:1100,report:r.report};}
const buildings={};
for(const [id,name] of Object.entries(names)){
 const r={...section(rules,id),...section(map,id)},a=section(art,id);
 const b=buildings[id]={id,name,desc:desc[id],ra2:true,role:'structure',role_name:'建筑',faction:id==='CAOILD'?'civilian':'yuri',foundation:a.foundation,armor:'structure',ra2_armor:r.armor,hp:+r.strength,cost:Number(r.cost||0),power:Number(r.power||0),powered:r.powered?.toLowerCase()==='yes',sight:Number(r.sight||5)*55,radius:Math.max(...a.foundation.split('x').map(Number))*12,tags:['structure'],builds:[],base_normal:r.basenormal?.toLowerCase()!=='no'};
 if(id==='CAOILD'){Object.assign(b,{oil_startup:+r.producecashstartup,oil_amount:+r.producecashamount,oil_period:+r.producecashdelay/15});continue;}
 b.capturable = r.capturable?.toLowerCase() === 'true' || r.capturable?.toLowerCase() === 'yes';
 if(id==='YAPOWR')Object.assign(b,{garrison_slots:+r.passengers,extra_power:+r.extrapower,size_limit:+r.sizelimit});
 if(id==='NATBNK')b.garrison_slots=1;
 if(id==='YAGGUN'){b.guns=Array.from({length:6},(_,i)=>gun(r['weapon'+(i+1)]));b.weapon={...b.guns[0],ra2_aa:true};}

 sheet(id,id,true);
 const layers=[];
 for(const kind of ['idleanim','activeanim','activeanimtwo','activeanimthree','activeanimfour'])if(a[kind]){const l={kind,...layer(a[kind])};if(a[kind+'damaged'])l.dmg=layer(a[kind+'damaged']);layers.push(l);}
 if(id === "YAPOWR") {
  // Each sheet is two equal health runs, followed by their shadow masks.
  for (const l of layers) {
   const half = l.frames / 2;
   Object.assign(l, {loopStart:0, loopEnd:half-1});
   Object.assign(l.dmg, {loopStart:half, loopEnd:l.frames-1});
  }
  layers.push(layers.shift()); // lights go above the animated body
 }
 if(layers.length)json(root+'bldanim/'+id+'.json',{id,layers});
}
const r=section(rules,'LTNK');const tank={id:'LTNK',name:'狂风坦克',desc:'用坦克炮攻击地面目标，也可以进驻坦克碉堡。',faction:'yuri',role:'vehicle',role_name:'载具',tags:['vehicle'],armor:'heavy',ra2_armor:r.armor,ra2:true,hp:+r.strength,cost:+r.cost,sight:+r.sight*55,speed:+r.speed*15,radius:16,weapon:gun(r.primary),elite_weapon:gun(r.eliteprimary),move:{turret:true,crusher:true,rot_units:+r.rot,speed_units:+r.speed,movement_zone:r.movementzone}};
const initiate=JSON.parse(fs.readFileSync('data/ra2/death.json')).crew_units.INIT;
initiate.weapon=gun('PsychicJab'); initiate.elite_weapon=gun('PsychicJabE');
const catalog={buildings,units:{LTNK:tank,INIT:initiate}};
for (const unit of Object.values(catalog.units)) {
 const rule = {...section(rules,unit.id), ...section(map,unit.id)};
 if (rule.buildtimemultiplier !== undefined) unit.build_time_multiplier = Number(rule.buildtimemultiplier);
}
exportAnimations(game,catalog);
json('data/hollywood_yuri.json',catalog);
const rows=Object.values(section(map,'Structures')).map(v=>v.split(',')).filter(([house,id])=>house.startsWith('Yuri')&&id!=='YAGRND');
json('data/maps/hollywood_sites.json',rows.map(([h,id,_,x,y])=>[id,+x,+y,h]));
for(const id of ['LTNK','YAGGUN'])exportTurret(src,pal,id);
execFileSync(process.execPath,['tools/yuri_building_theaters.mjs',game],{stdio:'inherit'});
