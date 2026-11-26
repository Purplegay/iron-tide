import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed,encodePng} from '../../ra2pipe/art_lib.mjs';
import {loadNormals,parseVxl,renderVxl} from '../../ra2pipe/vxl_lib.mjs';
import {exportTurret} from './hollywood_turrets.mjs';
export function exportCast(game){
 const src=new YrSource(game), ini=n=>parseIni(src.read(n).data.toString('latin1')), rules=ini('rulesmd.ini'),art=ini('artmd.ini'),map=ini('all02umd.map');
 const sec=(table,id)=>Object.fromEntries(getSec(table,id)?.keys||[]),raw=id=>({...sec(rules,id),...sec(map,id)});
 const save=(p,o)=>fs.writeFileSync(p,JSON.stringify(o,null,1)+'\n');
 const names={SLAV:'奴隶矿工',AMBU:'救护车',ARND:'阿诺',CALA06:'机场控制塔',CAPARK04:'公园长椅',CAR:'轿车',CAURB01:'电话亭',CIV1:'市民',CIV2:'市民',CIV3:'市民',CIVBF:'海滨游客',CIVBFM:'海滨游客',CIVBTM:'海滨游客',CIVP:'民用飞机',CIVSF:'冬装市民',CIVSFM:'冬装市民',CIVSTM:'冬装市民',CLNT:'克林特',CONA:'挖掘机',DNOA:'霸王龙',DOLY:'摄影车',EUROC:'欧洲轿车',FTRK:'消防车',GAGATE_A:'边境关卡',JEEP:'吉普车',LIMO:'豪华轿车',PICK:'小货车',PTRUCK:'皮卡',SMIN:'奴隶矿场',STANG:'跑车',STLN:'史泰龙',SUVB:'黑色越野车',SUVW:'白色越野车',TAXI:'出租车',WINI:'房车',YENGINEER:'尤里工程师',YTNK:'盖特坦克',YURI:'尤里复制人',YAREFN:'奴隶矿场（展开）'};
 const catalog={units:{},buildings:{},placements:[],teams:[],waypoints:sec(map,'Waypoints')};
 const palette=decodePal(src.read('unittem.pal').data);for(let i=16;i<32;i++){const shade=palette[i*4]/252;[87,168,255].forEach((c,k)=>palette[i*4+k]=Math.round(c*shade));}
 loadNormals('../refs/ts-ra2/src/data/vxl/normals.ts');
 function voxel(id,hit,turret=''){
  const model=parseVxl(hit.data),facings=32,frames=Array.from({length:facings},(_,facing)=>renderVxl(model,{facing,facings,pal:palette}));
  const left=Math.min(...frames.map(f=>f.minX)),top=Math.min(...frames.map(f=>f.minY));
  const frameW=Math.ceil(Math.max(...frames.map(f=>f.minX+f.width))-left)+4,frameH=Math.ceil(Math.max(...frames.map(f=>f.minY+f.height))-top)+4,width=facings*(frameW+2)+2,height=frameH+4,rgba=new Uint8Array(width*height*4);
  frames.forEach((f,i)=>{const x=2+i*(frameW+2)+Math.round(f.minX-left),y=2+Math.round(f.minY-top);for(let j=0;j<f.height;j++)rgba.set(f.rgba.subarray(j*f.width*4,(j+1)*f.width*4),((y+j)*width+x)*4);});
  const p='assets/ra2/vxl/'+id;fs.writeFileSync(p+'.png',encodePng(width,height,rgba));save(p+'.json',{frameW,frameH,facings,turret});
 }
 function gun(id){const g=raw(id);return {name:id,ra2_weapon_id:'YR_HOL_'+id,ra2_projectile:g.projectile,ra2_warhead:'YR_HOL_'+g.warhead,damage:Number(g.damage||0),range:Number(g.range||0)*55,cooldown:Number(g.rof||15)/15,burst:Number(g.burst||1),attack_type:'bullet',projectile_speed:/^(invisible|psychic)/i.test(g.projectile||'')?0:Number(g.speed||50)*22,report:g.report,ra2_aa:raw(g.projectile).aa?.toLowerCase()==='yes'};}
 for(const [id,name] of Object.entries(names)){
  const r=raw(id),a=sec(art,r.image||id),image=a.image||r.image||id,building=!!a.foundation,infantry=!!a.sequence,role=building?'structure':infantry?'infantry':id==='CIVP'?'air':'vehicle';
  const b={id,name,ra2:true,faction:['SMIN','SLAV','YAREFN','YURI','YTNK','YENGINEER'].includes(id)?'yuri':'civilian',role,role_name:{structure:'建筑',infantry:'步兵',air:'飞机',vehicle:'载具'}[role],tags:[role],cost:Number(r.cost||0),hp:Number(r.strength||1),ra2_armor:r.armor,armor:building?'structure':infantry?'unarmored':r.armor||'light',radius:building?18:infantry?7:15,sight:Number(r.sight||5)*55};
  if(building){Object.assign(b,{builds:[],foundation:a.foundation,power:Number(r.power||0)});catalog.buildings[id]=b;}else{Object.assign(b,{speed:Number(r.speed||0)*15,move:{speed_units:Number(r.speed||0),movement_zone:r.movementzone,crushable:r.crushable==='yes'},voice:{select:r.voiceselect,move:r.voicemove,attack:r.voiceattack}});catalog.units[id]=b;}
  if(b.faction === 'yuri' && r.buildtimemultiplier !== undefined) b.build_time_multiplier = Number(r.buildtimemultiplier);
  if(r.immunetopsionics==='yes')b.immune_to_psionics=true;
  if(r.selfhealing==='yes')b.self_healing=true;
  if(r.deployer==='yes')b.deployer=true;
  if(r.deployfire==='yes')Object.assign(b,{undeploy_ticks:+r.undeploydelay,fire_up_ticks:Number(a.fireup||1)});
  if(r.turret==='yes' && b.move)b.move.turret=true;
  if(r.rot && b.move)b.move.rot_units=+r.rot;
  if(r.primary)b.weapon=gun(r.primary);
  if(r.eliteprimary)b.elite_weapon=gun(r.eliteprimary);
  if(r.secondary)b.secondary_weapon=gun(r.secondary);
  if(r.isgattling==='yes'){
   b.guns=Array.from({length:6},(_,i)=>gun(r['weapon'+(i+1)]));
   b.elite_guns=Array.from({length:6},(_,i)=>gun(r['eliteweapon'+(i+1)]));
   b.stages=[+r.stage1,+r.stage2,+r.stage3];b.elite_stages=[+r.elitestage1,+r.elitestage2,+r.elitestage3];
   b.rate_up=+r.rateup;b.rate_down=+r.ratedown;
  }
  if(r.deploysinto)b.deploys_into=r.deploysinto;
  if(r.undeploysinto)Object.assign(b,{undeploys_into:r.undeploysinto,unsellable:true,base_normal:false,capturable:false,buildup:a.buildup});
  if(r.enslaves)Object.assign(b,{worker:r.enslaves,workers:+r.slavesnumber,regen_ticks:+r.slaveregenrate,reload_ticks:+r.slavereloadrate});
  if(r.slaved==='yes')Object.assign(b,{storage:+r.storage,harvest_ticks:+r.harvestrate});
  if(id==='YTNK'||id==='SMIN'){exportTurret(src,palette,id);continue;}
  const hit=src.read(image+'.vxl');if(hit){const turret=src.read(image+'tur.vxl');if(turret)voxel(id+'_turret',turret);voxel(id,hit,turret?id+'_turret':'');continue;}
  if(id==='YAREFN'){
   const archive=src.read('genermd.mix');
   src.indexMix(archive.data,archive.source,0);
  }
  const shpHit=(id==='YAREFN'?['YGREFN']:[image,image[0]+'U'+image.slice(2),image[0]+'T'+image.slice(2)]).map(n=>src.read(n+'.shp')).find(Boolean);if(!shpHit){if(id==='CALA06' && fs.existsSync('assets/ra2/hollywood/city/'+id+'.png'))continue;throw Error('Missing artwork '+id);}
  const shp=decodeShp(shpHit.data),cols=12,sheet=montageIndexed(shp,cols),p='assets/ra2/shp/'+id;
  fs.writeFileSync(p+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));save(p+'.json',{id,image,source:shpHit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:sheet.rects,dmg:building?Math.min(2,shp.frames.length/2):1,shadow:true});
  if(infantry)sequences(id,a.sequence,b,shp.frames.length/2);
 }
 function sequences(id,name,unit,bodyFrames){
  const original=sec(art,name),seq={};
  for(const key of ['Guard','Ready','Walk','Idle1','Idle2','FireUp','FireProne','Crawl','Prone','Down','Up','Die1','Die2','Die3','Die4','Die5','Cheer','Panic','Paradrop','Deploy','Deployed','Undeploy','Carry','Shovel']){
   const value=original[key.toLowerCase()];if(!value)continue;
   const [start,per,stride]=value.split(',').map(Number);
   seq[key]={start,per,stride,facings:stride>0?8:1};
   if(bodyFrames && start+per+(seq[key].facings-1)*stride>bodyFrames){
    // ARND's retail Paradrop=292 points at an empty shadow. Keep a visible directional pose.
    if(id==='ARND' && key==='Paradrop')seq[key]={...seq.Guard};
    else throw Error(id+' '+key+' outside body frames');
   }
   const cue=original[key.toLowerCase()+'sounds'];
   if(cue && unit){const [frame,sound]=cue.split(/\s+/);(unit.sequence_sounds??={})[key]={frame:+frame,sound};}
  }
  save('assets/ra2/shp/'+id+'.seq.json',{seq});
 }
 sequences('INIT',sec(art,'INIT').sequence);
 for(const id of ['YAREFNMK','YAREFN_A']){
  const hit=src.read('YG'+id.slice(2)+'.shp');
  const shape=decodeShp(hit.data),cols=8,sheet=montageIndexed(shape,cols),p='assets/ra2/shp/'+id;
  fs.writeFileSync(p+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
  save(p+'.json',{id,source:hit.source,cell:[shape.width,shape.height],cols,count:shape.frames.length/2,rects:sheet.rects,shadow:true});
  if(id.endsWith('_A'))save('assets/ra2/bldanim/YAREFN.json',{id:'YAREFN',layers:[{kind:'idleanim',image:id,frames:shape.frames.length/2,shadow:true,loopStart:0,loopEnd:Math.min(shape.frames.length/2-1,Number(sec(art,id).loopend??shape.frames.length/2-1)),rate:Number(sec(art,id).rate||900),loopCount:-1}]});
 }
 for(const kind of ['Infantry','Units','Structures'])for(const v of Object.values(sec(map,kind))){const [house,id,hp,x,y]=v.split(',');if(names[id]||['INIT','LTNK'].includes(id))catalog.placements.push({house,id,hp:Number(hp)/256,x:+x,y:+y});}
 for(const id of Object.values(sec(map,'TeamTypes'))){const t=sec(map,id);if(!/^Yuri_Base_Assault_/.test(t.name))continue;catalog.teams.push({name:t.name,units:Object.entries(sec(map,t.taskforce)).filter(([k])=>/^\d+$/.test(k)).flatMap(([,v])=>Array(Number(v.split(',')[0])).fill(v.split(',')[1])),route:Object.entries(sec(map,t.script)).filter(([k,v])=>/^\d+$/.test(k)&&/^(3|16),/.test(v)).map(([,v])=>Number(v.split(',')[1]))});}
 save('data/hollywood_cast.json',catalog);
}
