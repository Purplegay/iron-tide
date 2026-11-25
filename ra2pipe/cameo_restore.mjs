// Restore missing catalog cameos from local game data without regenerating gameplay data.
// RA2_MIX_DIR=<local game directory> IRON_TIDE_PROJECT=<candidate project> node ra2pipe/cameo_restore.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { PROJECT } from './paths.mjs';
import { openAll, readNamed, readFileFromMix, decodeShp, decodePal, frameToRgba, encodePng } from './art_lib.mjs';

const read = name => JSON.parse(fs.readFileSync(path.join(PROJECT, 'data', name), 'utf8'));
const units = read('ra2/units.json');
const buildings = read('ra2/buildings.json');
const source = { ...units.infantry, ...units.vehicles, ...units.aircraft, ...buildings.buildings };
const catalog = read('ra2_allied.json');
const pending = [];
const unavailable = [];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
openAll();
const paletteBytes = readFileFromMix('CAMEO.PAL');
if (!paletteBytes) throw new Error('Local CAMEO.PAL is missing.');
const palette = decodePal(paletteBytes);

for (const entity of [...catalog.units, ...catalog.buildings]) {
  const existing = catalog.art[entity.id]?.cameo;
  if (existing?.startsWith('res://') && fs.existsSync(path.join(PROJECT, existing.slice(6)))) continue;
  const name = source[entity.id]?.cameo;
  if (!name) {
    unavailable.push({ id: entity.id, reason: 'No source Cameo mapping; retain fallback.' });
    continue;
  }
  if (!/^[a-z0-9_]+$/i.test(name)) throw new Error(`Invalid cameo name for ${entity.id}.`);
  const bytes = readNamed('CAMEO.MIX', name + '.SHP');
  if (!bytes) throw new Error(`Missing CAMEO.MIX/${name}.SHP for ${entity.id}.`);
  const frame = decodeShp(bytes).frames[0];
  if (!frame || frame.w <= 0 || frame.h <= 0) throw new Error(`Invalid frame for ${entity.id}.`);
  const png = encodePng(frame.w, frame.h,
    frameToRgba(frame, palette, { canvasW: frame.w, canvasH: frame.h }));
  pending.push({
    png, id: entity.id, resource: `res://assets/ra2/cameo/${name}.png`,
    source: `CAMEO.MIX/${name}.SHP`, source_sha256: hash(bytes),
    palette: 'CAMEO.PAL', palette_sha256: hash(paletteBytes),
    dimensions: [frame.w, frame.h], png_sha256: hash(png)
  });
}

// Decode/validate every required source before modifying the candidate.
for (const item of pending) {
  const destination = path.join(PROJECT, item.resource.slice(6));
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, item.png);
  catalog.art[item.id] = { ...catalog.art[item.id], cameo: item.resource };
}
if (pending.length) {
  fs.writeFileSync(path.join(PROJECT, 'data/ra2_allied.json'), JSON.stringify(catalog, null, 1) + '\n');
  const provenance = path.join(PROJECT, 'assets/ra2/cameo/restoration.json');
  const previous = fs.existsSync(provenance) ? JSON.parse(fs.readFileSync(provenance, 'utf8')) : {};
  for (const { png, id, ...item } of pending) previous[id] = item;
  fs.writeFileSync(provenance, JSON.stringify(previous, null, 2) + '\n');
}
console.log(JSON.stringify({ restored: pending.map(({ png, ...item }) => item), unavailable }, null, 2));
