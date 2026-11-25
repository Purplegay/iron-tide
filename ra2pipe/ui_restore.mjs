// Export only locally supplied RA2 sidebar art. Does not change gameplay data.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { PROJECT } from './paths.mjs';
import { openAll, readNamed, decodeShp, decodePal, frameToRgba, encodePng } from './art_lib.mjs';

openAll();
const mix = 'SIDEC01.MIX';
const paletteBytes = readNamed(mix, 'SIDEBAR.PAL');
if (!paletteBytes) throw new Error('Missing local allied SIDEBAR.PAL');
const palette = decodePal(paletteBytes);
const hash = b => createHash('sha256').update(b).digest('hex');
const output = path.join(PROJECT, 'assets/ra2/ui');
const items = [];
for (const name of ['TOP', 'TAB01', 'TAB02', 'TAB03']) {
  const bytes = readNamed(mix, name + '.SHP');
  if (!bytes) throw new Error('Missing local sidebar art: ' + name);
  const shp = decodeShp(bytes);
  shp.frames.forEach((frame, index) => {
    const png = encodePng(shp.width, shp.height,
      frameToRgba(frame, palette, { canvasW: shp.width, canvasH: shp.height }));
    items.push({ name: `${name.toLowerCase()}-${index}.png`, png,
      source: `${mix}/${name}.SHP`, frame: index, dimensions: [shp.width, shp.height],
      source_sha256: hash(bytes), palette_sha256: hash(paletteBytes), png_sha256: hash(png) });
  });
}
fs.mkdirSync(output, { recursive: true });
for (const item of items) fs.writeFileSync(path.join(output, item.name), item.png);
fs.writeFileSync(path.join(output, 'provenance.json'), JSON.stringify(items.map(({png, ...item}) => item), null, 2) + '\n');
console.log(JSON.stringify({ exported: items.length, output }));
