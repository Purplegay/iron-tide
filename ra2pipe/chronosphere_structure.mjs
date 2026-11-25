// Scoped rebuild from the installed game's original SHPs; never edits game files.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';
import { buildingSheet } from './building_shapes.mjs';
import { PROJECT } from './paths.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output || fs.existsSync(output)) throw new Error('Usage: <local YR directory> <new external output directory>');
const source = new YrSource(game);
const inputs = [];
function read(name) {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing original ${name}`);
  inputs.push({ name, source: hit.source, sha256: sha256(hit.data) });
  return hit;
}
const body = decodeShp(read('GACSPH.SHP').data);
const dome = read('GACSPH_E.SHP');
const palette = decodePal(read('UNITTEM.PAL').data);
// Same Allied remap as art_build.mjs, preserving the runtime HouseColor shader input.
for (let i = 16; i < 32; i++) {
  const level = palette[i * 4] / 252;
  for (const [channel, value] of [0x57, 0xa8, 0xff].entries()) palette[i * 4 + channel] = Math.round(value * level);
  palette[i * 4 + 3] = 0;
}
const existing = JSON.parse(fs.readFileSync(path.join(PROJECT, 'assets/ra2/shp/GACSPH.json'), 'utf8'));
assert.deepEqual([body.width, body.height, body.frames.length], [...existing.cell, existing.count]);
const raw = montageIndexed(body, 6);
const composed = buildingSheet(body, 'GACSPH', {}, name => {
  assert.equal(name, 'GACSPH_E');
  return { buf: dome.data, mix: dome.source };
});
// Validate the existing sheet against original data before adopting a changed asset.
const expected = existing.baked_layers?.includes('GACSPH_E') ? composed.sheet : raw;
assert.deepEqual(encodePngIndexed(expected.width, expected.height, expected.indices, palette),
  fs.readFileSync(path.join(PROJECT, 'assets/ra2/shp/GACSPH.png')),
  'Installed source/palette must match the current project artwork');
fs.mkdirSync(output, { recursive: true });
const sheet = composed.sheet;
fs.writeFileSync(path.join(output, 'GACSPH.png'), encodePngIndexed(sheet.width, sheet.height, sheet.indices, palette));
fs.writeFileSync(path.join(output, 'GACSPH.json'), JSON.stringify({ ...existing, ...composed.metadata }) + '\n');
fs.writeFileSync(path.join(output, 'source-audit.json'), JSON.stringify({ inputs, archives: source.audit() }, null, 2));
console.log(JSON.stringify({ output, inputs: inputs.length, baked: composed.metadata.baked_layers }));
