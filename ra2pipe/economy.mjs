// Scoped economy export from the locally supplied rules.ini; no reference engine code.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { readIni, getSec, numOf } from './lib/ini.mjs';
import { INPUT, PROJECT } from './paths.mjs';

const source = path.join(INPUT, 'rules.ini');
const rules = readIni(source);
function positive(section, key) {
  const value = numOf(getSec(rules, section)?.keys.get(key.toLowerCase()));
  if (!(value > 0)) throw new Error(`Missing positive ${section}.${key}`);
  return value;
}
const economy = {
  source: 'rules.ini', source_sha256: createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
  resources: { ore: { value: positive('Riparius', 'Value') }, gems: { value: positive('Cruentus', 'Value') } },
  purifier_bonus: positive('General', 'PurifierBonus'),
  growth: { interval_seconds: positive('General', 'GrowthRate') * 60, fraction: positive('Riparius', 'GrowthPercentage'), spread_fraction: positive('Riparius', 'SpreadPercentage') },
  chrono_return_seconds: positive('General', 'ChronoMinimumDelay') / 15,
  storage: { CMIN: positive('CMIN', 'Storage'), HARV: positive('HARV', 'Storage') },
  // Timing is an explicit Godot adapter, not original executable frame timing.
  adapter: { harvest_units_per_second: 22 / positive('Riparius', 'Value'), unload_seconds: 1 }
};
fs.mkdirSync(path.join(PROJECT, 'data/ra2'), { recursive: true });
fs.writeFileSync(path.join(PROJECT, 'data/ra2/economy.json'), JSON.stringify(economy, null, 2) + '\n');
console.log(JSON.stringify(economy));
