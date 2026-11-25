import fs from 'node:fs';
import path from 'node:path';
import { PROJECT, INPUT } from './paths.mjs';
import { openAll, readNamed, readFileFromMix, decodeShp, decodePal, encodePngIndexed } from './art_lib.mjs';
import { loadBibShapes, buildingSheet, correctFactoryStructure } from './building_shapes.mjs';

const out = path.join(PROJECT, 'assets/ra2');
const bibs = loadBibShapes(INPUT);
// Optional IDs keep a scoped repair from rewriting unrelated building assets.
const supported = ['GAWEAP', 'GAREFN', 'GADEPT', 'GAAIRC'];
const requested = process.argv.slice(2);
const targets = requested.length ? [...new Set(requested)] : supported;
for (const id of targets) {
  if (!supported.includes(id)) throw new Error(`Unsupported foundation ${id}; choose ${supported.join(', ')}`);
}
openAll();
const palette = decodePal(readFileFromMix('UNITTEM.PAL'));
for (let i = 16; i < 32; i++) {
  const level = palette[i * 4] / 252;
  [0x57, 0xa8, 0xff].forEach((value, channel) => { palette[i * 4 + channel] = Math.round(value * level); });
}
const find = image => {
  for (const mix of ['SNOW.MIX', 'TEMPERAT.MIX', 'URBAN.MIX', 'GENERIC.MIX', 'CONQUER.MIX']) {
    const buf = readNamed(mix, image + '.SHP');
    if (buf) return { buf, mix };
  }
  return null;
};
fs.mkdirSync(path.join(out, 'shp'), { recursive: true });
for (const id of targets) {
  const source = find(id);
  if (!source) throw new Error(`Missing building ${id}`);
  const body = decodeShp(source.buf);
  const { sheet, metadata } = buildingSheet(body, id, bibs, find);
  fs.writeFileSync(path.join(out, `shp/${id}.png`), encodePngIndexed(sheet.width, sheet.height, sheet.indices, palette));
  fs.writeFileSync(path.join(out, `shp/${id}.json`), JSON.stringify({
    id, image: id, source: `${source.mix}/${id}.SHP`, palette: 'UNITTEM.PAL',
    cell: [body.width, body.height], cols: Math.min(12, body.frames.length), count: body.frames.length,
    rects: sheet.rects, dmg: 3, shadow: true, ...metadata
  }));
  console.log(id, metadata);
}
if (targets.includes('GAWEAP')) {
  const descriptorPath = path.join(out, 'bldanim/GAWEAP.json');
  const descriptor = JSON.parse(fs.readFileSync(descriptorPath, 'utf8'));
  for (const layer of descriptor.layers) {
    if (/^GAWEAP_[1-4]$/.test(layer.image)) correctFactoryStructure(layer, decodeShp(find(layer.image).buf).frames.length);
  }
  fs.writeFileSync(descriptorPath, JSON.stringify(descriptor));
}
