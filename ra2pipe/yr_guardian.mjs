// Scoped Guardian GI export from locally installed YR. Never regenerates live RA2 tables.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec, csv, boolOf } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_guardian.mjs <YR directory> <new external candidate>');
const out = path.join(fs.realpathSync(path.dirname(path.resolve(output))), path.basename(output));
for (const protectedRoot of [fs.realpathSync(root), fs.realpathSync(game)]) {
  if (out === protectedRoot || out.startsWith(protectedRoot + path.sep)) throw new Error('Candidate must be outside source and repository');
}
if (fs.existsSync(out)) throw new Error('Candidate exists; refusing overwrite');
const source = new YrSource(game);
const required = name => { const hit = source.read(name); if (!hit) throw new Error(`Missing ${name}`); return hit; };
const input = path.join(out, 'input');
const project = path.join(out, 'project');
fs.mkdirSync(input, { recursive: true });
for (const [name, target] of [['rulesmd.ini', 'rules.ini'], ['artmd.ini', 'art.ini']]) {
  fs.writeFileSync(path.join(input, target), required(name).data);
}
const build = spawnSync(process.execPath, [path.join(root, 'ra2pipe/build.mjs')], {
  env: { ...process.env, RA2_INPUT_DIR: input, IRON_TIDE_PROJECT: project }, encoding: 'utf8' });
fs.writeFileSync(path.join(out, 'build.log'), build.stdout + build.stderr);
if (build.status !== 0) throw new Error('Source normalization failed; see build.log');
const read = name => JSON.parse(fs.readFileSync(path.join(project, 'data/ra2', `${name}.json`), 'utf8'));
const rules = parseIni(required('rulesmd.ini').data.toString('latin1'));
const art = parseIni(required('artmd.ini').data.toString('latin1'));
const raw = getSec(rules, 'GGI');
const original = read('units').infantry.GGI;
if (!original || original.secondary !== 'MissileLauncher') throw new Error('Unsupported Guardian GI rules');
original.occupier = boolOf(raw.keys.get('occupier')); // Preserve explicit Occupier=no.
const gfx = getSec(art, original.image);
const unit = {
  id: 'GGI', name: '重装大兵', faction: 'allied', role: 'infantry', role_name: '反装甲步兵',
  ra2: true, expansion: 'yr', cost: original.cost, build_time: original.cost / 50,
  hp: original.hp, armor: 'unarmored', ra2_armor: original.armor,
  speed: original.speed * 15, sight: original.sight * 55, radius: 7,
  tags: ['infantry'], built_at: 'GAPILE', ra2_prereq: original.prerequisites,
  tech_level: original.tech_level, image: original.image, cameo: original.cameo,
  movement_zone: 'infantry', voxel: false, deployer: true, deploy_frame: original.deploy_frame,
  deploy_attack_mult: 1, deploy_defense_mult: 1,
  deployed_crushable: boolOf(raw.keys.get('deployedcrushable'), true),
  deployed_prone: false,
  desc: '尤复盟军步兵。站立使用机枪；部署后固定发射反装甲/防空导弹，具有近距盲区，且不可被普通坦克碾压。',
  move: { speed: original.speed * 15, speed_units: original.speed, rot: 0, rot_units: 0,
    accel_time: 0, accelerates: false, turret: false, crusher: false, crushable: boolOf(raw.keys.get('crushable')),
    weight: 0, movement_zone: original.movement_zone, locomotor: original.locomotor }
};
const pack = { version: 1, source: 'Local Steam Yuri Revenge', units: [unit], source_units: { GGI: original },
  weapons: {}, warheads: {}, projectiles: {}, art: {}, sounds: { specs: {}, entries: {} } };
const prefix = name => `YR_${name}`;
const weapons = read('weapons').weapons, warheads = read('warheads').warheads, projectiles = read('projectiles').projectiles;
const soundIds = new Set();
function weapon(name) {
  const w = structuredClone(weapons[name]);
  const pj = structuredClone(projectiles[w.projectile]);
  const wh = structuredClone(warheads[w.warhead]);
  wh.id = prefix(wh.id); pj.id = prefix(pj.id);
  pack.warheads[wh.id] = wh; pack.projectiles[pj.id] = pj;
  soundIds.add(w.report);
  w.id = prefix(w.id); w.warhead = wh.id; w.projectile = pj.id; w.report = prefix(w.report);
  pack.weapons[w.id] = w;
  return { name, attack_type: pj.aa ? 'rocket' : 'bullet', damage: w.damage,
    cooldown: w.rof / 15, range: w.range * 55, min_range: (w.min_range || 0) * 55,
    projectile_speed: w.speed > 0 ? Math.max(520, Math.min(1300, w.speed * 11)) : 0,
    burst: w.burst || 1, burst_delay: 0.12, aoe: 0,
    ra2_weapon_id: w.id, ra2_warhead: wh.id, ra2_projectile: pj.id, ra2_aa: pj.aa, report: w.report };
}
unit.weapon = weapon(original.primary); unit.elite_weapon = weapon(original.elite_primary);
unit.deployed_weapon = weapon(original.secondary); unit.elite_deployed_weapon = weapon(original.elite_secondary);
unit.veteran = { veteran: Object.fromEntries(csv(raw.keys.get('veteranabilities')).map(k => [k, true])),
  elite: Object.fromEntries(csv(raw.keys.get('eliteabilities')).map(k => [k, true])), elite_weapon: unit.elite_weapon };
unit.voice = {};
for (const [kind, key] of Object.entries({ select: 'voiceselect', move: 'voicemove', attack: 'voiceattack',
  feedback: 'voicefeedback', special: 'voicespecialattack', die: 'diesound', crush: 'crushsound', deploy: 'deploysound', undeploy: 'undeploysound' })) {
  const id = raw.keys.get(key);
  if (id) { soundIds.add(id); unit.voice[kind] = prefix(id); }
}
const provenance = {};
function write(name, data) { const target = path.join(project, name); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, data); }
function sheet(image, target, palette, remap) {
  const hit = required(`${image}.shp`);
  provenance[`${image}.shp`] = { source: hit.source, sha256: sha256(hit.data) };
  const decoded = decodeShp(hit.data);
  if (!decoded.frames.length) throw new Error(`Empty SHP: ${image}`);
  const pal = decodePal(required(palette).data);
  if (remap) for (let i = 16; i <= 31; i++) {
    const level = pal[i * 4] / 252;
    [87, 168, 255].forEach((channel, n) => pal[i * 4 + n] = Math.round(channel * level));
  }
  const montage = montageIndexed(decoded, Math.min(12, decoded.frames.length));
  write(`${target}.png`, encodePngIndexed(montage.width, montage.height, montage.indices, pal));
  return { id: image, image, source: hit.source, cell: [decoded.width, decoded.height],
    count: decoded.frames.length, rects: montage.rects, dmg: 1, shadow: remap };
}
const metadata = sheet(original.image, 'assets/ra2/shp/GGI', 'unittem.pal', true);
write('assets/ra2/shp/GGI.json', JSON.stringify(metadata));
sheet(original.cameo, `assets/ra2/cameo/${original.cameo}`, 'cameo.pal', false);
const sequence = getSec(art, gfx.keys.get('sequence'));
const seq = {};
for (const name of sequence.keyOrder) {
  const [start, per, stride] = sequence.keys.get(name.toLowerCase()).split(',').map(Number);
  if (!Number.isFinite(start) || !Number.isFinite(per) || per <= 0) continue;
  const facings = stride ? 8 : 1;
  if (start + per * facings > metadata.count / 2) throw new Error(`Invalid sequence: ${name}`);
  seq[name] = { start, per, facings };
}
for (const name of ['Guard', 'Walk', 'FireUp', 'Deployed', 'DeployedFire', 'Die1']) if (!seq[name]) throw new Error(`Missing ${name}`);
write('assets/ra2/shp/GGI.seq.json', JSON.stringify({ image: 'GGI', source: gfx.keys.get('sequence'), seq }));
pack.art.GGI = { shp: 'res://assets/ra2/shp/GGI.png', cameo: `res://assets/ra2/cameo/${original.cameo}.png` };
for (const name of ['soundmd.ini', 'audio.idx', 'audio.bag']) fs.writeFileSync(path.join(input, name), required(name).data);
fs.writeFileSync(path.join(input, 'sound_ids.json'), JSON.stringify([...soundIds]));
write('data/yr_allied.json', JSON.stringify(pack, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'source-audit.json'), JSON.stringify({ inputs: source.audit(), art: provenance,
  source: source.root, rules: required('rulesmd.ini').source, adaptation: '55px range cells; 15fps ROF; speed *15; extension production cost/50' }, null, 2));
console.log(JSON.stringify({ project, unit: 'GGI', frames: metadata.count, sounds: soundIds.size }));
