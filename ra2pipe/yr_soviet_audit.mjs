// Read-only Soviet intake from the user's local Yuri installation. No runtime registration.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, listSection, csv, numOf } from './lib/ini.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output || fs.existsSync(output)) throw new Error('Usage: yr_soviet_audit.mjs <YR install> <new external output directory>');
const root = fs.realpathSync(path.resolve(import.meta.dirname, '..'));
const parent = fs.realpathSync(path.dirname(path.resolve(output)));
const out = path.join(parent, path.basename(output));
for (const protectedRoot of [root, fs.realpathSync(game)]) {
  const relative = path.relative(protectedRoot, out);
  if (!relative || (!relative.startsWith('..' + path.sep) && relative !== '..' && !path.isAbsolute(relative)))
    throw new Error('Output must be outside the repository and game installation');
}
const source = new YrSource(game);
const inputs = {};
for (const name of ['rulesmd.ini', 'artmd.ini']) {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing native input: ${name}`);
  inputs[name] = {source: hit.source, sha256: sha256(hit.data), parsed: parseIni(hit.data.toString('latin1'))};
}
const rules = inputs['rulesmd.ini'].parsed, art = inputs['artmd.ini'].parsed;
// Reviewed ordinary roster, not Owner alone: captured technology often has every country as Owner.
const groups = {
  building: ['NAPOWR','NAHAND','NAREFN','NAWEAP','NARADR','NAYARD','NADEPT','NATECH','NANRCT','NAINDP'],
  defense: ['NAWALL','NALASR','NAFLAK','TESLA','NABNKR','NAIRON','NAMISL'],
  infantry: ['E2','DOG','SENGINEER','FLAKT','SHK','IVAN','TERROR','DESO','BORIS'],
  vehicle: ['HARV','HTNK','HTK','DRON','V3','TTNK','DTRUCK','APOC','ZEP','SCHP','SMCV'],
  air: [],
  naval: ['SAPC','SUB','HYD','SQD','DRED'],
  support: ['NACNST','HORV','SCHD','V3ROCKET','DMISL','BPLN','SPYP','CIVAN'],
};
const types = new Map();
for (const type of ['BuildingTypes','InfantryTypes','VehicleTypes','AircraftTypes'])
  for (const {id} of listSection(rules, type)) types.set(id, type);
const entities = [];
for (const [tab, ids] of Object.entries(groups)) for (const id of ids) {
  const keys = rules.get(id.toLowerCase())?.keys;
  if (!keys || !types.has(id)) throw new Error(`Unknown native entity: ${id}`);
  if (tab !== 'support' && numOf(keys.get('techlevel'), -1) < 0) throw new Error(`Non-production entry: ${id}`);
  const image = keys.get('image') || id;
  const artwork = art.get(image.toLowerCase())?.keys;
  const stem = artwork?.get('image') || image;
  const voxel = artwork?.get('voxel')?.toLowerCase() === 'yes';
  const candidates = voxel ? [stem + '.vxl'] : [stem + '.shp'];
  if (types.get(id) === 'BuildingTypes')
    for (const theater of ['T','G','A','N','D','L','U']) candidates.push(stem[0] + theater + stem.slice(2) + '.shp');
  const model = [...new Set(candidates)].find(name => source.read(name)) || null;
  const cameo = artwork?.get('cameo');
  const cameoFile = cameo ? cameo.replace(/\.shp$/i, '') + '.shp' : null;
  entities.push({id, tab, type: types.get(id), name: keys.get('name'),
    cost: numOf(keys.get('cost')), hp: numOf(keys.get('strength')), armor: keys.get('armor'),
    techLevel: numOf(keys.get('techlevel')), prerequisite: csv(keys.get('prerequisite')),
    requiredHouses: csv(keys.get('requiredhouses')), forbiddenHouses: csv(keys.get('forbiddenhouses')),
    weapons: Object.fromEntries(['primary','secondary','eliteprimary','elitesecondary'].filter(k=>keys.has(k)).map(k=>[k,keys.get(k)])),
    image, modelCandidate: model, cameo: cameoFile, cameoAvailable: !!(cameoFile && source.read(cameoFile)),
    nativeMechanisms: Object.fromEntries(['deploysinto','undeploysinto','deployfire','deployfireweapon','harvester','teleporter','passengers','spawns','spawnscount','ivan','engineer','c4','radiation','naval','balloonhover','jumpjet','superweapon','superweapon2','industrialplant','powersunit'].filter(k=>keys.has(k)).map(k=>[k,keys.get(k)])),
    status: 'reference_only_not_playable'});
}
const archives = source.audit();
const report = {schema:1, purpose:'Native Soviet migration inventory; presence checks do not validate rendering or behavior.',
  sources: Object.fromEntries(Object.entries(inputs).map(([k,v])=>[k,{source:v.source,sha256:v.sha256}])), archives,
  counts: Object.fromEntries(Object.entries(groups).map(([k,v])=>[k,v.length])),
  identityConflict: {legacyAlliedDog:'DOG', nativeAlliedDog:'ADOG', nativeSovietDog:'DOG', requiresSaveAndAssetMigration:true},
  entities};
fs.mkdirSync(out);
fs.writeFileSync(path.join(out,'soviet-native-inventory.json'), JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({counts:report.counts, modelCandidates:entities.filter(x=>x.modelCandidate).length,
  missingModelCandidates:entities.filter(x=>!x.modelCandidate).map(x=>x.id), missingProductionCameos:entities.filter(x=>x.tab!=='support'&&!x.cameoAvailable).map(x=>x.id), output:out}));
