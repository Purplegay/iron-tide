// ra2pipe/vxl_lib.mjs — VXL/HVA parsing + software isometric voxel renderer.
import { readFileSync } from 'node:fs';

// ---------------------------------------------------------------- normals
let _normals = null;
export function loadNormals(path = 'refs/ts-ra2/src/data/vxl/normals.ts') {
  if (_normals) return _normals;
  const txt = readFileSync(path, 'utf8');
  const sets = {};
  const reBlock = /export const (normals\d+)\s*:[^=]*=\s*\[([\s\S]*?)\n\];/g;
  let m;
  while ((m = reBlock.exec(txt))) {
    const name = m[1];
    const body = m[2];
    const arr = [];
    const reV = /new Vector3\(([^)]*)\)/g;
    let v;
    while ((v = reV.exec(body))) {
      const parts = v[1].split(',').map((s) => Number(s.trim()));
      arr.push(parts);
    }
    sets[name] = arr;
  }
  _normals = sets;
  return sets;
}

// ---------------------------------------------------------------- VXL
function asciiZ(buf, off, len) {
  let s = '';
  for (let i = 0; i < len; i++) { const c = buf[off + i]; if (!c) break; s += String.fromCharCode(c); }
  return s;
}

export function parseVxl(buf) {
  if (buf.length < 802 || !asciiZ(buf, 0, 16).startsWith('Voxel Animation')) throw new Error('Invalid VXL header');
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  let p = 0;
  const u32 = () => { const v = dv.getUint32(p, true); p += 4; return v; };
  const f32 = () => { const v = dv.getFloat32(p, true); p += 4; return v; };
  const u8 = () => buf[p++];
  const filename = asciiZ(buf, 0, 16).trim();
  p = 16;
  const paletteCount = u32();
  const headerCount = u32();
  const tailerCount = u32();
  const bodySize = u32();
  if (!headerCount || headerCount !== tailerCount || headerCount > 256 || 802 + headerCount * 28 + bodySize + tailerCount * 92 > buf.length)
    throw new Error('Invalid VXL section bounds');
  const paletteRemapStart = u8();
  const paletteRemapEnd = u8();
  p += 768; // palette

  const headers = [];
  for (let i = 0; i < headerCount; i++) { headers.push({ name: asciiZ(buf, p, 16).trim() }); p += 16 + 12; }
  const bodyStart = p;
  const tailerStart = bodyStart + bodySize;
  p = tailerStart;
  const tailers = [];
  for (let i = 0; i < tailerCount; i++) {
    const startingSpanOffset = u32();
    const endingSpanOffset = u32();
    const dataSpanOffset = u32();
    const hvaMultiplier = f32();
    const matrix = [];
    for (let k = 0; k < 12; k++) matrix.push(f32());
    const minBounds = [f32(), f32(), f32()];
    const maxBounds = [f32(), f32(), f32()];
    const sizeX = u8(), sizeY = u8(), sizeZ = u8(), normalsMode = u8();
    tailers.push({ startingSpanOffset, endingSpanOffset, dataSpanOffset, hvaMultiplier, matrix, minBounds, maxBounds, sizeX, sizeY, sizeZ, normalsMode });
  }
  const normalsSets = loadNormals();
  const bodyEnd = tailerStart;

  const limbs = [];
  for (let li = 0; li < headerCount; li++) {
    const t = tailers[li];
    const { sizeX, sizeY, sizeZ } = t;
    if (!sizeX || !sizeY || !sizeZ) throw new Error('Empty VXL dimensions');
    for (const offset of [t.startingSpanOffset, t.endingSpanOffset])
      if (offset + sizeX * sizeY * 4 > bodySize) throw new Error('VXL span table outside body');
    let q = bodyStart + t.startingSpanOffset;
    const rdI32 = () => { const v = dv.getInt32(q, true); q += 4; return v; };
    const sOff = new Int32Array(sizeX * sizeY);
    const eOff = new Int32Array(sizeX * sizeY);
    for (let i = 0; i < sizeX * sizeY; i++) sOff[i] = rdI32();
    q = bodyStart + t.endingSpanOffset;
    for (let i = 0; i < sizeX * sizeY; i++) eOff[i] = rdI32();

    const voxels = [];
    for (let y = 0; y < sizeY; y++) {
      for (let x = 0; x < sizeX; x++) {
        const idx = y * sizeX + x;
        if (sOff[idx] === -1 || eOff[idx] === -1) continue;
        q = bodyStart + t.dataSpanOffset + sOff[idx];
        const end = bodyStart + t.dataSpanOffset + eOff[idx] + 1;
        if (sOff[idx] < 0 || q >= end || end > bodyEnd) throw new Error('VXL span outside body');
        let z = 0;
        while (z < sizeZ) {
          if (q + 2 > end) throw new Error('Truncated VXL run');
          z += buf[q++];
          const cnt = buf[q++];
          if (z + cnt > sizeZ || q + cnt * 2 + 1 > end) throw new Error('Invalid VXL run');
          for (let i = 0; i < cnt; i++) {
            const colorIndex = buf[q++];
            const normalIndex = buf[q++];
            voxels.push({ x, y, z: z++, colorIndex, normalIndex });
          }
          q++; // skip
        }
      }
    }
    const key = t.normalsMode === 1 ? 'normals1' : t.normalsMode === 2 ? 'normals2' : t.normalsMode === 3 ? 'normals3' : 'normals4';
    limbs.push({
      name: headers[li].name, ...t, voxels,
      normals: normalsSets[key] || normalsSets.normals1 || [],
    });
  }
  return { filename, paletteCount, paletteRemapStart, paletteRemapEnd, limbs };
}

// ---------------------------------------------------------------- HVA
export function parseHva(buf) {
  if (buf.length < 24) throw new Error('Truncated HVA header');
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const frameCount = dv.getUint32(16, true), sectionCount = dv.getUint32(20, true);
  if (!frameCount || !sectionCount || sectionCount > 256 || frameCount > 4096 ||
      buf.length !== 24 + sectionCount * 16 + frameCount * sectionCount * 48) throw new Error('Invalid HVA dimensions');
  let p = 24;
  const sections = [];
  for (let i = 0; i < sectionCount; i++) {
    sections.push({ name: asciiZ(buf, p, 16).trim(), matrices: [] });
    p += 16;
  }
  for (let f = 0; f < frameCount; f++) for (const section of sections) {
    const m = Array.from({ length: 12 }, () => { const n = dv.getFloat32(p, true); p += 4; return n; });
    if (m.some(n => !Number.isFinite(n))) throw new Error('Invalid HVA transform');
    section.matrices.push(m);
  }
  return { frameCount, sectionCount, sections };
}

// HVA owns the section pose; its translations use the VXL multiplier.
// Never add the static VXL transform again: shipped files already describe that pose.
export function poseVxl(model, hva, frame = 0) {
  if (model.limbs.length !== hva.sectionCount) throw new Error('VXL/HVA section count mismatch');
  return { ...model, limbs: model.limbs.map((limb, index) => {
    // Section order is authoritative; shipped HTK has differing display names.
    const section = hva.sections[index];
    const matrix = [...section.matrices[frame % hva.frameCount]];
    for (const index of [3, 7, 11]) matrix[index] *= limb.hvaMultiplier;
    return { ...limb, matrix };
  }) };
}

// ---------------------------------------------------------------- render
function mat3Apply(m, x, y, z) {
  // row-major 12: [r0x,r0y,r0z,tx, r1x,r1y,r1z,ty, r2x,r2y,r2z,tz]
  return [
    m[0] * x + m[1] * y + m[2] * z + m[3],
    m[4] * x + m[5] * y + m[6] * z + m[7],
    m[8] * x + m[9] * y + m[10] * z + m[11],
  ];
}

/**
 * Render a parsed VXL into an RGBA image.
 * opts: { facing (0..n-1), facings, pal (Uint8Array 256*4), hva ({sections}) , frame }
 */
export function renderVxl(model, opts = {}) {
  const pal = opts.pal;
  const facings = opts.facings || 8;
  const facing = ((opts.facing || 0) % facings + facings) % facings;
  if (opts.hva) model = poseVxl(model, opts.hva, opts.frame || 0);
  // 影子模式：把体素沿光向压平到地面再投影。相机在屏幕上是固定的，光向也随之固定，
  // 因此只需按「世界高度」给一个恒定的屏幕位移（SH_SX 向右 / SH_SY 向下），即得红警2 的体素投影。
  const shadow = !!opts.shadow;
  const SH_SX = Number(opts.shadowSX ?? process.env.SH_SX ?? 1.10), SH_SY = Number(opts.shadowSY ?? process.env.SH_SY ?? 0.0);
  // Fixed 2:1 isometric camera (elevation 30deg); rotate the *view azimuth* per facing.
  const se = 0.5, ce = Math.sqrt(3) / 2;
  const az = Math.PI / 4 - (facing / facings) * Math.PI * 2;
  const c = Math.cos(az), s = Math.sin(az);
  const rx0 = -s, ry0 = c;               // screen right in world (x,y)
  const ux = -c * se, uy = -s * se, uz = ce; // screen up
  const wx = c * ce, wy = s * ce, wz = se;   // toward camera
  const Lsx = -0.45, Lsy = 0.80;
  const ll = Math.hypot(Lsx, Lsy);
  const L0 = Lsx / ll, L1 = Lsy / ll;

  const pts = [];
  for (const limb of model.limbs) {
    const sx = (limb.maxBounds[0] - limb.minBounds[0]) / Math.max(1, limb.sizeX);
    const sy = (limb.maxBounds[1] - limb.minBounds[1]) / Math.max(1, limb.sizeY);
    const sz = (limb.maxBounds[2] - limb.minBounds[2]) / Math.max(1, limb.sizeZ);
    const m = limb.matrix;
    for (const v of limb.voxels) {
      const [wx0, wy0, wz0] = mat3Apply(m, limb.minBounds[0] + (v.x + 0.5) * sx, limb.minBounds[1] + (v.y + 0.5) * sy, limb.minBounds[2] + (v.z + 0.5) * sz);
      const scrX = wx0 * rx0 + wy0 * ry0;
      const scrY = -(wx0 * ux + wy0 * uy + wz0 * uz);
      const depth = wx0 * wx + wy0 * wy + wz0 * wz;
      const rawNormal = limb.normals[v.normalIndex] || [0, 0, 1];
      const n = [0, 4, 8].map(row => m[row] * rawNormal[0] + m[row + 1] * rawNormal[1] + m[row + 2] * rawNormal[2]);
      const length = Math.hypot(...n) || 1;
      for (let axis = 0; axis < 3; axis++) n[axis] /= length;
      const nx = n[0] * rx0 + n[1] * ry0;
      const ny = n[0] * ux + n[1] * uy + n[2] * uz;
      const shade = 0.42 + 0.58 * Math.max(0, nx * L0 + ny * L1);
      pts.push({ sx: scrX, sy: scrY, d: depth, c: v.colorIndex, s: shade , zz: wz0 });
    }
  }
  if (!pts.length) return { width: 1, height: 1, rgba: new Uint8Array(4) };
  if (shadow) {
    // 以模型最低体素作为地面基准，按高度做恒定屏幕位移（影子落在右下方向）
    // A common model ground plane (not each turret/rotor's lowest voxel).
    // Undo the camera's height projection before casting onto that plane.
    const ground = Number(opts.shadowGround ?? 0);
    for (const pt of pts) {
      const dh = Math.max(0, pt.zz - ground);
      pt.sx += dh * SH_SX;
      pt.sy += (pt.zz - ground) * ce + dh * SH_SY;
    }
  }


  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const pt of pts) { if (pt.sx < minX) minX = pt.sx; if (pt.sx > maxX) maxX = pt.sx; if (pt.sy < minY) minY = pt.sy; if (pt.sy > maxY) maxY = pt.sy; }
  const pad = 1;
  const W = Math.ceil(maxX - minX) + 1 + pad * 2;
  const H = Math.ceil(maxY - minY) + 1 + pad * 2;
  const rgba = new Uint8Array(W * H * 4);
  const zbuf = new Float32Array(W * H).fill(-Infinity);
  for (const pt of pts) {
    const px = Math.round(pt.sx - minX) + pad;
    const py = Math.round(pt.sy - minY) + pad;
    if (px < 0 || py < 0 || px >= W || py >= H) continue;
    const i = py * W + px;
    if (!shadow) {
      if (pt.d <= zbuf[i]) continue;
      zbuf[i] = pt.d;
    }
    const o = i * 4;
    rgba[o] = Math.min(255, pal[pt.c * 4] * pt.s);
    rgba[o + 1] = Math.min(255, pal[pt.c * 4 + 1] * pt.s);
    rgba[o + 2] = Math.min(255, pal[pt.c * 4 + 2] * pt.s);
    rgba[o + 3] = 255;
  }
  return { width: W, height: H, rgba, minX, minY };
}
