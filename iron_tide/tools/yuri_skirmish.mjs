import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {parseVpl} from '../../ra2pipe/voxel_surface.mjs';
import {loadNormals} from '../../ra2pipe/vxl_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
import {writeVoxelUnit} from './yr_voxel_unit.mjs';
const source=new YrSource(process.argv[2]), theater=theaterReader(source,'TEMPERATE');
const section=(ini,id)=>Object.fromEntries(getSec(ini,id)?.keys||[]);
const ini=name=>parseIni(source.read(name).data.toString('latin1'));
const art=ini('artmd.ini'),rules=ini('rulesmd.ini'),pal=decodePal(theater.palette().data),cameoPal=decodePal(source.read('cameo.pal').data);
for(let i=16;i<32;i++){const shade=pal[4*i]/252;[87,168,255].forEach((v,j)=>pal[4*i+j]=Math.round(v*shade));}
loadNormals('../refs/ts-ra2/src/data/vxl/normals.ts');const vpl=parseVpl(source.read('voxels.vpl').data);
const read=file=>JSON.parse(fs.readFileSync('data/'+file+'.json'));
const save=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,1)+'\n');
const allied=read('ra2_allied'),soviet=read('yr_soviet'),campaign=[read('hollywood_yuri'),read('hollywood_cast'),read('head_games')];
const products={YABRCK:['INIT','YENGINEER','BRUTE','VIRUS','YURI','YURIPR'],YAWEAP:['LTNK','YTNK','SMIN','PCV','MIND','TELE','CAOS','DISK'],YAYARD:['YHVR','BSUB']};
const names={PCV:'尤里基地车',YHVR:'尤里两栖运输艇',BSUB:'雷鸣潜艇',YAYARD:'尤里船坞',GAFWLL:'尤里围墙'};
const tags={YACNST:['hq'],YABRCK:['barracks','production'],YAWEAP:['factory','production'],YAYARD:['shipyard','production','water','repair'],YAREFN:['refinery'],YAPOWR:['power'],YATECH:['tech'],NAPSIS:['radar'],YAGRND:[],NACLON:[],YAGGUN:['defense'],YAPSYT:['defense'],NATBNK:['defense'],GAFWLL:['defense','wall'],YAPPET:['defense','superweapon'],YAGNTC:['defense','superweapon']};
const pack={units:[],buildings:[],source_units:{},source_buildings:{},art:{},warheads:{}};
function sheet(id,wall=false){const hit=theater.shape(id)||source.read(id+'.shp');if(!hit)throw Error(id);const shp=decodeShp(hit.data),cols=Math.min(8,shp.frames.length),atlas=montageIndexed(shp,cols);const stem='assets/ra2/shp/'+id;fs.writeFileSync(stem+'.png',encodePngIndexed(atlas.width,atlas.height,atlas.indices,pal));save(stem+'.json',{id,image:id,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:wall?3:2,shadow:!wall,...(wall?{wall_layout:readWall()}: {})});return shp.frames.length;}
function readWall(){return JSON.parse(fs.readFileSync('assets/ra2/shp/GAWALL.json')).wall_layout;}
for(const id of [...Object.keys(tags),...Object.values(products).flat()]){
 const building=id in tags, kind=building?'buildings':'units',r=section(rules,id),a=section(art,r.image||id);
 const template={PCV:'AMCV',YHVR:'LCRF',BSUB:'SUB',GAFWLL:'GAWALL',YAYARD:'GAYARD'}[id];
 let d=template?[...allied[kind],...soviet[kind]].find(v=>v.id===template):campaign.map(c=>c[kind][id]).find(Boolean)||read('head_games_sites').powers[id];
 d=structuredClone(d);Object.assign(d,{id,name:names[id]||d.name,faction:'yuri',hp:+r.strength,cost:Number(r.cost||0),ra2_armor:r.armor,tech_level:+r.techlevel,ra2_prereq:(r.prerequisite||'').split(',').filter(Boolean).map(x=>x.toUpperCase()),image:r.image||id});delete d.build_time;
 const original={id,hp:d.hp,cost:d.cost,armor:r.armor,owner:r.owner.split(','),tech_level:d.tech_level,adjacent:+r.adjacent||0,size:+r.size||1,extra:{}};
 for(const key of ['Passengers','SizeLimit','DeploysInto','UndeploysInto','BuildLimit','Naval','Underwater','NavalTargeting','LandTargeting','SpeedType','Size','BaseNormal','WaterBound'])if(key.toLowerCase() in r)original.extra[key]=r[key.toLowerCase()];
 pack['source_'+kind][id]=original;
 if(building){Object.assign(d,{tags:['structure',...tags[id]],builds:products[id]||[],power:+r.power||0,capturable:r.capturable==='yes',water_bound:r.waterbound==='yes',foundation:a.foundation||d.foundation});if(r.undeploysinto)d.undeploys_into=r.undeploysinto;if(['YAGNTC','YAPPET','NAPSIS'].includes(id)){const sw=section(rules,r.superweapon);d.superweapon={id:r.superweapon,type:sw.type,name:d.name,ui_name:id==='NAPSIS'?'心灵探测':d.name,recharge_seconds:Number(sw.rechargetime)*60};}if(id==='YATECH')d.superweapon=soviet.buildings.find(v=>v.id==='NATECH').superweapon;
 if(['YAYARD','YAPPET','YAGNTC','GAFWLL'].includes(id)){sheet(id,id==='GAFWLL');const layers=[];for(const key of ['activeanim','activeanimtwo','activeanimthree','idleanim','superanim']){if(!a[key])continue;const an=section(art,a[key]),image=an.image||a[key],count=sheet(image);layers.push({kind:key==='superanim'?'idleanim':key,image,frames:count,loopStart:Number(an.loopstart||0),loopEnd:Math.min(count-1,Number(an.loopend||0)),rate:Number(an.rate||200)});}if(layers.length)save('assets/ra2/bldanim/'+id+'.json',{id,layers});}
 }else{d.built_at=Object.keys(products).find(k=>products[k].includes(id));if(template){d.speed=Number(r.speed)*15;d.move.speed=d.speed;d.move.speed_units=+r.speed;d.sight=Number(r.sight)*55;d.desc={PCV:'在空旷陆地展开为尤里建造厂。',YHVR:'运送步兵和车辆。驶到岸边后部署即可卸载。',BSUB:'用鱼雷攻击舰船，也能从远海发射巡航导弹打击陆地目标。'}[id];writeVoxelUnit(id,id,source,vpl,pal);if(id==='PCV')d.deploys_into='YACNST';if(id==='BSUB'){d.weapon={...d.weapon,name:'BoomerTorpedo',ra2_weapon_id:'BoomerTorpedo',damage:60,cooldown:8,burst:2,range:385};d.shore_weapon={name:'CruiseLauncher',ra2_weapon_id:'CruiseLauncher',damage:200,range:1100,min_range:440,cooldown:50/15,burst:2,burst_delay:0.35,attack_type:'missile',projectile_speed:330,ra2_warhead:'YR_CMISLWH',ra2_aa:false,aoe:55};const wh=section(rules,'CMISLWH');pack.warheads.YR_CMISLWH={verses:Object.fromEntries(wh.verses.split(',').map((x,i)=>[['none','flak','plate','light','medium','heavy','wood','steel','concrete','special_1','special_2'][i],parseFloat(x)/100])),cell_spread:+wh.cellspread||1};}}}
 const icon=a.cameo;if(icon){const hit=source.read(icon+'.shp');if(hit){const sh=decodeShp(hit.data),s=montageIndexed(sh,1,[0]);const path='assets/ra2/cameo/'+icon+'.png';fs.writeFileSync(path,encodePngIndexed(s.width,s.height,s.indices,cameoPal));pack.art[id]={cameo:'res://'+path};}}
 const descriptions={NAPSIS:'提供雷达并解锁雷鸣潜艇。心灵探测充能完成后，点击地图可侦察一片区域。',YACNST:'建造尤里基地设施，可以收起为基地车。',YABRCK:'训练新兵、工程师和心灵控制部队。',YAREFN:'部署后派出矿工采矿。附近矿石耗尽时可以收起矿场，驶向下一片矿区。',YAPOWR:'提供 150 电力，可让己方步兵进入以增加供电。',YAYARD:'建在水面，生产两栖运输艇和雷鸣潜艇。雷鸣潜艇需要心灵感应器。',YAGRND:'选中己方地面部队，右键回收厂。部队进入后被回收，所得资金归入己方账户。',NACLON:'己方兵营每训练一名步兵，复制中心会尝试从自己的出口放出一名副本。',YAPPET:'充能后选取地面区域，夺取中心附近敌方地面单位的控制权，并重创周围建筑。',YAGNTC:'充能后选取地面区域，将范围内的步兵转化为己方狂兽人。',INIT:'用心灵火焰攻击地面目标，可进入生化反应炉供电。',YENGINEER:'进入敌方可占领建筑可接管设施，也能修复受损的己方建筑。',YURI:'控制敌方地面单位。消灭控制者可以解放被控制的部队。',YTNK:'连续射击时提高火力，能攻击地面和空中目标。',SMIN:'驶近矿区后展开为奴隶矿场，派出矿工采集资源。'};
 if(descriptions[id]) d.desc=descriptions[id];
 pack[kind].push(d);
}
const missile=section(rules,'CMISL');
writeVoxelUnit('CMISL',missile.image,source,vpl,pal);
pack.units.push({...structuredClone(soviet.units.find(unit=>unit.id==='DMISL')),id:'CMISL',name:'巡航导弹',desc:'雷鸣潜艇发射的巡航导弹，可被防空火力拦截。',faction:'yuri',hp:Number(missile.strength)});
pack.source_units.CMISL={hp:Number(missile.strength),cost:0,tech_level:-1,extra:{Spawned:'yes'}};
save('data/yr_yuri.json',pack);
