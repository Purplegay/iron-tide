// Export the retail YR cash pickup animation without rebuilding the combat FX library.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from '../../ra2pipe/lib/yr_source.mjs';
import { parseIni, getSec } from '../../ra2pipe/lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from '../../ra2pipe/art_lib.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node tools/yr_cash_crate_fx.mjs <retail YR directory> <new output directory>');
const source = new YrSource(game);
const inputs = {};
function read(name) {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing retail resource: ${name}`);
  inputs[name] = { source: hit.source, sha256: sha256(hit.data) };
  return hit.data;
}
const rules = parseIni(read('rulesmd.ini').toString('latin1'));
const art = parseIni(read('artmd.ini').toString('latin1'));
const powerup = getSec(rules, 'Powerups').keys.get('money');
const id = powerup?.split(',')[1]?.trim().toUpperCase();
if (id !== 'MONEY') throw new Error(`Unexpected retail cash animation: ${id}`);
const info = getSec(art, id).keys;
const rate = Number(info.get('rate'));
if (!(rate > 0)) throw new Error(`Invalid retail animation Rate: ${rate}`);
const palette = decodePal(read('anim.pal'));
const shp = decodeShp(read('money.shp'));
const count = shp.frames.length;
if (!count) throw new Error('Empty retail MONEY.SHP');
const sheet = montageIndexed(shp, Math.min(count, 12));
source.audit();
fs.mkdirSync(output);
fs.writeFileSync(path.join(output, `${id}.png`), encodePngIndexed(sheet.width, sheet.height, sheet.indices, palette));
const metadata = { id, kind: 'fx', cell: [shp.width, shp.height], count, rects: sheet.rects,
  fps: rate / 60, rate, normalized: info.get('normalized')?.toLowerCase() === 'yes', powerup,
  palette: 'ANIM.PAL', source: inputs['money.shp'], inputs };
fs.writeFileSync(path.join(output, `${id}.json`), JSON.stringify(metadata) + '\n');
console.log(JSON.stringify(metadata));
