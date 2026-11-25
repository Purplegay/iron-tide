import { PROJECT, INPUT, requireMixDirectory } from './paths.mjs';
// ra2pipe/art_build.mjs — Step B production pipeline: RA2 MIX -> PNG assets.
// usage: node art_build.mjs [cameo|shp|vxl|anim|resources|all]
import { mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { openAll, readNamed, readFileFromMix, decodeShp, decodePal, encodePng, encodePngIndexed, montageIndexed, frameToRgba } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';
import { loadBibShapes, buildingSheet, correctFactoryStructure } from './building_shapes.mjs';
import { buildingAnimationRange, separateBuildingHealthRanges } from './building_animation_ranges.mjs';
import { exportUnitMuzzles } from './unit_muzzles.mjs';
import { exportTransportRotors } from './transport_rotors.mjs';
import { dolphinSequence } from './dolphin_sequence.mjs';
import { loadWallDefinitions, wallLayout } from './wall_layout.mjs';

import { YrSource } from './lib/yr_source.mjs';
const yr = process.argv.includes('--yr-assets') ? new YrSource(requireMixDirectory()) : null;
const OUT = `${PROJECT}/assets/ra2`;
const mode = process.argv[2] || 'all';
if (mode === 'resources' || mode === 'all') await import('./resource_art.mjs');
if (mode === 'resources') process.exit(0);
const out = (s) => process.stdout.write(s + '\n');

const units = JSON.parse(readFileSync(`${PROJECT}/data/ra2/units.json`, 'utf8'));
const buildings = JSON.parse(readFileSync(`${PROJECT}/data/ra2/buildings.json`, 'utf8'));
const allUnits = [].concat(Object.values(units.infantry), Object.values(units.vehicles), Object.values(units.aircraft));
const allBuildings = Object.values(buildings.buildings);

openAll();

// art.ini infantry sequences -> cache[<image>] = { image, source, seq:{Name:{start,per,facings}} }
function loadSequences() {
  const cache = {};
  let txt = '';
  try { txt = readFileSync(`${INPUT}/art.ini`, 'utf8'); } catch { return cache; }
  const secs = {}; let cur = null;
  for (const raw of txt.split(/\r?\n/)) {
    const line = raw.trim();
    const h = line.match(/^\[([^\]]+)\](?:\s*;.*)?$/);
    if (h) { cur = h[1]; secs[cur] = []; continue; }
    if (!cur || !line || line.startsWith(';')) continue;
    secs[cur].push(line);
  }
  for (const key of Object.keys(secs)) {
    const m = key.match(/^(.*)Sequence$/i);
    if (!m) continue;
    const seq = {};
    for (const line of secs[key]) {
      const i = line.indexOf('='); if (i < 0) continue;
      const name = line.slice(0, i).trim();
      const parts = line.slice(i + 1).split(',').map((x) => x.trim());
      const start = parseInt(parts[0], 10), per = parseInt(parts[1], 10), third = parseInt(parts[2] || '0', 10);
      if (isNaN(start) || isNaN(per)) continue;
      seq[name] = { start, per, facings: third ? 8 : 1 };
    }
    cache[m[1].toLowerCase()] = { image: m[1], source: 'art.ini/[' + key + ']', seq };
  }
  // Image IDs need not match sequence names (ROCK -> RocketeerSequence).
  for (const [image, lines] of Object.entries(secs)) {
    const link = lines.find(line => /^Sequence\s*=/i.test(line));
    if (!link) continue;
    const name = link.slice(link.indexOf('=') + 1).split(';')[0].trim();
    const sequence = cache[name.replace(/Sequence$/i, '').toLowerCase()];
    if (sequence) cache[image.toLowerCase()] = { ...sequence, image };
  }
  return cache;
}
const SEQ_CACHE = loadSequences();
out('sequences loaded: ' + Object.keys(SEQ_CACHE).join(', '));

const cameoPal = decodePal(readFileFromMix('CAMEO.PAL'));
const PALS = {
  temperat: decodePal(readFileFromMix('UNITTEM.PAL')),
  snow: readFileFromMix('UNITSNOW.PAL') ? decodePal(readFileFromMix('UNITSNOW.PAL')) : null,
  urban: readFileFromMix('UNITURBAN.PAL') ? decodePal(readFileFromMix('UNITURBAN.PAL')) : null,
};
// (D-1) RA2 house-colour remap. UNITTEM.PAL entries 16..31 are the "house colour" ramp,
// stored as pure red (252,0,0 .. 32,0,0). Allied entries are rendered with the allied blue
// ramp instead (same mechanism RA2 uses per-house). Soviet-only art keeps the original red.
const HOUSE_LO = 16, HOUSE_N = 16;
const SIDE_HOUSE_RGB = { allied: [0x57, 0xa8, 0xff] };
function remapPalette(base, rgb) {
  const out = Buffer.from(base);
  for (let i = 0; i < HOUSE_N; i++) {
    const e = (HOUSE_LO + i) * 4, lv = base[e] / 252;
    out[e] = Math.round(rgb[0] * lv); out[e + 1] = Math.round(rgb[1] * lv); out[e + 2] = Math.round(rgb[2] * lv); out[e + 3] = 0;
  }
  return out;
}
const PAL_CACHE = { temperat: PALS.temperat };
function palFor(sides) {
  const side = process.argv.includes('--house-remap') ? 'allied' : (Array.isArray(sides) ? sides : []).find((x) => SIDE_HOUSE_RGB[x]);
  if (!side) return PALS.temperat;
  if (!PAL_CACHE[side]) PAL_CACHE[side] = remapPalette(PALS.temperat, SIDE_HOUSE_RGB[side]);
  return PAL_CACHE[side];
}
out('house palettes: ' + Object.keys(SIDE_HOUSE_RGB).join(', '));
const BUILDING_MIXES = ['SNOW.MIX', 'TEMPERAT.MIX', 'URBAN.MIX', 'GENERIC.MIX', 'CONQUER.MIX'];

function findShp(image, mixes) {
  if (yr) {
    const hit = yr.read(image + '.SHP');
    if (hit) return { buf: hit.data, mix: hit.source };
  }
  for (const m of mixes) {
    const b = readNamed(m, image + '.SHP');
    if (b) return { buf: b, mix: m };
  }
  const b = readFileFromMix(image + '.SHP');
  if (b) return { buf: b, mix: 'flat' };
  return null;
}

const manifest = { version: 2, generated: new Date().toISOString(), sources: {}, counts: {}, items: [] };
mkdirSync(OUT, { recursive: true });

// ------------------------------------------------------------------ cameos
if (mode === 'cameo' || mode === 'all') {
  mkdirSync(`${OUT}/cameo`, { recursive: true });
  let ok = 0, miss = 0;
  const seen = new Set();
  for (const e of [...allUnits, ...allBuildings]) {
    const cn = e.cameo;
    if (!cn || seen.has(cn)) continue;
    seen.add(cn);
    const b = yr?.read(cn + '.SHP')?.data || readNamed('CAMEO.MIX', cn + '.SHP');
    if (!b) { miss++; continue; }
    const shp = decodeShp(b);
    const f = shp.frames[0];
    const rgba = frameToRgba(f, cameoPal, { canvasW: f.w, canvasH: f.h });
    writeFileSync(`${OUT}/cameo/${cn}.png`, encodePng(f.w, f.h, rgba));
    ok++;
  }
  out(`cameo: ok=${ok} miss=${miss}`);
  manifest.counts.cameo = ok;
}

// ------------------------------------------------------------------ SHP sheets
if (mode === 'shp' || mode === 'all') {
  const bibShapes = loadBibShapes(INPUT);
  const wallDefinitions = loadWallDefinitions(INPUT);
  mkdirSync(`${OUT}/shp`, { recursive: true });
  let ok = 0, miss = 0, bytes = 0;
  const missing = [];
  const jobs = [];
  for (const e of allUnits) {
    if (e.voxel) continue; // voxel units handled by vxl stage
    jobs.push({ e, kind: 'unit', mixes: ['CONQUER.MIX', 'SNOW.MIX', 'GENERIC.MIX'] });
  }
  for (const e of allBuildings) jobs.push({ e, kind: 'building', mixes: BUILDING_MIXES });

  for (const { e, kind, mixes } of jobs) {
    const image = e.image || e.id;
    const pal = palFor(e.sides);
    const hit = findShp(image, mixes);
    if (!hit) { miss++; missing.push(image); continue; }
    let shp;
    try { shp = decodeShp(hit.buf); } catch { miss++; missing.push(image + '(err)'); continue; }
    const n = shp.frames.length;
    const cols = Math.min(12, Math.max(1, n));
    const composition = kind === 'building'
      ? buildingSheet(shp, image, bibShapes, name => findShp(name, mixes))
      : { sheet: montageIndexed(shp, cols), metadata: {} };
    const sheet = composition.sheet;
    const png = encodePngIndexed(sheet.width, sheet.height, sheet.indices, pal);
    writeFileSync(`${OUT}/shp/${e.id}.png`, png);
    writeFileSync(`${OUT}/shp/${e.id}.json`, JSON.stringify({
      id: e.id, image, source: hit.mix + '/' + image + '.SHP', palette: 'UNITTEM.PAL',
      cell: [shp.width, shp.height], cols, count: n, rects: sheet.rects,
      dmg: e.id === 'NABNKR' && n === 8 ? 4 : n >= 6 ? 3 : 1, shadow: n >= 6,
      ...composition.metadata,
      ...(kind === 'building' ? wallLayout(wallDefinitions[image.toUpperCase()], n) : {}),
    }));
    // (D-2) infantry frame sequences (art.ini [<image>Sequence])
    if (kind === 'unit') {
      const seq = e.id === 'DRON' && n === 176
        ? {image:'DRON', source:'artmd.ini [DRON] WalkFrames=6 FiringFrames=4, eight facings',
          seq:{Guard:{start:48,per:1,facings:8},Walk:{start:0,per:6,facings:8},FireUp:{start:56,per:4,facings:8}}}
        : e.id === 'DLPH'
        ? dolphinSequence(readFileSync(`${INPUT}/art.ini`, 'utf8'), n)
        : SEQ_CACHE[String(image).toLowerCase()] || SEQ_CACHE[String(e.id).toLowerCase()];
      if (seq) writeFileSync(`${OUT}/shp/${e.id}.seq.json`, JSON.stringify(seq));
    }
    bytes += png.length;
    ok++;
  }
  out(`shp: ok=${ok} miss=${miss} bytes=${(bytes / 1048576).toFixed(2)}MB`);
  if (missing.length) out('  missing: ' + missing.slice(0, 40).join(', ') + (missing.length > 40 ? ` ...(+${missing.length - 40})` : ''));
  manifest.counts.shp = ok;
  manifest.missing_shp = missing;
}

// ------------------------------------------------------------------ building buildup (construction) SHP
// art.ini 每个建筑 Buildup=<NAME>：NAME.SHP 是独立建造序列（第 0 帧=刚放下，末帧=落成）。
// 产出 assets/ra2/shp/<NAME>.png|json —— 与主体同格式，运行时走 RA2Art.art(NAME) 取帧。
if (mode === 'buildup' || mode === 'all') {
  let ok = 0, miss = 0;
  const seen = new Set();
  const missing = [];
  for (const e of allBuildings) {
    const name = String(e.buildup || '').toUpperCase();
    if (!name || seen.has(name)) continue;
    seen.add(name);
    const hit = findShp(name, BUILDING_MIXES);
    if (!hit) { miss++; missing.push(name); continue; }
    let shp;
    try { shp = decodeShp(hit.buf); } catch { miss++; missing.push(name + '(err)'); continue; }
    // buildup SHP 与主体一样把影子帧追加在后半段（count 恒为偶数，末帧=落成）。
    // 取前半段作为可见建造序列：第 0 帧=刚放下的空基座，末帧=落成，与建造进度 0→1 正序对应。
    const nAll = shp.frames.length;
    const n = (nAll % 2 === 0) ? nAll / 2 : nAll;
    const cols = Math.min(12, Math.max(1, n));
    const sheet = montageIndexed(shp, cols);
    writeFileSync(`${OUT}/shp/${name}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, palFor(e.sides)));
    writeFileSync(`${OUT}/shp/${name}.json`, JSON.stringify({
      id: name, image: name, source: hit.mix + '/' + name + '.SHP', palette: 'UNITTEM.PAL',
      cell: [shp.width, shp.height], cols, count: n, rects: sheet.rects.slice(0, n), dmg: 1, shadow: false,
      buildup: true, raw_count: nAll,
    }));
    ok++;
  }
  out(`buildup: ok=${ok} miss=${miss}`);
  if (missing.length) out('  buildup missing: ' + missing.join(', '));
  manifest.counts.buildup = ok;
  manifest.missing_buildup = missing;
}

// ------------------------------------------------------------------ building anim layers (art.ini ActiveAnim/IdleAnim)
// RA2 的建筑动效不在主体 SHP 里：art.ini 用 ActiveAnim/ActiveAnimTwo..Four/IdleAnim 指向独立的动画 SHP。
// 动画 SHP 与主体 SHP 同画布（cell 完全一致），所以运行时复用主体的 drawOffset 直接叠在主体之上即可像素级对齐。
// 产出：
//   assets/ra2/anim/<IMAGE>.png|json  —— 动画 SHP 帧表（与主体同 cell，SHP 帧网格格式）
//   assets/ra2/bldanim/<ID>.json      —— 该建筑要叠哪几层 + 帧区间/Rate/受损(Damaged)变体
if (mode === 'anim' || mode === 'all') {
  // 动画 SHP 与建筑/单位 SHP 同格式，直接放进 shp/，运行时走同一条装载路径
  const ANIM_SHEET_DIR = `${OUT}/shp`;
  const ANIM_DESC_DIR = `${OUT}/bldanim`;
  // art.ini 段索引：段名大写，键小写；值里的内联注释以 ';' 截断
  const iniSections = {};
  try {
    let cur = null;
    for (const rawLine of readFileSync(`${INPUT}/art.ini`, 'utf8').split(/\r?\n/)) {
      const line = rawLine.trim();
      const head = line.match(/^\[([^\]]+)\]/); // 段头后面可能跟 \t; 注释
      if (head) { cur = head[1].toUpperCase(); iniSections[cur] = {}; continue; }
      if (!cur || !line || line.charAt(0) === ';') continue;
      const eq = line.indexOf('=');
      if (eq < 0) continue;
      let val = line.slice(eq + 1);
      const sc = val.indexOf(';');
      if (sc >= 0) val = val.slice(0, sc);
      iniSections[cur][line.slice(0, eq).trim().toLowerCase()] = val.trim();
    }
  } catch { /* 没有 art.ini 则整段跳过 */ }
  const iniSec = (n) => iniSections[String(n || '').toUpperCase()] || null;
  const iniNum = (s, k, d) => { const n = s && s[k] !== undefined ? parseInt(s[k], 10) : NaN; return isNaN(n) ? d : n; };
  const iniBool = (s, k, d) => { if (!s || s[k] === undefined) return d; return /^(yes|true|1)$/i.test(s[k]); };
  const ANIM_PROP = /^(activeanim(two|three|four)?|idleanim(two|three|four)?|productionanim(two|three|four)?|specialanim(two|three|four)?|superanim(two|three|four)?|deployinganim|underdooranim|roofdeployinganim|underroofdooranim)$/;
  // RA2 NewTheater：名字第 2 个字符换成剧场代号再试一次
  const findAnimShp = (image) => {
    const up = String(image).toUpperCase();
    let hit = findShp(up, BUILDING_MIXES);
    if (hit) return { ...hit, image: up };
    for (const th of ['T', 'S', 'U', 'D']) {
      const alt = up.charAt(0) + th + up.slice(2);
      hit = findShp(alt, BUILDING_MIXES);
      if (hit) return { ...hit, image: alt };
    }
    return null;
  };
  // 同一个 SHP 的帧布局只解一次（Shadow=/帧数属于 SHP 自身，普通层与受损层必须共用）
  const shapeCache = new Map();
  const loadShape = (image) => {
    const up = String(image).toUpperCase();
    if (shapeCache.has(up)) return shapeCache.get(up);
    let base = null;
    const hit = findAnimShp(up);
    if (hit) {
      try { base = { image: hit.image, mix: hit.mix, shp: decodeShp(hit.buf) }; } catch { base = { miss: image }; }
    } else base = { miss: image };
    if (base && !base.miss) {
      // Shadow=yes 时 SHP 总帧数 = 2 × 实际帧数：前一半可见帧，后一半是同一动作的黑影
      const own = iniSec(base.image);
      base.shadow = iniBool(own, 'shadow', false);
      base.frames = Math.max(1, Math.floor(base.shp.frames.length / (base.shadow ? 2 : 1)));
    }
    shapeCache.set(up, base);
    return base;
  };
  const packAnim = (image, sec) => {
    const base = loadShape(sec?.image || image);
    if (!base || base.miss) return { miss: base ? base.miss : image };
    const shadow = iniBool(sec, 'shadow', base.shadow);
    const frames = Math.max(1, Math.floor(base.shp.frames.length / (shadow ? 2 : 1)));
    const interval = buildingAnimationRange(base.image, sec, frames);
    return {
      image: base.image, mix: base.mix, shp: base.shp, frames, shadow,
      ...interval, rate: iniNum(sec, 'rate', 900), reverse: iniBool(sec, 'reverse', false),
      loopCount: iniNum(sec, 'loopcount', -1),
      translucent: iniBool(sec, 'translucent', false),
      translucency: sec && sec['translucency'] !== undefined ? parseFloat(sec['translucency']) : 0.25,
    };
  };
  mkdirSync(ANIM_SHEET_DIR, { recursive: true });
  mkdirSync(ANIM_DESC_DIR, { recursive: true });
  const wroteSheet = new Set();
  const exportSheet = (a, sides) => {
    if (wroteSheet.has(a.image)) return;
    wroteSheet.add(a.image);
    const cols = Math.min(12, Math.max(1, a.shp.frames.length));
    const sheet = montageIndexed(a.shp, cols);
    writeFileSync(`${ANIM_SHEET_DIR}/${a.image}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, palFor(sides)));
    writeFileSync(`${ANIM_SHEET_DIR}/${a.image}.json`, JSON.stringify({
      id: a.image, kind: 'anim', source: a.mix + '/' + a.image + '.SHP', palette: 'UNITTEM.PAL',
      cell: [a.shp.width, a.shp.height], cols, count: a.shp.frames.length, rects: sheet.rects,
      frames: a.frames, shadow: a.shadow,
    }));
  };
  let animOk = 0;
  const animMissing = [];
  for (const e of allBuildings) {
    const image = String(e.image || e.id).toUpperCase();
    const bs = iniSec(image) || iniSec(e.id);
    if (!bs) continue;
    let bodyW = 0, bodyH = 0;
    const bodyHit = findShp(image, BUILDING_MIXES);
    if (bodyHit) { try { const b = decodeShp(bodyHit.buf); bodyW = b.width; bodyH = b.height; } catch { /* noop */ } }
    const layers = [];
    for (const prop of Object.keys(bs)) {
      if (!ANIM_PROP.test(prop)) continue;
      const imageName = bs[prop];
      if (!imageName || /^none$/i.test(imageName)) continue;
      const a = packAnim(imageName, iniSec(imageName));
      if (a.miss) { animMissing.push(e.id + ':' + prop + '=' + a.miss); continue; }
      // 动画 SHP 必须与主体同画布，否则没法用同一套偏移对齐
      if (bodyW && (a.shp.width !== bodyW || a.shp.height !== bodyH)) {
        animMissing.push(e.id + ':' + prop + '=' + a.image + '(cell ' + a.shp.width + 'x' + a.shp.height + '!=' + bodyW + 'x' + bodyH + ')');
        continue;
      }
      const layer = {
        kind: prop, image: a.image, loopStart: a.loopStart, loopEnd: a.loopEnd, rate: a.rate,
        frames: a.frames, shadow: a.shadow, reverse: a.reverse,
        loopCount: a.loopCount, oneShot: a.loopCount === 1,
        translucent: a.translucent, translucency: a.translucency,
        x: iniNum(bs, prop + 'x', 0), y: iniNum(bs, prop + 'y', 0),
      };
      exportSheet(a, e.sides);
      const dmgName = bs[prop + 'damaged'];
      if (dmgName) {
        const dsec = iniSec(dmgName);
        const dimg = (dsec && dsec.image) || dmgName;
        const d = packAnim(dimg, dsec || iniSec(dimg));
        if (!d.miss && (!bodyW || (d.shp.width === bodyW && d.shp.height === bodyH))) {
          layer.dmg = {
            image: d.image, loopStart: d.loopStart, loopEnd: d.loopEnd, rate: d.rate,
            frames: d.frames, shadow: d.shadow, reverse: d.reverse, loopCount: d.loopCount,
          };
          exportSheet(d, e.sides);
        }
      }
      separateBuildingHealthRanges(layer);
      correctFactoryStructure(layer, a.shp.frames.length);
      layers.push(layer);
    }
    if (layers.length) {
      writeFileSync(`${ANIM_DESC_DIR}/${e.id}.json`, JSON.stringify({ id: e.id, image, layers }));
      animOk++;
    }
  }
  out(`anim: ok=${animOk} sheets=${wroteSheet.size} miss=${animMissing.length}`);
  if (animMissing.length) out('  anim missing: ' + animMissing.slice(0, 24).join(', ') + (animMissing.length > 24 ? ` ...(+${animMissing.length - 24})` : ''));
  manifest.counts.anim = animOk;
  manifest.missing_anim = animMissing;
}
// ------------------------------------------------------------------ combat FX anims
// 战斗特效动画（武器 Anim= 炮口火光 / 弹头 AnimList= 命中动画 / 弹道 Image= 弹体）。
// 这些是 RA2 的动画 SHP（ANIM.PAL 调色，与单位/建筑不同），单独放 assets/ra2/fx/。
// 关键处理：把每帧裁到「全动画并集包围盒」，这样 cell 中心 == 动画内容中心，
// 运行时只需把 cell 居中画在目标像素上，就与 RA2 的「动画居中于落点」一致。
if (mode === 'fx' || mode === 'all') {
  const FX_DIR = `${OUT}/fx`;
  mkdirSync(FX_DIR, { recursive: true });
  const animPal = decodePal(readFileFromMix('ANIM.PAL'));
  const animations = JSON.parse(readFileSync(`${PROJECT}/data/ra2/animations.json`, 'utf8')).animations;
  const projectiles = JSON.parse(readFileSync(`${PROJECT}/data/ra2/projectiles.json`, 'utf8')).projectiles;
  const wanted = new Map(); // IMAGE -> meta
  for (const [id, a] of Object.entries(animations)) {
    wanted.set(String(a.image || id).toUpperCase(), {
      id, rate: a.rate, fps: a.fps, loopStart: a.loop_start, loopEnd: a.loop_end, shadow: !!a.shadow,
      sound: a.start_sound || null,
    });
  }
  for (const [id, p] of Object.entries(projectiles)) {
    const im = String(p.image || '').toUpperCase();
    if (im && !wanted.has(im)) wanted.set(im, { id, projectile: true, fps: 15, rate: 900, loopStart: -1, loopEnd: -1, shadow: false });
  }
  const FX_MIXES = ['CONQUER.MIX', 'ANIMS.MIX', 'GENERIC.MIX'];
  let ok = 0, miss = 0;
  const missing = [];
  for (const [image, meta] of [...wanted.entries()].sort()) {
    const hit = findShp(image, FX_MIXES);
    if (!hit) { miss++; missing.push(image); continue; }
    let shp;
    try { shp = decodeShp(hit.buf); } catch { miss++; missing.push(image + '(err)'); continue; }
    // Shadow=yes 的动画 SHP 后一半是同一动作的黑影帧，只取前一半
    const nVisible = meta.shadow ? Math.max(1, Math.floor(shp.frames.length / 2)) : shp.frames.length;
    const frames = shp.frames.slice(0, nVisible);
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const f of frames) {
      minX = Math.min(minX, f.x); minY = Math.min(minY, f.y);
      maxX = Math.max(maxX, f.x + f.w); maxY = Math.max(maxY, f.y + f.h);
    }
    const bw = Math.max(1, maxX - minX), bh = Math.max(1, maxY - minY);
    const shifted = {
      width: bw, height: bh,
      frames: frames.map((f) => ({ data: f.data, w: f.w, h: f.h, x: f.x - minX, y: f.y - minY })),
    };
    const cols = Math.min(12, Math.max(1, shifted.frames.length));
    const sheet = montageIndexed(shifted, cols);
    writeFileSync(`${FX_DIR}/${image}.png`, encodePngIndexed(sheet.width, sheet.height, sheet.indices, animPal));
    writeFileSync(`${FX_DIR}/${image}.json`, JSON.stringify({
      id: image, kind: 'fx', source: hit.mix + '/' + image + '.SHP', palette: 'ANIM.PAL',
      cell: [bw, bh], cols, count: shifted.frames.length, rects: sheet.rects,
      fps: meta.fps, rate: meta.rate, loopStart: meta.loopStart, loopEnd: meta.loopEnd,
      sound: meta.sound || null,
      projectile: !!meta.projectile, raw_count: shp.frames.length,
    }));
    ok++;
  }
  out(`fx: ok=${ok} miss=${miss}`);
  if (missing.length) out('  fx missing: ' + missing.join(', '));
  manifest.counts.fx = ok;
  manifest.missing_fx = missing;
}

// ------------------------------------------------------------------ VXL vehicle renders
if (mode === 'vxl' || mode === 'all') {
  mkdirSync(`${OUT}/vxl`, { recursive: true });
  let ok = 0, miss = 0;
  const missing = [];
  const VXL_MIXES = ['CONQUER.MIX', 'LOCAL.MIX', 'SNOW.MIX', 'ANIMS.MIX', 'GENERIC.MIX'];
  const readVxlFile = (nm) => {
    const n = nm.toUpperCase();
    for (const m of VXL_MIXES) { const b = readNamed(m, n); if (b) return { b, m }; }
    const b = readFileFromMix(n); if (b) return { b, m: 'flat' };
    return null;
  };
  let turretOk = 0;
  for (const e of allUnits) {
    if (!e.voxel) continue;
    const base = (e.image || e.id).toUpperCase();
    const pal = palFor(e.sides);
    const hit = readVxlFile(base + '.VXL');
    if (!hit) { miss++; missing.push(base + '.VXL'); continue; }
    let model;
    try { model = parseVxl(hit.b); } catch { miss++; missing.push(base + '.VXL(err)'); continue; }
    const FAC = 8;
    // RA2 stores the rotating turret / barrel as separate VXLs (<image>tur.vxl / <image>barl.vxl)
    const turLimbs = [], turSrc = [];
    for (const suf of ['tur', 'barl']) {
      const th = readVxlFile(base + suf + '.VXL');
      if (!th) continue;
      try { const tm = parseVxl(th.b); for (const l of tm.limbs) turLimbs.push(l); turSrc.push(base + suf); } catch {}
    }
    if (turLimbs.length) {
      const turModel = { limbs: turLimbs };
      const hs = [], ts = [];
      for (let f = 0; f < FAC; f++) {
        hs.push(renderVxl(model, { facing: f, facings: FAC, pal }));
        ts.push(renderVxl(turModel, { facing: f, facings: FAC, pal }));
      }
      let gminX = Infinity, gminY = Infinity, gmaxX = -Infinity, gmaxY = -Infinity;
      const upd = (r) => { gminX = Math.min(gminX, r.minX); gminY = Math.min(gminY, r.minY); gmaxX = Math.max(gmaxX, r.minX + r.width); gmaxY = Math.max(gmaxY, r.minY + r.height); };
      hs.forEach(upd); ts.forEach(upd);
      const shs = [], sts = [];
      for (let f = 0; f < FAC; f++) {
        shs.push(renderVxl(model, { facing: f, facings: FAC, pal, shadow: true }));
        sts.push(renderVxl(turModel, { facing: f, facings: FAC, pal, shadow: true }));
      }
      shs.forEach(upd); sts.forEach(upd);
      const pad = 2, cw = Math.ceil(gmaxX - gminX) + pad * 2, ch = Math.ceil(gmaxY - gminY) + pad * 2;
      const W = FAC * (cw + pad) + pad, H = ch + pad * 2;
      const paint = (arr) => {
        const cv = new Uint8Array(W * H * 4);
        arr.forEach((im, i) => {
          const ox = pad + i * (cw + pad) + Math.round(im.minX - gminX), oy = pad + Math.round(im.minY - gminY);
          for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
            const so = (y * im.width + x) * 4; if (!im.rgba[so + 3]) continue;
            const o = ((oy + y) * W + ox + x) * 4;
            cv[o] = im.rgba[so]; cv[o + 1] = im.rgba[so + 1]; cv[o + 2] = im.rgba[so + 2]; cv[o + 3] = 255;
          }
        });
        return cv;
      };
      writeFileSync(`${OUT}/vxl/${e.id}.png`, encodePng(W, H, paint(hs)));
      writeFileSync(`${OUT}/vxl/${e.id}.json`, JSON.stringify({ id: e.id, image: e.image, vxl: base + '.VXL', source: hit.m, facings: FAC, frameW: cw, frameH: ch, turret: e.id + '_tur' }));
      writeFileSync(`${OUT}/vxl/${e.id}_tur.png`, encodePng(W, H, paint(ts)));
      writeFileSync(`${OUT}/vxl/${e.id}_tur.json`, JSON.stringify({ id: e.id + '_tur', image: base, vxl: turSrc.join('+') + '.VXL', source: hit.m, facings: FAC, frameW: cw, frameH: ch, of: e.id }));
      const cvSh = paint(shs), cvSt = paint(sts);
      for (let q = 0; q < cvSh.length; q += 4) {
        if (cvSh[q + 3] || cvSt[q + 3]) { cvSh[q] = 0; cvSh[q + 1] = 0; cvSh[q + 2] = 0; cvSh[q + 3] = 255; }
      }
      writeFileSync(`${OUT}/vxl/${e.id}_shd.png`, encodePng(W, H, cvSh));
      writeFileSync(`${OUT}/vxl/${e.id}_shd.json`, JSON.stringify({ id: e.id + '_shd', image: e.image, of: e.id, source: hit.m, facings: FAC, frameW: cw, frameH: ch }));
      turretOk++; ok++;
      continue;
    }
    const imgs = [];
    for (let f = 0; f < FAC; f++) imgs.push(renderVxl(model, { facing: f, facings: FAC, pal }));
    // 影子：同一模型沿光向压平（RA2 体素阴影），与主体共用一套 cell 几何
    const shds = [];
    for (let f = 0; f < FAC; f++) shds.push(renderVxl(model, { facing: f, facings: FAC, pal, shadow: true }));
    let gminX = Infinity, gminY = Infinity, gmaxX = -Infinity, gmaxY = -Infinity;
    const upd = (r) => { gminX = Math.min(gminX, r.minX); gminY = Math.min(gminY, r.minY); gmaxX = Math.max(gmaxX, r.minX + r.width); gmaxY = Math.max(gmaxY, r.minY + r.height); };
    imgs.forEach(upd); shds.forEach(upd);
    const pad = 2, cw = Math.ceil(gmaxX - gminX) + pad * 2, ch = Math.ceil(gmaxY - gminY) + pad * 2;
    const W = FAC * (cw + pad) + pad, H = ch + pad * 2;
    const paint = (arr, black) => {
      const cv = new Uint8Array(W * H * 4);
      arr.forEach((im, i) => {
        const ox = pad + i * (cw + pad) + Math.round(im.minX - gminX), oy = pad + Math.round(im.minY - gminY);
        for (let y = 0; y < im.height; y++) for (let x = 0; x < im.width; x++) {
          const so = (y * im.width + x) * 4; if (!im.rgba[so + 3]) continue;
          const o = ((oy + y) * W + ox + x) * 4;
          cv[o] = black ? 0 : im.rgba[so]; cv[o + 1] = black ? 0 : im.rgba[so + 1]; cv[o + 2] = black ? 0 : im.rgba[so + 2]; cv[o + 3] = 255;
        }
      });
      return cv;
    };
    writeFileSync(`${OUT}/vxl/${e.id}.png`, encodePng(W, H, paint(imgs, false)));
    writeFileSync(`${OUT}/vxl/${e.id}.json`, JSON.stringify({ id: e.id, image: e.image, vxl: base + '.VXL', source: hit.m, facings: FAC, frameW: cw, frameH: ch,
      facing_offset: FAC / 2 }));
    writeFileSync(`${OUT}/vxl/${e.id}_shd.png`, encodePng(W, H, paint(shds, true)));
    writeFileSync(`${OUT}/vxl/${e.id}_shd.json`, JSON.stringify({ id: e.id + '_shd', image: e.image, of: e.id, source: hit.m, facings: FAC, frameW: cw, frameH: ch }));
    ok++;
  }
  out(`vxl: ok=${ok} turret=${turretOk} miss=${miss}`);
  if (missing.length) out('  missing: ' + missing.slice(0, 30).join(', ') + (missing.length > 30 ? ` ...(+${missing.length - 30})` : ''));
  manifest.counts.vxl = ok;
  manifest.missing_vxl = missing;
  exportUnitMuzzles();
  exportTransportRotors(PROJECT);
}

// 只有全量构建才刷新索引，避免单模式运行覆盖完整清单
if (mode === 'all') writeFileSync(`${OUT}/ra2_art_index.json`, JSON.stringify(manifest, null, 1));
