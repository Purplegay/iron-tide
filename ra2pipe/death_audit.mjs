// Read-only official YR death/survivor field inventory; no runtime import.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/death_audit.mjs <YR directory> <new audit.json>');
if (fs.existsSync(output)) throw new Error('Audit output already exists; choose a new path');
const source = new YrSource(game);
const ruleBytes = source.read('rulesmd.ini'), artBytes = source.read('artmd.ini');
const rules = parseIni(ruleBytes.data.toString('latin1')), art = parseIni(artBytes.data.toString('latin1'));
const row = (ini, id) => Object.fromEntries(getSec(ini, id)?.keys || []);
const fields = ['image', 'crewed', 'cost', 'aibaseplanningside', 'explosion', 'mindebris', 'maxdebris',
  'debrisanim', 'debristypes', 'debrismaximums', 'debrisminimums', 'debrisdamages', 'leaverubble',
  'deathweapon', 'deathanim', 'deathanims', 'crashable', 'explodes', 'occupiable', 'maxnumberoccupants'];
const pick = (data, keys) => Object.fromEntries(keys.filter(k => k in data).map(k => [k, data[k]]));
const fxRoot = path.resolve('iron_tide/assets/ra2/fx');
const present = new Set(fs.readdirSync(fxRoot).filter(p => p.endsWith('.json')).map(p => p.slice(0, -5).toUpperCase()));
const animations = new Set();
const types = {};
for (const category of ['InfantryTypes', 'VehicleTypes', 'AircraftTypes', 'BuildingTypes']) {
  types[category] = [];
  for (const id of new Set(Object.values(row(rules, category)))) {
    const definition = row(rules, id);
    if (!Object.keys(definition).length) continue;
    const appearance = row(art, definition.image || id);
    const sequence = appearance.sequence ? row(art, appearance.sequence) : {};
    const values = pick(definition, fields);
    for (const field of ['explosion', 'debrisanim', 'deathanim', 'deathanims']) {
      for (const name of (definition[field] || '').split(',').map(s => s.trim()).filter(Boolean)) animations.add(name.toUpperCase());
    }
    types[category].push({ id, explicit_rules: values,
      art: pick(appearance, ['sequence', 'buildup', 'activeanimdamaged', 'productionanimdamaged', 'destroyanim']),
      death_sequences: Object.fromEntries(Object.entries(sequence).filter(([k]) => /^(wet)?die\d+$/.test(k))) });
  }
}
const general = row(rules, 'General');
const generalText = ruleBytes.data.toString('latin1').split(/^\[General\]\s*$/mi)[1]?.split(/^\[/m)[0] || '';
const result = {
  source: { rules: { location: ruleBytes.source, sha256: sha256(ruleBytes.data) }, art: { location: artBytes.source, sha256: sha256(artBytes.data) } },
  general: pick(general, ['survivorrate', 'alliedsurvivordivisor', 'sovietsurvivordivisor', 'thirdsurvivordivisor', 'crewescape',
    'alliedcrew', 'sovietcrew', 'thirdcrew', 'technician', 'engineer', 'conditionred', 'conditionyellow']),
  audio_visual: pick(row(rules, 'AudioVisual'), ['conditionred', 'conditionyellow']),
  original_comments: generalText.split(/\r?\n/).filter(line => /^(SurvivorRate|AlliedSurvivorDivisor|SovietSurvivorDivisor|ThirdSurvivorDivisor|CrewEscape|AlliedCrew|SovietCrew|ThirdCrew|Technician|Engineer)=/i.test(line)),
  types,
  referenced_animation_manifest_presence: [...animations].sort().map(id => {
    const original = row(art, id), image = original.image || id;
    const media = source.read(image + '.shp');
    return { id, imported_fx: present.has(id), original_art: original,
      original_shp: media ? { location: media.source, sha256: sha256(media.data) } : null };
  }),
  boundary: 'Explicit original fields only: absent is not false/default. Asset presence does not prove runtime consumption. Crew/division/random/placement behaviour needs engine evidence; this script neither modifies gameplay nor imports missing media.',
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ output, categories: Object.fromEntries(Object.entries(types).map(([k, v]) => [k, v.length])),
  referenced_animations: animations.size, imported_fx: result.referenced_animation_manifest_presence.filter(a => a.imported_fx).length,
  crewed_buildings: types.BuildingTypes.filter(x => /^yes$/i.test(x.explicit_rules.crewed || '')).length,
  rubble_buildings: types.BuildingTypes.filter(x => /^(yes|true|1)$/i.test(x.explicit_rules.leaverubble || '')).length }));
