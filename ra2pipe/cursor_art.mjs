// Extract only cursor artwork from the user's local RA2 MIX files.
// Frame labels cross-checked against https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml
import { mkdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { PROJECT } from './paths.mjs';
import { openAll, readFileFromMix, decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';

openAll();
const shape = readFileFromMix('MOUSE.SHP');
const palette = readFileFromMix('MOUSEPAL.PAL');
if (!shape || !palette) throw new Error('MOUSE.SHP and MOUSEPAL.PAL are required.');
const sequences = {
  arrow: { start: 0, count: 1, hotspot: [0, 0] },
  select: { start: 18, count: 13 },
  move: { start: 31, count: 10 },
  blocked: { start: 384, count: 1 },
  attack: { start: 58, count: 5 },
  harvest: { start: 53, count: 5 },
  attack_move: { start: 404, count: 9 },
  pan: { start: 385, count: 1 },
  deploy: { start: 110, count: 9 },
  deploy_infantry: { start: 239, count: 10 },
  undeploy: { start: 120, count: 9 },
  sell: { start: 129, count: 10 },
  sell_blocked: { start: 149, count: 1 },
  repair: { start: 170, count: 20 },
  repair_blocked: { start: 190, count: 1 },
  enter: { start: 89, count: 10 },
  enter_blocked: { start: 99, count: 1 },
  c4: { start: 309, count: 10 },
  sabotage: { start: 229, count: 5 },
};
const shp = decodeShp(shape);
const indices = [];
for (const sequence of Object.values(sequences)) {
  sequence.offset = indices.length;
  sequence.hotspot ??= [Math.floor(shp.width / 2), Math.floor(shp.height / 2)];
  for (let i = 0; i < sequence.count; i++) {
    if (!shp.frames[sequence.start + i]) throw new Error('Cursor frame missing');
    indices.push(sequence.start + i);
  }
}
const sheet = montageIndexed(shp, 10, indices);
const png = encodePngIndexed(sheet.width, sheet.height, sheet.indices, decodePal(palette));
const hash = data => createHash('sha256').update(data).digest('hex');
const out = `${PROJECT}/assets/ra2/cursors`;
mkdirSync(out, { recursive: true });
writeFileSync(`${out}/mouse.png`, png);
writeFileSync(`${out}/mouse.json`, JSON.stringify({
  source: 'MOUSE.SHP', palette: 'MOUSEPAL.PAL', source_sha256: hash(shape), palette_sha256: hash(palette),
  png_sha256: hash(png), cell: [shp.width, shp.height], cols: 10, fps: 15, sequences,
  reference: 'https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml',
}, null, 2) + '\n');
console.log(`Exported ${indices.length} cursor frames to ${out}`);
