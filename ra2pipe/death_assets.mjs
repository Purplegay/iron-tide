// Official installed YR inputs -> scoped death presentation/rules manifest.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';
import { bakeDeathVoxels } from './death_voxels.mjs';
const [game, project] = process.argv.slice(2);
if (!game || !project) throw Error('Usage: death_assets.mjs <installed YR> <Godot project>');
const src = new YrSource(game), rr = src.read('rulesmd.ini'), ar = src.read('artmd.ini');
const rules = parseIni(rr.data.toString('latin1')), art = parseIni(ar.data.toString('latin1'));
const row = (doc,id) => Object.fromEntries(getSec(doc,id)?.keys || []);
const list = v => (v || '').split(',').map(x=>x.trim().toUpperCase()).filter(Boolean);
const yes = v => /^(yes|true|1)$/i.test(v || '');
const manifest = {source:{rules:sha256(rr.data),art:sha256(ar.data)},general:row(rules,'General'),types:{},animations:{},missing:[]};
const wanted = new Set(['TWLT026','TWLT036','SMOKEY2','ELECTRO','FLAMEGUY']);
for (const key of ['infantryexplode','infantryheadpop','infantrynuked','infantrybrute']) for (const id of list(manifest.general[key])) wanted.add(id);
for (const category of ['InfantryTypes','VehicleTypes','AircraftTypes','BuildingTypes']) {
 for (const id of Object.values(row(rules,category))) {
  const raw = row(rules,id); if (!Object.keys(raw).length) continue;
  manifest.types[id.toUpperCase()] = {...raw,native_category:category};
  for (const key of ['explosion','debrisanim','deathanim','deathanims']) for (const fx of list(raw[key])) wanted.add(fx);
 }
}
const folder = path.join(project,'assets/ra2/death'); fs.mkdirSync(folder,{recursive:true});
bakeDeathVoxels(src, folder, row, rules, art, manifest, wanted);
const palette = decodePal(src.read('anim.pal').data);
for (const id of wanted) {
 const raw = row(art,id), image = raw.image || id, bytes = src.read(image+'.shp');
 if (!bytes) { manifest.missing.push(id); continue; }
 const shp = decodeShp(bytes.data), frames = yes(raw.shadow) || yes(raw.isflamingguy) ? shp.frames.slice(0,shp.frames.length/2) : shp.frames;
 // Preserve the common original canvas; all frames keep the same pivot.
 const sheet = montageIndexed({...shp,frames}, Math.min(12,frames.length));
 fs.writeFileSync(path.join(folder,id+'.png'),encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
 manifest.animations[id] = {raw,source:bytes.source,sha256:sha256(bytes.data),cell:[shp.width,shp.height],
  count:frames.length,rects:sheet.rects,fps:Number(raw.rate || 900)/60,sound:raw.startsound || raw.report || ''};
}
// Escape-only actors are registered privately; never add them to production lists.
manifest.crew_units = {};
const unitPalette = decodePal(src.read('unittem.pal').data);
for (let i=16;i<32;i++) {
 const light=unitPalette[i*4]/252;
 for (const [channel,value] of [0x57,0xa8,0xff].entries()) unitPalette[i*4+channel]=Math.round(value*light);
}
for (const id of ['E2','INIT','CTECH']) {
 const raw = row(rules,id), appearance=row(art,raw.image || id), image=appearance.image || raw.image || id;
 const bytes=src.read(image+'.shp'); if (!bytes) throw Error('Missing crew '+id);
 const shp=decodeShp(bytes.data), sheet=montageIndexed(shp,12), seq={};
 for (const [key,value] of Object.entries(row(art,appearance.sequence))) {
  const name={idle1:'Idle1',idle2:'Idle2',guard:'Guard',walk:'Walk',fireup:'FireUp',firedown:'FireDown',prone:'Prone',crawl:'Crawl',die1:'Die1',die2:'Die2'}[key];
  if (!name) continue;
  const [start,per,stride]=value.split(',').map(Number);
  seq[name]={start,per,facings:stride>0?8:1,stride};
 }
 const dest=path.join(project,'assets/ra2/shp',id);
 if (!fs.existsSync(dest+'.png') || JSON.parse(fs.readFileSync(dest+'.json','utf8')).death_crew_import) {
  fs.writeFileSync(dest+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,unitPalette));
  fs.writeFileSync(dest+'.json',JSON.stringify({id,kind:'shp',image,death_crew_import:true,cell:[shp.width,shp.height],count:shp.frames.length,cols:12,rects:sheet.rects,shadow:true,source:bytes.source}));
  fs.writeFileSync(dest+'.seq.json',JSON.stringify({seq}));
 }
 const w=row(rules,raw.primary), p=row(rules,w.projectile);
 manifest.crew_units[id]={id,name:{E2:'动员兵',INIT:'尤里新兵',CTECH:'技师'}[id],ra2:true,faction:id==='E2'?'soviet':id==='INIT'?'yuri':'civilian',
  role:'infantry',tags:['infantry'],cost:Number(raw.cost),hp:Number(raw.strength),armor:'unarmored',ra2_armor:raw.armor,
  speed:Number(raw.speed)*15,radius:7,sight:Number(raw.sight)*55,tech_level:-1,built_at:'',image,
  move:{speed:Number(raw.speed)*15,speed_units:Number(raw.speed),movement_zone:'Infantry',crushable:true},
  weapon:{name:raw.primary,damage:Number(w.damage),cooldown:Number(w.rof)/15,range:Number(w.range)*55,attack_type:'bullet',projectile_speed:1100,
   ra2_weapon_id:raw.primary,ra2_warhead:w.warhead,ra2_projectile:w.projectile,ra2_aa:yes(p.aa),report:w.report || ''},
  voice:{select:raw.voiceselect,move:raw.voicemove,attack:raw.voiceattack,die:raw.diesound}};
}
fs.writeFileSync(path.join(project,'data/ra2/death.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({types:Object.keys(manifest.types).length,animations:Object.keys(manifest.animations).length,missing:manifest.missing}));
