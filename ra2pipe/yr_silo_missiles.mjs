// Extract projectile bodies and their independent house-color masks from a local YR install.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource } from './lib/yr_source.mjs';
import { decodePal, decodeShp, encodePng } from './art_lib.mjs';

const [game, output] = process.argv.slice(2);
const source = new YrSource(game);
const palette = decodePal(source.read('unittem.pal').data);
const frames = ['NKMSLUP','NKMSLDN'].map(id => decodeShp(source.read(id + '.shp').data).frames[0]);
const { w, h } = frames[0];
const width = w * 4;
const pixels = Buffer.alloc(width * h * 4);
for (const [direction, frame] of frames.entries()) {
  if (frame.w !== w || frame.h !== h) throw Error('Missile body dimensions differ');
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const index = frame.data[y * w + x];
      if (!index) continue;
      const mask = index >= 16 && index < 32;
      const tile = direction * 2 + Number(mask);
      const dst = (y * width + tile * w + x) * 4;
      for (let c = 0; c < 3; c++) {
        pixels[dst + c] = mask ? Math.round(255 * palette[4 * index] / 252) : palette[4 * index + c];
      }
      pixels[dst + 3] = 255;
    }
  }
}
const base = path.join(output,'SILO_MISSILES');
fs.writeFileSync(base + '.png', encodePng(width,h,pixels));
fs.writeFileSync(base + '.json', JSON.stringify({
  id: 'SILO_MISSILES', source: 'NKMSLUP/NKMSLDN native body bounds and faction masks',
  palette: 'UNITTEM.PAL', count: 4, cell: [w,h],
  rects: [0,1,2,3].map(i => ({ x:i*w,y:0,w,h }))
}) + '\n');
