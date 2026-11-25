// Scoped, repeatable export from the user's installed YR; never rewrites live RA2 tables.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';
import { MixFile, MixEntry, DataStream } from '../tools/ra2bundle.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_robot.mjs <YR directory> <new external candidate>');
const out = path.join(fs.realpathSync(path.dirname(path.resolve(output))), path.basename(output));
for (const protectedRoot of [fs.realpathSync(root), fs.realpathSync(game)])
  if (out === protectedRoot || out.startsWith(protectedRoot + path.sep)) throw new Error('Candidate must be external');
if (fs.existsSync(out)) throw new Error('Refusing to overwrite existing candidate');
const source = new YrSource(game), provenance = {};
const required = name => {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing ${name}`);
  provenance[name] = { source: hit.source, sha256: sha256(hit.data) };
  return hit;
};
const input = path.join(out, 'input'), project = path.join(out, 'project');
fs.mkdirSync(input, { recursive: true });
for (const [name, target] of [['rulesmd.ini', 'rules.ini'], ['artmd.ini', 'art.ini']])
  fs.writeFileSync(path.join(input, target), required(name).data);
const build = spawnSync(process.execPath, [path.join(root, 'ra2pipe/build.mjs')], {
  env: { ...process.env, RA2_INPUT_DIR: input, IRON_TIDE_PROJECT: project }, encoding: 'utf8' });
fs.writeFileSync(path.join(out, 'build.log'), build.stdout + build.stderr);
if (build.status !== 0) throw new Error('Normalization failed');
const read = name => JSON.parse(fs.readFileSync(path.join(project, 'data/ra2', name + '.json')));
const art = parseIni(required('artmd.ini').data.toString('latin1'));
const rules = parseIni(required('rulesmd.ini').data.toString('latin1'));
const original = read('units').vehicles.ROBO, building = read('buildings').buildings.GAROBO;
const raw = getSec(rules, 'ROBO').keys, gfx = getSec(art, 'GAROBO').keys;
if (original.primary !== 'Robogun' || getSec(rules, 'GAROBO').keys.get('powersunit') !== 'ROBO')
  throw new Error('Unsupported source rules');
const pack = { version: 1, source: 'Local Steam Yuri Revenge', units: [], buildings: [],
  source_units: { ROBO: original }, source_buildings: { GAROBO: building },
  weapons: {}, warheads: {}, projectiles: {}, art: {}, sounds: {} };
const w = structuredClone(read('weapons').weapons.Robogun);
const wh = structuredClone(read('warheads').warheads[w.warhead]);
const pj = structuredClone(read('projectiles').projectiles[w.projectile]);
wh.id = 'YR_ROBO_' + wh.id; pj.id = 'YR_ROBO_' + pj.id;
w.id = 'YR_Robogun'; w.warhead = wh.id; w.projectile = pj.id; w.report = 'YR_' + w.report;
pack.weapons[w.id] = w; pack.warheads[wh.id] = wh; pack.projectiles[pj.id] = pj;
const buildMultiplier = Number(raw.get('buildtimemultiplier') || 1);
const unit = { id: 'ROBO', name: '机器人坦克', faction: 'allied', role: 'vehicle', role_name: '两栖机器人',
  ra2: true, expansion: 'yr', cost: original.cost, hp: original.hp, build_time: original.cost / 50 * buildMultiplier,
  build_time_multiplier: buildMultiplier, armor: 'heavy', ra2_armor: original.armor,
  speed: original.speed * 15, sight: original.sight * 55, radius: 15, tags: ['vehicle'],
  built_at: 'GAWEAP', ra2_prereq: original.prerequisites, tech_level: original.tech_level,
  image: original.image, cameo: original.cameo, movement_zone: 'amphibious', voxel: true,
  powered_by: 'GAROBO', immune_to_psionics: true, immune_to_radiation: true,
  desc: '两栖无人坦克。需己方已运转的机器人控制中心与充足电力；断电或失去控制中心后停机，恢复后继续执行原指令。不能升级。',
  move: { speed: original.speed * 15, speed_units: original.speed, rot: Number(raw.get('rot')) * 360 / 256 * 15,
    rot_units: Number(raw.get('rot')), accel_time: 0, accelerates: false, turret: true, crusher: true,
    crushable: false, weight: 0, movement_zone: original.movement_zone, speed_type: 'Hover', locomotor: original.locomotor },
  weapon: { name: 'Robogun', attack_type: 'shell', damage: w.damage, cooldown: w.rof / 15,
    range: w.range * 55, min_range: (w.min_range || 0) * 55, projectile_speed: Math.max(520, Math.min(1300, w.speed * 11)),
    burst: w.burst || 1, burst_delay: 0.12, aoe: 0, ra2_weapon_id: w.id, ra2_warhead: wh.id,
    ra2_projectile: pj.id, ra2_aa: pj.aa, report: w.report }, voice: {} };
const soundIds = new Set(['RobotTankAttack']);
for (const [kind, key] of Object.entries({ select: 'voiceselect', select_deactivated: 'voiceselectdeactivated',
  move: 'voicemove', attack: 'voiceattack', die: 'diesound', activate: 'activatesound', deactivate: 'deactivatesound' })) {
  const id = raw.get(key);
  if (id) { soundIds.add(id); unit.voice[kind] = 'YR_' + id; }
}
pack.units.push(unit);
pack.buildings.push({ id: 'GAROBO', name: '机器人控制中心', faction: 'allied', role: 'structure', role_name: '科技建筑',
  ra2: true, expansion: 'yr', cost: building.cost, hp: building.hp, build_time: building.cost / 50,
  armor: 'structure', ra2_armor: building.armor, radius: 26, sight: building.sight * 55,
  tags: ['structure'], builds: [], foundation: gfx.get('foundation'), buildup: gfx.get('buildup'),
  ra2_prereq: building.prerequisites, tech_level: building.tech_level, power: building.power, powered: true,
  powers_unit: 'ROBO', desc: '解锁机器人坦克。耗电 100；任意一座己方控制中心正常运转即可控制本方所有机器人坦克。' });
function write(name, data) {
  const target = path.join(project, name); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, data);
}
const json = (name, data) => write(name, JSON.stringify(data, null, 2) + '\n');
const pal = decodePal(required('unittem.pal').data);
for (let i = 16; i < 32; i++) {
  const level = pal[i * 4] / 252;
  [87, 168, 255].forEach((c, k) => pal[i * 4 + k] = Math.round(c * level));
}
// YR uses GENERMD.MIX (not GENERICMD). Resolve this archive explicitly so
// duplicate building names in SNOWMD cannot override the temperate artwork.
const genericBytes = required('genermd.mix').data;
const savedLog = console.log;
let generic;
try { console.log = () => {}; generic = new MixFile(new DataStream(new DataView(genericBytes.buffer, genericBytes.byteOffset, genericBytes.length))); }
finally { console.log = savedLog; }
function genericShape(name) {
  const e = generic.getEntry(MixEntry.hashFilename(name.toUpperCase()) >>> 0);
  if (!e) return null;
  const begin = generic.getDataStart() + e.offset;
  if (begin < generic.getDataStart() || begin + e.length > genericBytes.length) throw new Error('Invalid generic SHP range');
  const hit = { data: genericBytes.subarray(begin, begin + e.length), source: 'ra2md.mix > genermd.mix > ' + name };
  provenance[name] = {source: hit.source, sha256: sha256(hit.data)};
  return hit;
}
// Damaged active frames share the same source sheet.
function shape(name, id = name, options = {}, palette = pal) {
  const hit = genericShape(name[0] + 'G' + name.slice(2) + '.shp') || genericShape(name + '.shp');
  if (!hit) throw new Error(`Missing temperate SHP ${name}`);
  const shp = decodeShp(hit.data);
  const sheet = montageIndexed(shp, Math.min(12, shp.frames.length));
  write(`assets/ra2/shp/${id}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, palette));
  const meta = { id, image: name, source: hit.source, cell: [shp.width, shp.height], count: shp.frames.length,
    rects: sheet.rects, dmg: 1, shadow: false, ...options };
  if (options.buildup) { meta.raw_count = meta.count; meta.count /= 2; meta.rects = meta.rects.slice(0, meta.count); }
  json(`assets/ra2/shp/${id}.json`, meta);
  return meta;
}
const body = shape('GAROBO', 'GAROBO', { dmg: 3, shadow: true });
shape(gfx.get('buildup'), gfx.get('buildup'), { buildup: true });
const active = shape(gfx.get('activeanim'), gfx.get('activeanim'), {shadow: true, frames: 40});
if (body.cell.join() !== active.cell.join() || active.count !== 80) throw new Error('Unexpected controller animation layout');
const layer = { kind: 'activeanim', image: gfx.get('activeanim'), frames: 40, shadow: true, x: 0, y: 0 };
for (const [suffix, target] of [['', layer], ['damaged', layer.dmg = {}]]) {
  const keys = getSec(art, gfx.get('activeanim' + suffix)).keys;
  Object.assign(target, { image: layer.image, frames: 40, shadow: true,
    loopStart: Number(keys.get('loopstart')), loopEnd: Number(keys.get('loopend')), rate: Number(keys.get('rate')) });
}
json('assets/ra2/bldanim/GAROBO.json', { id: 'GAROBO', layers: [layer] });
for (const [id, cameo] of [['ROBO', original.cameo], ['GAROBO', gfx.get('cameo')]]) {
  const hit = required(cameo + '.shp'), sheet = montageIndexed(decodeShp(hit.data), 1);
  write(`assets/ra2/cameo/${cameo}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, decodePal(required('cameo.pal').data)));
  pack.art[id] = { cameo: `res://assets/ra2/cameo/${cameo}.png`, [id === 'ROBO' ? 'vxl' : 'shp']: `res://assets/ra2/${id === 'ROBO' ? 'vxl' : 'shp'}/${id}.png` };
}
// Bake independent hull/turret/shadow atlases on one common canvas, retaining remap colours.
const model = name => parseVxl(required(name + '.vxl').data);
const hull = model('robo'), tur = model('robotur');
const frames = [hull, tur].map(m => Array.from({length: 8}, (_, facing) => renderVxl(m, {pal, facing, facings: 8})));
const shadows = [hull, tur].map(m => Array.from({length: 8}, (_, facing) => renderVxl(m, {pal, facing, facings: 8, shadow: true})));
const all = [...frames.flat(), ...shadows.flat()];
const minX = Math.min(...all.map(f => f.minX)), minY = Math.min(...all.map(f => f.minY));
const cw = Math.ceil(Math.max(...all.map(f => f.minX + f.width)) - minX) + 4;
const ch = Math.ceil(Math.max(...all.map(f => f.minY + f.height)) - minY) + 4;
const width = 8 * (cw + 2) + 2, height = ch + 4;
for (const [id, rows, shadow] of [['ROBO', [frames[0]], false], ['ROBO_tur', [frames[1]], false], ['ROBO_shd', shadows, true]]) {
  const rgba = new Uint8Array(width * height * 4);
  for (const row of rows) row.forEach((im, f) => {
    const ox = 2 + f * (cw + 2) + Math.round(im.minX - minX), oy = 2 + Math.round(im.minY - minY);
    for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
      const src = (y * im.width + x) * 4, dst = ((oy + y) * width + ox + x) * 4;
      if (!im.rgba[src + 3]) continue;
      for (let c = 0; c < 3; c++) rgba[dst + c] = shadow ? 0 : im.rgba[src + c];
      rgba[dst + 3] = 255;
    }
  });
  write(`assets/ra2/vxl/${id}.png`, encodePng(width, height, rgba));
  json(`assets/ra2/vxl/${id}.json`, {id, facings: 8, frameW: cw, frameH: ch, facing_offset: 4, ...(id === 'ROBO' ? {turret: 'ROBO_tur'} : {})});
}
// Same occupied front-face projection as the existing unit_muzzles pipeline.
const points = tur.limbs.flatMap(l => l.voxels.map(v => {
  const p = ['x','y','z'].map((k, i) => l.minBounds[i] + (v[k] + .5) * (l.maxBounds[i] - l.minBounds[i]) / l[['sizeX','sizeY','sizeZ'][i]]);
  return [0,4,8].map(r => l.matrix[r]*p[0] + l.matrix[r+1]*p[1] + l.matrix[r+2]*p[2] + l.matrix[r+3]);
}));
const tip = Math.max(...points.map(p => p[0])), face = points.filter(p => Math.abs(p[0]-tip) < .001);
const point = [0,1,2].map(i => face.reduce((s,p) => s+p[i],0)/face.length);
const origins = frames[1].map(f => [Math.round(f.minX-minX)+1-f.minX, Math.round(f.minY-minY)+1-f.minY]);
const muzzles = origins.map((o,f) => {const az = Math.PI/4-f*Math.PI/4; return [o[0]-point[0]*Math.sin(az)+point[1]*Math.cos(az), o[1]+.5*(point[0]*Math.cos(az)+point[1]*Math.sin(az))-point[2]*Math.sqrt(3)/2];});
if (muzzles.some(p => p[0]<0 || p[1]<0 || p[0]>=cw || p[1]>=ch)) throw new Error('Muzzle outside model canvas');
json('assets/ra2/unitweapon/ROBO.json', {id:'ROBO',image:'ROBO_tur',frameW:cw,frameH:ch,facings:8,muzzle_model_point:point,origins,muzzles});
json('data/yr_robot.json', pack);
for (const name of ['soundmd.ini','audio.idx','audio.bag']) fs.writeFileSync(path.join(input,name), required(name).data);
fs.writeFileSync(path.join(input,'sound_ids.json'), JSON.stringify([...soundIds]));
fs.writeFileSync(path.join(out,'source-audit.json'), JSON.stringify({inputs:source.audit(),files:provenance,source:source.root},null,2));
console.log(JSON.stringify({project, unit:'ROBO', building:'GAROBO', sounds:soundIds.size, canvas:[cw,ch]}));
