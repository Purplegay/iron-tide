// Scoped local asset extraction for IFV alternate turrets and Mirage disguise.
// Usage: node ra2pipe/allied_ability_art.mjs <local YR folder> <new external output>
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { decodePal, decodeShp, montageIndexed, encodePngIndexed, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';
import { parseIni, getSec } from './lib/ini.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output || fs.existsSync(output)) throw new Error('Supply local YR and a new external output folder');
const source = new YrSource(game), provenance = {};
const required = name => {
  const hit = source.read(name);
  if (!hit) throw new Error('Missing ' + name);
  provenance[name] = { source: hit.source, sha256: sha256(hit.data) };
  return hit.data;
};
const write = (name, bytes) => { const file = path.join(output, name); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, bytes); };
const json = (name, value) => write(name, JSON.stringify(value, null, 2) + '\n');
const palette = decodePal(required('unittem.pal'));
for (let i = 16; i < 32; i++) {
  const brightness = palette[i * 4] / 252;
  [87, 168, 255].forEach((c, k) => palette[i * 4 + k] = Math.round(c * brightness));
}
const model = name => parseVxl(required(name + '.vxl'));
const hull = model('fv'), standard = model('fvtur');
const facings = 32;
const frames = m => Array.from({ length: facings }, (_, facing) => renderVxl(m, { pal: palette, facing, facings }));
const base = [...frames(hull), ...frames(standard)];
for (const m of [hull, standard]) for (let facing = 0; facing < facings; facing++) base.push(renderVxl(m, { pal: palette, facing, facings, shadow: true }));
const minX = Math.min(...base.map(f => f.minX)), minY = Math.min(...base.map(f => f.minY));
const cw = Math.ceil(Math.max(...base.map(f => f.minX + f.width)) - minX) + 4;
const ch = Math.ceil(Math.max(...base.map(f => f.minY + f.height)) - minY) + 4;
// Keep the existing hull/shadow canvas and anchoring; never recenter alternate turrets.
for (let mode = 1; mode <= 3; mode++) {
  const turret = model('fvtur' + mode);
  const images = frames(turret);
  const mx = Math.min(minX, ...images.map(f => f.minX)), my = Math.min(minY, ...images.map(f => f.minY));
  const tw = Math.ceil(Math.max(minX + cw, ...images.map(f => f.minX + f.width)) - mx);
  const th = Math.ceil(Math.max(minY + ch, ...images.map(f => f.minY + f.height)) - my);
  const width = facings * (tw + 2) + 2, height = th + 4;
  const rgba = new Uint8Array(width * height * 4);
  images.forEach((im, facing) => {
    const x0 = Math.round(im.minX - mx), y0 = Math.round(im.minY - my);
    for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
      const from = (y * im.width + x) * 4;
      if (!im.rgba[from + 3]) continue;
      const to = ((2 + y0 + y) * width + 2 + facing * (tw + 2) + x0 + x) * 4;
      rgba.set(im.rgba.subarray(from, from + 4), to);
    }
  });
  const id = 'FV_tur' + mode;
  write(`assets/ra2/vxl/${id}.png`, encodePng(width, height, rgba));
  json(`assets/ra2/vxl/${id}.json`, { id, facings, frameW: tw, frameH: th, facing_offset: facings / 2, of: 'FV', draw_offset: [mx-minX, my-minY] });
  const points = turret.limbs.flatMap(l => l.voxels.map(v => {
    const p = ['x','y','z'].map((k,i) => l.minBounds[i] + (v[k]+0.5) * (l.maxBounds[i]-l.minBounds[i]) / l[['sizeX','sizeY','sizeZ'][i]]);
    return [0,4,8].map(r => l.matrix[r]*p[0]+l.matrix[r+1]*p[1]+l.matrix[r+2]*p[2]+l.matrix[r+3]);
  }));
  const front = Math.max(...points.map(p => p[0])), face = points.filter(p => Math.abs(p[0]-front)<0.001);
  const point = [0,1,2].map(i => face.reduce((sum,p) => sum+p[i],0)/face.length);
  const muzzles = images.map((im,f) => {const az=Math.PI/4-f*Math.PI*2/facings; return [Math.round(im.minX-minX)+1-im.minX-point[0]*Math.sin(az)+point[1]*Math.cos(az), Math.round(im.minY-minY)+1-im.minY+0.5*(point[0]*Math.cos(az)+point[1]*Math.sin(az))-point[2]*Math.sqrt(3)/2];});
  json(`assets/ra2/unitweapon/FV_mode${mode}.json`, {id:'FV', image:id, frameW:cw, frameH:ch, facings, muzzles});
}
const rules = parseIni(required('rulesmd.ini').toString('latin1'));
const trees = getSec(rules, 'General').keys.get('defaultmiragedisguises').split(',').map(id => id.trim().toUpperCase());
const terrainPalette = decodePal(required('isotem.pal'));
for (const id of trees) {
  const tree = decodeShp(required(id.toLowerCase() + '.tem'));
  const montage = montageIndexed(tree, 1, [0]);
  write('assets/ra2/shp/' + id + '.png', encodePngIndexed(montage.width, montage.height, montage.indices, terrainPalette));
  json('assets/ra2/shp/' + id + '.json', { id, rects: montage.rects, count: 1, cell: [tree.width, tree.height] });
}
const art = parseIni(required('artmd.ini').toString('latin1'));
const entry = getSec(art, 'SNIPE'), sequence = getSec(art, entry.keys.get('sequence'));
const seq = {};
for (const [key, value] of sequence.keys) {
  const values = value.split(',').slice(0,3).map(Number);
  if (values.length < 2 || values.some(v => !Number.isFinite(v))) continue;
  const name = [...['Ready','Guard','Prone','Walk','FireUp','Down','Crawl','Up','FireProne','Idle1','Idle2','Die1','Die2','Cheer']].find(n => n.toLowerCase()===key);
  if (name) seq[name] = { start:values[0], per:values[1], stride:values[2] || values[1], facings:values.length>2 && values[2]>0 ? 8 : 1 };
}
json('assets/ra2/shp/SNIPE.seq.json', {id:'SNIPE', sequence:entry.keys.get('sequence'), seq});
json('provenance.json', { inputs: provenance, canvas: [cw, ch] });
console.log(JSON.stringify({ output, canvas: [cw, ch], inputCount: Object.keys(provenance).length }));
