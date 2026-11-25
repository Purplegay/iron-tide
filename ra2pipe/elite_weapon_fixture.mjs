// Independent expectations from installed rulesmd.ini, not normalized runtime data.
import fs from 'node:fs';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
const [game, output] = process.argv.slice(2);
if (!game || !output || fs.existsSync(output)) throw new Error('Usage: <local YR> <new fixture.json>');
const hit = new YrSource(game).read('rulesmd.ini');
if (!hit) throw new Error('Missing rulesmd.ini');
const ini = parseIni(hit.data.toString('latin1'));
const ids = ['E1','ENGINEER','JUMPJET','GHOST','DOG','CLEG','SPY','CCOMAND','PTROOP','SNIPE','TANY',
  'AMCV','MTNK','CARRIER','DEST','AEGIS','LCRF','SHAD','DLPH','TNKD','CMIN','SREF','MGTK','FV','CDEST','ORCA','BEAG','GGI','ROBO','BFRT','HORNET'];
const result = { source: { archive: hit.source, sha256: sha256(hit.data) }, units: {}, weapons: {}, warheads: {}, projectiles: {} };
for (const id of ids) {
  const section = getSec(ini,id);
  if (!section) throw new Error(`Missing ${id}`);
  const row = Object.fromEntries(section.keys);
  result.units[id] = row;
  for (const [key, value] of section.keys) {
    if (!/^(elite)?(primary|secondary|weapon\d+)$/.test(key)) continue;
    const weapon = getSec(ini,value);
    if (!weapon) continue;
    const raw = Object.fromEntries(weapon.keys);
    result.weapons[weapon.name] = raw;
    for (const [field, bag] of [['warhead','warheads'], ['projectile','projectiles']]) {
      const entry = getSec(ini, raw[field]);
      if (entry) result[bag][entry.name] = Object.fromEntries(entry.keys);
    }
  }
}
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output,units:ids.length,weapons:Object.keys(result.weapons).length,source:result.source}));
