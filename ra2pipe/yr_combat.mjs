// Reconcile existing combat catalogs against the user's local YR, without adding
// unsupported units or overwriting the installed game/live project.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec, numOf, csv } from './lib/ini.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_combat.mjs <local YR> <new external candidate>');
const out = path.join(fs.realpathSync(path.dirname(path.resolve(output))), path.basename(output));
for (const p of [fs.realpathSync(root), fs.realpathSync(game)])
  if (out === p || out.startsWith(p + path.sep)) throw new Error('External candidate required');
if (fs.existsSync(out)) throw new Error('Refusing candidate overwrite');
const source = new YrSource(game);
const hit = source.read('rulesmd.ini');
if (!hit) throw new Error('rulesmd.ini missing');
const rules = parseIni(hit.data.toString('latin1'));
const changes = [], gaps = [], files = [];
const armor = ['none', 'flak', 'plate', 'light', 'medium', 'heavy', 'wood', 'steel', 'concrete', 'special_1', 'special_2'];
const originalId = id => String(id).replace(/^YR_(?:ROBO_)?/, '');
const original = id => getSec(rules, originalId(id));
const activeWeapons = new Set(['hornetlauncher', 'hornetweapon', 'hornetweapone']);
const activeWarheads = new Set();
const activeUnits = new Set(['HORNET']);
const read = name => JSON.parse(fs.readFileSync(path.join(root, 'iron_tide/data', name), 'utf8'));
function set(object, key, value, context) {
  if (JSON.stringify(object[key]) !== JSON.stringify(value)) {
    changes.push({ context, key, before: object[key] ?? null, after: value });
    object[key] = value;
  }
}
function weapon(row, context, runtime = false) {
  const raw = original(runtime ? row.ra2_weapon_id : row.id);
  if (!raw) { gaps.push({ context, reason: 'source weapon missing' }); return; }
  activeWeapons.add(raw.name.toLowerCase());
  activeWarheads.add(String(raw.keys.get('warhead')).toLowerCase());
  const wh = original(raw.keys.get('warhead'));
  // These Damage values represent control/erasure rather than direct HP loss.
  // Record the unfinished adapter instead of silently converting it to a gun.
  if (runtime && ['mindcontrol', 'temporal'].some(k => wh?.keys.get(k)?.toLowerCase() === 'yes')) {
    gaps.push({ context, reason: 'special control/erasure adapter still required', original_damage: numOf(raw.keys.get('damage')), runtime_damage: row.damage });
    return;
  }
  const fields = runtime ? { damage: ['damage', 1, 0], cooldown: ['rof', 1 / 15, 0],
    range: ['range', 55, 0], min_range: ['minimumrange', 55, 0], burst: ['burst', 1, 1] }
    : { damage: ['damage', 1, 0], rof: ['rof', 1, 0], range: ['range', 1, 0],
      min_range: ['minimumrange', 1, 0], burst: ['burst', 1, 1], ambient_damage: ['ambientdamage', 1, 0] };
  for (const [key, [sourceKey, scale, fallback]] of Object.entries(fields))
    set(row, key, numOf(raw.keys.get(sourceKey), fallback) * scale, context);
  for (const [key, sourceKey] of Object.entries(runtime ? { ra2_warhead: 'warhead', ra2_projectile: 'projectile' } : { warhead: 'warhead', projectile: 'projectile' })) {
    // Preserve prefixed aliases when they refer to the same original definition.
    if (originalId(row[key]).toLowerCase() !== String(raw.keys.get(sourceKey)).toLowerCase())
      set(row, key, raw.keys.get(sourceKey), context);
  }
}
function warhead(row, context) {
  const raw = original(row.id);
  if (!raw) return;
  const verses = csv(raw.keys.get('verses'));
  set(row, 'verses_raw', raw.keys.get('verses') || '', context);
  set(row, 'verses', Object.fromEntries(armor.map((a, i) => [a, numOf(verses[i], 1)])), context);
  for (const [key, sourceKey] of Object.entries({ cell_spread: 'cellspread', percent_at_max: 'percentatmax', prone_damage: 'pronedamage' }))
    set(row, key, numOf(raw.keys.get(sourceKey)), context);
}
function write(name, doc) {
  const dest = path.join(out, 'data', name);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, JSON.stringify(doc, null, 2) + '\n');
  files.push({ path: name, before_sha256: sha256(fs.readFileSync(path.join(root, 'iron_tide/data', name))), after_sha256: sha256(fs.readFileSync(dest)) });
}
for (const name of ['ra2_allied.json', 'yr_allied.json', 'yr_robot.json']) {
  const doc = read(name);
  for (const entity of [...doc.units || [], ...doc.buildings || []]) {
    activeUnits.add(entity.id);
    for (const key of ['weapon', 'elite_weapon', 'deployed_weapon', 'elite_deployed_weapon'])
      if (entity[key]?.ra2_weapon_id) weapon(entity[key], `${entity.id}.${key}`, true);
    if (entity.veteran?.elite_weapon?.ra2_weapon_id) weapon(entity.veteran.elite_weapon, `${entity.id}.veteran.elite_weapon`, true);
  }
  for (const row of Object.values(doc.weapons || {})) weapon(row, row.id);
  for (const row of Object.values(doc.warheads || {})) warhead(row, row.id);
  write(name, doc);
}
for (const [file, key, update] of [['ra2/weapons.json', 'weapons', weapon], ['ra2/warheads.json', 'warheads', warhead]]) {
  const doc = read(file);
  const active = key === 'weapons' ? activeWeapons : activeWarheads;
  for (const row of Object.values(doc[key])) if (active.has(row.id.toLowerCase())) update(row, `${key}.${row.id}`);
  doc.combat_source = { name: 'Local Yuri Revenge rulesmd.ini', sha256: sha256(hit.data) };
  write(file, doc);
}
// Source HP/armor used in RA2 mode; extension-mode building HP stays intentional.
const units = read('ra2/units.json');
for (const category of ['infantry', 'vehicles', 'aircraft']) for (const row of Object.values(units[category])) {
  if (!activeUnits.has(row.id)) continue;
  const raw = original(row.id);
  if (!raw) continue;
  set(row, 'hp', numOf(raw.keys.get('strength')), `${category}.${row.id}`);
  set(row, 'armor', (raw.keys.get('armor') || 'none').toLowerCase(), `${category}.${row.id}`);
}
write('ra2/units.json', units);
// Independent raw source fixture for runtime regression (no normalized game data).
const fixture = { rules_sha256: sha256(hit.data), weapons: {}, warheads: {}, entities: {}, projectiles: {} };
for (const id of activeWeapons) {
  const raw = original(id);
  if (raw) {
    fixture.weapons[raw.name] = Object.fromEntries(raw.keys);
    const projectile = original(raw.keys.get('projectile'));
    if (projectile) fixture.projectiles[projectile.name] = Object.fromEntries(projectile.keys);
  }
}
for (const id of activeWarheads) {
  const raw = original(id);
  if (raw) fixture.warheads[raw.name] = Object.fromEntries(raw.keys);
}
for (const id of activeUnits) {
  const raw = original(id);
  if (raw) fixture.entities[raw.name] = { strength: numOf(raw.keys.get('strength')), armor: raw.keys.get('armor') || 'none' };
}
fs.mkdirSync(path.join(out, 'tests/fixtures'), { recursive: true });
fs.writeFileSync(path.join(out, 'tests/fixtures/yr_damage_source.json'), JSON.stringify(fixture, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'audit.json'), JSON.stringify({ source: source.root,
  rules: { archive: hit.source, sha256: sha256(hit.data) }, inputs: source.audit(), files, changes, gaps }, null, 2) + '\n');
console.log(JSON.stringify({ out, changes: changes.length, gaps }));
