import { requireMixDirectory } from './paths.mjs';
// ra2pipe/art_lib.mjs — RA2 art decoding: MIX resolve, SHP, PAL, PNG encode.
import { readFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { MixFile, MixEntry, DataStream } from '../tools/ra2bundle.mjs';

// ---------------------------------------------------------------- MIX layer
const MIX_NAMES = (() => {
  const base = ['CONQUER', 'LOCAL', 'CAMEO', 'ANIMS', 'VXL', 'UI', 'SOUNDS', 'SOUND', 'GENERIC', 'TEMPERAT', 'SNOW', 'URBAN', 'ISOTEM', 'ISOSNOW', 'ISOURB', 'ISOTEMP', 'MOVIES01', 'MOVIES02', 'MOVIES', 'LANG', 'RA2', 'ART', 'SIDE', 'SIDEC', 'SIDEA', 'SIDES', 'SIDEN', 'MULTI', 'MAPS01', 'MAPS02', 'CONQ', 'AI', 'EVA', 'MISSION', 'CURSORS', 'HIRES', 'LOADSCR', 'MAPS', 'MUSIC', 'THEME', 'WDT', 'PAL'];
  const names = base.map((b) => b + '.MIX');
  for (const p of ['SIDEC', 'SIDEA', 'SIDES', 'SIDEN', 'MOVIES', 'SOUNDS', 'TEMPERAT', 'SNOW', 'URBAN', 'ISOTEM', 'ISOSNOW', 'ISOURB', 'SOUN', 'MUSIC', 'WDT']) {
    for (let i = 0; i < 12; i++) names.push(`${p}${i.toString().padStart(2, '0')}.MIX`);
  }
  const m = new Map();
  for (const n of names) m.set(MixEntry.hashFilename(n) >>> 0, n);
  return m;
})();

let _cache = null;
function silenced(fn) {
  const orig = console.log;
  console.log = () => {};
  try { return fn(); } finally { console.log = orig; }
}

/** Lazily load every MIX under refs/ra2pack/full and build a global name resolver. */
export function openAll(mixDir = requireMixDirectory(), names = ['RA2.MIX', 'LANGUAGE.MIX']) {
  if (_cache) return _cache;
  const files = [];
  for (const n of names) {
    let buf;
    try { buf = readFileSync(`${mixDir}/${n}`); } catch { continue; }
    files.push({ name: n, buf });
  }
  // (hash -> {buf, off, len, trace})
  const index = new Map();
  silenced(() => {
    for (const f of files) {
      let mix;
      try {
        mix = new MixFile(new DataStream(new DataView(f.buf.buffer, f.buf.byteOffset, f.buf.length)));
      } catch { continue; }
      if (mix.getEntryCount() === 0) continue;
      collect({ mix, ds: mix.getDataStart(), buf: f.buf, off: 0, trace: f.name }, index, 1);
    }
  });
  // named sub-mix map: label -> { buf, off, len, ds }
  const named = new Map();
  silenced(() => {
    for (const f of files) {
      let root;
      try { root = new MixFile(new DataStream(new DataView(f.buf.buffer, f.buf.byteOffset, f.buf.length))); } catch { continue; }
      const ds = root.getDataStart();
      for (const h of root.getEntryHashes()) {
        const e = root.getEntry(h);
        const key = h >>> 0;
        const nm = MIX_NAMES.get(key);
        if (!nm || key === MixEntry.hashFilename(f.name) >>> 0) continue;
        const off = ds + e.offset;
        if (off + e.length > f.buf.length) continue;
        named.set(nm, { buf: f.buf, off, len: e.length, ds: null });
      }
    }
  });
  _cache = { files, index, named };
  return _cache;
}

/** Read a file that lives inside a *named* sub-mix (e.g. 'TEMPERAT.MIX'). */
export function readNamed(submix, name) {
  const { named } = openAll();
  const s = named.get(submix);
  if (!s) return null;
  if (!s.ds) {
    silenced(() => {
      const m = new MixFile(new DataStream(new DataView(s.buf.buffer, s.buf.byteOffset + s.off, s.len)));
      s.mix = m; s.ds = m.getDataStart();
    });
  }
  const e = s.mix.getEntry(MixEntry.hashFilename(name) >>> 0);
  if (!e) return null;
  const o = s.off + s.ds + e.offset;
  return Buffer.from(s.buf.buffer, s.buf.byteOffset + o, e.length);
}

export function namedSubmixes() {
  return [...openAll().named.keys()];
}

/** Parse the sub-mix stored at top-level RA2.MIX entry `hashHex` (e.g. '3b5a96de'). */
export function entriesByHash(hashHex, mixFile = 'RA2.MIX') {
  const { files } = openAll();
  const f = files.find((x) => x.name === mixFile);
  if (!f) return [];
  const want = parseInt(hashHex, 16) >>> 0;
  let root;
  silenced(() => { root = new MixFile(new DataStream(new DataView(f.buf.buffer, f.buf.byteOffset, f.buf.length))); });
  const ds = root.getDataStart();
  for (const h of root.getEntryHashes()) {
    if ((h >>> 0) !== want) continue;
    const e = root.getEntry(h);
    const off = ds + e.offset;
    let m;
    silenced(() => { m = new MixFile(new DataStream(new DataView(f.buf.buffer, f.buf.byteOffset + off, e.length))); });
    const mds = m.getDataStart();
    const out = [];
    for (const hh of m.getEntryHashes()) {
      const ee = m.getEntry(hh);
      out.push({ hash: hh >>> 0, len: ee.length, buf: Buffer.from(f.buf.buffer, f.buf.byteOffset + off + mds + ee.offset, ee.length) });
    }
    return out;
  }
  return [];
}

function collect(node, index, depth) {
  const { mix, ds, buf, off, trace } = node;
  for (const h of mix.getEntryHashes()) {
    const e = mix.getEntry(h);
    if (!e) continue;
    const o = off + ds + e.offset;
    if (o + e.length > buf.length) continue;
    const key = h >>> 0;
    if (!index.has(key) || index.get(key).len < e.length) {
      index.set(key, { buf, off: o, len: e.length, trace });
    }
    if (depth > 0 && e.length >= 64) {
      const child = (() => {
        try {
          const m = new MixFile(new DataStream(new DataView(buf.buffer, buf.byteOffset + o, e.length)));
          return m.getEntryCount() > 0 ? { mix: m, ds: m.getDataStart(), buf, off: o, trace: `${trace} > 0x${key.toString(16)}` } : null;
        } catch { return null; }
      })();
      if (child) collect(child, index, depth - 1);
    }
  }
}

export function hasFile(name) {
  const { index } = openAll();
  return index.has(MixEntry.hashFilename(name) >>> 0);
}

/** Returns a Buffer slice of the given file's payload, or null. */
export function readFileFromMix(name) {
  const { index } = openAll();
  const e = index.get(MixEntry.hashFilename(name) >>> 0);
  if (!e) return null;
  return Buffer.from(e.buf.buffer, e.buf.byteOffset + e.off, e.len);
}

export function traceOf(name) {
  const { index } = openAll();
  const e = index.get(MixEntry.hashFilename(name) >>> 0);
  return e ? `${e.trace} len=${e.len}` : 'missing';
}

// ---------------------------------------------------------------- PAL
export function decodePal(buf) {
  const pal = new Uint8Array(256 * 4);
  const n = Math.min(256, (buf.length / 3) | 0);
  for (let i = 0; i < n; i++) {
    pal[i * 4 + 0] = buf[3 * i + 0] * 4;
    pal[i * 4 + 1] = buf[3 * i + 1] * 4;
    pal[i * 4 + 2] = buf[3 * i + 2] * 4;
    pal[i * 4 + 3] = 255;
  }
  return pal;
}

// ---------------------------------------------------------------- SHP
function format3(src, width, height) {
  const out = new Uint8Array(width * height);
  let s = 0, d = 0;
  for (let y = 0; y < height; y++) {
    let lineLen = ((src[s + 1] << 8) | src[s]) - 2;
    s += 2;
    let x = 0;
    while (lineLen > 0) {
      const v = src[s++]; lineLen--;
      if (v !== 0) {
        if (d < out.length && x < width) out[d++] = v;
        x++;
      } else {
        let run = src[s++]; lineLen--;
        if (x + run > width) run = (width - x) & 255;
        for (let k = 0; k < run; k++) { if (d < out.length && x < width) out[d++] = 0; x++; }
      }
    }
    while (x < width && d < (y + 1) * width && d < out.length) { out[d++] = 0; x++; }
    d = (y + 1) * width;
  }
  return out;
}

/** Decode a RA2 SHP buffer. Returns {width,height,frames:[{x,y,w,h,data}]}. */
export function decodeShp(buf) {
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  let p = 0;
  const rdU16 = () => { const v = dv.getUint16(p, true); p += 2; return v; };
  const rdI32 = () => { const v = dv.getInt32(p, true); p += 4; return v; };
  const reserved = dv.getInt16(0, true);
  let width = 0, height = 0, nFrames = 0;
  if (reserved === 0) {
    width = dv.getInt16(2, true); height = dv.getInt16(4, true); nFrames = dv.getInt16(6, true);
    p = 8;
  } else {
    width = 0; height = 0; nFrames = dv.getUint16(0, true); p = 2;
  }
  const heads = [];
  for (let i = 0; i < nFrames; i++) {
    const x = rdU16() << 16 >> 16, y = rdU16() << 16 >> 16;
    const w = rdU16() << 16 >> 16, h = rdU16() << 16 >> 16;
    const ct = buf[p++]; p += 3;
    rdI32(); rdI32();
    const off = rdI32();
    heads.push({ x, y, w, h, ct, off });
  }
  const frames = [];
  let maxW = 0, maxH = 0;
  for (let i = 0; i < nFrames; i++) {
    const { x, y, w, h, ct, off } = heads[i];
    let next = i < nFrames - 1 ? heads[i + 1].off : buf.length;
    if (next < off || next > buf.length) next = buf.length;
    const len = next - off;
    const size = w * h;
    let data;
    if (size === 0) data = new Uint8Array(0);
    else if (ct <= 1) {
      data = new Uint8Array(size);
      const n = Math.min(len, size);
      if (n > 0) data.set(buf.subarray(off, off + n));
    } else if (ct === 2) {
      data = new Uint8Array(size);
      let q = off, d = 0;
      for (let r = 0; r < h; r++) {
        if (q + 2 > buf.length) break;
        const lineLen = buf.readUInt16LE(q) - 2; q += 2;
        if (lineLen < 0 || q + lineLen > buf.length) break;
        const chunk = buf.subarray(q, q + lineLen); q += lineLen;
        if (d + lineLen <= size) data.set(chunk, d);
        d += lineLen;
      }
    } else if (ct === 3) {
      data = format3(buf.subarray(off, off + len), w, h);
    } else {
      data = new Uint8Array(size);
    }
    frames.push({ x, y, w, h, data });
    maxW = Math.max(maxW, x + w); maxH = Math.max(maxH, y + h);
  }
  if (reserved !== 0) { width = maxW; height = maxH; }
  return { width, height, frames };
}

// ---------------------------------------------------------------- PNG
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, 'ascii');
  const body = Buffer.concat([t, data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
/** Encode RGBA bytes (w*h*4) into a PNG Buffer. */
export function encodePng(width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    Buffer.from(rgba.buffer, rgba.byteOffset + y * stride, stride).copy(raw, y * (stride + 1) + 1);
  }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

/** Encode 8-bit indexed pixels (Uint8Array w*h) as a palette PNG with tRNS for index 0. */
export function encodePngIndexed(width, height, indices, pal, transparentFirst = true) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 3; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const plte = Buffer.alloc(256 * 3);
  for (let i = 0; i < 256; i++) { plte[i * 3] = pal[i * 4]; plte[i * 3 + 1] = pal[i * 4 + 1]; plte[i * 3 + 2] = pal[i * 4 + 2]; }
  const trns = Buffer.alloc(256);
  trns.fill(255);
  if (transparentFirst) trns[0] = 0;
  const stride = width;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    Buffer.from(indices.buffer, indices.byteOffset + y * stride, stride).copy(raw, y * (stride + 1) + 1);
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('PLTE', plte),
    chunk('tRNS', trns),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Compose SHP frames into one indexed sheet (cell = declared canvas). Returns {width,height,indices,rects}. */
export function montageIndexed(shp, cols, indices = null, cellW = null, cellH = null) {
  const cw = cellW || shp.width;
  const ch = cellH || shp.height;
  const idxs = indices || shp.frames.map((_, i) => i);
  const rows = Math.ceil(idxs.length / cols);
  const W = cols * cw, H = rows * ch;
  const out = new Uint8Array(W * H);
  const rects = [];
  idxs.forEach((fi, n) => {
    const f = shp.frames[fi];
    if (!f) return;
    const cx = (n % cols) * cw, cy = Math.floor(n / cols) * ch;
    for (let yy = 0; yy < f.h; yy++) {
      const ty = cy + f.y + yy;
      if (ty < 0 || ty >= H) continue;
      for (let xx = 0; xx < f.w; xx++) {
        const tx = cx + f.x + xx;
        if (tx < 0 || tx >= W) continue;
        const v = f.data[yy * f.w + xx];
        if (v) out[ty * W + tx] = v;
      }
    }
    rects.push({ i: fi, x: cx, y: cy, w: cw, h: ch });
  });
  return { width: W, height: H, indices: out, rects };
}

/** Compose SHP frames into a single RGBA sheet (cols per row). */
export function montage(shp, pal, cols, indices = null, opts = {}) {
  const cw = opts.cellW || shp.width;
  const ch = opts.cellH || shp.height;
  const idxs = indices || shp.frames.map((_, i) => i);
  const rows = Math.ceil(idxs.length / cols);
  const W = cols * cw, H = rows * ch;
  const rgba = new Uint8Array(W * H * 4);
  idxs.forEach((fi, n) => {
    const f = shp.frames[fi];
    if (!f) return;
    const cx = (n % cols) * cw, cy = Math.floor(n / cols) * ch;
    for (let yy = 0; yy < f.h; yy++) {
      const ty = cy + f.y + yy;
      if (ty < 0 || ty >= H) continue;
      for (let xx = 0; xx < f.w; xx++) {
        const tx = cx + f.x + xx;
        if (tx < 0 || tx >= W) continue;
        const v = f.data[yy * f.w + xx];
        if (!v) continue;
        const o = (ty * W + tx) * 4;
        rgba[o] = pal[v * 4]; rgba[o + 1] = pal[v * 4 + 1]; rgba[o + 2] = pal[v * 4 + 2]; rgba[o + 3] = 255;
      }
    }
  });
  return { width: W, height: H, rgba };
}

/** Paint one SHP frame into RGBA using palette; index 0 = transparent. */
export function frameToRgba(frame, pal, opts = {}) {
  const { forceOpaque = false } = opts;
  // place frame at (x,y) within canvas of given size
  const cw = opts.canvasW || frame.w;
  const ch = opts.canvasH || frame.h;
  const ox = opts.originX || 0;
  const oy = opts.originY || 0;
  const rgba = new Uint8Array(cw * ch * 4);
  for (let yy = 0; yy < frame.h; yy++) {
    const ty = frame.y + oy + yy;
    if (ty < 0 || ty >= ch) continue;
    for (let xx = 0; xx < frame.w; xx++) {
      const tx = frame.x + ox + xx;
      if (tx < 0 || tx >= cw) continue;
      const idx = frame.data[yy * frame.w + xx];
      const o = (ty * cw + tx) * 4;
      if (idx === 0 && !forceOpaque) { rgba[o + 3] = 0; continue; }
      rgba[o + 0] = pal[idx * 4 + 0];
      rgba[o + 1] = pal[idx * 4 + 1];
      rgba[o + 2] = pal[idx * 4 + 2];
      rgba[o + 3] = idx === 0 ? (forceOpaque ? 255 : 0) : 255;
    }
  }
  return rgba;
}
