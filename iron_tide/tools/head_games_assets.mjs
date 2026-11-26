import {parseVpl,renderSurface} from '../../ra2pipe/voxel_surface.mjs';
import {loadNormals,parseVxl,parseHva,poseVxl} from '../../ra2pipe/vxl_lib.mjs';
import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed,encodePng} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
const source=new YrSource(process.argv[2]);
const theater=theaterReader(source,'TEMPERATE');
const ini=file=>parseIni(source.read(file).data.toString('latin1'));
const rules=ini('rulesmd.ini'),art=ini('artmd.ini');
const section=(table,id)=>Object.fromEntries(getSec(table,id)?.keys||[]);
const save=(file,value)=>fs.writeFileSync(file,JSON.stringify(value,null,1)+'\n');
const palette=decodePal(theater.palette().data);
for(let i=16;i<32;i++){const shade=palette[i*4]/252;[87,168,255].forEach((v,j)=>palette[i*4+j]=Math.round(v*shade));}
loadNormals('../refs/ts-ra2/src/data/vxl/normals.ts');
const vpl = parseVpl(source.read('voxels.vpl').data);
const voxelPalette = decodePal(theater.palette().data);
for (let index = 16; index < 32; index++) {
 const shade = voxelPalette[index * 4] / 252;
 [87,168,255].forEach((value, channel) => voxelPalette[index * 4 + channel] = Math.round(value * shade));
}
import {writeVoxelUnit} from './yr_voxel_unit.mjs';
import {writeHeadGamesLayers} from './head_games_building_layers.mjs';
const castleOnly = process.argv.includes('--castle-only');
if (!castleOnly) writeHeadGamesLayers(id => section(art,id), theater, source, palette);
const pack={units:{},buildings:{},warheads:{}};
for(const [id,name] of Object.entries({BRUTE:'狂兽人',VIRUS:'病毒狙击手',YURIPR:'尤里改',MIND:'精神控制车',TELE:'磁电坦克',CAOS:'神经突击车',DISK:'镭射幽浮',NAPSYB:'心灵信标',CATRAN03:'尤里的城堡',YAPSYT:'心灵控制塔',CASLAB:'秘密实验室',YATECH:'尤里作战实验室',NACLON:'复制中心'})){
 if (castleOnly && id !== 'CATRAN03') continue;
 const r=section(rules,id),a=section(art,r.image||id),infantry=!!a.sequence,vehicle=!!a.voxel;
 const image=a.image||r.image||id;
 const stem='assets/ra2/shp/'+(id==='NAPSYB'?'SOV07_BEACON':id);
 if(!vehicle){
 const hit=infantry?source.read(image+'.shp'):theater.shape(image)||source.read(image+'.shp');
 const shape=decodeShp(hit.data),cols=Math.min(12,shape.frames.length),sheet=montageIndexed(shape,cols);

 if (id === 'CATRAN03') {
  // The three standing frames use unit colors. LeaveRubble uses terrain colors.
  if (shape.frames.length !== 8) throw Error('Unexpected castle frame layout');
  const iso = decodePal(source.read('isotem.pal').data);
  const rubble = sheet.rects[3];
  const rgba = new Uint8Array(sheet.indices.length * 4);
  for (let i = 0; i < sheet.indices.length; i++) {
   const index = sheet.indices[i];
   if (!index) continue;
   const x = i % sheet.width;
   const pal = x >= rubble.x && x < rubble.x + rubble.w ? iso : palette;
   rgba.set(pal.subarray(index * 4, index * 4 + 4), i * 4);
  }
  fs.writeFileSync(stem+'.png', encodePng(sheet.width, sheet.height, rgba));
  if (castleOnly) break;
 } else fs.writeFileSync(stem+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
 save(stem+'.json',{id,image,source:hit.source,cell:[shape.width,shape.height],cols,count:shape.frames.length,rects:sheet.rects,dmg:infantry?1:2,shadow:true});
 }else{
 writeVoxelUnit(id,image,source,vpl,voxelPalette);
 }
 const def={id:id==='NAPSYB'?'SOV07_BEACON':id,name,ra2:true,faction:'yuri',hp:+r.strength,ra2_armor:r.armor,sight:+r.sight*55||330,cost:+r.cost||0};
 if(!infantry && !vehicle){Object.assign(def,{role:'structure',role_name:'建筑',tags:['structure'],armor:'structure',foundation:a.foundation||'3x3',radius:35,builds:[],capturable:id==='YATECH' && ['yes','true','1'].includes(String(r.capturable).toLowerCase()),power:Number(r.power||0),powered:r.powered==='yes',desc:{NAPSYB:'摧毁信标，解救对应基地。',CATRAN03:'摧毁城堡，结束尤里的抵抗。',YAPSYT:'控制附近的敌方地面部队。摧毁塔可解放被控制的部队。',CASLAB:'尤里控制的技术设施。',YATECH:'尤里研究高阶作战技术的设施。',NACLON:'尤里的兵员复制设施。'}[id]});pack.buildings[def.id]=def;continue;}
 const seq={};for(const [key,value] of Object.entries(section(art,a.sequence))){const match=['Guard','Ready','Walk','FireUp','Idle1','Idle2','Die1','Die2','Die3','Die4','Die5','Cheer','Panic','SecondaryFire'].find(k=>k.toLowerCase()===key);if(match){const [start,per,stride]=value.split(',').map(Number);seq[match]={start,per,stride,facings:stride?8:1};}}if(infantry)save(stem+'.seq.json',{seq});
 function weapon(id){const w=section(rules,id),wh=section(rules,w.warhead),armor=['none','flak','plate','light','medium','heavy','wood','steel','concrete','special_1','special_2'];const verses=Object.fromEntries((wh.verses||'100%,100%,100%,100%,100%,100%,100%,100%,100%,100%,100%').split(',').map((v,i)=>[armor[i],parseFloat(v)/100]));pack.warheads['YR_S07_'+w.warhead]={verses,inf_death:+wh.infdeath||0,cell_spread:parseFloat(wh.cellspread)||0,extra:{MindControl:wh.mindcontrol||'no'}};return {name:id,damage:+w.damage,cooldown:Number(w.rof||15)/15,range:+w.range*55,attack_type:'bullet',projectile_speed:0,ra2_warhead:'YR_S07_'+w.warhead,ra2_projectile:w.projectile,report:w.report,ra2_aa:section(rules,w.projectile).aa==='yes'};}
 Object.assign(def,{role:'infantry',role_name:'步兵',armor:'unarmored',tags:['infantry'],radius:10,speed:+r.speed*15,move:{speed_units:+r.speed,crushable:false},immune_to_psionics:true,weapon:weapon(r.primary),...(r.secondary?{secondary_weapon:weapon(r.secondary)}:{}),desc:'近身攻击步兵和车辆。用步兵火力在它靠近前将它击倒。'});if(id!=='BRUTE'){
  const role=id==='DISK'?'air':vehicle?'vehicle':'infantry';
  Object.assign(def,{role,role_name:{air:'空军',vehicle:'载具',infantry:'步兵'}[role],tags:[role],armor:role==='air'?'air':vehicle?r.armor:'unarmored',radius:vehicle?17:8,immune_to_psionics:r.immunetopsionics==='yes',desc:{VIRUS:'远距离狙击步兵。',YURIPR:'控制一个敌方地面单位或建筑。',MIND:'可以同时控制多个地面单位，控制过多会损失生命。',TELE:'用磁力拖近车辆，用震荡攻击建筑。',CAOS:'释放混乱气体，让附近的地面部队攻击自己人。',DISK:'用激光对空对地，靠近电厂或矿场可干扰敌方经济。'}[id]});
 }
 pack.units[id]=def;
}
if (!castleOnly) save('data/head_games.json',pack);
