// ra2pipe/faction.mjs
// Step C 阶段1：把 Step A 的 RA2 盟军数据（data/ra2/*.json）翻译成引擎 schema，
// 并挂上 Step B 的美术索引（assets/ra2/{cameo,shp,vxl}），产出 data/ra2_allied.json。
// 只读取，不改动 data/units.json（additive）。
//
// 2026-10-11「规则全量迁移」：不再用「弹头名字猜类型 + 引擎 7×6 克制表」近似，而是把 RA2
// 的真实护甲类别（ra2_armor）、真实弹头（ra2_warhead）、真实弹道防空标志（ra2_aa）带进运行时，
// 由引擎按 warhead.Verses[armor_class] 结算伤害。手写的 UNIT_WEAPON_OVERRIDE / DEF_WEAPON
// 已删除：SREF 的 Weapon1=Comet 与防御建筑的 Primary= 现在由 build.mjs 直接提取。
import fs from 'node:fs';
import path from 'node:path';

import { readIni, getSec } from './lib/ini.mjs';
import { PROJECT, INPUT } from './paths.mjs';
const cwd = path.dirname(PROJECT);
const soviet = process.argv.includes('--soviet');
const faction = soviet ? 'soviet' : 'allied';
const RA2DIR = soviet ? process.env.YR_NORMALIZED_DIR : path.join(PROJECT, 'data', 'ra2');
const ARTDIR = path.join(PROJECT, 'assets', 'ra2');
const OUT = path.join(PROJECT, 'data', soviet ? 'yr_soviet.json' : 'ra2_allied.json');

const readJSON = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const num = (v) => {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : 0;
};
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const round2 = (v) => Math.round(v * 100) / 100;

const unitsDoc = readJSON(path.join(RA2DIR, 'units.json'));
const bldDoc = readJSON(path.join(RA2DIR, 'buildings.json'));
const wepDoc = readJSON(path.join(RA2DIR, 'weapons.json'));
const whDoc = readJSON(path.join(RA2DIR, 'warheads.json'));
const pjDoc = readJSON(path.join(RA2DIR, 'projectiles.json'));

const wepIndex = wepDoc.weapons || wepDoc;
const whIndex = whDoc.warheads || whDoc;
const pjIndex = pjDoc.projectiles || pjDoc;

// 棱镜支援链：棱镜建筑 id 取自 rules.ini [General] PrismType=（build.mjs 已写入 general.json）。
let PRISM_TYPE = 'ATESLA';
let swDoc = { weapons: {} };
try {
  const gen = readJSON(path.join(RA2DIR, 'general.json'));
  if (gen && gen.prism && gen.prism.type) PRISM_TYPE = String(gen.prism.type);
} catch (e) { /* 缺 general.json 时退回原版 id */ }
try {
  swDoc = readJSON(path.join(RA2DIR, 'superweapons.json'));
} catch (e) { /* 超级武器为可选数据 */ }

// RA2 逻辑帧率：15 fps（ROF 单位即 1/15 秒）；range 单位＝格，引擎按 55px/格换算。
const ROF_FPS = 15.0;
const PX_PER_CELL = 55.0;

// ---------------------------------------------------------------- RA2 移动规则换算
// Speed：社区口径 ≈3 点 Speed = 1 格/秒 → 每点 Speed = 移动格宽/3 px/s。
//        引擎移动格宽取 45px（承袭既往载具手写系数 15，避免回归；步兵/空军不再各自手写 26/24）。
// ROT  ：1/256 圈 / RA2 逻辑帧（1/15s）→ 每点 = (360/256)*15 = 21.09375 °/s。
//        与弹道 ROT（60~100 → 接近瞬时追踪）自洽；缺省 ROT 表示瞬时转向（步兵、部分载具）。
// Accelerates：仅 =yes 才做起停斜坡；盟军白名单内无单位开启（只有苏军潜艇/海豚），故不改既高手感。
const MOVE_CELL_PX = 45.0;
const SPEED_PX_PER_UNIT = MOVE_CELL_PX / 3.0;
const ROT_DEG_PER_SEC = (360.0 / 256.0) * ROF_FPS;
const DEFAULT_ACCEL_TIME = 0.6;

const yes = (v) => String(v || '').toLowerCase() === 'yes';

// 单位/建筑的移动规则块（RA2 rules.ini 为唯一事实源）
function buildMove(u, role, speedPx) {
  const extra = u.extra || {};
  const rotUnits = num(extra.ROT);
  const accel = yes(extra.Accelerates) || (soviet && u.id === 'SUB' && String(extra.Accelerates).toLowerCase() === 'true');
  const cu = extra.Crushable;
  const crushable = cu === undefined || cu === null || cu === ''
    ? role === 'infantry'
    : yes(cu);
  const move = {
    speed: speedPx,                                        // px/s（统一口径：Speed * MOVE_CELL_PX/3，旧手写 26/15/24 已删）
    speed_units: num(u.speed) || 0,                        // rules.ini 原值
    rot: rotUnits > 0 ? round2(rotUnits * ROT_DEG_PER_SEC) : 0, // 车体/炮塔转向速率 °/s；0 = 瞬时
    rot_units: rotUnits,
    accel_time: accel ? clamp(num(extra.AccelerationFactor) || DEFAULT_ACCEL_TIME, 0.15, 3.0) : 0,
    accelerates: accel,
    turret: !!u.turret,
    crusher: !!u.crusher || yes(extra.Crusher),
    crushable: crushable,
    weight: num(extra.Weight),
    movement_zone: u.movement_zone || null,
    speed_type: extra.SpeedType || null,
    locomotor: u.locomotor || null,
  };
  const dock = extra.Dock;
  if (dock) move.dock = String(dock).toUpperCase();
  return move;
}

// ---------------------------------------------------------------- 美术索引
const listSet = (d) => new Map(fs.readdirSync(path.join(ARTDIR, d)).map((f) => [f.toLowerCase(), f]));
const cameoSet = listSet('cameo');
const shpSet = listSet('shp');
const vxlSet = listSet('vxl');

function artFor(id, cameo) {
  const out = {};
  if (cameo && cameoSet.has(cameo.toLowerCase() + '.png'))
    out.cameo = `res://assets/ra2/cameo/${cameoSet.get(cameo.toLowerCase() + '.png')}`;
  const u = id.toUpperCase();
  if (shpSet.has(u.toLowerCase() + '.png')) out.shp = `res://assets/ra2/shp/${shpSet.get(u.toLowerCase() + '.png')}`;
  if (vxlSet.has(u.toLowerCase() + '.png')) out.vxl = `res://assets/ra2/vxl/${vxlSet.get(u.toLowerCase() + '.png')}`;
  return out;
}

// ---------------------------------------------------------------- 护甲 / 弹头
const ARMOR = {
  none: 'unarmored', flak: 'light', plate: 'medium', light: 'light', medium: 'medium',
  heavy: 'heavy', wood: 'structure', steel: 'structure', concrete: 'structure',
  special_1: 'heavy', special_2: 'heavy',
};

// 引擎旧词表（armor 字段 / UI / 兼容路径）；RA2 真实类别另存 ra2_armor。
function legacyAttackType(wh) {
  const k = String(wh || '').toUpperCase();
  if (k.includes('AA') || k.includes('FLAK')) return 'flak';
  if (k.includes('ROCKET') || k.includes('MISSILE') || k.includes('MAVERICK') || k.includes('TORPEDO')) return 'rocket';
  if (k.includes('COMET') || k.includes('PRISM') || k.includes('LASER') || k.includes('TESLA') || k.includes('SHOCK') || k.includes('ION')) return 'tesla';
  if (k.includes('AP') || k.includes('SAP') || k.includes('HE') || k.includes('CANNON') || k.includes('HOWITZER')) return 'shell';
  if (k.includes('SA') || k.includes('SSA') || k.includes('SMALL')) return 'bullet';
  return 'bullet';
}

// 单位武器一律取 RA2 真实数据（不再覆写）。
function buildWeapon(primId, secId) {
  const w = wepIndex[primId] || wepIndex[secId];
  if (!w) return null;
  const damage = num(w.damage);
  if (damage <= 1 && !(soviet && ['V3Launcher', 'Flare', 'RadEruptionWeapon'].includes(w.id))) return null; // 维修/装饰型武器（伤害≤1）不转
  const rof = num(w.rof) || 30;
  const rng = num(w.range) || 4;
  const spd = num(w.speed) || 0;
  const pj = w.projectile ? (pjIndex[w.projectile] || null) : null;
  return {
    name: String(primId || secId || ''),
    attack_type: legacyAttackType(w.warhead),
    damage: Math.round(damage),
    cooldown: round2(clamp(rof / ROF_FPS, 0.15, 30.0)),
    range: Math.round(rng * PX_PER_CELL),
    projectile_speed: spd > 0 ? Math.round(clamp(spd * 11, 520, 1300)) : 0,
    burst: Math.max(1, Math.round(num(w.burst) || 1)),
    burst_delay: 0.12,
    aoe: 0,
    min_range: Math.round(num(w.min_range) * PX_PER_CELL),
    // ---- RA2 真实规则：引擎按 warhead.Verses[目标 ra2_armor] 结算 ----
    ra2_weapon_id: w.id || String(primId || secId || ''),
    ra2_warhead: w.warhead || null,
    ra2_projectile: w.projectile || null,
    ra2_aa: !!(pj && pj.aa),
    // ---- RA2 开火音效：rules.ini 的 Report= 指向 [sound.ini] 的 sound id ----
    report: (w.report || '').trim(),
  };
}

// ---------------------------------------------------------------- 老兵 / 精英（RA2 rules.ini VeteranAbilities / EliteAbilities）
// RA2 单位按「击杀价值」累积经验：达到 VeteranRatio × 自身价值升 Veteran(1)，再一倍升 Elite(2)。
// 每次升级授予一组能力（STRONGER/FIREPOWER/ROF/SIGHT/FASTER/SELF_HEAL/SCATTER...），
// 并用 [General] 的倍率（VeteranCombat/Speed/Armor/ROF）叠加；Elite 另有专属武器（ElitePrimary=）。
// 全局倍率从 rules.ini [General] 提取（build.mjs 已写入 data/ra2/general.json）。
// 能力 → 引擎可执行的数值/行为映射：
//   STRONGER  = 提升最大生命并补满（ra2 原版：升级时按倍率补血）
//   FIREPOWER = 伤害 × VeteranCombat（1.1）
//   ROF       = 冷却 × VeteranROF（0.6，即射速更快）
//   SIGHT     = 视野 × VeteranSight（本作 0 → 忽略，因原版为 0.0 防崩溃）
//   FASTER    = 速度 × VeteranSpeed（1.2）
//   SELF_HEAL = 每帧缓慢自愈（非战斗时）
//   SCATTER   = 被击中后附近同类散开（高价值单位，本作以「受击后短暂加速脱离」近似）
const ABILITY_KEYS = ['STRONGER', 'FIREPOWER', 'ROF', 'SIGHT', 'FASTER', 'SELF_HEAL', 'SCATTER'];
function parseAbilities(raw) {
  const out = {};
  for (const a of String(raw || '').split(',')) {
    const k = a.trim().toUpperCase();
    if (ABILITY_KEYS.includes(k)) out[k] = true;
  }
  return out;
}
// 提取该单位/建筑的 veteran 块（无 VeteranAbilities 时返回 null）
function buildVeteran(extra, eliteWeapon) {
  const vet = parseAbilities((extra || {}).VeteranAbilities);
  const elite = parseAbilities((extra || {}).EliteAbilities);
  if (!Object.keys(vet).length && !Object.keys(elite).length && !eliteWeapon) return null;
  const out = {
    veteran: vet,
    elite: elite,
  };
  if (eliteWeapon) out.elite_weapon = eliteWeapon;
  return out;
}

// ---------------------------------------------------------------- 单位/建筑语音（RA2 rules.ini → [sound.ini] 的 sound id）
// rules.ini 的小节里 VoiceSelect=/VoiceMove=/VoiceAttack=/VoiceFeedback=/VoiceSpecialAttack=/
// DieSound=/CrushSound=/DeploySound=/UndeploySound= 的值，就是 [sound.ini] 里 [SoundList] 条目的
// 名字（原版这些条目内的 Sounds= 带 '$' 前缀，表「单位语音」；无 '$' 表纯音效）。
// 注意：语音与武器开火音是两套东西（GIAttackCommand=下令，GIAttack=开火）。
const VOICE_MAP = [
  ['select', 'VoiceSelect'], ['move', 'VoiceMove'], ['attack', 'VoiceAttack'],
  ['feedback', 'VoiceFeedback'], ['special', 'VoiceSpecialAttack'], ['die', 'DieSound'],
  ['crush', 'CrushSound'], ['deploy', 'DeploySound'], ['undeploy', 'UndeploySound'],
];
function buildVoice(extra) {
  const v = {};
  for (const [key, src] of VOICE_MAP) {
    const val = String((extra || {})[src] || '').trim();
    if (val) v[key] = val;
  }
  return Object.keys(v).length ? v : null;
}

// ---------------------------------------------------------------- 建筑白名单
const BUILDING_TAGS = soviet ? {
  NANRCT: ['structure', 'power'], NAINDP: ['structure', 'tech'], NAIRON: ['structure', 'superweapon'], NAMISL: ['structure', 'superweapon'],
  NAYARD: ['structure', 'production', 'shipyard', 'repair'],
  NACNST: ['structure', 'hq', 'production'], NAPOWR: ['structure', 'power'],
  NAHAND: ['structure', 'production', 'barracks'], NAREFN: ['structure', 'resource', 'refinery'],
  NAWEAP: ['structure', 'production', 'factory'], NARADR: ['structure', 'radar'], NATECH: ['structure', 'tech'], NADEPT: ['structure', 'repair'], NALASR: ['structure', 'defense'],
  NAFLAK: ['structure', 'defense'], TESLA: ['structure', 'defense'],
  NABNKR: ['structure', 'defense'], NAWALL: ['structure', 'defense', 'wall'],
} : {
  GACNST: ['structure', 'hq', 'production'],   // 建造场（Construction Yard）：rules.ini 里的基地核心；
                                              // battle.gd 的 _check_end 靠 ['hq'] 标签找 HQ，缺它开局即判负
  GAPOWR: ['structure', 'power'],
  GAREFN: ['structure', 'resource', 'refinery'],
  GAOREP: ['structure', 'resource', 'purifier'],
  GAPILE: ['structure', 'production', 'barracks'],
  GAWEAP: ['structure', 'production', 'factory'],
  GAAIRC: ['structure', 'production', 'airbase', 'radar'],
  GADEPT: ['structure', 'repair'],
  GATECH: ['structure', 'tech'],
  GAPILL: ['structure', 'defense'],
  ATESLA: ['structure', 'defense'],
  GTGCAN: ['structure', 'defense'],
  // 船坞（Naval=yes / WaterBound=yes）：四格水上建筑，生产六种盟军舰船。
  GAYARD: ['structure', 'production', 'shipyard', 'repair'],
  // 超级武器：超时空传送仪（ChronoSphereSpecial）、天气控制器（LightningStormSpecial）。
  GACSPH: ['structure', 'superweapon'],
  GAWEAT: ['structure', 'superweapon'],
  GAGAP: ['structure', 'defense'],
  GASAND: ['structure', 'defense', 'wall'],
  GAWALL: ['structure', 'defense', 'wall'],
  GASPYSAT: ['structure', 'radar'],
  // 爱国者飞弹（RA2 盟军防空建筑）：Primary=RedEye2 → 弹道 AAHeatSeeker（aa=yes）
  // → 运行时 weapon.ra2_aa=true，全项目唯一「平地对空」防御点。
  NASAM: ['structure', 'defense'],
};

// 防御建筑武器一律取 RA2 真实 Primary=（build.mjs 已提取），不再手写覆写。
function parseFoundation(f) {
  const m = String(f || '2x2').toLowerCase().split('x');
  return { w: parseInt(m[0], 10) || 2, h: parseInt(m[1], 10) || 2 };
}

function roleNameForBuilding(tags) {
  if (tags.includes('defense')) return tags.includes('wall') ? '围墙' : '防御建筑';
  if (tags.includes('superweapon')) return '超级武器';
  if (tags.includes('shipyard')) return '船坞';
  if (tags.includes('power')) return '电力建筑';
  if (tags.includes('resource')) return '经济建筑';
  if (tags.includes('production')) return '生产建筑';
  if (tags.includes('radar')) return '雷达建筑';
  if (tags.includes('tech')) return '科技建筑';
  if (tags.includes('repair')) return '维修建筑';
  return '建筑';
}

// ---------------------------------------------------------------- 单位
const ROLE_NAME = { infantry: '步兵', vehicle: '载具', air: '空军', naval: '海军', economy: '采矿' };
const NAVAL_MZ = new Set(['water', 'ship', 'amphibious']);

// 正式盟军阵容白名单（排除平民/动物/战役专属/重复条目）
const UNIT_WHITELIST = new Set(soviet ? ['E2', 'HTNK', 'HARV', 'SMCV', 'FLAKT', 'HTK', 'SENGINEER', 'SHK', 'APOC', 'DRON', 'V3', 'DOG', 'ZEP', 'SCHP', 'SUB', 'HYD', 'SAPC', 'TTNK', 'DTRUCK', 'TERROR', 'IVAN', 'CIVAN', 'DESO', 'BORIS', 'DRED', 'SQD'] : [
  // 步兵
  'E1', 'ENGINEER', 'JUMPJET', 'SNIPE', 'SPY', 'TANY', 'GHOST', 'CLEG', 'DOG', 'TTNK',
  // 隐藏科技步兵（RA2 tech_level 9，需 GATECH）：超时空突击队 / 心灵突击队
  'CCOMAND', 'PTROOP',
  // 载具 / 直升机
  'MTNK', 'FV', 'MGTK', 'SREF', 'TNKD', 'AMCV', 'SHAD', 'CMIN',
  // 空军
  'ORCA', 'BEAG',
  // 海军（GAYARD 六舰）：驱逐舰 / 神盾巡洋舰 / 航空母舰 / 两栖运输艇 / 海豚 / 海岸驱逐舰
  'DEST', 'AEGIS', 'CARRIER', 'LCRF', 'DLPH', 'CDEST',
]);

function unitRole(id, u) {
  const extra = u.extra || {};
  const isHarv = String(extra.Harvester || '').toLowerCase() === 'yes' || id === 'CMIN' || id === 'HARV';
  if (isHarv) return 'economy';
  const mz = String(u.movement_zone || '').toLowerCase();
  if (u.kind === 'aircraft' || mz === 'fly') return 'air';
  if (NAVAL_MZ.has(mz)) return 'naval';
  if (u.kind === 'infantry') return 'infantry';
  return 'vehicle';
}

const units = [];
const buildings = [];
const art = {};

// 建筑
for (const [id, tags] of Object.entries(BUILDING_TAGS)) {
  const b = (bldDoc.buildings || {})[id];
  if (!b) continue;
  if (!(b.sides || []).includes(faction)) continue;
  const found = parseFoundation(b.foundation);
  const entry = {
    id,
    name: b.display_name || id,
    faction,
    role: 'structure',
    role_name: roleNameForBuilding(tags),
    cost: num(b.cost),
    build_time: clamp(Math.round(num(b.cost) / 50), 4, 40),
    hp: Math.round(num(b.hp) * 3),
    armor: 'structure',
    ra2_armor: String(b.armor || 'concrete').toLowerCase(),
    radius: clamp(Math.round(6 + (found.w + found.h) * 4), 14, 60),
    sight: Math.round(num(b.sight) * 55),
    tags: tags.slice(),
    builds: [],
    desc: 'RA2 盟军建筑 · ' + String(b.category || ''),
    ra2: true,
  };
  if (b.foundation) entry.foundation = b.foundation;
  if (b.buildup) entry.buildup = b.buildup;
  const bw = buildWeapon(b.primary, b.secondary);
  if (bw) entry.weapon = bw;
  // 老兵武器（ElitePrimary=/EliteWeapon1=）
  const bEliteW = buildWeapon(b.elite_primary || (b.extra && b.extra.EliteWeapon1), null);
  const bv = buildVoice(b.extra);
  if (bv) entry.voice = bv;
  const bVet = buildVeteran(b.extra, bEliteW);
  if (bVet) entry.veteran = bVet;
  if (Array.isArray(b.prerequisites) && b.prerequisites.length) entry.ra2_prereq = b.prerequisites;
  if (b.tech_level != null) entry.tech_level = b.tech_level;
  // RA2 电力：Power= 正数=发电 / 负数=耗电；Powered=yes=低电离线。
  if (num(b.power)) entry.power = num(b.power);
  if (b.powered) entry.powered = true;
  // 水界建筑（GAYARD Naval=yes / WaterBound=yes）：只允许建在水面。
  const bx = b.extra || {};
  if (String(bx.Naval || '').toLowerCase() === 'yes'
      || String(bx.WaterBound || '').toLowerCase() === 'yes') {
    entry.water_bound = true;
    if (!entry.tags.includes('water')) entry.tags.push('water');
  }
  // 超级武器：建筑节 SuperWeapon=<Special 节名>，节数据来自 data/ra2/superweapons.json。
  const swId = String(bx.SuperWeapon || '');
  const swDef = swId && swDoc.weapons ? swDoc.weapons[swId] : null;
  if (swDef) {
    entry.superweapon = {
      id: swId,
      type: String(swDef.type || ''),
      name: swDef.name || swId,
      ui_name: swDef.ui_name || '',
      recharge_seconds: Math.max(30.0, num(swDef.recharge_seconds) || 420.0),
      recharge_voice: swDef.recharge_voice || '',
      action: swDef.action || '',
    };
    if (swDef.storm) entry.superweapon.storm = swDef.storm;
    if (!entry.tags.includes('superweapon')) entry.tags.push('superweapon');
  }
  // 棱镜支援链（T5）：rules.ini [General] PrismType=ATESLA 指明棱镜建筑 id（只有一座）。
  // 该建筑可与同 id 的友方棱镜互相充能；支援光束（Secondary=PrismSupport）在主武器开火时触发，
  // 见 building.gd _prism_support_chain()。general.json 的 prism.type 为唯一事实源。
  if (id === PRISM_TYPE) {
    entry.prism_type = id;
    if (b.secondary && /prism/i.test(String(b.secondary))) {
      entry.prism_support_weapon = String(b.secondary);
      // 支援武器换算后的像素射程（PrismSupport Range=8 格 → 440px）；
      // 支援塔必须自身也在目标射程内，见 building.gd _prism_support_chain()。
      const sw = buildWeapon(b.secondary, null);
      if (sw && num(sw.range) > 0) entry.prism_support_range = sw.range;
    }
  }
  buildings.push(entry);
  art[id] = artFor(id, b.cameo);
}

const buildingIds = new Set(buildings.map((b) => b.id));
const PRODUCERS = ['GAPILE', 'GAWEAP', 'GAAIRC', 'GAYARD'];

// 单位：只收盟军（含 GAYARD 海军）
for (const kind of ['infantry', 'vehicles', 'aircraft']) {
  const bucket = unitsDoc[kind] || {};
  for (const [id, u] of Object.entries(bucket)) {
    if (!(u.sides || []).includes(faction)) continue;
    if (!UNIT_WHITELIST.has(id)) continue;
    const mz = String(u.movement_zone || '').toLowerCase();

    const role = unitRole(id, u);
    const isAir = role === 'air';
    const isInf = role === 'infantry';
    const isEco = role === 'economy';
    const isNaval = role === 'naval';
    const extra = u.extra || {};
    const isHarv = isEco;

    // built_at：优先取 prerequisites 里的生产建筑，否则按兵种兜底
    let builtAt = '';
    for (const p of (u.prerequisites || [])) {
      if (PRODUCERS.includes(p)) { builtAt = p; break; }
    }
    if (!builtAt) builtAt = isAir ? 'GAAIRC' : isInf ? 'GAPILE' : isNaval ? 'GAYARD' : 'GAWEAP';
    if (isHarv) builtAt = 'GAWEAP';
    if (soviet) builtAt = isNaval ? 'NAYARD' : isInf ? 'NAHAND' : 'NAWEAP';

    const tags = [];
    if (isAir) tags.push('air');
    if (isInf) tags.push('infantry');
    if (isNaval) tags.push('naval', 'ship');
    if (isEco) tags.push('harvester', 'vehicle');
    if (!isAir && !isInf && !isEco && !isNaval) tags.push('vehicle');

    const sz = num(u.size) || 1;
    const radius = isInf ? 7 : isAir ? 13 : isNaval ? clamp(12 + sz * 2, 14, 26) : clamp(9 + sz * 2, 10, 18);
    // 速度与转向一律按 RA2 规则换算（不再按兵种手写系数）
    const move = buildMove(u, role, clamp(Math.round((num(u.speed) || 4) * SPEED_PX_PER_UNIT), 40, 300));
    const speed = move.speed;
    const sightC = num(u.sight) || 5;
    const sight = Math.round(sightC * (isInf ? 60 : isAir ? 50 : 40));

    const entry = {
      id,
      name: u.display_name || id,
      faction,
      role,
      role_name: ROLE_NAME[role] || role,
      cost: num(u.cost),
      build_time: clamp(Math.round(num(u.cost) / 50), 3, 40),
      hp: Math.round(num(u.hp)),
      armor: isAir ? 'air' : (ARMOR[String(u.armor || 'none').toLowerCase()] || 'unarmored'),
      ra2_armor: String(u.armor || 'none').toLowerCase(),
      speed,
      move,
      radius,
      sight,
      tags,
      built_at: builtAt,
      voxel: !!u.voxel,
      desc: 'RA2 盟军 · ' + String(u.category || ''),
      ra2: true,
    };
    const w = buildWeapon(u.primary, u.secondary);
    if (w) entry.weapon = w;
    // 老兵武器：ElitePrimary=/EliteWeapon1= → 引擎在升到 Elite 时替换主武器。
    const eliteW = buildWeapon(u.elite_primary || extra.EliteWeapon1, null);
    if (eliteW) entry.elite_weapon = eliteW;
    if (id === 'E1') {
      entry.deployed_weapon = buildWeapon(u.secondary, null);
      entry.elite_deployed_weapon = buildWeapon(u.elite_secondary || extra.EliteSecondary, null);
    }
    const v = buildVoice(extra);
    if (v) entry.voice = v;
    const vetBlock = buildVeteran(extra, eliteW);
    if (vetBlock) entry.veteran = vetBlock;
    if (isHarv) entry.harvester = { income_per_sec: 22.0, cargo_cap: 500, unload_time: 1.0 };
    if (Array.isArray(u.prerequisites) && u.prerequisites.length) entry.ra2_prereq = u.prerequisites;
    if (u.tech_level != null) entry.tech_level = u.tech_level;
    if (mz) entry.movement_zone = mz;
    if (u.image) entry.image = u.image;
    if (u.cameo) entry.cameo = u.cameo;
    // 卧倒/展开（RA2 `Deployer=yes` + art.ini Sequence `Deployed=`）
    // → 引擎 unit.deploy()/can_deploy() 与卧倒姿态帧 _deploy_frame。
    if (u.deployer) entry.deployer = true;
    if (num(u.deploy_frame) >= 0) {
      entry.deploy_frame = num(u.deploy_frame);
      // 扩展模式额外加成；RA2 模式倍率为 1，部署时切换 Secondary 武器。
      entry.deploy_attack_mult = 1.5;
      entry.deploy_defense_mult = 1.15;
    }

    if (soviet && id === 'DOG') entry.id = 'SOV_DOG'; // DOG is the legacy Allied save ID.
    units.push(entry);
    if (!art[entry.id]) art[entry.id] = artFor(entry.id, u.cameo);
  }
}

// 回填 builds
const buildsByProducer = {};
for (const u of units) {
  (buildsByProducer[u.built_at] = buildsByProducer[u.built_at] || []).push(u.id);
}
for (const b of buildings) {
  b.builds = buildsByProducer[b.id] || [];
}

const doc = {
  version: 1,
  generated_from: 'data/ra2/*.json (Step A) + assets/ra2/* (Step B)',
  note: 'RA2 盟军阵营 + 科技树（引擎 schema）。仅增量，不动 data/units.json。',
  faction,
  counts: { units: units.length, buildings: buildings.length, art: Object.keys(art).length },
  units,
  buildings,
  art,
};

if (soviet) {
  const names = {BORIS:'鲍里斯', DRED:'无畏级战舰', SQD:'巨型乌贼', NAINDP:'工业工厂', NANRCT:'核子反应炉', NAIRON:'铁幕装置', NAMISL:'核弹发射井', SAPC:'苏联两栖运输艇', TTNK:'磁能坦克', DTRUCK:'自爆卡车', TERROR:'恐怖分子', IVAN:'疯狂伊文', CIVAN:'超时空伊文', DESO:'辐射工兵', NAYARD:'苏联造船厂', SUB:'台风级潜艇', HYD:'海蝎', SOV_DOG:'苏联警犬', ZEP:'基洛夫空艇', SCHP:'武装直升机', NATECH:'苏联作战实验室', APOC:'天启坦克', DRON:'恐怖机器人', V3:'V3 火箭车', NACNST:'苏联建造厂', NAPOWR:'磁能反应炉', NAHAND:'苏联兵营', NAREFN:'苏联矿石精炼场', NAWEAP:'苏联战车工厂', NADEPT:'苏联维修厂', NALASR:'哨戒炮', NARADR:'苏联雷达', SHK:'磁暴步兵', TESLA:'磁暴线圈', NAFLAK:'防空炮', NABNKR:'战斗碉堡', NAWALL:'苏联围墙', FLAKT:'防空步兵', HTK:'防空履带车', SENGINEER:'苏联工程师', E2:'动员兵', HTNK:'犀牛坦克', HARV:'武装采矿车', SMCV:'苏联机动基地车'};
  doc.generated_from = 'Local Yuri Revenge rulesmd.ini and artmd.ini';
  // soundmd.ini [TeslaCoilPowerUp] uses the existing btespow sample at Volume=85.
  doc.sounds = { specs: { YR_SOV_TeslaCoilPowerUp: { sounds: ['yr_sov_btespow'], volume: 85 } },
    entries: { yr_sov_btespow: {file: 'btespow.wav'} } };
  for (const [id, sounds, volume, range, delay] of [
    ['MIGMove', ['vmigmoa','vmigmob'], 100, 10, 1500],
    ['MIGMissionAborted', ['vmigdib'], 85, 40, 0],
    ['SeigeChopperDeploy', ['vchodepa'], 60, 10, 0],
  ]) {
    doc.sounds.specs[id] = {sounds, volume, range};
    if (delay) doc.sounds.specs[id].delay_ms = delay;
    for (const key of sounds) doc.sounds.entries[key] = { file: 'yr_full/'+key+'.wav' };
  }
  const waterSamples = ['gexpwala','gexpwalb','gexpwalc'];
  doc.sounds.specs.ExplosionWaterLarge = {sounds:waterSamples, volume:55};
  for (const key of waterSamples) doc.sounds.entries[key] = {file:key+'.wav'};
  delete doc.note;
  doc.source_units = {};
  doc.source_buildings = {};
  doc.weapons = {};
  doc.warheads = {};
  function registerWeapon(weapon) {
    if (!weapon) return;
    const native = wepIndex[weapon.ra2_weapon_id];
    const id = 'YR_SOV_' + native.id, warhead = 'YR_SOV_' + native.warhead;
    doc.warheads[warhead] = { ...whIndex[native.warhead], id: warhead };
    doc.weapons[id] = { ...native, id, warhead };
    weapon.ra2_weapon_id = id;
    weapon.ra2_warhead = warhead;
    weapon.cooldown = native.rof / ROF_FPS;
  }
  for (const entry of [...units, ...buildings]) {
    const id = entry.id;
    const raw = bldDoc.buildings[id] || unitsDoc.infantry[id === 'SOV_DOG' ? 'DOG' : id] || unitsDoc.vehicles[id];
    (bldDoc.buildings[id] ? doc.source_buildings : doc.source_units)[id] = raw;
    entry.name = names[id];
    if (id === 'SHK' || id === 'TESLA') {
      const field = id === 'SHK' ? 'charge_weapon' : 'charged_weapon';
      entry[field] = buildWeapon(raw.secondary);
      registerWeapon(entry[field]);
    }
    if (id === 'BORIS' || id === 'SQD') {
      entry.special_weapon = buildWeapon(raw.secondary);
      registerWeapon(entry.special_weapon);
      if (raw.elite_secondary && raw.elite_secondary !== raw.secondary) { entry.elite_special_weapon = buildWeapon(raw.elite_secondary); registerWeapon(entry.elite_special_weapon); }
    }
    if (id === 'NAINDP') entry.vehicle_cost_factor = Number(raw.extra.UnitsCostBonus);
    if (id === 'DESO') {
      entry.immune_to_radiation = true;
      entry.deployed_weapon = buildWeapon(raw.secondary);
      registerWeapon(entry.deployed_weapon);
      entry.deployed_prone = false;
    }
    if (id === 'TESLA') {
      const art = getSec(readIni(path.join(INPUT, 'art.ini')), raw.image).keys;
      entry.fire_delay = Number(art.get('delayedfiredelay')) / ROF_FPS;
      entry.fire_flh = art.get('primaryfireflh').split(',').map(Number);
    }
    if (id === 'NAFLAK') entry.weapon.flak_scatter = yes(pjIndex[entry.weapon.ra2_projectile].extra.FlakScatter);
    if (id === 'NABNKR') {
      entry.garrison_slots = Number(raw.extra.MaxNumberOccupants);
      const art = getSec(readIni(path.join(INPUT, 'art.ini')), raw.image).keys;
      entry.fire_ports = Array.from({length: entry.garrison_slots}, (_, i) => art.get('muzzleflash' + i).split(',').map(Number));
      entry.garrison_weapons = {};
      for (const name of ['UCPara', 'UCElitePara', 'UCM1Carbine', 'UCEliteM1Carbine']) {
        const gun = buildWeapon(name);
        registerWeapon(gun);
        entry.garrison_weapons[name] = gun;
      }
    }
    if (id === 'NATECH') {
      const general = getSec(readIni(path.join(INPUT, 'rules.ini')), 'General').keys;
      Object.assign(entry.superweapon, {ui_name:'力场护盾', radius:Number(general.get('forceshieldradius')) * PX_PER_CELL,
        duration:Number(general.get('forceshieldduration')) / ROF_FPS, blackout:Number(general.get('forceshieldblackoutduration')) / ROF_FPS});
    }
    if (id === 'ZEP') entry.bomb_flh = getSec(readIni(path.join(INPUT,'art.ini')), 'ZEP').keys.get('primaryfireflh').split(',').map(Number);
    if (id === 'SCHP') {
      const nativeArt = readIni(path.join(INPUT,'art.ini'));
      const animation = getSec(nativeArt,raw.extra.DeployingAnim).keys;
      const mounts = getSec(nativeArt,raw.image).keys;
      entry.air_flh = mounts.get('primaryfireflh').split(',').map(Number);
      entry.ground_flh = mounts.get('secondaryfireflh').split(',').map(Number);
      entry.deploy_animation = {rate:Number(animation.get('rate')), sound:animation.get('startsound')};
      entry.deployer = true;
      entry.deployed_prone = false;
      entry.deploy_attack_mult = 1;
      entry.deployed_weapon = buildWeapon(raw.secondary);
      entry.elite_deployed_weapon = buildWeapon(raw.elite_secondary);
      registerWeapon(entry.deployed_weapon);
      registerWeapon(entry.elite_deployed_weapon);
    }
    if (id === 'APOC' || id === 'ZEP') {
      const general = getSec(readIni(path.join(INPUT, 'rules.ini')), 'General').keys;
      entry.self_repair = {step:1, interval:Number(general.get('repairrate'))*60};
    }
    if (id === 'APOC') {
      entry.anti_air_weapon = buildWeapon(raw.secondary);
      registerWeapon(entry.anti_air_weapon);
      entry.elite_anti_air_weapon = entry.anti_air_weapon;
    }
    if (id === 'DRON') {
      entry.immune_to_psionics = yes(raw.extra.ImmuneToPsionics);
      entry.immune_to_radiation = yes(raw.extra.ImmuneToRadiation);
    }
    if (id === 'V3' || id === 'DRED') {
      const rules = readIni(path.join(INPUT, 'rules.ini'));
      const general = getSec(rules, 'General').keys;
      const prefix = id === 'V3' ? 'v3rocket' : 'dmisl';
      entry.rocket = {damage:Number(general.get(prefix + 'damage')), elite_damage:Number(general.get(prefix + 'elitedamage')),
        windup:Number(general.get(prefix + 'tiltframes')) / ROF_FPS, reload:Number(raw.extra.SpawnRegenRate) / ROF_FPS,
        speed:Number(getSec(rules, raw.extra.Spawns).keys.get('speed')) * MOVE_CELL_PX / 3,
        altitude:Number(general.get(prefix + 'altitude')) * PX_PER_CELL / 256};
      for (const name of (id === 'V3' ? ['V3WH', 'V3EWH'] : ['DMISLWH','DMISLEWH'])) doc.warheads['YR_SOV_' + name] = {...whIndex[name], id:'YR_SOV_' + name};
    }
    if (id === 'FLAKT' || id === 'HTK' || id === 'HYD') {
      entry.anti_air_weapon = buildWeapon(raw.secondary);
      entry.elite_anti_air_weapon = buildWeapon(raw.elite_secondary);
      for (const gun of [entry.weapon, entry.elite_weapon, entry.anti_air_weapon, entry.elite_anti_air_weapon]) {
        gun.flak_scatter = yes(pjIndex[gun.ra2_projectile].extra.FlakScatter);
      }
      registerWeapon(entry.anti_air_weapon);
      registerWeapon(entry.elite_anti_air_weapon);
    }
    registerWeapon(entry.weapon);
    registerWeapon(entry.elite_weapon);
    // buildVeteran shares the elite weapon object with the runtime entry.
    entry.desc = '苏联 · ' + entry.role_name;
    entry.hp = raw.hp;
    if (bldDoc.buildings[id]) {
      entry.adjacent = raw.adjacent ?? 2;
      entry.base_normal = String(raw.extra?.BaseNormal || 'yes').toLowerCase() !== 'no';
    }
    entry.build_time_multiplier = Number(raw.extra?.BuildTimeMultiplier || 1);
    delete entry.build_time;
    if (!raw.deployer) delete entry.deploy_frame;
    if (entry.harvester) entry.harvester.cargo_cap = Number(raw.extra.Storage);
  }
  const rocket = unitsDoc.aircraft.V3ROCKET;
  doc.units.push({id:rocket.id, name:'V3 火箭', faction, role:'air', role_name:'导弹',
    hp:rocket.hp, cost:rocket.cost, armor:ARMOR[rocket.armor], ra2_armor:rocket.armor,
    speed:rocket.speed*SPEED_PX_PER_UNIT, radius:5, sight:PX_PER_CELL, tags:['air'], tech_level:-1, ra2:true});
  doc.source_units.V3ROCKET = rocket;
  doc.art.V3ROCKET = artFor('V3ROCKET', null);
  doc.counts.units = doc.units.length;
  doc.counts.art = Object.keys(doc.art).length;
  for (const id of ['DMISL','BPLN','SPYP']) {
    const aircraft = unitsDoc.aircraft[id];
    const entry = {id, name:id === 'DMISL' ? '无畏导弹' : id === 'SPYP' ? '间谍侦察机' : '米格攻击机', faction, role:'air', role_name:'支援', hp:aircraft.hp, cost:0, armor:ARMOR[aircraft.armor], ra2_armor:aircraft.armor, speed:aircraft.speed*SPEED_PX_PER_UNIT, radius:8, sight:Math.max(1,aircraft.sight)*PX_PER_CELL, tags:['air'], tech_level:-1, ra2:true};
    if (id === 'BPLN') {
      entry.weapon = buildWeapon(aircraft.primary); registerWeapon(entry.weapon);
      entry.elite_weapon = buildWeapon(aircraft.elite_primary); registerWeapon(entry.elite_weapon);
    }
    if (id === 'SPYP') {
      const camera=wepIndex[aircraft.primary];
      entry.recon_camera={range:camera.range*PX_PER_CELL, radius:camera.damage*PX_PER_CELL, sound:camera.report};
    }
    doc.units.push(entry); doc.source_units[id]=aircraft; doc.art[id]=artFor(id,null);
  }
  doc.counts.units = doc.units.length; doc.counts.art = Object.keys(doc.art).length;
  const rad = getSec(readIni(path.join(INPUT, 'rules.ini')), 'Radiation').keys;
  doc.radiation = {duration:Number(rad.get('raddurationmultiple')), interval:Number(rad.get('radapplicationdelay'))/ROF_FPS,
    max_level:Number(rad.get('radlevelmax')), level_delay:Number(rad.get('radleveldelay')), factor:Number(rad.get('radlevelfactor')), warhead:rad.get('radsitewarhead')};
  if (units.length !== 30 || buildings.length !== 18) throw new Error('Incomplete Soviet roster');
  fs.writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');
  process.exit(0);
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
// Scoped regeneration preserves unrelated runtime schema adjustments.
if (process.argv.includes('--gi-weapons-only')) {
  const existing = JSON.parse(fs.readFileSync(OUT, 'utf8'));
  const target = existing.units.find(u => u.id === 'E1');
  const generated = units.find(u => u.id === 'E1');
  if (!target || !generated?.deployed_weapon || !generated?.elite_deployed_weapon) throw new Error('Missing GI weapon sources');
  target.deployed_weapon = generated.deployed_weapon;
  target.elite_deployed_weapon = generated.elite_deployed_weapon;
  fs.writeFileSync(OUT, JSON.stringify(existing, null, 1), 'utf8');
  console.log('Updated E1 deployed weapon pair only');
  process.exit(0);
}
fs.writeFileSync(OUT, JSON.stringify(doc, null, 1), 'utf8');

// 报告
const lines = [];
lines.push(`RA2 盟军阵营 → ${path.relative(cwd, OUT)}`);
lines.push(`units=${units.length} buildings=${buildings.length} art=${Object.keys(art).length}`);
lines.push('');
lines.push('建筑:');
for (const b of buildings) lines.push(`  ${b.id.padEnd(8)} ${b.name}  cost=${b.cost} hp=${b.hp} r=${b.radius} pre=${(b.ra2_prereq || []).join('+')} builds=${b.builds.join(',')}`);
lines.push('');
lines.push('');
lines.push('电力（power）：');
for (const b of buildings) {
  if (b.power) lines.push(`  ${b.id.padEnd(10)} power=${String(b.power).padStart(6)}${b.powered ? '  Powered=yes' : ''}`);
}
const pw = buildings.filter((b) => b.power);
lines.push(`  → 发电建筑=${pw.filter((b) => b.power > 0).length}  耗电建筑=${pw.filter((b) => b.power < 0).length}  Powered（低电离线）=${buildings.filter((b) => b.powered).length}`);
lines.push('');
lines.push('单位:');
for (const u of units) lines.push(`  ${u.id.padEnd(10)} ${(u.name || '').padEnd(8)} ${u.role.padEnd(8)} built_at=${u.built_at} cost=${u.cost} hp=${u.hp} armor=${u.armor}/${u.ra2_armor} wpn=${u.weapon ? (u.weapon.ra2_warhead || u.weapon.attack_type) + '/' + u.weapon.damage + (u.weapon.ra2_aa ? '/AA' : '') : '-'} pre=${(u.ra2_prereq || []).join('+')}`);
lines.push('');
lines.push('语音（voice）：');
for (const e of [...units, ...buildings]) {
  if (e.voice) lines.push(`  ${e.id.padEnd(10)} ${Object.entries(e.voice).map(([k, v]) => `${k}=${v}`).join(' ')}`);
}
const noArt = [...units, ...buildings].filter((e) => !art[e.id] || !art[e.id].cameo).map((e) => e.id);
lines.push('');
lines.push(`无 cameo 美术: ${noArt.join(', ') || '(无)'}`);
const report = lines.join('\n');
fs.mkdirSync(path.join(cwd, 'ra2pipe', 'out'), { recursive: true });
fs.writeFileSync(path.join(cwd, 'ra2pipe', 'out', 'faction_report.txt'), report, 'utf8');
console.log(report);
