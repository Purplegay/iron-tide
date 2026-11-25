// Read-only local YR art intake; does not alter gameplay tables or their save digest.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni } from './lib/ini.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/projectile_visuals.mjs <YR directory> <new candidate.json>');
if (fs.existsSync(output)) throw new Error('Refusing to overwrite candidate');
const source = new YrSource(game);
const hit = source.read('artmd.ini');
if (!hit) throw new Error('Missing artmd.ini');
const art = parseIni(hit.data.toString('latin1'));
const root = path.resolve(import.meta.dirname, '../iron_tide');
const files = ['data/ra2/projectiles.json', 'data/ra2/allied_capabilities.json', 'data/yr_allied.json', 'data/yr_robot.json', 'data/yr_fortress.json'];
const images = {};
for (const file of files) {
  const pack = JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
  for (const projectile of Object.values(pack.projectiles || {})) {
    const image = String(projectile.image || '').toUpperCase();
    if (!image || image === 'NONE' || images[image]) continue;
    const section = art.get(image.toLowerCase());
    const keys = section?.keys;
    if (!keys) continue;
    const flags = {};
    for (const field of ['UseLineTrail', 'LineTrailColor', 'LineTrailColorDecrement', 'Trailer', 'SpawnDelay', 'Rotates']) {
      if (keys.has(field.toLowerCase())) flags[field] = keys.get(field.toLowerCase());
    }
    if (Object.keys(flags).length) images[image] = flags;
  }
}
fs.writeFileSync(output, JSON.stringify({ source: { file: 'artmd.ini', archive: hit.source, sha256: sha256(hit.data) }, images }, null, 2) + '\n');
console.log(JSON.stringify({ output, images }));
