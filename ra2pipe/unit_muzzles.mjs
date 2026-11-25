// Derive emitters from local voxel geometry without rewriting the existing PNGs.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { PROJECT } from './paths.mjs';
import { openAll, readNamed, readFileFromMix, decodePal, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';

const specs = {
  MTNK: ['GTNK', 'GTNKBARL', 0],
  FV: ['FV', 'FVTUR', 0],
  SREF: ['SREF', 'SREFTUR', 2],
  MGTK: ['RTNK', 'RTNKBARL', 0],
  TNKD: ['TNKD', 'TNKD', 0],
  ORCA: ['FALC', 'FALC', 0],
  BEAG: ['BEAG', 'BEAG', 0],
  HORNET: ['HORNET', 'HORNET', 0],
};
function readModel(name, required = true) {
  for (const mix of ['CONQUER.MIX', 'LOCAL.MIX', 'SNOW.MIX', 'ANIMS.MIX', 'GENERIC.MIX']) {
    const bytes = readNamed(mix, name + '.VXL');
    if (bytes) return { model: parseVxl(bytes), source: `${mix}/${name}.VXL` };
  }
  const bytes = readFileFromMix(name + '.VXL');
  if (bytes) return { model: parseVxl(bytes), source: `flat/${name}.VXL` };
  if (required) throw new Error(`Missing emitter source ${name}`);
  return null;
}
function emitterPoint(model, axis) {
  const points = model.limbs.flatMap(limb => limb.voxels.map(voxel => {
    const p = ['x', 'y', 'z'].map((key, i) => limb.minBounds[i]
      + (voxel[key] + 0.5) * (limb.maxBounds[i] - limb.minBounds[i]) / limb[['sizeX', 'sizeY', 'sizeZ'][i]]);
    return [0, 4, 8].map(row => limb.matrix[row] * p[0] + limb.matrix[row + 1] * p[1]
      + limb.matrix[row + 2] * p[2] + limb.matrix[row + 3]);
  }));
  const tip = Math.max(...points.map(p => p[axis]));
  const face = points.filter(p => Math.abs(p[axis] - tip) < 0.001);
  if (!face.length) throw new Error('Emitter has no occupied face');
  return [0, 1, 2].map(i => face.reduce((sum, p) => sum + p[i], 0) / face.length);
}

export function exportUnitMuzzles(project = PROJECT, repairTankDestroyer = false) {
  openAll();
  const out = path.join(project, 'assets/ra2');
  const pal = decodePal(readFileFromMix('UNITTEM.PAL'));
  for (let i = 16; i < 32; i++) {
    const level = pal[i * 4] / 252;
    [0x57, 0xa8, 0xff].forEach((c, channel) => { pal[i * 4 + channel] = Math.round(c * level); });
    pal[i * 4 + 3] = 0;
  }
  const writes = [];
  const images = [];
  for (const [id, [base, emitter, axis]] of Object.entries(specs)) {
    const body = readModel(base);
    const parts = ['TUR', 'BARL'].map(s => readModel(base + s, false)).filter(Boolean);
    const turret = parts.length ? { limbs: parts.flatMap(p => p.model.limbs) } : null;
    const sources = turret ? [body.model, turret] : [body.model];
    const frames = sources.map(model => Array.from({ length: 8 }, (_, facing) =>
      renderVxl(model, { pal, facing, facings: 8 })));
    const shadows = sources.flatMap(model => Array.from({ length: 8 }, (_, facing) =>
      renderVxl(model, { pal, facing, facings: 8, shadow: true })));
    const all = [...frames.flat(), ...shadows];
    const minX = Math.min(...all.map(f => f.minX)), minY = Math.min(...all.map(f => f.minY));
    const width = Math.ceil(Math.max(...all.map(f => f.minX + f.width)) - minX) + 4;
    const height = Math.ceil(Math.max(...all.map(f => f.minY + f.height)) - minY) + 4;
    for (const name of [id, ...(turret ? [id + '_tur'] : []), id + '_shd']) {
      const file = path.join(out, 'vxl', name + '.png');
      const png = fs.readFileSync(file);
      if (png.readUInt32BE(16) === 8 * (width + 2) + 2 && png.readUInt32BE(20) === height + 4)
        continue;
      if (id !== 'TNKD' || !repairTankDestroyer)
        throw new Error(`${name}: PNG dimensions disagree with atlas; explicitly rebuild source before exporting anchors`);
      const sheetW = 8 * (width + 2) + 2, sheetH = height + 4;
      const pixels = new Uint8Array(sheetW * sheetH * 4);
      const source = name.endsWith('_shd') ? shadows : frames[0];
      source.forEach((frame, facing) => {
        const x = 2 + facing * (width + 2) + Math.round(frame.minX - minX);
        const y = 2 + Math.round(frame.minY - minY);
        for (let row = 0; row < frame.height; row++)
          pixels.set(frame.rgba.subarray(row * frame.width * 4, (row + 1) * frame.width * 4),
            ((y + row) * sheetW + x) * 4);
      });
      images.push([file, encodePng(sheetW, sheetH, pixels)]);
      console.log(`${name}: rebuilt mismatched PNG from local source (${sheetW}x${sheetH})`);
    }
    for (const name of [id, ...(turret ? [id + '_tur'] : [])]) {
      const file = path.join(out, 'vxl', name + '.json');
      const metadata = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (metadata.frameW !== width || metadata.frameH !== height || metadata.facings !== 8)
        throw new Error(`${name}: existing atlas does not match model canvas ${width}x${height}`);
      writes.push([file, { ...metadata, facing_offset: 4 }]);
    }
    const muzzleSource = readModel(emitter);
    const point = emitterPoint(muzzleSource.model, axis);
    const origins = frames.at(-1).map(f => [
      Math.round(f.minX - minX) + 1 - f.minX,
      Math.round(f.minY - minY) + 1 - f.minY,
    ]);
    const muzzles = origins.map((origin, f) => {
      const az = Math.PI / 4 - f * Math.PI / 4;
      return [
        origin[0] - point[0] * Math.sin(az) + point[1] * Math.cos(az),
        origin[1] + 0.5 * (point[0] * Math.cos(az) + point[1] * Math.sin(az)) - point[2] * Math.sqrt(3) / 2,
      ];
    });
    if (muzzles.some(p => p[0] < 0 || p[1] < 0 || p[0] >= width || p[1] >= height))
      throw new Error(`${id}: emitter outside atlas`);
    writes.push([path.join(out, 'unitweapon', id + '.json'), {
      id, image: turret ? id + '_tur' : id, frameW: width, frameH: height, facings: 8,
      facing_axis: 'model +X', emitter_face: axis === 2 ? 'highest Z' : 'front +X',
      muzzle_model_point: point, muzzle_source: muzzleSource.source, origins, muzzles,
    }]);
    console.log(`${id}: verified ${width}x${height}, 8 emitters from ${muzzleSource.source}`);
  }
  // Validate all canvases before changing any metadata.
  fs.mkdirSync(path.join(out, 'unitweapon'), { recursive: true });
  for (const [file, bytes] of images) fs.writeFileSync(file, bytes);
  for (const [file, value] of writes) fs.writeFileSync(file, JSON.stringify(value));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href)
  exportUnitMuzzles(PROJECT, process.argv.includes('--repair-tank-destroyer'));
