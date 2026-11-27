// Usage: node tools/yr_garrison_pips.mjs <local YR installation> <new output directory>
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from '../../ra2pipe/lib/yr_source.mjs';
import { decodeShp, decodePal, encodePngIndexed } from '../../ra2pipe/art_lib.mjs';

const [game, out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw new Error('Expected a local YR installation and a new output directory');
const source = new YrSource(game);
const shape = source.read('pips.shp');
const palette = source.read('palette.pal');
if (!shape || !palette) throw new Error('Missing PIPS.SHP or PALETTE.PAL');
const shp = decodeShp(shape.data);
const pal = decodePal(palette.data);
const provenance = (name, resource) => ({ name, archive: resource.source, sha256: sha256(resource.data) });
const metadata = { source: provenance('PIPS.SHP', shape), palette: provenance('PALETTE.PAL', palette), frames: {} };
fs.mkdirSync(out, { recursive: true });
for (const [name, index] of [['empty', 6], ['occupied', 7]]) {
  const frame = shp.frames[index];
  if (!frame?.w || !frame.h) throw new Error(`Missing pip frame ${index}`);
  const png = encodePngIndexed(frame.w, frame.h, frame.data, pal);
  fs.writeFileSync(path.join(out, `${name}.png`), png);
  metadata.frames[name] = { index, size: [frame.w, frame.h], offset: [frame.x, frame.y], sha256: sha256(png) };
}
fs.writeFileSync(path.join(out, 'source.json'), JSON.stringify(metadata, null, 2) + '\n');
