import fs from 'node:fs';
import path from 'node:path';
import { PROJECT } from '../ra2pipe/paths.mjs';

const missing = [];
let imports = 0;
function scan(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) scan(file);
    else if (file.endsWith('.import')) {
      imports++;
      if (!fs.existsSync(file.slice(0, -7))) missing.push(path.relative(PROJECT, file.slice(0, -7)));
    }
  }
}
scan(path.join(PROJECT, 'assets'));
const read = name => JSON.parse(fs.readFileSync(path.join(PROJECT, 'data', name), 'utf8'));
const base = read('units.json');
const ra2 = read('ra2_allied.json');
const exists = resource => !!resource && resource.startsWith('res://') &&
  fs.existsSync(path.join(PROJECT, resource.slice(6)));
const entities = [];
for (const type of ['units', 'buildings']) {
  // Same merge order as GameData._load_ra2_allied; keep legacy/extension entries explicit.
  const index = new Map([...base[type], ...ra2[type]].map(entity => [entity.id, entity]));
  for (const [id, entity] of index) {
    const candidates = ['vxl', 'shp'].map(kind => `res://assets/ra2/${kind}/${id}.png`);
    const sprite = candidates.find(exists) || '';
    const declaredSprite = ra2.art[id]?.vxl || ra2.art[id]?.shp || '';
    const cameo = ra2.art[id]?.cameo || '';
    const buildup = entity.buildup ? `res://assets/ra2/shp/${entity.buildup.toUpperCase()}.png` : '';
    entities.push({
      id, name: entity.name, type, faction: entity.faction,
      scope: ra2[type].some(row => row.id === id) ? 'ra2_catalog' : 'legacy_or_extension',
      sprite: { path: sprite, declared_path: declaredSprite,
        status: sprite ? 'present' : declaredSprite ? 'missing_file' : 'procedural_fallback',
        metadata: sprite ? exists(sprite.replace(/\.png$/, '.json')) : false },
      cameo: { path: cameo, status: exists(cameo) ? 'present' : cameo ? 'missing_file' : 'procedural_fallback' },
      buildup: { path: buildup, status: exists(buildup) ? 'present' : buildup ? 'missing_file' : 'not_configured' }
    });
  }
}
// Building layers can have metadata without a PNG or .import, so the import scan
// alone cannot detect missing doors, roof layers or damaged variants.
const animationReferences = [];
for (const entity of entities.filter(row => row.type === 'buildings')) {
  const descriptor = path.join(PROJECT, 'assets', 'ra2', 'bldanim', `${entity.id}.json`);
  if (!fs.existsSync(descriptor)) continue;
  for (const layer of JSON.parse(fs.readFileSync(descriptor, 'utf8')).layers || []) {
    for (const image of new Set([layer.image, layer.dmg?.image].filter(Boolean))) {
      const resource = `res://assets/ra2/shp/${image}.png`;
      animationReferences.push({ building: entity.id, kind: layer.kind, image, path: resource,
        status: exists(resource) ? 'present' : 'missing_file' });
    }
  }
}
const missingAnimations = animationReferences.filter(row => row.status === 'missing_file');
// Unit bodies can load while their independent turret or shadow is absent.
const unitLayers = [];
for (const entity of entities.filter(row => row.type === 'units' && row.sprite.path.includes('/vxl/'))) {
  const metadata = JSON.parse(fs.readFileSync(path.join(PROJECT, entity.sprite.path.slice(6).replace(/\.png$/, '.json')), 'utf8'));
  for (const [kind, id] of [['shadow', entity.id + '_shd'], ['turret', metadata.turret]]) {
    if (!id) continue;
    const resource = `res://assets/ra2/vxl/${id}.png`;
    unitLayers.push({ unit: entity.id, kind, path: resource,
      status: exists(resource) ? 'present' : kind === 'shadow' ? 'procedural_fallback' : 'missing_file' });
  }
}
const buildingTurrets = ['GTGCAN', 'NASAM'].map(id => {
  const descriptor = `res://assets/ra2/bldturret/${id}.json`;
  const data = exists(descriptor) ? JSON.parse(fs.readFileSync(path.join(PROJECT, descriptor.slice(6)), 'utf8')) : {};
  const image = data.image ? `res://assets/ra2/vxl/${data.image}.png` : '';
  const metadata = image.replace(/\.png$/, '.json');
  return { building: id, descriptor, image, metadata,
    status: exists(descriptor) && exists(image) && exists(metadata) ? 'present' : 'missing_file' };
});
const buildingFoundations = ['GAWEAP', 'GAREFN', 'GADEPT', 'GAAIRC'].map(id => {
  const resource = `res://assets/ra2/shp/${id}.json`;
  const data = exists(resource) ? JSON.parse(fs.readFileSync(path.join(PROJECT, resource.slice(6)), 'utf8')) : {};
  return { building: id, bib: data.bib, source: data.bib_source,
    added_pixels: data.bib_added_pixels,
    status: data.bib === id + 'BB' && data.bib_added_pixels?.length === 6 &&
      data.bib_added_pixels.slice(0, 3).every(count => count > 0) &&
      exists(resource.replace(/\.json$/, '.png')) ? 'present' : 'missing_composition' };
});
const summary = {
  entities: entities.length,
  sprite_fallback: entities.filter(row => row.sprite.status !== 'present').length,
  cameo_fallback: entities.filter(row => row.cameo.status !== 'present').length,
  broken_references: entities.filter(row => row.sprite.status === 'missing_file' ||
    (row.sprite.declared_path && !exists(row.sprite.declared_path)) ||
    row.cameo.status === 'missing_file' || row.buildup.status === 'missing_file').length,
  animation_references: animationReferences.length,
  missing_animation_files: new Set(missingAnimations.map(row => row.path)).size,
  missing_unit_turrets: unitLayers.filter(row => row.kind === 'turret' && row.status === 'missing_file').length,
  unit_shadow_fallback: unitLayers.filter(row => row.kind === 'shadow' && row.status !== 'present').length,
  missing_building_turrets: buildingTurrets.filter(row => row.status !== 'present').length,
  missing_building_foundations: buildingFoundations.filter(row => row.status !== 'present').length
};
const report = { project: PROJECT, imports, missing, summary, entities, animationReferences, unitLayers, buildingTurrets, buildingFoundations };
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i += 2) {
  if (!['--output', '--markdown'].includes(args[i]) || !args[i + 1]) {
    throw new Error('Usage: node tools/check-assets.mjs [--output report.json] [--markdown inventory.md]');
  }
  const destination = path.resolve(args[i + 1]);
  const clean = value => String(value ?? '').replaceAll('|', '\\|').replaceAll('\n', ' ');
  const state = item => item.status === 'present' ? '有' : item.status === 'missing_file' ? '引用文件缺失' :
    item.status === 'not_configured' ? '未配置' : '占位';
  const markdown = [
    '# 美术资源盘点', '',
    '由 `node tools/check-assets.mjs --markdown docs/ASSET_INVENTORY.md` 生成。',
    '按实际 GameData 数据合并顺序枚举；“目录”不代表所有条目均已解锁或可生产。',
    '“占位”表示没有按运行时 ID 接入专用素材，继续使用现有程序化外观；不自动借用其他单位素材。',
    '文件存在检查不代替 Godot 导入、渲染或使用者视觉确认。精确资源路径见同工具的 `--output` JSON。',
    '', `共 ${summary.entities} 个条目；主体占位 ${summary.sprite_fallback}，图标占位 ${summary.cameo_fallback}，主体/图标/展开引用文件缺失 ${summary.broken_references}。`,
    `现有 ${imports} 个导入描述对应的原文件缺失 ${missing.length} 个。`, '',
    `另核对 ${summary.animation_references} 个建筑叠层引用（含损伤变体），缺失 ${summary.missing_animation_files} 张图片。`,
    ...missingAnimations.map(row => `- ${clean(row.building)} / ${clean(row.kind)}：${clean(row.path)}`), '',
    `载具独立炮塔缺失 ${summary.missing_unit_turrets} 张；${summary.unit_shadow_fallback} 个载具仍使用程序化阴影。`,
    ...unitLayers.filter(row => row.status !== 'present').map(row => `- ${clean(row.unit)} / ${clean(row.kind)}：${clean(row.path)}`), '',
    `巨炮/爱国者独立炮塔组合缺失 ${summary.missing_building_turrets} 项（描述、图集和元数据一并核对）。`, '',
    `战车工厂/矿场/维修厂的 BibShape 底座合成缺失 ${summary.missing_building_foundations} 项；成品主体含底座，放置和点击复用该主体。`, '',
    '| ID | 名称 | 类型 | 范围 | 主体 | 图标 | 建造动画 |', '|---|---|---|---|---|---|---|',
    ...entities.map(row => `| ${[row.id, row.name, row.type === 'units' ? '单位' : '建筑',
      row.scope === 'ra2_catalog' ? 'RA2 目录' : '历史/扩展', state(row.sprite), state(row.cameo), state(row.buildup)].map(clean).join(' | ')} |`),
    ''
  ].join('\n');
  fs.writeFileSync(destination, args[i] === '--output' ? JSON.stringify(report, null, 2) + '\n' : markdown);
}
console.log(JSON.stringify({ project: PROJECT, imports, missing, summary }, null, 2));
process.exitCode = missing.length || summary.broken_references || summary.missing_animation_files ||
  summary.missing_unit_turrets || summary.missing_building_turrets || summary.missing_building_foundations ? 1 : 0;
