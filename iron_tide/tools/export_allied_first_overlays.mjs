// node tools/export_allied_first_overlays.mjs RETAIL_SOURCE_DIR data/maps/yr_all01umd.json data/ra2/allied_first_overlays.json
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {unpackOverlay} from './head_games_overlays.mjs';
const [source, layout, output] = process.argv.slice(2);
const map = JSON.parse(fs.readFileSync(layout));
const raw = fs.readFileSync(path.join(source, 'all01umd.map.map'));
const sha256 = createHash('sha256').update(raw).digest('hex');
if (map.id !== 'yr_all01umd' || sha256 !== 'dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0') throw Error('Unexpected retail map');
const rules = fs.readFileSync(path.join(source,'rulesmd.ini'),'latin1');
function section(text,name) {
  const section = text.split(`[${name}]`)[1];
  if (!section) throw Error(`Missing ${name}`);
  return section.split(/\n\s*\[/)[0];
}
// Overlay IDs are zero-based insertion positions, not printed INI keys.
const types = [...section(rules,'OverlayTypes').matchAll(/^\s*(\d+)\s*=\s*([^;\s]+)/gm)].map(m=>m[2]);
const plane = name => unpackOverlay(section(raw.toString('latin1'),name).trim().split(/\r?\n/).map(line=>line.slice(line.indexOf('=')+1).trim()).join(''));
const codes = plane('OverlayPack'), frames = plane('OverlayDataPack');
const [x0,y0] = map.retail_origin;
const rows = [];
for (const [u,v] of map.cells) {
  const index = v+x0+(y0-u)*512, code=codes[index];
  if (code===255) continue;
  if (!types[code]) throw Error(`Unknown overlay ${code}`);
  rows.push([u,v,types[code],frames[index]]);
}
fs.writeFileSync(output, JSON.stringify({sha256,rows},null,1)+'\n');
