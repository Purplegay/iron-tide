// From iron_tide: node tools/yuri_superweapon_lids.mjs "<retail YR directory>"
import fs from 'node:fs';
import { YrSource, sha256 } from '../../ra2pipe/lib/yr_source.mjs';
import { parseIni, getSec } from '../../ra2pipe/lib/ini.mjs';
import { decodePal, decodeShp, montageIndexed, encodePngIndexed } from '../../ra2pipe/art_lib.mjs';
import { theaterReader } from './theater_shapes.mjs';
import { yuriSuperweaponIdleArt } from './yuri_superweapon_idle_art.mjs';

const source = new YrSource(process.argv[2]);
const theater = theaterReader(source, 'TEMPERATE');
const art = parseIni(source.read('artmd.ini').data.toString('latin1'));
const paletteFile = theater.palette();
const palette = decodePal(paletteFile.data);
for (let i = 16; i < 32; i++) {
 const shade = palette[i * 4] / 252;
 [87, 168, 255].forEach((value, c) => palette[i * 4 + c] = Math.round(value * shade));
}
const save = (path, data) => fs.writeFileSync(path, JSON.stringify(data, null, 1) + '\n');
for (const id of ['YAPPET', 'YAGNTC']) {
 const desc = yuriSuperweaponIdleArt(id, key => Object.fromEntries(getSec(art, key)?.keys || []), image => {
  const stem = `assets/ra2/shp/${image}`;
  // Keep the already-published closed pose and lights unchanged.
  if (image.endsWith('_E') || image.endsWith('_A')) return JSON.parse(fs.readFileSync(stem + '.json')).count;
  const hit = theater.shape(image);
  const shp = decodeShp(hit.data);
  const count = shp.frames.length, cols = Math.min(8, count), atlas = montageIndexed(shp, cols);
  fs.writeFileSync(stem + '.png', encodePngIndexed(atlas.width, atlas.height, atlas.indices, palette));
  save(stem + '.json', { id: image, image, source: hit.source, source_sha256: sha256(hit.data),
   palette: paletteFile.source, cell: [shp.width, shp.height], cols, count, rects: atlas.rects, shadow: true });
  return count;
 });
 save(`assets/ra2/bldanim/${id}.json`, desc);
}
