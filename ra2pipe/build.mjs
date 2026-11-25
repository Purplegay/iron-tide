// RA2 -> JSON data pipeline (Step A).
// Reads: extracted/rules.ini, extracted/art.ini, refs/ts-ra2/public/general.csf
// Writes: iron_tide/data/ra2/*.json
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { readIni, listSection, getSec, csv, numOf, boolOf } from './lib/ini.mjs';
import { readCsf } from './lib/csf.mjs';

import { INPUT, PROJECT, CSF } from './paths.mjs';
const RULES = path.join(INPUT, 'rules.ini');
const ART = path.join(INPUT, 'art.ini');
const OUT = path.join(PROJECT, 'data', 'ra2');

// Armor type order used by RA2 `Verses=` (11 slots).
const ARMOR_ORDER = ['none', 'flak', 'plate', 'light', 'medium', 'heavy', 'wood', 'steel', 'concrete', 'special_1', 'special_2'];

const rules = readIni(RULES);
const art = readIni(ART);
const csf = readCsf(CSF);

// ---- localization -------------------------------------------------------
const localization = {};
for (const k of csf.order) {
  const v = csf.map.get(k);
  if (v != null && v !== '') localization[k] = v;
}
function loc(label) {
  if (!label) return null;
  return csf.map.get(String(label).toUpperCase()) || null;
}
function nameOf(section) {
  const uiname = section.keys.get('uiname'); // e.g. "Name:E1"
  let label = null;
  if (uiname) {
    label = uiname.includes(':') ? uiname.slice(uiname.indexOf(':') + 1) : uiname;
  }
  return { label, display: label ? loc(`Name:${label}`) : null };
}

// ---- 卧倒/展开姿态帧：art.ini 序列 Deployed= ----------------------------
// [<Image>Sequence] 里的 Deployed=<start>,<count>,<per> → 返回首帧号；
// 例：美国大兵 [GISequence] Deployed=292,1,1 → 292（引擎按 _deploy_frame + 朝向取帧）。
// 回归备忘：这几项曾被一次性脚本 p7_deploy.mjs 直接补进 JSON，全量重产时丢失，
// 导致「美国大兵能部署但没有卧倒姿态」。现在按事实源 art.ini 数据化重算。
function deployedFrameOf(seqName) {
  if (!seqName) return -1;
  const seq = getSec(art, seqName);
  if (!seq) return -1;
  const v = seq.keys.get('deployed');
  if (!v) return -1;
  const n = parseInt(String(v).trim().split(',')[0], 10);
  return Number.isFinite(n) ? n : -1;
}

// ---- faction / country mapping -----------------------------------------
const sides = getSec(rules, 'Sides');
const sideMap = { allied: [], soviet: [], civilian: [], mutant: [] };
if (sides) {
  for (const k of sides.keyOrder) {
    const v = sides.keys.get(k.toLowerCase());
    const list = csv(v);
    const lk = k.toLowerCase();
    if (lk === 'gdi') sideMap.allied.push(...list);
    else if (lk === 'nod') sideMap.soviet.push(...list);
    else if (lk === 'civilian') sideMap.civilian.push(...list);
    else if (lk === 'mutant') sideMap.mutant.push(...list);
  }
}
const alliedSet = new Set(sideMap.allied.map((s) => s.toLowerCase()));
const sovietSet = new Set(sideMap.soviet.map((s) => s.toLowerCase()));
function sidesOfOwners(owners) {
  const out = [];
  for (const o of owners) {
    const lo = o.toLowerCase();
    if (alliedSet.has(lo) && !out.includes('allied')) out.push('allied');
    if (sovietSet.has(lo) && !out.includes('soviet')) out.push('soviet');
  }
  return out;
}

const countries = getSec(rules, 'Countries');
const countryList = [];
if (countries) {
  for (const k of countries.keyOrder) {
    const id = countries.keys.get(k.toLowerCase());
    const side = alliedSet.has(id.toLowerCase()) ? 'allied' : sovietSet.has(id.toLowerCase()) ? 'soviet' : 'other';
    countryList.push({ id, side, display: loc(`Name:${id}`) });
  }
}

// ---- helpers ------------------------------------------------------------
function artOf(section, id) {
  const img = section.keys.get('image') || id; // art sections are keyed by Image, else by id
  const a = art.get(String(img).toLowerCase()) || null;
  return { img, art: a };
}
function pickExtra(section, curated) {
  const extra = {};
  const set = new Set(curated.map((c) => c.toLowerCase()));
  for (const k of section.keyOrder) {
    if (set.has(k.toLowerCase())) continue;
    extra[k] = section.keys.get(k.toLowerCase());
  }
  return extra;
}

const CURATED_TECHNO = [
  'uiname', 'name', 'image', 'category', 'primary', 'secondary', 'eliteprimary', 'elitesecondary',
  'strength', 'armor', 'speed', 'sight', 'cost', 'techlevel', 'points', 'prerequisite', 'owner',
  'soylent', 'threatposed', 'size', 'physicalsize', 'movementzone', 'locomotor', 'turret', 'crusher',
  'deployer', 'occupier', 'isselectablecombatant', 'buildcat', 'factory', 'power', 'adjacent',
  'capturable', 'crewed', 'aibaseplanningside', 'requiresstolenalliedtechlevel', 'requiresstolensoviettechlevel',
  'prismtype',
];

function baseEntity(id, section, kind) {
  const { label, display } = nameOf(section);
  const { img, art: a } = artOf(section, id);
  const owners = csv(section.keys.get('owner'));
  const o = {};
  o.id = id;
  o.kind = kind;
  o.rules_name = section.keys.get('name') || null;
  o.uiname_label = label;
  o.display_name = display || section.keys.get('name') || id;
  o.image = img || id;
  o.category = section.keys.get('category') || null;
  o.hp = numOf(section.keys.get('strength'));
  o.armor = (section.keys.get('armor') || '').toLowerCase() || null;
  o.speed = numOf(section.keys.get('speed'));
  o.sight = numOf(section.keys.get('sight'));
  o.cost = numOf(section.keys.get('cost'));
  o.tech_level = numOf(section.keys.get('techlevel'), -1);
  o.points = numOf(section.keys.get('points'));
  o.prerequisites = csv(section.keys.get('prerequisite'));
  o.owner = owners;
  o.sides = sidesOfOwners(owners);
  if (a) {
    o.cameo = a.keys.get('cameo') || null;
    o.alt_cameo = a.keys.get('altcameo') || null;
    o.voxel = boolOf(a.keys.get('voxel'), false);
    o.sequence = a.keys.get('sequence') || null;
    o.foundation = a.keys.get('foundation') || null;
    o.buildup = a.keys.get('buildup') || null;
  } else {
    o.cameo = null;
  }
  return o;
}

function technoEntity(id, section, kind) {
  const o = baseEntity(id, section, kind);
  // RA2 units may declare weapons via Primary=/Secondary= OR via Weapon1..N (e.g. the
  // Prism Tank [SREF] has its Primary commented out and uses Weapon1=Comet + WeaponCount=1).
  o.primary = section.keys.get('primary') || section.keys.get('weapon1') || null;
  o.secondary = section.keys.get('secondary') || section.keys.get('weapon2') || null;
  o.elite_primary = section.keys.get('eliteprimary') || section.keys.get('eliteweapon1') || null;
  o.elite_secondary = section.keys.get('elitesecondary') || section.keys.get('eliteweapon2') || null;
  o.weapon_count = numOf(section.keys.get('weaponcount'), 0);
  o.soylent = numOf(section.keys.get('soylent'));
  o.threat_posed = numOf(section.keys.get('threatposed'));
  o.size = numOf(section.keys.get('size'));
  o.physical_size = numOf(section.keys.get('physicalsize'));
  o.movement_zone = section.keys.get('movementzone') || null;
  o.locomotor = section.keys.get('locomotor') || null;
  o.turret = boolOf(section.keys.get('turret'), false);
  o.crusher = boolOf(section.keys.get('crusher'), false);
  o.deployer = boolOf(section.keys.get('deployer'), false);
  // 卧倒/展开姿态首帧：art.ini [<Image>Sequence] Deployed=<start>,<count>,<per>（见 deployedFrameOf）
  o.deploy_frame = deployedFrameOf(o.sequence);
  o.occupier = boolOf(section.keys.get('occupier'), false) || section.keys.has('occupier');
  o.extra = pickExtra(section, CURATED_TECHNO);
  return o;
}

// ---- units --------------------------------------------------------------
const infantryIds = listSection(rules, 'InfantryTypes').map((x) => x.id);
const vehicleIds = listSection(rules, 'VehicleTypes').map((x) => x.id);
const aircraftIds = listSection(rules, 'AircraftTypes').map((x) => x.id);
const buildingIds = listSection(rules, 'BuildingTypes').map((x) => x.id);

const infantry = {};
const vehicles = {};
const aircraft = {};
const buildings = {};

for (const id of infantryIds) {
  const s = getSec(rules, id);
  if (!s) continue;
  infantry[id] = technoEntity(id, s, 'infantry');
}
for (const id of vehicleIds) {
  const s = getSec(rules, id);
  if (!s) continue;
  vehicles[id] = technoEntity(id, s, 'vehicle');
}
for (const id of aircraftIds) {
  const s = getSec(rules, id);
  if (!s) continue;
  aircraft[id] = technoEntity(id, s, 'aircraft');
}
for (const id of buildingIds) {
  const s = getSec(rules, id);
  if (!s) continue;
  const o = baseEntity(id, s, 'building');
  // defensive structures carry Primary=/Secondary= in rules.ini (Pillbox=Vulcan2, Prism Tower=PrismShot, ...)
  o.primary = s.keys.get('primary') || s.keys.get('weapon1') || null;
  o.secondary = s.keys.get('secondary') || s.keys.get('weapon2') || null;
  o.elite_primary = s.keys.get('eliteprimary') || null;
  o.elite_secondary = s.keys.get('elitesecondary') || null;
  o.weapon_count = numOf(s.keys.get('weaponcount'), 0);
  o.build_cat = s.keys.get('buildcat') || null;
  o.factory = s.keys.get('factory') || null;
  o.power = numOf(s.keys.get('power'));
  // RA2 Powered=yes：低电时该建筑离线（防御塔停火 / 经济建筑停摆）。
  o.powered = boolOf(s.keys.get('powered'), false);
  o.adjacent = numOf(s.keys.get('adjacent'));
  o.capturable = boolOf(s.keys.get('capturable'), false);
  o.crewed = boolOf(s.keys.get('crewed'), false);
  o.ai_base_planning_side = numOf(s.keys.get('aibaseplanningside'), -1);
  o.extra = pickExtra(s, CURATED_TECHNO);
  buildings[id] = o;
}

// ---- weapons ------------------------------------------------------------
const weaponIds = new Set();
for (const bundle of [infantry, vehicles, aircraft, buildings]) {
  for (const o of Object.values(bundle)) {
    for (const f of ['primary', 'secondary', 'elite_primary', 'elite_secondary']) {
      if (o[f]) weaponIds.add(o[f]);
    }
  }
}
// also pull every section that looks like a weapon (referenced ones only + a global sweep
// around the weapon block: sections having Damage= & ROF= & Range=)
const weapons = {};
const weaponSections = new Set([...weaponIds].map((w) => w.toLowerCase()));
for (const [k, s] of rules) {
  if (s.keys.has('damage') && s.keys.has('rof') && s.keys.has('range') && !s.keyOrder.includes('strength')) {
    weaponSections.add(k);
  }
}
for (const key of weaponSections) {
  const s = rules.get(key);
  if (!s) continue;
  const o = {};
  o.id = s.name;
  o.damage = numOf(s.keys.get('damage'));
  o.rof = numOf(s.keys.get('rof'));
  o.range = numOf(s.keys.get('range'));
  o.projectile = s.keys.get('projectile') || null;
  o.speed = numOf(s.keys.get('speed'));
  o.warhead = s.keys.get('warhead') || null;
  o.burst = numOf(s.keys.get('burst'), 1);
  o.anim = s.keys.get('anim') || null;
  o.report = s.keys.get('report') || null;
  o.bright = boolOf(s.keys.get('bright'), false);
  o.min_range = numOf(s.keys.get('minimumrange'));
  o.ambient_damage = numOf(s.keys.get('ambientdamage'));
  o.extra = pickExtra(s, ['damage', 'rof', 'range', 'projectile', 'speed', 'warhead', 'burst', 'anim', 'report', 'bright', 'minimumrange', 'ambientdamage']);
  weapons[s.name] = o;
}

// ---- warheads -----------------------------------------------------------
const warheadIds = listSection(rules, 'Warheads').map((x) => x.id);
const warheadSet = new Set(warheadIds.map((w) => w.toLowerCase()));
for (const w of Object.values(weapons)) if (w.warhead) warheadSet.add(w.warhead.toLowerCase());
const warheads = {};
for (const key of warheadSet) {
  const s = rules.get(key);
  if (!s) continue;
  const raw = s.keys.get('verses') || '';
  const parts = csv(raw);
  const verses = {};
  // RA2 semantics: missing trailing slots default to 100% (ModEnc).
  for (let i = 0; i < ARMOR_ORDER.length; i++) {
    verses[ARMOR_ORDER[i]] = i < parts.length ? numOf(parts[i], 1) : 1;
  }
  const o = {};
  o.id = s.name;
  o.verses_raw = raw;
  o.verses = verses;
  o.cell_spread = numOf(s.keys.get('cellspread'));
  o.percent_at_max = numOf(s.keys.get('percentatmax'));
  o.prone_damage = numOf(s.keys.get('pronedamage'));
  o.inf_death = numOf(s.keys.get('infdeath'));
  o.wall = boolOf(s.keys.get('wall'), false);
  o.wood = boolOf(s.keys.get('wood'), false);
  o.anim_list = csv(s.keys.get('animlist'));
  o.extra = pickExtra(s, ['verses', 'cellspread', 'percentatmax', 'pronedamage', 'infdeath', 'wall', 'wood', 'animlist']);
  warheads[s.name] = o;
}

// ---- projectiles --------------------------------------------------------
// Projectile sections hold the AA= flag that decides whether a weapon can target aircraft
// (RA2 has no 'air' armor class; anti-air is a projectile property, not a warhead one).
const projectileIds = new Set();
for (const w of Object.values(weapons)) if (w.projectile) projectileIds.add(w.projectile);
const projectiles = {};
for (const pid of projectileIds) {
  const s = rules.get(String(pid).toLowerCase());
  if (!s) continue;
  const aaRaw = s.keys.get('aa') || null;
  projectiles[s.name] = {
    id: s.name,
    aa: boolOf(aaRaw, false),
    aa_raw: aaRaw,
    image: s.keys.get('image') || null,
    inviso: boolOf(s.keys.get('inviso'), false),
    arcing: boolOf(s.keys.get('arcing'), false),
    dropping: boolOf(s.keys.get('dropping'), false),
    rot: numOf(s.keys.get('rot')),
    shadow: boolOf(s.keys.get('shadow'), false),
    proximity: boolOf(s.keys.get('proximity'), false),
    vertical: boolOf(s.keys.get('vertical'), false),
    extra: pickExtra(s, ['aa', 'image', 'inviso', 'arcing', 'dropping', 'rot', 'shadow', 'proximity', 'vertical']),
  };
}

// ---- tech tree ----------------------------------------------------------
const techTree = {};
function addTech(bundle, kind) {
  for (const [id, o] of Object.entries(bundle)) {
    techTree[id] = {
      kind,
      cost: o.cost,
      tech_level: o.tech_level,
      prerequisites: o.prerequisites,
      owner: o.owner,
      sides: o.sides,
      build_cat: o.build_cat || null,
      factory: o.factory || null,
      requires: o.prerequisites,
      image: o.image,
      cameo: o.cameo || null,
    };
  }
}
addTech(infantry, 'infantry');
addTech(vehicles, 'vehicle');
addTech(aircraft, 'aircraft');
addTech(buildings, 'building');

// ---- rosters per side ---------------------------------------------------
function rosterFor(side) {
  const pick = (bundle) => Object.values(bundle).filter((o) => o.sides.includes(side) && (o.tech_level == null || o.tech_level >= 0)).map((o) => o.id);
  return {
    infantry: pick(infantry),
    vehicles: pick(vehicles),
    aircraft: pick(aircraft),
    buildings: pick(buildings),
  };
}

const factions = {
  sides: { allied: sideMap.allied, soviet: sideMap.soviet, civilian: sideMap.civilian, mutant: sideMap.mutant },
  countries: countryList,
  rosters: { allied: rosterFor('allied'), soviet: rosterFor('soviet') },
};

// ---- animations (art.ini) -----------------------------------------------
// Weapon `Anim=` (muzzle flash, up to 8 entries indexed by facing) and
// Warhead `AnimList=` (impact animations) name animation SHP images. Pull
// their art.ini params so the runtime can play them at the real rate.
// Rate model (RA2 tick): fps = Rate / 60, default Rate = 900 -> 15 fps.
const DEFAULT_ANIM_RATE = 900;
const numOr = (v, def) => { const n = parseInt(v, 10); return Number.isFinite(n) ? n : def; };
const boolOr = (v, def = false) => {
  if (v === null || v === undefined) return def;
  const s = String(v).trim().toLowerCase();
  return s === 'yes' || s === 'true' || s === '1';
};
const asList = (v) => (Array.isArray(v) ? v : csv(v));
const animNames = new Set();
for (const w of Object.values(weapons)) for (const n of asList(w.anim)) animNames.add(n);
for (const wh of Object.values(warheads)) for (const n of asList(wh.anim_list)) animNames.add(n);
// 超级武器表现动画不由武器/弹头引用，按 RA2 art.ini 原节名显式补入：
// 天气控制器闪电（WCLBOLT1-3）与超时空传送（CHRONOAR/CHRONOFD/CHRONOTG）。
for (const n of ['WCLBOLT1', 'WCLBOLT2', 'WCLBOLT3', 'WCLCLOUD1', 'WCLCLOUD2', 'WCLCLOUD3',
                 'CHRONOAR', 'CHRONOFD', 'CHRONOTG']) animNames.add(n);
const animations = {};
for (const id of [...animNames].map((s) => String(s).trim()).filter((s) => /^[A-Za-z0-9_-]+$/.test(s)).sort()) {
  const a = art.get(id.toLowerCase());
  const g = (k) => (a ? (a.keys.get(k) || null) : null);
  const rateRaw = g('rate');
  const rate = rateRaw === null ? DEFAULT_ANIM_RATE : numOr(rateRaw, DEFAULT_ANIM_RATE);
  animations[id] = {
    id,
    image: g('image') || id,
    rate,
    fps: Math.round((rate / 60) * 1000) / 1000,
    loop_start: numOr(g('loopstart'), -1),
    loop_end: numOr(g('loopend'), -1),
    next: g('next'),
    shadow: boolOr(g('shadow')),
    translucent: boolOr(g('translucent')),
    custom_palette: g('custompalette'),
    // RA2 动画音效事实源：优先 art.ini StartSound=，其次 Report=
    // （爆炸类动画如 EXPLOSML/EXPLOLRG 只用 Report=Explosion13/Explosion09）。
    start_sound: g('startsound') || g('report'),
    report: g('report'),
    in_art_ini: !!a,
  };
}

// ---- write --------------------------------------------------------------
fs.mkdirSync(OUT, { recursive: true });
function writeJson(name, obj) {
  const p = path.join(OUT, name);
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
  return p;
}
function sha(p) {
  return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').slice(0, 16);
}

writeJson('localization.json', { version: 1, language: csf.language, labels: localization });
writeJson('units.json', {
  version: 1,
  source: 'RA2 rules.ini + art.ini + general.csf',
  armor_order: ARMOR_ORDER,
  counts: { infantry: Object.keys(infantry).length, vehicles: Object.keys(vehicles).length, aircraft: Object.keys(aircraft).length },
  infantry, vehicles, aircraft,
});
writeJson('buildings.json', { version: 1, armor_order: ARMOR_ORDER, count: Object.keys(buildings).length, buildings });
writeJson('weapons.json', { version: 1, count: Object.keys(weapons).length, weapons });
writeJson('warheads.json', { version: 1, armor_order: ARMOR_ORDER, count: Object.keys(warheads).length, warheads });
writeJson('projectiles.json', { version: 1, count: Object.keys(projectiles).length, projectiles });
writeJson('animations.json', {
  version: 1,
  source: 'RA2 art.ini (+ rules.ini Anim=/AnimList= references)',
  defaults: { rate: DEFAULT_ANIM_RATE, fps: DEFAULT_ANIM_RATE / 60 },
  count: Object.keys(animations).length,
  animations,
});
writeJson('factions.json', factions);
writeJson('tech_tree.json', { version: 1, count: Object.keys(techTree).length, entities: techTree });

// ---- [General] 全局规则（老兵倍率等）-----------------------------------
// rules.ini [General] 里的全局倍率：老兵升级比例 / 伤害 / 速度 / 护甲 / 射速 / 上限。
// 运行时 Ra2Damage / unit.gd 用它结算老兵加成，避免把 3.0/1.1/1.2/1.5/0.6/2 硬编码。
const gen = getSec(rules, 'General');
const gget = (k, d) => {
  const v = gen ? gen.keys.get(k.toLowerCase()) : null;
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : d;
};
const general = {
  version: 1,
  source: 'RA2 rules.ini [General]',
  aircraft: { reload_minutes: gget('reloadrate', 0.3) },
  repair: {
    step: gget('repairstep', 8),
    rate_minutes: gget('repairrate', 0.016),
    percent: (() => {
      const raw = gen ? gen.keys.get('repairpercent') : null;
      const n = parseFloat(raw);
      return Number.isFinite(n) ? n / 100 : 0.15;
    })(),
  },
  veteran: {
    ratio: gget('veteranratio', 3.0),     // 升级所需击杀价值 = 自身价值 × ratio（每级）
    combat: gget('veterancombat', 1.1),   // FIREPOWER 伤害倍率
    speed: gget('veteranspeed', 1.2),     // FASTER 速度倍率
    sight: gget('veteransight', 0.0),     // SIGHT 视野倍率（原版 0.0，防崩溃）
    armor: gget('veteranarmor', 1.5),     // STRONGER 生命倍率
    rof: gget('veteranrof', 0.6),         // ROF 冷却倍率（<1 = 更快）
    cap: Math.round(gget('veterancap', 2)), // 最高等级（2 = Elite）
  },
  // 棱镜支援链（rules.ini [General] 行 133-138）：一族 PrismType= 建筑（光棱塔）互相充能。
  // 每座友方棱镜的支援光束给开火方增加 modifier 伤害，最多 max 座，支援后 offline delay 帧。
  prism: {
    type: (gen ? gen.keys.get('prismtype') : null) || 'ATESLA',  // PrismType=；in building code，识别棱镜建筑
    modifier: (() => {                                          // PrismSupportModifier=150%（百分比）
      const raw = gen ? gen.keys.get('prismsupportmodifier') : null;
      const n = parseFloat(raw);
      return Number.isFinite(n) ? n / 100.0 : 1.5;
    })(),
    max: Math.round(gget('prismsupportmax', 8)),      // PrismSupportMax：每座棱镜最多被几束支援
    delay: gget('prismsupportdelay', 60),             // PrismSupportDelay：支援后自身离线帧数
    duration: gget('prismsupportduration', 15),       // PrismSupportDuration：支援光束可见帧数
    height: gget('prismsupportheight', 420),          // PrismSupportHeight：瞄准点抬高 leptons
  },
  // 建造规则（rules.ini [General] 25/37/38/279/300/330）
  build: {
    build_speed: gget('buildspeed', 0.7),             // 分钟 / 1000 credits
    buildup_time_minutes: gget('builduptime', 0.06),  // 建筑放置后 buildup 动画均值
    refund_percent: (() => {                          // RefundPercent=50%
      const raw = gen ? gen.keys.get('refundpercent') : null;
      const n = parseFloat(String(raw).replace('%', ''));
      return Number.isFinite(n) ? n / 100.0 : 0.5;
    })(),
    multiple_factory: gget('multiplefactory', 0.8),   // 多工厂累计折扣
    wall_build_speed: gget('wallbuildspeedcoefficient', 3.0), // 时间倍率（越大越慢）
    base_unit: (gen ? gen.keys.get('baseunit') : null) || 'AMCV,SMCV',
  },
};
writeJson('general.json', general);

// ---- 超级武器（rules.ini [SuperWeaponTypes] + *Special 节）----------------
// 建筑节只保存 SuperWeapon=<节名>；RechargeTime 单位为分钟，这里统一换算成秒。
// 天气控制器的时间参数位于 [AudioVisual]（LightningDeferment 等），一并提取。
const swList = listSection(rules, 'SuperWeaponTypes');
const avSec = getSec(rules, 'AudioVisual');
const genSec = getSec(rules, 'General');
const numAny = (k, d) => {
  for (const s of [genSec, avSec]) {
    if (!s) continue;
    const v = parseFloat(s.keys.get(k.toLowerCase()));
    if (Number.isFinite(v)) return v;
  }
  return d;
};
const avStr = (k, d) => (avSec && avSec.keys.has(k.toLowerCase()) ? avSec.keys.get(k.toLowerCase()) : d);
const superweapons = {};
for (const item of swList) {
  const sec = getSec(rules, item.id);
  if (!sec) continue;
  const kv = (k, d = null) => (sec.keys.has(k.toLowerCase()) ? sec.keys.get(k.toLowerCase()) : d);
  const num = (k, d = 0) => {
    const n = parseFloat(kv(k));
    return Number.isFinite(n) ? n : d;
  };
  const entry = {
    id: item.id,
    type: kv('type', item.id),
    name: kv('name', item.id),
    ui_name: loc(kv('uiname')),
    action: kv('action'),
    sidebar_image: kv('sidebarimage'),
    pre_click: kv('preclick'),
    recharge_voice: kv('rechargevoice'),
    recharge_seconds: num('rechargetime', 0) * 60.0,
    is_powered: boolOf(kv('ispowered'), true),
    show_timer: boolOf(kv('showtimer'), true),
  };
  if (String(entry.type).toLowerCase() === 'lightningstorm') {
    entry.storm = {
      deferment_frames: numAny('lightningdeferment', 250),
      duration_frames: numAny('lightningduration', 180),
      damage: numAny('lightningdamage', 250),
      warhead: avStr('lightningwarhead', 'IonWH'),
      hit_delay_frames: numAny('lightninghitdelay', 10),
      scatter_delay_frames: numAny('lightningscatterdelay', 5),
      cell_spread: numAny('lightningcellspread', 10),
      separation: numAny('lightningseparation', 3),
      bolts: String(avStr('weatherconbolts', 'WCLBOLT1,WCLBOLT2,WCLBOLT3')).split(',').map(s => s.trim()).filter(Boolean),
      clouds: String(avStr('weatherconclouds', '')).split(',').map(s => s.trim()).filter(Boolean),
      bolt_explosion: avStr('weatherconboltExplosion', 'EXPLOLB'),
      start_sound: avStr('stormsound', 'WeatherIntro'),
      strike_sound: avStr('lightningsounds', 'WeatherStrike'),
    };
  }
  superweapons[item.id] = entry;
}
writeJson('superweapons.json', { version: 1, source: 'RA2 rules.ini [SuperWeaponTypes]', weapons: superweapons });

// ids declared in a type-list but with no rules section (RA2 has a few)
const declaredAll = {
  infantry: infantryIds, vehicles: vehicleIds, aircraft: aircraftIds, buildings: buildingIds,
};
const unresolved = {};
for (const [kind, ids] of Object.entries(declaredAll)) {
  const miss = ids.filter((id) => !getSec(rules, id));
  if (miss.length) unresolved[kind] = miss;
}

const meta = {
  version: 1,
  generated_at: new Date().toISOString(),
  unresolved,
  sources: {
    rules_ini: { size: fs.statSync(RULES).size, sha256_16: sha(RULES) },
    art_ini: { size: fs.statSync(ART).size, sha256_16: sha(ART) },
    general_csf: { size: fs.statSync(CSF).size, sha256_16: sha(CSF) },
  },
  counts: {
    infantry: Object.keys(infantry).length,
    vehicles: Object.keys(vehicles).length,
    aircraft: Object.keys(aircraft).length,
    buildings: Object.keys(buildings).length,
    weapons: Object.keys(weapons).length,
    warheads: Object.keys(warheads).length,
    projectiles: Object.keys(projectiles).length,
    superweapons: Object.keys(superweapons).length,
    tech_tree: Object.keys(techTree).length,
    localization_labels: Object.keys(localization).length,
    countries: countryList.length,
  },
  armor_order: ARMOR_ORDER,
};
writeJson('meta.json', meta);
await import('./economy.mjs');

const totalBytes = fs.readdirSync(OUT).reduce((a, f) => a + fs.statSync(path.join(OUT, f)).size, 0);
console.log('WROTE', OUT);
console.log('COUNTS', JSON.stringify(meta.counts));
console.log('TOTAL_BYTES', totalBytes);
console.log('FILES', fs.readdirSync(OUT).join(', '));
