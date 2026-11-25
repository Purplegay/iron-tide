// Extract production restrictions only; do not replace combat tables or saved unit identities.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni } from './lib/ini.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/production_rules.mjs <YR directory> <new candidate.json>');
if (fs.existsSync(output)) throw new Error('Refusing to overwrite candidate');
const source = new YrSource(game), hit = source.read('rulesmd.ini');
if (!hit) throw new Error('Missing rulesmd.ini');
const rules = parseIni(hit.data.toString('latin1'));
const root = path.resolve(import.meta.dirname, '../iron_tide/data');
const units = {};
for (const file of ['ra2_allied.json', 'yr_allied.json', 'yr_robot.json', 'yr_fortress.json']) {
  for (const unit of JSON.parse(fs.readFileSync(path.join(root, file), 'utf8')).units) {
    const keys = rules.get(unit.id.toLowerCase())?.keys;
    if (!keys) throw new Error(`Missing rules for ${unit.id}`);
    const flags = {};
    for (const field of ['RequiresStolenAlliedTech', 'RequiresStolenSovietTech', 'RequiresStolenThirdTech', 'Spawned']) {
      if (keys.has(field.toLowerCase())) flags[field] = keys.get(field.toLowerCase());
    }
    const level = Number(keys.get('techlevel') ?? -1);
    if (!Number.isInteger(level)) throw new Error(`Invalid TechLevel for ${unit.id}`);
    units[unit.id] = { tech_level: level, extra: flags };
  }
}
fs.writeFileSync(output, JSON.stringify({ source: { file: 'rulesmd.ini', archive: hit.source, sha256: sha256(hit.data) }, units }, null, 2) + '\n');
console.log(`Wrote ${Object.keys(units).length} production records to ${output}`);
