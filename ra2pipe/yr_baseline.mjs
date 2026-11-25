// Read-only local Yuri intake. Outputs an external candidate, never edits game archives.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, listSection, numOf, boolOf } from './lib/ini.mjs';
import { decodeShp, decodePal, frameToRgba, encodePng } from './art_lib.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output || fs.existsSync(output)) throw new Error('Usage: yr_baseline.mjs <YR install> <new external candidate>');
const root = path.resolve(import.meta.dirname, '..');
const out = path.resolve(output);
for (const protectedRoot of [root, fs.realpathSync(game)])
  if (out === protectedRoot || out.startsWith(protectedRoot + path.sep)) throw new Error('External output required');
const source = new YrSource(game);
const hit = source.read('rulesmd.ini');
if (!hit) throw new Error('Missing rulesmd.ini');
const rules = parseIni(hit.data.toString('latin1'));
const entities = {}, rawEntities = {}, lists = {};
for (const type of ['BuildingTypes', 'InfantryTypes', 'VehicleTypes', 'AircraftTypes'])
  lists[type] = listSection(rules, type).map(x => x.id);
const ids = new Set();
for (const name of ['ra2_allied', 'yr_allied', 'yr_robot', 'yr_fortress']) {
  const doc = JSON.parse(fs.readFileSync(path.join(root, 'iron_tide/data', name + '.json'), 'utf8'));
  for (const row of [...doc.units || [], ...doc.buildings || []]) ids.add(row.id);
}
for (const id of ids) {
  const keys = rules.get(id.toLowerCase())?.keys;
  if (!keys) throw new Error(`Native entity missing: ${id}`);
  const row = {hp: numOf(keys.get('strength'), 1), cost: numOf(keys.get('cost'), 0),
    ra2_armor: keys.get('armor') || 'none', build_time_multiplier: numOf(keys.get('buildtimemultiplier'), 1),
    adjacent: numOf(keys.get('adjacent'), 2), base_normal: boolOf(keys.get('basenormal'), true),
    tech_level: numOf(keys.get('techlevel'), -1), cameo_priority: numOf(keys.get('cameopriority'), 0)};
  entities[id] = row;
  rawEntities[id] = Object.fromEntries(keys);
}
const general = rules.get('general').keys;
const build = {build_speed: numOf(general.get('buildspeed'), .7),
  buildup_time_minutes: numOf(general.get('builduptime'), .06),
  multiple_factory: numOf(general.get('multiplefactory'), .8),
  wall_build_speed: numOf(general.get('wallbuildspeedcoefficient'), 3),
  refund_percent: numOf(general.get('refundpercent'), .5)};
const provenance = {archive: hit.source, file: 'rulesmd.ini', sha256: sha256(hit.data)};
fs.mkdirSync(out, {recursive:true});
fs.writeFileSync(path.join(out, 'yr_baseline.json'), JSON.stringify({source:provenance, build, entities, lists}, null, 2)+'\n');
fs.writeFileSync(path.join(out, 'yr_baseline_source.json'), JSON.stringify({source:provenance, general:Object.fromEntries(general), entities:rawEntities}, null, 2)+'\n');
// Original mouse guard icon, frame 68 (PointerType.Guard); retain provenance.
const shape = source.read('mouse.shp'), palette = source.read('mousepal.pal');
if (!shape || !palette) throw new Error('Missing Yuri cursor art');
const shp = decodeShp(shape.data);
const png = encodePng(shp.width, shp.height, frameToRgba(shp.frames[68], decodePal(palette.data), {canvasW:shp.width, canvasH:shp.height}));
fs.writeFileSync(path.join(out, 'guard.png'), png);
fs.writeFileSync(path.join(out, 'guard-source.json'), JSON.stringify({source:shape.source, frame:68, source_sha256:sha256(shape.data), palette_sha256:sha256(palette.data), png_sha256:sha256(png)}, null,2)+'\n');
for (const [name, fingerprint] of source.inputs)
  if (sha256(fs.readFileSync(path.join(source.root, name))) !== fingerprint.sha256) throw new Error('Input archive changed');
console.log(JSON.stringify({entities:ids.size, source:provenance, output:out}));
