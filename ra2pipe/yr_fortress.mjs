// Scoped, repeatable export from the user's installed YR; never rewrites live RA2 tables.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_fortress.mjs <YR directory> <new external candidate>');
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
const original = read('units').vehicles.BFRT;
const raw = getSec(rules, 'BFRT').keys;
if (original.primary !== '20mmRapid' || raw.get('opentopped') !== 'yes')
  throw new Error('Unsupported source rules');
const combat = getSec(rules, 'CombatDamage').keys;
const pack = { version: 1, source: 'Local Steam Yuri Revenge', units: [], buildings: [],
  source_units: { BFRT: original }, weapons: {}, warheads: {}, projectiles: {}, art: {}, sounds: {} };
const w = structuredClone(read('weapons').weapons['20mmRapid']);
const wh = structuredClone(read('warheads').warheads[w.warhead]);
const pj = structuredClone(read('projectiles').projectiles[w.projectile]);
wh.id = 'YR_BFRT_' + wh.id; pj.id = 'YR_BFRT_' + pj.id;
w.id = 'YR_20mmRapid'; w.warhead = wh.id; w.projectile = pj.id; w.report = 'YR_' + w.report;
pack.weapons[w.id] = w; pack.warheads[wh.id] = wh; pack.projectiles[pj.id] = pj;
const buildMultiplier = Number(raw.get('buildtimemultiplier') || 1);
const unit = { id: 'BFRT', name: '战斗要塞', faction: 'allied', role: 'vehicle', role_name: '重型步兵战车',
  ra2: true, expansion: 'yr', cost: original.cost, hp: original.hp, build_time: original.cost / 50 * buildMultiplier,
  build_time_multiplier: buildMultiplier, armor: 'heavy', ra2_armor: original.armor,
  speed: original.speed * 15, sight: original.sight * 55, radius: 24, tags: ['vehicle'],
  built_at: 'GAWEAP', ra2_prereq: original.prerequisites, tech_level: original.tech_level,
  image: original.image, cameo: original.cameo, movement_zone: 'land', voxel: true,
  open_topped: { range_bonus: Number(combat.get('opentoppedrangebonus')) * 55,
    damage_multiplier: Number(combat.get('opentoppeddamagemultiplier')),
    warp_distance: Number(combat.get('opentoppedwarpdistance')) * 55 },
  desc: '搭载 5 名步兵并允许乘员独立开火，乘员射程增加 2 格、伤害乘以 1.2；可碾压敌方普通地面载具。需要盟军战车工厂与作战实验室。E 或点击已选中的车体卸载。',
  move: { speed: original.speed * 15, speed_units: original.speed, rot: Number(raw.get('rot')) * 360 / 256 * 15,
    rot_units: Number(raw.get('rot')), accel_time: 0, accelerates: false, turret: false, crusher: true,
    crushable: false, weight: Number(raw.get('weight')), movement_zone: original.movement_zone,
    speed_type: 'Track', locomotor: original.locomotor },
  weapon: { name: '20mmRapid', attack_type: 'bullet', damage: w.damage, cooldown: w.rof / 15,
    range: w.range * 55, min_range: (w.min_range || 0) * 55, projectile_speed: Math.max(520, Math.min(1300, w.speed * 11)),
    burst: w.burst || 1, burst_delay: 0.12, aoe: 0, ra2_weapon_id: w.id, ra2_warhead: wh.id,
    ra2_projectile: pj.id, ra2_aa: pj.aa, report: w.report }, voice: {} };
const soundIds = new Set([w.report.replace(/^YR_/, '')]);
for (const [kind, key] of Object.entries({ select: 'voiceselect', move: 'voicemove', attack: 'voiceattack', die: 'diesound' })) {
  const id = raw.get(key);
  if (id) { soundIds.add(id); unit.voice[kind] = 'YR_' + id; }
}
pack.units.push(unit);
function write(name, data) {
  const target = path.join(project, name); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, data);
}
const json = (name, data) => write(name, JSON.stringify(data, null, 2) + '\n');
const pal = decodePal(required('unittem.pal').data);
for (let i = 16; i < 32; i++) {
  const level = pal[i * 4] / 252;
  [87, 168, 255].forEach((c, k) => pal[i * 4 + k] = Math.round(c * level));
}
// Bake independent hull/shadow atlases on one common canvas, retaining remap colours.
const model = name => parseVxl(required(name + '.vxl').data);
const hull = model('bfrt');
const frames = [Array.from({length: 32}, (_, facing) => renderVxl(hull, {pal, facing, facings: 32}))];
const shadows = [Array.from({length: 32}, (_, facing) => renderVxl(hull, {pal, facing, facings: 32, shadow: true}))];
const all = [...frames.flat(), ...shadows.flat()];
const minX = Math.min(...all.map(f => f.minX)), minY = Math.min(...all.map(f => f.minY));
const cw = Math.ceil(Math.max(...all.map(f => f.minX + f.width)) - minX) + 4;
const ch = Math.ceil(Math.max(...all.map(f => f.minY + f.height)) - minY) + 4;
const width = 32 * (cw + 2) + 2, height = ch + 4;
for (const [id, rows, shadow] of [['BFRT', [frames[0]], false], ['BFRT_shd', shadows, true]]) {
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
  json(`assets/ra2/vxl/${id}.json`, {id, facings: 32, frameW: cw, frameH: ch, facing_offset: 16});
}
// Occupied front-face projection as the existing unit_muzzles pipeline.
const points = hull.limbs.flatMap(l => l.voxels.map(v => {
  const p = ['x','y','z'].map((k, i) => l.minBounds[i] + (v[k] + .5) * (l.maxBounds[i] - l.minBounds[i]) / l[['sizeX','sizeY','sizeZ'][i]]);
  return [0,4,8].map(r => l.matrix[r]*p[0] + l.matrix[r+1]*p[1] + l.matrix[r+2]*p[2] + l.matrix[r+3]);
}));
const tip = Math.max(...points.map(p => p[0])), face = points.filter(p => Math.abs(p[0]-tip) < .001);
const point = [0,1,2].map(i => face.reduce((s,p) => s+p[i],0)/face.length);
const origins = frames[0].map(f => [Math.round(f.minX-minX)+1-f.minX, Math.round(f.minY-minY)+1-f.minY]);
const muzzles = origins.map((o,f) => {const az = Math.PI/4-f*Math.PI/16; return [o[0]-point[0]*Math.sin(az)+point[1]*Math.cos(az), o[1]+.5*(point[0]*Math.cos(az)+point[1]*Math.sin(az))-point[2]*Math.sqrt(3)/2];});
if (muzzles.some(p => p[0]<0 || p[1]<0 || p[0]>=cw || p[1]>=ch)) throw new Error('Muzzle outside model canvas');
json('assets/ra2/unitweapon/BFRT.json', {id:'BFRT',image:'BFRT',frameW:cw,frameH:ch,facings:32,muzzle_model_point:point,origins,muzzles});
const cameo = required(original.cameo + '.shp'), sheet = montageIndexed(decodeShp(cameo.data), 1);
write(`assets/ra2/cameo/${original.cameo}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, decodePal(required('cameo.pal').data)));
pack.art.BFRT = {cameo: `res://assets/ra2/cameo/${original.cameo}.png`, vxl: 'res://assets/ra2/vxl/BFRT.png'};
json('data/yr_fortress.json', pack);
for (const name of ['soundmd.ini','audio.idx','audio.bag']) fs.writeFileSync(path.join(input,name), required(name).data);
fs.writeFileSync(path.join(input,'sound_ids.json'), JSON.stringify([...soundIds]));
fs.writeFileSync(path.join(out,'source-audit.json'), JSON.stringify({inputs:source.audit(),files:provenance,source:source.root},null,2));
console.log(JSON.stringify({project, unit:'BFRT', sounds:soundIds.size, canvas:[cw,ch]}));
