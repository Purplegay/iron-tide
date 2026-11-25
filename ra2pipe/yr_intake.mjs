// Stage YR source files and dependency inventory outside the live project.
// This deliberately does not publish production buttons or claim mechanics parity.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseIni, getSec, listSection, csv, boolOf, numOf } from './lib/ini.mjs';
import { YrSource, sha256 } from './lib/yr_source.mjs';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const types = { InfantryTypes: 'infantry', VehicleTypes: 'vehicle', AircraftTypes: 'aircraft' };
const sectionData = section => section ? Object.fromEntries(section.keys) : {};
const inside = (candidate, root) => candidate === root || candidate.startsWith(root + path.sep);

export function inventory(source) {
  const rulesFile = source.read('rulesmd.ini');
  const artFile = source.read('artmd.ini');
  const report = { version: 1, status: 'blocked_missing_yr_inputs', runtime_enabled: false,
    source_directory: source.root, inputs: {}, rules_source: rulesFile?.source || null,
    art_source: artFile?.source || null, blockers: [], units: [],
    limits: ['File presence is not image decoding or animation verification.',
      'No unit mechanics are certified by this inventory.',
      'Loose files override archives; this does not certify an unmodified retail installation.',
      'Only base RA2/YR archives and expandmd01.mix are read; custom mod archives are not loaded.'] };
  if (!rulesFile) report.blockers.push('missing:rulesmd.ini');
  if (!artFile) report.blockers.push('missing:artmd.ini');
  if (!rulesFile || !artFile) { report.inputs = source.audit(); return report; }
  const rulesText = rulesFile.data.toString('latin1');
  const artText = artFile.data.toString('latin1');
  const rules = parseIni(rulesText), art = parseIni(artText);
  if (/^\s*(?:\[\s*#?include\s*\]|\$include|#include)/im.test(rulesText + '\n' + artText)) {
    report.blockers.push('unsupported:INI includes must be flattened first');
  }
  // Catch a vanilla rules.ini renamed rulesmd.ini; never infer YR from voice files.
  const ids = new Set(Object.keys(types).flatMap(type => listSection(rules, type).map(item => item.id.toUpperCase())));
  if (!['GGI', 'INIT', 'YTNK'].every(id => ids.has(id))) report.blockers.push('not_verified_yr:missing GGI/INIT/YTNK roster');
  for (const [list, kind] of Object.entries(types)) {
    for (const { id } of listSection(rules, list)) {
      const raw = sectionData(getSec(rules, id));
      const image = raw.image || id;
      const graphics = sectionData(getSec(art, image));
      const shape = graphics.image || image;
      const missing = [];
      if (!Object.keys(raw).length) missing.push(`rules_section:${id}`);
      if (!Object.keys(graphics).length) missing.push(`art_section:${image}`);
      const resources = {};
      const inspect = (name, required = true) => {
        const result = source.read(name);
        resources[name] = result ? { source: result.source, bytes: result.data.length, sha256: sha256(result.data) } : null;
        if (required && (!result || result.data.length === 0)) missing.push(`resource:${name}`);
      };
      const voxel = boolOf(graphics.voxel);
      inspect(`${shape}.${voxel ? 'vxl' : 'shp'}`);
      if (voxel) inspect(`${shape}.hva`);
      if (voxel && boolOf(raw.turret)) {
        // These can be integrated into the main voxel; record without inventing a hard requirement.
        for (const part of ['tur', 'barl']) for (const ext of ['vxl', 'hva']) inspect(`${shape}${part}.${ext}`, false);
      }
      if (graphics.cameo) inspect(graphics.cameo.toLowerCase().endsWith('.shp') ? graphics.cameo : `${graphics.cameo}.shp`);
      else missing.push('art:Cameo');
      if (graphics.sequence && !getSec(art, graphics.sequence)) missing.push(`sequence:${graphics.sequence}`);
      const weapons = {};
      const weaponNames = new Set(Object.entries(raw).filter(([key]) => /^(?:elite)?(?:primary|secondary|weapon\d+)$/.test(key)).map(([, value]) => value));
      for (const name of weaponNames) {
        const weapon = sectionData(getSec(rules, name));
        weapons[name] = weapon;
        if (!Object.keys(weapon).length) missing.push(`weapon:${name}`);
        for (const key of ['warhead', 'projectile']) {
          if (weapon[key] && !getSec(rules, weapon[key])) missing.push(`${key}:${weapon[key]}`);
        }
      }
      const prerequisites = csv(raw.prerequisite).map(name => ({ id: name,
        alternatives: csv(getSec(rules, 'General')?.keys.get(`prerequisite${name.toLowerCase()}`)),
        raw: sectionData(getSec(rules, name)) }));
      for (const prerequisite of prerequisites) {
        if (!prerequisite.alternatives.length && !Object.keys(prerequisite.raw).length) missing.push(`prerequisite:${prerequisite.id}`);
        for (const alternative of prerequisite.alternatives) if (!getSec(rules, alternative)) missing.push(`prerequisite_alternative:${alternative}`);
      }
      report.units.push({ id, kind, image, voxel, owners: csv(raw.owner), cost: numOf(raw.cost),
        tech_level: numOf(raw.techlevel), prerequisites, raw, art: graphics, weapons, resources,
        missing, status: missing.length ? 'blocked_dependencies' : 'requires_mechanism_and_render_validation' });
    }
  }
  if (!report.units.length) report.blockers.push('empty:unit roster');
  report.status = report.blockers.length ? 'blocked_invalid_yr_inputs' : 'inventoried_not_integrated';
  report.inputs = source.audit();
  return report;
}

export function stage(directory, output) {
  const sourceRoot = fs.realpathSync(directory);
  const absolute = path.resolve(output);
  // Resolve the existing parent to disallow junction/symlink paths back into source/runtime.
  const parent = fs.realpathSync(path.dirname(absolute));
  const destination = path.join(parent, path.basename(absolute));
  if (inside(destination, fs.realpathSync(repository)) || inside(destination, sourceRoot)) {
    throw new Error('Use a new output directory outside both the repository and game source.');
  }
  if (fs.existsSync(destination)) throw new Error('Output already exists; previous evidence will not be overwritten.');
  const source = new YrSource(sourceRoot);
  const report = inventory(source);
  fs.mkdirSync(destination);
  if (report.status === 'inventoried_not_integrated') {
    for (const name of ['rulesmd.ini', 'artmd.ini']) fs.writeFileSync(path.join(destination, name), source.read(name).data, { flag: 'wx' });
  }
  report.inputs = source.audit();
  fs.writeFileSync(path.join(destination, 'inventory.json'), JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  return report;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [directory, output, ...extra] = process.argv.slice(2);
    if (!directory || !output || extra.length) throw new Error('Usage: node ra2pipe/yr_intake.mjs <local YR directory> <new external output directory>');
    const report = stage(directory, output);
    console.log(JSON.stringify({ status: report.status, units: report.units.length,
      blocked_units: report.units.filter(unit => unit.missing.length).length, blockers: report.blockers, output }));
    if (report.blockers.length) process.exitCode = 2;
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
