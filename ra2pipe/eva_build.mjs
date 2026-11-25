import { PROJECT, INPUT, requireMixDirectory } from './paths.mjs';
// eva_build.mjs — 提取 RA2 EVA 语音。
// 事实源：LANGUAGE.MIX > audio.mix(0xad29acfa) 内的 459 个 RIFF/IMA-ADPCM 条目；
//         名字由 eva.ini 的 Allied=(cevaNNN) / Russian=(csofNNN) 反查（hashFilename）。
// 输出：iron_tide/assets/ra2/eva/<name>.wav（PCM16）+ data/ra2/eva_index.json + data/ra2/eva_specs.json
// 用法: node ra2pipe/eva_build.mjs build | stats
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { MixFile, MixEntry, DataStream } from '../tools/ra2bundle.mjs';

const MODE = process.argv[2] || 'stats';
const silence = (fn) => { const o = console.log; console.log = () => {}; try { return fn(); } finally { console.log = o; } };

// ===== IMA ADPCM 解码（与 sfx_build.mjs 同实现）=====
const STEP = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];
const ADJ = [-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
function nib(pred, idx, nibble, out) {
  const step = STEP[idx]; const d = nibble & 7; const diff = ((2*d+1)*step) >> 3;
  if (nibble & 8) pred -= diff; else pred += diff;
  if (pred > 32767) pred = 32767; else if (pred < -32768) pred = -32768;
  idx += ADJ[nibble]; if (idx < 0) idx = 0; else if (idx > 88) idx = 88;
  out[0] = pred; out[1] = idx; return pred;
}
function decodeIma(data, blockAlign, channels) {
  const hdr = 4 * channels;
  const est = Math.ceil(data.length / blockAlign) * 1017 * channels;
  const pcm = new Int16Array(est); let o = 0; const tmp = [0, 0];
  for (let bo = 0; bo + hdr <= data.length; bo += blockAlign) {
    const end = Math.min(bo + blockAlign, data.length);
    const pred = [], idx = [];
    for (let c = 0; c < channels; c++) { pred[c] = data.readInt16LE(bo + c*4); idx[c] = data[bo + c*4 + 2]; if (idx[c] < 0) idx[c] = 0; if (idx[c] > 88) idx[c] = 88; }
    for (let c = 0; c < channels; c++) pcm[o++] = pred[c];
    if (channels === 1) {
      for (let i = bo + hdr; i < end; i++) { const b = data[i];
        for (const nb of [b & 0xf, (b >> 4) & 0xf]) { tmp[0] = pred[0]; tmp[1] = idx[0]; pcm[o++] = nib(pred[0], idx[0], nb, tmp); pred[0] = tmp[0]; idx[0] = tmp[1]; } }
    } else {
      for (let i = bo + hdr; i + 4 <= end; i += 4) {
        for (let c = 0; c < channels; c++) { for (let k = 0; k < 4; k++) { const b = data[i+k];
          for (const nb of [b & 0xf, (b >> 4) & 0xf]) { tmp[0] = pred[c]; tmp[1] = idx[c]; pcm[o++] = nib(pred[c], idx[c], nb, tmp); pred[c] = tmp[0]; idx[c] = tmp[1]; } } } }
    }
  }
  return pcm.subarray(0, o);
}
function pcm16Wav(pcm, sampleRate, channels) {
  const db = pcm.length * 2; const b = Buffer.alloc(44 + db);
  b.write('RIFF', 0, 'latin1'); b.writeUInt32LE(36 + db, 4); b.write('WAVE', 8, 'latin1');
  b.write('fmt ', 12, 'latin1'); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(channels, 22);
  b.writeUInt32LE(sampleRate, 24); b.writeUInt32LE(sampleRate*channels*2, 28); b.writeUInt16LE(channels*2, 32); b.writeUInt16LE(16, 34);
  b.write('data', 36, 'latin1'); b.writeUInt32LE(db, 40);
  for (let i = 0; i < pcm.length; i++) b.writeInt16LE(pcm[i], 44 + i*2);
  return b;
}

// ===== ini 解析 =====
function parseIni(txt) {
  const secs = {}; const order = []; let cur = null;
  for (const raw of txt.split(/\r?\n/)) {
    const ln = raw.trim(); if (!ln || ln.startsWith(';')) continue;
    const m = ln.match(/^\[(.+?)\]$/); if (m) { cur = m[1]; secs[cur] = secs[cur] || {}; order.push(cur); continue; }
    const kv = ln.match(/^([^=]+?)=(.*)$/); if (kv && cur) secs[cur][kv[1].trim()] = kv[2].trim();
  }
  return { secs, order };
}

// ===== 打开 audio.mix =====
const lBuf = readFileSync(`${requireMixDirectory()}/LANGUAGE.MIX`);
let root; silence(() => { root = new MixFile(new DataStream(new DataView(lBuf.buffer, lBuf.byteOffset, lBuf.length))); });
const ds = root.getDataStart();
let ae; for (const h of root.getEntryHashes()) if ((h >>> 0) === 0xad29acfa) { ae = root.getEntry(h); break; }
const aoff = ds + ae.offset;
let audio; silence(() => { audio = new MixFile(new DataStream(new DataView(lBuf.buffer, lBuf.byteOffset + aoff, ae.length))); });
const asds = audio.getDataStart();
// 收集音频数据所在的 Buffer（相对 lBuf）
const riff = [];  // {hash, o, len}
for (const h of audio.getEntryHashes()) {
  const ce = audio.getEntry(h); const o = aoff + asds + ce.offset;
  if (lBuf.toString('latin1', o, o+4) === 'RIFF') riff.push({ hash: h >>> 0, o, len: ce.length });
}

// ===== eva.ini =====
const eva = parseIni(readFileSync(`${INPUT}/eva.ini`, 'latin1'));
// 事件 -> {allied, russian, text, type, priority}
const events = {};
for (const name of eva.order) {
  if (name === 'DialogList') continue;
  const s = eva.secs[name]; if (!s) continue;
  const rec = { text: s.Text || '', allied: (s.Allied || '').toLowerCase(), russian: (s.Russian || '').toLowerCase(),
    type: (s.Type || '').toUpperCase(), priority: (s.Priority || 'NORMAL').toUpperCase(), index: eva.order.indexOf(name) };
  if (rec.allied || rec.russian) events[name] = rec;
}
// 名字候选
const nameSet = new Set();
for (const r of Object.values(events)) { if (r.allied) nameSet.add(r.allied); if (r.russian) nameSet.add(r.russian); }
const hashToName = new Map();
for (const n of nameSet) {
  for (const v of [n + '.wav', n]) { const h = MixEntry.hashFilename(v) >>> 0; if (!hashToName.has(h)) hashToName.set(h, n); }
}

const matched = riff.filter(r => hashToName.has(r.hash));
console.log(`RIFF entries=${riff.length} eva events=${Object.keys(events).length} candidateNames=${nameSet.size} matched=${matched.length}`);
const unmatched = riff.filter(r => !hashToName.has(r.hash));
console.log('unmatched hashes=' + unmatched.length + ' sample=' + unmatched.slice(0,5).map(r=>'0x'+r.hash.toString(16)).join(','));

if (MODE === 'build') {
  const OUT = `${PROJECT}/assets/ra2/eva`; mkdirSync(OUT, { recursive: true });
  const idx = {}; let ok = 0, fail = 0, bytes = 0;
  for (const r of matched) {
    const name = hashToName.get(r.hash);
    const w = lBuf.subarray(r.o, r.o + r.len);
    if (w.toString('latin1', 0, 4) !== 'RIFF' || w.toString('latin1', 8, 12) !== 'WAVE') { fail++; continue; }
    const fmtTag = w.readUInt16LE(20); const channels = w.readUInt16LE(22); const sampleRate = w.readUInt32LE(24);
    const blockAlign = w.readUInt16LE(32);
    // 定位 data chunk
    let p = 12, dataOff = -1, dataLen = 0;
    while (p + 8 <= w.length) { const cid = w.toString('latin1', p, p+4); const clen = w.readUInt32LE(p+4);
      if (cid === 'data') { dataOff = p + 8; dataLen = clen; break; }
      p += 8 + clen + (clen & 1); }
    if (dataOff < 0) { fail++; continue; }
    const raw = w.subarray(dataOff, dataOff + dataLen);
    let pcm;
    if (fmtTag === 1) { pcm = new Int16Array((raw.length/2)|0); for (let i=0;i<pcm.length;i++) pcm[i]=raw.readInt16LE(i*2); }
    else if (fmtTag === 17) { pcm = decodeIma(raw, blockAlign || 512, channels); }
    else { fail++; continue; }
    const out = pcm16Wav(pcm, sampleRate, channels);
    const fn = name.toLowerCase() + '.wav';
    writeFileSync(`${OUT}/${fn}`, out);
    idx[name.toLowerCase()] = { file: fn, sampleRate, channels, frames: (pcm.length/channels)|0, durMs: Math.round((pcm.length/channels)/sampleRate*1000), bytes: out.length };
    ok++; bytes += out.length;
  }
  writeFileSync(`${PROJECT}/data/ra2/eva_index.json`, JSON.stringify({ count: ok, entries: idx }));
  writeFileSync(`${PROJECT}/data/ra2/eva_specs.json`, JSON.stringify({ count: Object.keys(events).length, events }));
  console.log(`WRITE ok=${ok} fail=${fail} total=${(bytes/1048576).toFixed(2)}MB -> ${OUT}`);
}
