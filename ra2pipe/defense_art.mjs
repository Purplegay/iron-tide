// Export complete defense building art to IRON_TIDE_PROJECT for review first.
import fs from 'node:fs';
import path from 'node:path';
import { PROJECT } from './paths.mjs';
import { openAll, readNamed, readFileFromMix, decodeShp, decodePal, montageIndexed, encodePngIndexed, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';
import { exportDefenseRecoil } from './defense_recoil.mjs';

const buildings = JSON.parse(fs.readFileSync(path.join(PROJECT, 'data/ra2/buildings.json'), 'utf8')).buildings;
const out = path.join(PROJECT, 'assets/ra2');
for (const folder of ['shp', 'vxl', 'bldturret']) fs.mkdirSync(path.join(out, folder), { recursive: true });
openAll();
const palette = decodePal(readFileFromMix('UNITTEM.PAL'));
for (let i = 16; i < 32; i++) {
  const level = palette[i * 4] / 252;
  [0x57, 0xa8, 0xff].forEach((value, channel) => { palette[i * 4 + channel] = Math.round(value * level); });
}
function find(name, mixes) {
  for (const mix of mixes) {
    const bytes = readNamed(mix, name);
    if (bytes) return { bytes, source: `${mix}/${name}` };
  }
  const bytes = readFileFromMix(name);
  if (!bytes) throw new Error(`Missing source: ${name}`);
  return { bytes, source: `flat/${name}` };
}
const writeJson = (name, value) => fs.writeFileSync(path.join(out, name), JSON.stringify(value));
// Anchor to the visible voxel muzzle, in this renderer's model units. FLH uses
// a different scale; applying it directly would put effects outside the sprite.
function muzzlePoint(model, singlePod) {
  const points = model.limbs.flatMap(limb => limb.voxels.map(voxel => {
    const p = ['x', 'y', 'z'].map((axis, i) => limb.minBounds[i]
      + (voxel[axis] + 0.5) * (limb.maxBounds[i] - limb.minBounds[i]) / limb[['sizeX', 'sizeY', 'sizeZ'][i]]);
    return [0, 4, 8].map(row => limb.matrix[row] * p[0] + limb.matrix[row + 1] * p[1]
      + limb.matrix[row + 2] * p[2] + limb.matrix[row + 3]);
  }));
  const front = Math.max(...points.map(p => p[0]));
  // SAM has two separate launcher pods: use one pod rather than their empty gap.
  const face = points.filter(p => Math.abs(p[0] - front) < 0.001 && (!singlePod || p[1] < 0));
  if (!face.length) throw new Error('No front muzzle voxels');
  return [0, 1, 2].map(axis => face.reduce((sum, p) => sum + p[axis], 0) / face.length);
}
function muzzleAnchors(origins, point) {
  return origins.map((origin, facing) => {
    const az = Math.PI / 4 - facing * Math.PI * 2 / origins.length;
    return [
      origin[0] - point[0] * Math.sin(az) + point[1] * Math.cos(az),
      origin[1] + 0.5 * (point[0] * Math.cos(az) + point[1] * Math.sin(az)) - point[2] * Math.sqrt(3) / 2,
    ];
  });
}
const turrets = process.argv.includes('--outpost') ? [['CAOUTP', 'CTOUTP']] : process.argv.includes('--flak') ? [['NAFLAK', 'NAFLAK']] : process.argv.includes('--soviet') ? [['NALASR', 'NALASR']] : [['NASAM', 'NASAM'], ['GTGCAN', 'GAGCAN']];
for (const [id, bodyImage] of turrets) {
  if (process.argv.includes('--recoil-only') && id !== 'GTGCAN') continue;
  const config = buildings[id];
  const names = [config.extra.TurretAnim, ...(id === 'GTGCAN' ? ['GTGCANBARL'] : [])];
  const sources = names.map(name => find(`${name}.VXL`, ['LOCAL.MIX', 'CONQUER.MIX']));
  const models = sources.map(source => parseVxl(source.bytes));
  const muzzle = muzzlePoint(models.at(-1), id === 'NASAM');
  if (process.argv.includes('--recoil-only')) {
    const descriptor = JSON.parse(fs.readFileSync(path.join(out, `bldturret/${id}.json`), 'utf8'));
    exportDefenseRecoil(out, id, config, models, palette, descriptor);
    continue;
  }
  if (process.argv.includes('--anchors-only')) {
    const descriptor = JSON.parse(fs.readFileSync(path.join(out, `bldturret/${id}.json`), 'utf8'));
    descriptor.muzzles = muzzleAnchors(descriptor.origins, muzzle);
    descriptor.muzzle_model_point = muzzle;
    descriptor.muzzle_source = sources.at(-1).source;
    writeJson(`bldturret/${id}.json`, descriptor);
    console.log(`${id}: updated ${descriptor.muzzles.length} muzzle anchors only`);
    continue;
  }
  const bodySource = find(`${bodyImage}.SHP`, ['SNOW.MIX', 'TEMPERAT.MIX', 'URBAN.MIX', 'GENERIC.MIX', 'CONQUER.MIX']);
  if (id !== 'CAOUTP') { // Outpost body already includes the separate bib.
  const body = decodeShp(bodySource.bytes);
  const sheet = montageIndexed(body, Math.min(12, body.frames.length));
  fs.writeFileSync(path.join(out, `shp/${id}.png`), encodePngIndexed(sheet.width, sheet.height, sheet.indices, palette));
  writeJson(`shp/${id}.json`, { id, image: bodyImage, source: bodySource.source, palette: 'UNITTEM.PAL',
    cell: [body.width, body.height], cols: Math.min(12, body.frames.length), count: body.frames.length,
    rects: sheet.rects, dmg: 3, shadow: true });
  }
  // GTGCANTUR and GTGCANBARL use the same model origin. Render their voxels
  // together so depth sorting also handles the barrel behind the turret.
  const model = { limbs: models.flatMap(model => model.limbs) };
  const facings = 32;
  const frames = Array.from({ length: facings }, (_, facing) => renderVxl(model, { pal: palette, facing, facings }));
  // renderVxl has one transparent pixel around its projection. Retain the
  // projected (0,0,0), rather than anchoring each facing to its opaque bounds.
  const minX = Math.floor(Math.min(...frames.map(frame => frame.minX))) - 2;
  const minY = Math.floor(Math.min(...frames.map(frame => frame.minY))) - 2;
  const frameW = Math.ceil(Math.max(...frames.map(frame => frame.minX + frame.width))) - minX + 2;
  const frameH = Math.ceil(Math.max(...frames.map(frame => frame.minY + frame.height))) - minY + 2;
  const pad = 2;
  const width = facings * (frameW + pad) + pad, height = frameH + pad * 2;
  const rgba = new Uint8Array(width * height * 4);
  const origins = [];
  frames.forEach((frame, i) => {
    const x = Math.round(frame.minX - minX), y = Math.round(frame.minY - minY);
    origins.push([x + 1 - frame.minX, y + 1 - frame.minY]);
    for (let row = 0; row < frame.height; row++) {
      const target = ((pad + y + row) * width + pad + i * (frameW + pad) + x) * 4;
      rgba.set(frame.rgba.subarray(row * frame.width * 4, (row + 1) * frame.width * 4), target);
    }
  });
  const image = `${id}_turret`;
  fs.writeFileSync(path.join(out, `vxl/${image}.png`), encodePng(width, height, rgba));
  writeJson(`vxl/${image}.json`, { id: image, facings, frameW, frameH, source: sources.map(source => source.source).join('+') });
  // SAM and GTGCAN barrels point along model +X; the runtime unit convention
  // uses -X. Keep this correction local to these building assets.
  const descriptor = { image, origins, facing_offset: facings / 2,
    offset: [Number(config.extra.TurretAnimX || 0), Number(config.extra.TurretAnimY || 0)],
    source: sources.map(source => source.source), body_source: bodySource.source,
    muzzles: muzzleAnchors(origins, muzzle), muzzle_model_point: muzzle, muzzle_source: sources.at(-1).source };
  writeJson(`bldturret/${id}.json`, descriptor);
  exportDefenseRecoil(out, id, config, models, palette, descriptor);
  console.log(`${id}: ${bodySource.source}; ${sources.map(source => source.source).join(' + ')}; ${facings} facings`);
}
