// Local original ore/gem overlays. Pixels are decoded, never redrawn or recolored.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { readFileFromMix, traceOf, decodeShp, decodePal, montage, encodePng } from './art_lib.mjs';
import { PROJECT } from './paths.mjs';
// Tiberium overlays use TEMPERAT.PAL, not terrain ISOTEM or unit UNITTEM.
// Some stripped local MIX packs omit it; retain a hash-identified tool palette.
const bundledPalette = new URL('./palettes/temperat.pal', import.meta.url);
const localPalette = readFileFromMix('TEMPERAT.PAL');
const paletteBytes = localPalette || fs.readFileSync(bundledPalette);
const paletteSource = localPalette ? traceOf('TEMPERAT.PAL')+'/TEMPERAT.PAL'
  : 'https://github.com/FS-21/Advanced-SHP-Editor/blob/main/Palettes/Red%20Alert%202/temperat.pal';
if (paletteBytes.length !== 768 || Math.max(...paletteBytes) > 63) throw new Error('Invalid TEMPERAT.PAL');
const palette = decodePal(paletteBytes);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const output = path.join(PROJECT, 'assets/ra2/resources');
fs.mkdirSync(output, {recursive:true});
const items = [];
for (const [kind,prefix] of [['ore','TIB'],['gems','GEM']]) {
  for (let variation=1; variation<=3; variation++) {
    const name = `${prefix}${String(variation).padStart(2,'0')}.TEM`;
    const bytes = readFileFromMix(name);
    if (!bytes) throw new Error('Missing '+name);
    const shp = decodeShp(bytes);
    const sheet = montage(shp,palette,6);
    const png = encodePng(sheet.width,sheet.height,sheet.rgba);
    const id = `${kind}-${variation}`;
    fs.writeFileSync(path.join(output,id+'.png'),png);
    items.push({id,kind,source:traceOf(name)+'/'+name,source_sha256:hash(bytes),palette:paletteSource,
      palette_sha256:hash(paletteBytes),png_sha256:hash(png),cell:[shp.width,shp.height],cols:6,count:shp.frames.length,
      density_frames:shp.frames.length/2});
  }
}
fs.writeFileSync(path.join(output,'provenance.json'),JSON.stringify(items,null,2)+'\n');
console.log(JSON.stringify(items));
