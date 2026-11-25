import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MixEntry } from '../tools/ra2bundle.mjs';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { inventory, stage } from './yr_intake.mjs';

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'iron-tide-yr-intake-'));
console.log(`Fixture evidence: ${root}`);
const directory = name => { const dir = path.join(root, name); fs.mkdirSync(dir); return dir; };
// Independent legacy MIX fixture writer: count, data size, (hash, offset, size), payload.
function mix(entries) {
  const payloads = Object.entries(entries).map(([name, value]) => [name, Buffer.from(value)]);
  const size = payloads.reduce((sum, [, data]) => sum + data.length, 0);
  const header = Buffer.alloc(6 + 12 * payloads.length);
  header.writeUInt16LE(payloads.length, 0); header.writeUInt32LE(size, 2);
  let offset = 0;
  payloads.forEach(([name, data], index) => {
    const at = 6 + index * 12;
    header.writeUInt32LE(MixEntry.hashFilename(name.toUpperCase()) >>> 0, at);
    header.writeUInt32LE(offset, at + 4); header.writeUInt32LE(data.length, at + 8);
    offset += data.length;
  });
  return Buffer.concat([header, ...payloads.map(([, data]) => data)]);
}
const rules = `[InfantryTypes]\n0=GGI\n1=INIT\n[VehicleTypes]\n0=YTNK
[General]\nPrerequisiteBarracks=GAPILE
[GGI]\nOwner=British,Americans\nCost=400\nTechLevel=2\nPrerequisite=BARRACKS\nPrimary=TestGun
[INIT]\nImage=INIT\nCost=200
[YTNK]\nTurret=yes\nCost=600\nWeapon1=TestGun\nEliteWeapon1=EliteGun
[GAPILE]\nName=Allied Barracks
[TestGun]\nDamage=20\nWarhead=TestWH\nProjectile=Invisible
[EliteGun]\nDamage=30\nWarhead=TestWH\nProjectile=Invisible
[TestWH]\nVerses=100%,100%,100%,100%,100%,100%,100%,100%,100%,100%,100%
[Invisible]\nInviso=yes\nAA=yes`;
const art = `[GGI]\nSequence=GGISequence\nCameo=GGIICON
[GGISequence]\nReady=0,1,1
[INIT]\nCameo=INITICON
[YTNK]\nVoxel=yes\nCameo=YTNKICON`;
function fixture(name) {
  const dir = directory(name);
  fs.writeFileSync(path.join(dir, 'rulesmd.ini'), rules);
  fs.writeFileSync(path.join(dir, 'artmd.ini'), art);
  // These deliberately are presence-only markers, not claimed to be playable images.
  for (const name of ['GGI.shp', 'GGIICON.shp', 'INIT.shp', 'INITICON.shp', 'YTNK.vxl', 'YTNK.hva', 'YTNKICON.shp']) {
    fs.writeFileSync(path.join(dir, name), 'presence-only-fixture');
  }
  return dir;
}

test('nested archives use expansion priority even when the replacement is shorter', () => {
  const dir = directory('priority');
  fs.writeFileSync(path.join(dir, 'RA2.MIX'), mix({ 'LOCAL.MIX': mix({ 'rulesmd.ini': 'old longer payload' }) }));
  fs.writeFileSync(path.join(dir, 'ra2md.mix'), mix({ 'localmd.mix': mix({ 'rulesmd.ini': 'yr' }) }));
  fs.writeFileSync(path.join(dir, 'expandmd01.mix'), mix({ 'rulesmd.ini': 'p' }));
  const source = new YrSource(dir);
  assert.equal(source.read('RULESMD.INI').data.toString(), 'p');
  assert.match(source.read('rulesmd.ini').source, /^expandmd01.mix/);
  assert.equal(Object.keys(source.audit()).length, 3);
});

test('loose input priority and mutation detection preserve source provenance', () => {
  const dir = fixture('mutation');
  fs.writeFileSync(path.join(dir, 'ra2md.mix'), mix({ 'rulesmd.ini': 'archive' }));
  const source = new YrSource(dir);
  assert.equal(source.read('rulesmd.ini').data.toString(), rules);
  assert.throws(() => source.read('../rulesmd.ini'), /Unsafe/);
  fs.writeFileSync(path.join(dir, 'rulesmd.ini'), 'changed');
  assert.throws(() => source.read('rulesmd.ini'), /changed/);
  assert.throws(() => source.audit(), /changed/);
});

test('complete inventory retains owners, weapons and generic prerequisite alternatives, never enabling units', () => {
  const report = inventory(new YrSource(fixture('complete')));
  assert.equal(report.status, 'inventoried_not_integrated');
  assert.equal(report.runtime_enabled, false);
  assert.equal(report.units.length, 3);
  assert.deepEqual(report.units.map(unit => unit.missing), [[], [], []]);
  const gi = report.units.find(unit => unit.id === 'GGI');
  assert.deepEqual(gi.owners, ['British', 'Americans']);
  assert.equal(gi.cost, 400);
  assert.deepEqual(gi.prerequisites[0].alternatives, ['GAPILE']);
  assert.equal(gi.weapons.TestGun.damage, '20');
  assert.equal(report.units.find(unit => unit.id === 'YTNK').weapons.EliteGun.damage, '30');
  assert(report.units.every(unit => unit.status === 'requires_mechanism_and_render_validation'));
});

test('missing model, icon, sequence, weapon dependency and prerequisite are reported by unit', () => {
  const dir = fixture('missing');
  fs.unlinkSync(path.join(dir, 'YTNK.hva'));
  fs.unlinkSync(path.join(dir, 'GGIICON.shp'));
  fs.writeFileSync(path.join(dir, 'artmd.ini'), art.replace('[GGISequence]', '[WrongSequence]'));
  fs.writeFileSync(path.join(dir, 'rulesmd.ini'), rules.replace('Warhead=TestWH', 'Warhead=UnknownWH').replace('GAPILE\n[GGI]', 'NOFACTORY\n[GGI]'));
  const report = inventory(new YrSource(dir));
  const gi = report.units.find(unit => unit.id === 'GGI');
  assert(gi.missing.includes('resource:GGIICON.shp'));
  assert(gi.missing.includes('sequence:GGISequence'));
  assert(gi.missing.includes('warhead:UnknownWH'));
  assert(gi.missing.includes('prerequisite_alternative:NOFACTORY'));
  assert(report.units.find(unit => unit.id === 'YTNK').missing.includes('resource:YTNK.hva'));
});

test('vanilla or renamed voice-pack rules cannot pass as YR', () => {
  const dir = directory('vanilla');
  fs.writeFileSync(path.join(dir, 'rules.ini'), '[InfantryTypes]\n0=E1');
  let report = inventory(new YrSource(dir));
  assert.deepEqual(report.blockers, ['missing:rulesmd.ini', 'missing:artmd.ini']);
  fs.writeFileSync(path.join(dir, 'rulesmd.ini'), '[InfantryTypes]\n0=E1');
  fs.writeFileSync(path.join(dir, 'artmd.ini'), '[E1]\nCameo=GIICON');
  report = inventory(new YrSource(dir));
  assert.equal(report.status, 'blocked_invalid_yr_inputs');
  assert(report.blockers.some(reason => reason.startsWith('not_verified_yr')));
});

test('malformed archives fail instead of falling back to base data', () => {
  const dir = directory('corrupt');
  const archive = mix({ 'rulesmd.ini': 'x' });
  archive.writeUInt32LE(999999, 10); // first entry payload offset
  fs.writeFileSync(path.join(dir, 'ra2md.mix'), archive);
  assert.throws(() => new YrSource(dir), /outside file/);
});

test('external staging is exact, read-only and refuses existing/source/runtime outputs', () => {
  const dir = fixture('stage');
  const before = sha256(fs.readFileSync(path.join(dir, 'rulesmd.ini')));
  const out = path.join(root, 'candidate');
  stage(dir, out);
  assert.equal(sha256(fs.readFileSync(path.join(out, 'rulesmd.ini'))), before);
  assert.equal(sha256(fs.readFileSync(path.join(dir, 'rulesmd.ini'))), before);
  assert.throws(() => stage(dir, out), /already exists/);
  assert.throws(() => stage(dir, path.join(dir, 'output')), /outside/);
  assert.throws(() => stage(dir, path.join(path.dirname(fileURLToPath(import.meta.url)), 'output')), /outside/);
});

test('INI includes block staging instead of silently dropping mod dependencies', () => {
  const dir = fixture('includes');
  fs.appendFileSync(path.join(dir, 'rulesmd.ini'), '\n[#include]\n0=extra.ini');
  const out = path.join(root, 'blocked-candidate');
  const report = stage(dir, out);
  assert.equal(report.status, 'blocked_invalid_yr_inputs');
  assert(report.blockers.some(reason => reason.startsWith('unsupported:')));
  assert.equal(fs.existsSync(path.join(out, 'rulesmd.ini')), false);
  assert.equal(fs.existsSync(path.join(out, 'inventory.json')), true);
});
