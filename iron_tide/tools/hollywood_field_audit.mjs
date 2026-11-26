// Run from project root with the installed game directory and ALL02UMD.MAP.
import fs from 'node:fs';
import {YrSource} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni,getSec} from '../../ra2pipe/lib/ini.mjs';
import {decodeShp,decodePal,montageIndexed,encodePngIndexed,frameToRgba,encodePng} from '../../ra2pipe/art_lib.mjs';
const [game,mapPath]=process.argv.slice(2),src=new YrSource(game);
const rules=parseIni(src.read('rulesmd.ini').data.toString('latin1')),art=parseIni(src.read('artmd.ini').data.toString('latin1')),map=parseIni(fs.readFileSync(mapPath,'latin1'));
const sec=(ini,id)=>Object.fromEntries(getSec(ini,id)?.keys||[]);
const raw=id=>({...sec(rules,id),...sec(map,id)});
const csv=v=>(v||'').split(',').map(x=>x.trim()).filter(Boolean);
const json=(path,data)=>fs.writeFileSync(path,JSON.stringify(data,null,1)+'\n');
const ids=new Map();function add(id,source){if(!ids.has(id))ids.set(id,new Set());ids.get(id).add(source);}
for(const kind of ['Infantry','Units','Aircraft','Structures'])for(const row of Object.values(sec(map,kind)))add(row.split(',')[1],kind);
for(const group of Object.values(sec(map,'TaskForces')))for(const [key,row] of Object.entries(sec(map,group)))if(/^\d+$/.test(key))add(row.split(',')[1],'TaskForce');
const yuri=JSON.parse(fs.readFileSync('data/hollywood_yuri.json'));const armor=['none','flak','plate','light','medium','heavy','wood','steel','concrete','special_1','special_2'];
const pack={weapons:{},warheads:{}};
const cameoPalette = decodePal(src.read('cameo.pal').data);
pack.art = {};
const cast = JSON.parse(fs.readFileSync('data/hollywood_cast.json'));
const yuriForms = new Set();
for (const unit of Object.values({...yuri.units, ...cast.units})) {
 if (unit.faction !== 'yuri') continue;
 yuriForms.add(unit.id);
 if (unit.deploys_into) yuriForms.add(unit.deploys_into);
}
for (const id of yuriForms) {
 const name = sec(art, raw(id).image || id).cameo;
 const shape = decodeShp(src.read(name + '.shp').data);
 const file = 'assets/ra2/cameo/' + name + '.png';
 const rgba = frameToRgba(shape.frames[0], cameoPalette, {canvasW:shape.width, canvasH:shape.height});
 const png = encodePng(shape.width, shape.height, rgba);
 if (!fs.existsSync(file) || !fs.readFileSync(file).equals(png)) fs.writeFileSync(file, png);
 pack.art[id] = {cameo:'res://' + file};
}
const lighting=sec(map,'Lighting');
pack.daylight=Object.fromEntries(['ambient','ground','red','green','blue'].map(k=>{
 const value=Number(lighting[k]);
 if(!Number.isFinite(value))throw Error('Missing ALL02UMD Lighting.'+k);
 return [k,value];
}));
// Original firing points and smoke sockets, in leptons. Read map overrides first.
pack.unit_fx={};
for(const id of ['YURI','INIT','LTNK','YTNK','SMIN','YAREFN']){
 const r=raw(id),a=sec(art,r.image||id),fx={primary:csv(a.primaryfireflh).map(Number)};
 if(a.secondaryfireflh)fx.secondary=csv(a.secondaryfireflh).map(Number);
 if(id==='YURI'){
  fx.control_line_ticks=Number(raw('CombatDamage').mindcontrolattacklineframes);
  if(!Number.isFinite(fx.control_line_ticks))throw Error('Missing MindControlAttackLineFrames');
 }
 if(r.damagesmokeoffset)fx.damage_smoke=csv(r.damagesmokeoffset).map(Number);
 if(r.refinerysmokeparticlesystem){
  fx.vents=['one','two','three','four'].map(n=>csv(r['refinerysmokeoffset'+n]).map(Number));
  const system=raw(r.refinerysmokeparticlesystem),particle=raw(system.holdswhat);
  fx.smoke_image=particle.image;
  fx.smoke_ticks=Number(r.refinerysmokeframes);
  fx.spawn_ticks=Number(system.spawnframes);
  fx.smoke_opacity=1-Number(particle.translucency)/100;
  fx.particle_ticks=Number(particle.maxec);
  fx.particle_cap=Number(system.particlecap);
  fx.frame_ticks=Number(particle.stateaiadvance);
  fx.end_frame=Number(particle.endstateai);
  fx.velocity=Number(particle.velocity);
  fx.deceleration=Number(particle.deacc);
 }
 pack.unit_fx[id]=fx;
}
const palette=decodePal(src.read('anim.pal').data);
function fx(id){const path='assets/ra2/fx/'+id.toUpperCase();if(fs.existsSync(path+'.png'))return;
 const anim=sec(art,id),image=anim.image||id,hit=src.read(image+'.shp');if(!hit)throw Error('Missing FX '+image);
 const shp=decodeShp(hit.data),cols=Math.min(8,shp.frames.length),sheet=montageIndexed(shp,cols);
 fs.writeFileSync(path+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));json(path+'.json',{id,cell:[shp.width,shp.height],rects:sheet.rects,count:shp.frames.length,fps:Number(anim.rate||900)/60});}
fx('MINDANIM');
fx('UCINIT');
const windowMeta='assets/ra2/fx/UCINIT.json',windowArt=JSON.parse(fs.readFileSync(windowMeta));
windowArt.translucent=sec(art,'UCINIT').translucent?.toLowerCase()==='yes';
json(windowMeta,windowArt);
const selected=new Set();for(const id of ['INIT','LTNK','YAGGUN','YURI','YTNK','SMIN','SLAV','ARND','STLN','CLNT','DNOA','YENGINEER'])for(const [k,v] of Object.entries(raw(id)))if(/^(elite)?(primary|secondary|occupyweapon|weapon\d+)$/.test(k))selected.add(v);
for(const id of selected){const w=raw(id),h=raw(w.warhead),key='YR_HOL_'+id,wh='YR_HOL_'+w.warhead;
 pack.weapons[key]={id:key,damage:+w.damage,rof:+w.rof,range:+w.range,anim:csv(w.anim),bright:w.bright?.toLowerCase()==='yes',projectile:w.projectile,warhead:wh,report:w.report,burst:+(w.burst||1),extra:{OccupantAnim:w.occupantanim||'',OpenToppedAnim:w.opentoppedanim||''}};
 pack.warheads[wh]={id:wh,verses:Object.fromEntries(csv(h.verses).map((v,i)=>[armor[i],parseFloat(v)/100])),anim_list:csv(h.animlist),inf_death:+(h.infdeath||0),cell_spread:+(h.cellspread||0),percent_at_max:parseFloat(h.percentatmax||'1'),prone_damage:parseFloat(h.pronedamage||'100%')/100,extra:{Sparky:h.sparky||'no',Rocker:h.rocker||'no',MindControl:h.mindcontrol||'no',PsychicDamage:h.psychicdamage||'no',AffectsAllies:h.affectsallies||'yes'}};
 for(const image of [...csv(w.anim),...csv(w.occupantanim),...csv(w.opentoppedanim),...csv(h.animlist)])fx(image);
}
const city=JSON.parse(fs.readFileSync('data/maps/yr_all02umd.json')).site_types;const table={};
pack.fire_ports={};
for(const id of Object.keys(city)){
 const rule=raw(id),drawing=sec(art,rule.image||id);
 if(rule.canbeoccupied?.toLowerCase()!=='yes')continue;
 const ports=Array.from({length:Number(rule.maxnumberoccupants)},(_,i)=>csv(drawing['muzzleflash'+i]).map(Number));
 if(ports.some(p=>p.length!==2))throw Error('Missing firing port on '+id);
 pack.fire_ports[id]=ports;
}
json('data/hollywood_combat.json',pack);
for(const [id,origins] of ids){const r=raw(id),a=sec(art,r.image||id);const guns={};for(const [k,w] of Object.entries(r))if(/^(elite)?(primary|secondary|weapon\d+|occupyweapon)$/.test(k)){const g=raw(w),h=raw(g.warhead);guns[k]={id:w,muzzle:g.anim,projectile:g.projectile,warhead:g.warhead,impact:h.animlist};}table[id]={origins:[...origins],mission_definition:!!(yuri.buildings[id]||yuri.units[id]),city_site:!!city[id],map_overrides:sec(map,id),rules:r,art:a,weapons:guns};}
json('docs/memory/HOLLYWOOD_NATIVE_FIELD_INVENTORY.json',table);console.log('Types',ids.size,'weapons',selected.size,'warheads',Object.keys(pack.warheads).length);
