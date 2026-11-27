// Read-only retail intake; outputs evidence, not a playable campaign.
import fs from 'node:fs';
import path from 'node:path';
import { DataStream, MixEntry, MixFile } from '../../tools/ra2bundle.mjs';
import { parseIni } from '../../ra2pipe/lib/ini.mjs';
import { YrSource, sha256 } from '../../ra2pipe/lib/yr_source.mjs';

const [game, out] = process.argv.slice(2);
if (!game || !out) throw new Error('Usage: node tools/audit_sov02_retail.mjs GAME_DIR OUTPUT_DIR');
const source = new YrSource(game);
const archive = source.loose('mapsmd03.mix').data;
const logging = console.log;
let mix;
try { console.log = () => {}; mix = new MixFile(new DataStream(new DataView(archive.buffer, archive.byteOffset, archive.byteLength))); }
finally { console.log = logging; }
const retailBattle = parseIni(source.read('battlemd.ini').data.toString('latin1'));
const member = retailBattle.get('sov02')?.keys.get('scenario')?.toLowerCase();
if (!member) throw new Error('No SOV02 Scenario in retail battlemd.ini');
const hash = MixEntry.hashFilename(member);
const entry = mix.getEntry(hash);
if (!entry) throw new Error('Missing retail member ' + member);
const offset = mix.getDataStart() + entry.offset;
const raw = archive.subarray(offset, offset + entry.length);
const map = parseIni(raw.toString('latin1'));
if (!map.has('triggers')) throw new Error('Retail trigger verification failed');
const sections = Object.fromEntries(['Basic','Map','Houses','Waypoints','VariableNames','Triggers','Events','Actions','Tags','CellTags','TeamTypes','TaskForces','ScriptTypes','AITriggerTypes','AITriggerTypesEnable','Structures','Units','Infantry'].map(name => [name, Object.fromEntries(map.get(name.toLowerCase())?.keys ?? [])]));
for (const key of ['Houses','TeamTypes','TaskForces','ScriptTypes']) {
  sections[key + 'Records'] = Object.fromEntries(Object.values(sections[key]).map(id => [id, Object.fromEntries(map.get(id.toLowerCase())?.keys ?? [])]));
}
const report = { archive: 'mapsmd03.mix', archive_sha256: sha256(archive), member, member_hash: (hash >>> 0).toString(16), map_sha256: sha256(raw), sections };
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, member), raw);
fs.writeFileSync(path.join(out, 'sov02_script_evidence.json'), JSON.stringify(report, null, 2));
const rows = Object.entries(sections.Triggers).map(([id, definition]) => {
  const tags = Object.entries(sections.Tags).filter(([, value]) => value.split(',').at(-1)?.toLowerCase() === id);
  const tagIds = new Set(tags.map(([tag]) => tag));
  const cellTags = Object.entries(sections.CellTags).filter(([, tag]) => tagIds.has(tag.toLowerCase()));
  const events = sections.Events[id];
  const actions = sections.Actions[id];
  if (!events || !actions) throw new Error('Incomplete trigger ' + id);
  return [id, ...definition.split(',').slice(0, 3), definition.split(',').slice(3).join(','), events, actions, tags.map(([tag]) => tag).join(','), cellTags.map(([cell]) => cell).join(',')].join('\t');
});
fs.writeFileSync(path.join(out, 'SOV02_TRIGGER_INDEX.tsv'), ['ID\t房号键\t关联触发器\t名称\t启停和难度字段\t事件\t动作\t标签\t触发格', ...rows].join('\n') + '\n');
console.log(JSON.stringify({ ...report, sections: Object.fromEntries(Object.entries(sections).map(([k,v]) => [k, Object.keys(v).length])), basic: sections.Basic, map: sections.Map }, null, 2));
