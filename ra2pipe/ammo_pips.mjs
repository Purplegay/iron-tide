// Extract the original ammo marker, never renderer code from a reference engine.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { decodeShp, decodePal, encodePngIndexed } from './art_lib.mjs';
const [game, out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw new Error('Usage: <local YR> <new output folder>');
const source = new YrSource(game);
const shape = source.read('pips2.shp'), palette = source.read('palette.pal');
if (!shape || !palette) throw new Error('Missing PIPS2.SHP or PALETTE.PAL');
const frame = decodeShp(shape.data).frames[12];
if (!frame || frame.w < 1 || frame.h < 1) throw new Error('Missing ammo frame 12');
fs.mkdirSync(out, {recursive: true});
const png = encodePngIndexed(frame.w, frame.h, frame.data, decodePal(palette.data));
fs.writeFileSync(path.join(out, 'ammo.png'), png);
fs.writeFileSync(path.join(out, 'ammo.json'), JSON.stringify({
  frame: 12, size: [frame.w, frame.h], offset: [frame.x, frame.y],
  source: {name: 'PIPS2.SHP', archive: shape.source, sha256: sha256(shape.data)},
  palette: {name: 'PALETTE.PAL', archive: palette.source, sha256: sha256(palette.data)},
  png_sha256: sha256(png)
}, null, 2) + '\n');
console.log(JSON.stringify({out, size:[frame.w,frame.h]}));
