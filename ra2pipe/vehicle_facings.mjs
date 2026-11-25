// Re-bake scoped ground vehicles, aircraft or playable Allied ships from installed MIX files.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { decodePal, encodePng } from './art_lib.mjs';
import { parseVxl, parseHva, poseVxl, renderVxl } from './vxl_lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [game, output, scope = 'ground'] = process.argv.slice(2);
if (!game || !output || !['ground', 'aircraft', 'naval', 'all'].includes(scope)) throw new Error('Usage: node ra2pipe/vehicle_facings.mjs <YR directory> <new external candidate> [ground|aircraft|naval|all]');
const out = path.resolve(output);
for (const protectedRoot of [root, fs.realpathSync(game)])
  if (out === protectedRoot || out.startsWith(protectedRoot + path.sep)) throw new Error('Candidate must be external');
if (fs.existsSync(out)) throw new Error('Candidate already exists');
const source = new YrSource(game), inputs = {}, writes = [];
function read(name, optional = false) {
  const hit = source.read(name);
  if (!hit) { if (optional) return null; throw new Error(`Missing ${name}`); }
  inputs[name] = { source: hit.source, sha256: sha256(hit.data) };
  return hit.data;
}
const pal = decodePal(read('unittem.pal'));
for (let i = 16; i < 32; i++) {
  const level = pal[i * 4] / 252;
  [87, 168, 255].forEach((value, channel) => pal[i * 4 + channel] = Math.round(value * level));
}
const facings = 32;
let specs = scope === 'aircraft'
  ? { ORCA: 'FALC', BEAG: 'BEAG', SHAD: 'SHAD', HORNET: 'HORNET' }
  : scope === 'naval' ? { DEST: 'DEST', AEGIS: 'AEGIS', CARRIER: 'CARRIER', LCRF: 'LCRF' }
  : { MTNK: 'GTNK', FV: 'FV', SREF: 'SREF', MGTK: 'RTNK', TNKD: 'TNKD', ROBO: 'ROBO', CMIN: 'CMIN', AMCV: 'MCV' };
const project = path.join(root, 'iron_tide');
if (scope === 'all') {
  specs = {};
  for (const name of fs.readdirSync(path.join(project, 'assets/ra2/vxl')).sort()) {
    if (!name.endsWith('.json') || /_(tur\w*|shd)\.json$/i.test(name)) continue;
    const metadata = JSON.parse(fs.readFileSync(path.join(project, 'assets/ra2/vxl', name)));
    const id = name.slice(0, -5);
    specs[id] = (metadata.vxl || metadata.image || id).replace(/\.vxl$/i, '');
  }
}
const posesAudit = {};
function loadModel(base) {
  const model = parseVxl(read(base + '.vxl'));
  const hva = parseHva(read(base + '.hva'));
  return { model, hva };
}
const json = (name, value) => writes.push([name, JSON.stringify(value, null, 2) + '\n']);
for (const [id, base] of Object.entries(specs)) {
  const old = JSON.parse(fs.readFileSync(path.join(project, `assets/ra2/vxl/${id}.json`)));
  const hull = loadModel(base);
  // Respect the current model's split parts, including fixed-barrel vehicles.
  const parts = old.turret ? ['tur', 'barl'].filter(s => read(base + s + '.vxl', true)).map(s => loadModel(base + s)) : [];
  if (old.turret && !parts.length) throw new Error(`${id}: missing turret`);
  const variants = id === 'FV' ? [1, 2, 3].map(n => loadModel(base + 'tur' + n)) : [];
  const models = [[hull], ...(parts.length ? [parts] : []), ...variants.map(m => [m])];
  const poses = Math.max(...models.flat().map(m => m.hva.frameCount));
  posesAudit[id] = { image: base, poses, sections: models.flat().map(m => m.hva.sections.map(s => s.name)) };
  const bake = (group, shadow) => Array.from({ length: facings * poses }, (_, i) =>
    renderVxl({ limbs: group.flatMap(m => poseVxl(m.model, m.hva, Math.floor(i / facings)).limbs) },
      { pal, facing: i % facings, facings, shadow, shadowGround: 0 }));
  const frames = models.map(m => bake(m, false));
  const shadows = models.map(m => bake(m, true));
  const all = [...frames.flat(), ...shadows.flat()];
  const minX = Math.min(...all.map(f => f.minX)), minY = Math.min(...all.map(f => f.minY));
  const cw = Math.ceil(Math.max(...all.map(f => f.minX + f.width)) - minX) + 4;
  const ch = Math.ceil(Math.max(...all.map(f => f.minY + f.height)) - minY) + 4;
  const width = facings * (cw + 2) + 2, height = poses * (ch + 2) + 2;
  const names = [id, ...(parts.length ? [id + '_tur'] : []), ...variants.map((_, i) => id + '_tur' + (i + 1))];
  const layers = names.flatMap((name, i) => [[name, [frames[i]], false], [name + '_shd', [shadows[i]], true]]);
  for (const [name, rows, shadow] of layers) {
    const pixels = new Uint8Array(width * height * 4);
    for (const row of rows) row.forEach((im, i) => {
      const ox = 2 + (i % facings) * (cw + 2) + Math.round(im.minX - minX), oy = 2 + Math.floor(i / facings) * (ch + 2) + Math.round(im.minY - minY);
      for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
        const src = (y * im.width + x) * 4, dst = ((oy + y) * width + ox + x) * 4;
        if (!im.rgba[src + 3]) continue;
        for (let c = 0; c < 3; c++) pixels[dst + c] = shadow ? 0 : im.rgba[src + c];
        pixels[dst + 3] = 255;
      }
    });
    writes.push([`assets/ra2/vxl/${name}.png`, encodePng(width, height, pixels)]);
    const metadataPath = path.join(project, `assets/ra2/vxl/${name}.json`);
    const metadata = fs.existsSync(metadataPath) ? JSON.parse(fs.readFileSync(metadataPath)) : { id: name };
    const { animated_limbs, adaptation, ...retained } = metadata;
    json(`assets/ra2/vxl/${name}.json`, { ...retained, facings, frameW: cw, frameH: ch, facing_offset: facings / 2,
      poses, fps: metadata.fps || (poses > 1 ? 20 : 0), pose_source: 'local VXL + HVA', shadow_projection: 'ground-plane-v2',
      ...(name === id && parts.length ? { split_shadow: true } : {}), ...(metadata.of ? { draw_offset: [0, 0] } : {}) });
  }
  const weaponPath = path.join(project, `assets/ra2/unitweapon/${id}.json`);
  if (fs.existsSync(weaponPath)) {
    const weapon = JSON.parse(fs.readFileSync(weaponPath));
    const p = weapon.muzzle_model_point;
    if (!Array.isArray(p) || p.length !== 3) throw new Error(`${id}: no model-space emitter`);
    const origins = frames[parts.length ? 1 : 0].slice(0, facings).map(f => [Math.round(f.minX - minX) + 1 - f.minX, Math.round(f.minY - minY) + 1 - f.minY]);
    const muzzles = origins.map((o, f) => {
      const az = Math.PI / 4 - f * Math.PI * 2 / facings;
      return [o[0] - p[0] * Math.sin(az) + p[1] * Math.cos(az), o[1] + .5 * (p[0] * Math.cos(az) + p[1] * Math.sin(az)) - p[2] * Math.sqrt(3) / 2];
    });
    if (muzzles.some(p => p[0] < 0 || p[1] < 0 || p[0] >= cw || p[1] >= ch)) throw new Error(`${id}: emitter outside atlas`);
    json(`assets/ra2/unitweapon/${id}.json`, { ...weapon, frameW: cw, frameH: ch, facings, origins, muzzles });
  }
  for (let v = 0; v < variants.length; v++) {
    const model = poseVxl(variants[v].model, variants[v].hva);
    const points = model.limbs.flatMap(l => l.voxels.map(voxel => {
      const xyz = ['x','y','z'].map((axis, a) => l.minBounds[a] + (voxel[axis] + .5) * (l.maxBounds[a] - l.minBounds[a]) / l[['sizeX','sizeY','sizeZ'][a]]);
      return [0,4,8].map(row => l.matrix[row]*xyz[0]+l.matrix[row+1]*xyz[1]+l.matrix[row+2]*xyz[2]+l.matrix[row+3]);
    }));
    const front = Math.max(...points.map(p => p[0]));
    const face = points.filter(p => Math.abs(p[0]-front) < .001);
    const point = [0,1,2].map(a => face.reduce((sum,p)=>sum+p[a],0)/face.length);
    const origins = frames[v+2].slice(0,facings).map(f => [Math.round(f.minX-minX)+1-f.minX,Math.round(f.minY-minY)+1-f.minY]);
    const muzzles = origins.map((o,f)=>{const az=Math.PI/4-f*Math.PI*2/facings;return [o[0]-point[0]*Math.sin(az)+point[1]*Math.cos(az),o[1]+.5*(point[0]*Math.cos(az)+point[1]*Math.sin(az))-point[2]*Math.sqrt(3)/2];});
    json(`assets/ra2/unitweapon/FV_mode${v+1}.json`, {id:'FV',image:`FV_tur${v+1}`,frameW:cw,frameH:ch,facings,muzzle_model_point:point,origins,muzzles});
  }
  console.log(`${id}: ${facings} facings, common hull/turret/shadow canvas ${cw}x${ch}`);
}
for (const [name, bytes] of writes) {
  const target = path.join(out, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes);
}
fs.writeFileSync(path.join(out, 'source-audit.json'), JSON.stringify({ source: source.root, inputs, archives: source.audit(), models: posesAudit, files: writes.map(([name, bytes]) => ({ name, sha256: sha256(bytes) })) }, null, 2));
