// Original VoxelAnim media, independently baked for the Godot death consumer.
import fs from 'node:fs';
import path from 'node:path';
import {parseVxl, parseHva, poseVxl} from './vxl_lib.mjs';
import {renderSurface, parseVpl} from './voxel_surface.mjs';
import {decodePal, encodePng} from './art_lib.mjs';
import {sha256} from './lib/yr_source.mjs';

export function bakeDeathVoxels(src, folder, row, rules, art, manifest, wanted) {
 manifest.combat = row(rules, 'CombatDamage');
 manifest.gravity = Number(row(rules, 'AudioVisual').gravity || 6);
 manifest.voxels = {}; manifest.weapons = {}; manifest.warheads = {};
 const weaponIds = new Set([manifest.combat.deathweapon]);
 for (const type of Object.values(manifest.types)) {
  if (type.deathweapon) weaponIds.add(type.deathweapon);
  if (type.explodes === 'yes' && type.primary) weaponIds.add(type.primary);
 }
 for (const id of weaponIds) if (id) {
  const weapon = row(rules,id); manifest.weapons[id.toUpperCase()] = weapon;
  if(weapon.warhead) {
   const wh=row(rules,weapon.warhead), ratio=v=>String(v).endsWith('%')?parseFloat(v)/100:Number(v);
   const armor=['none','flak','plate','light','medium','heavy','wood','steel','concrete','special_1','special_2'];
   const verses=(wh.verses||Array(11).fill('100%').join(',')).split(',').map(ratio);
   const extra={}; for(const [raw,key] of [['affectsallies','AffectsAllies'],['causesdeathweapon','CausesDeathWeapon'],['radiation','Radiation']])if(wh[raw]!==undefined)extra[key]=wh[raw];
   manifest.warheads[weapon.warhead]={id:weapon.warhead,verses:Object.fromEntries(armor.map((a,i)=>[a,verses[i]??1])),cell_spread:Number(wh.cellspread||0),percent_at_max:ratio(wh.percentatmax??1),prone_damage:ratio(wh.pronedamage??1),inf_death:Number(wh.infdeath||1),anim_list:(wh.animlist||'').split(',').filter(v=>/^[a-z0-9_]+$/i.test(v)),extra};
  }
  for (const anim of (row(rules,weapon.warhead).animlist || '').split(',')) if(anim) {
   const name=anim.trim().toUpperCase();
   if(/^[A-Z0-9_]+$/.test(name)) wanted.add(name);
   else manifest.missing.push('INVALID_ANIM:'+name);
  }
 }
 const ids = new Set(['TIRE','PIECE','GASTANK']);
 for (const type of Object.values(manifest.types)) for (const id of (type.debristypes || '').split(',')) if(id) ids.add(id.trim().toUpperCase());
 const pal = decodePal(src.read('unittem.pal').data), vpl = parseVpl(src.read('voxels.vpl').data);
 for (const id of ids) {
  const raw = row(rules,id), image = row(art,id).image || raw.image || id;
  const vxl = src.read(image+'.vxl'), hva = src.read(image+'.hva');
  if(!vxl) {manifest.missing.push('VXL:'+id); continue;}
  const model = poseVxl(parseVxl(vxl.data),hva ? parseHva(hva.data) : null);
  // Genuine voxel surfaces, yaw + tumble poses; no chopped-up full-tank sprite.
  const frames = [];
  for(let tumble=0;tumble<8;tumble++) for(let facing=0;facing<16;facing++) {
   const c=Math.cos(tumble*Math.PI/4),s=Math.sin(tumble*Math.PI/4);
   const limbs=model.limbs.map(l=>{const m=l.matrix.slice();const n=m.slice();
    for(let k=0;k<4;k++){n[4+k]=c*m[4+k]-s*m[8+k];n[8+k]=s*m[4+k]+c*m[8+k];}
    return {...l,matrix:n};});
   frames.push(renderSurface({limbs},{pal,vpl,facing,facings:16,shadow:false}));
  }
  const minX=Math.floor(Math.min(...frames.map(f=>f.minX)))-2,minY=Math.floor(Math.min(...frames.map(f=>f.minY)))-2;
  const cw=Math.ceil(Math.max(...frames.map(f=>f.minX+f.width)))-minX+2,ch=Math.ceil(Math.max(...frames.map(f=>f.minY+f.height)))-minY+2;
  const width=cw*16,height=ch*8,pixels=new Uint8Array(width*height*4),rects=[];
  frames.forEach((im,i)=>{const x=(i%16)*cw,y=Math.floor(i/16)*ch;rects.push({x,y,w:cw,h:ch});
   for(let yy=0;yy<im.height;yy++)for(let xx=0;xx<im.width;xx++) {
    const a=(yy*im.width+xx)*4,b=((y+Math.round(im.minY-minY)+yy)*width+x+Math.round(im.minX-minX)+xx)*4;
    if(im.rgba[a+3]) pixels.set(im.rgba.subarray(a,a+4),b);
   }
  });
  fs.writeFileSync(path.join(folder,id+'.png'),encodePng(width,height,pixels));
  manifest.voxels[id]={raw,source:vxl.source,sha256:sha256(vxl.data),hva_sha256:hva?sha256(hva.data):null,cell:[cw,ch],origin:[-minX,-minY],rects,facings:16,poses:8};
  if(raw.expireanim) wanted.add(raw.expireanim.toUpperCase());
 }
}
