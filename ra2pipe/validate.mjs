// Assertions over the generated iron_tide/data/ra2/*.json against known
// ground-truth values from the original RA2 rules. Prints RA2_SUMMARY.
import fs from 'node:fs';
import { PROJECT } from './paths.mjs';
const D = `${PROJECT}/data/ra2`;
const load = (f) => JSON.parse(fs.readFileSync(`${D}/${f}`, 'utf8'));

const loc = load('localization.json').labels;
const units = load('units.json');
const buildings = load('buildings.json').buildings;
const weapons = load('weapons.json').weapons;
const warheads = load('warheads.json').warheads;
const factions = load('factions.json');
const tech = load('tech_tree.json').entities;
const meta = load('meta.json');

let ok = 0, fail = 0;
const failures = [];
function check(name, cond, got) {
  if (cond) { ok++; } else { fail++; failures.push(`${name} (got: ${JSON.stringify(got)})`); }
}
const near = (a, b) => a != null && Math.abs(a - b) < 1e-9;

// localization
check('loc:Name:E1==美国大兵', loc['NAME:E1'] === '美国大兵', loc['NAME:E1']);
check('loc:Name:MTNK==灰熊坦克', loc['NAME:MTNK'] === '灰熊坦克', loc['NAME:MTNK']);
check('loc:Name:GAPILE==盟军兵营', loc['NAME:GAPILE'] === '盟军兵营', loc['NAME:GAPILE']);
check('loc:labels>4000', Object.keys(loc).length > 4000, Object.keys(loc).length);

// units / E1
const e1 = units.infantry.E1;
check('E1 exists', !!e1, !!e1);
check('E1.display_name', e1 && e1.display_name === '美国大兵', e1 && e1.display_name);
check('E1.hp==125', e1 && near(e1.hp, 125), e1 && e1.hp);
check('E1.armor==none', e1 && e1.armor === 'none', e1 && e1.armor);
check('E1.cost==200', e1 && near(e1.cost, 200), e1 && e1.cost);
check('E1.primary==M60', e1 && e1.primary === 'M60', e1 && e1.primary);
check('E1.image==GI', e1 && e1.image === 'GI', e1 && e1.image);
check('E1.cameo==GIICON', e1 && e1.cameo === 'GIICON', e1 && e1.cameo);
check('E1.prereq=[GAPILE]', e1 && e1.prerequisites.length === 1 && e1.prerequisites[0] === 'GAPILE', e1 && e1.prerequisites);
check('E1.sides==allied', e1 && e1.sides.includes('allied'), e1 && e1.sides);

// MTNK
const mtnk = units.vehicles.MTNK;
check('MTNK.hp==300', mtnk && near(mtnk.hp, 300), mtnk && mtnk.hp);
check('MTNK.armor==heavy', mtnk && mtnk.armor === 'heavy', mtnk && mtnk.armor);
check('MTNK.primary==105mm', mtnk && mtnk.primary === '105mm', mtnk && mtnk.primary);
check('MTNK.cost==700', mtnk && near(mtnk.cost, 700), mtnk && mtnk.cost);
check('MTNK.voxel==true', mtnk && mtnk.voxel === true, mtnk && mtnk.voxel);

// weapons
const m60 = weapons.M60;
check('M60.damage==15', m60 && near(m60.damage, 15), m60 && m60.damage);
check('M60.rof==20', m60 && near(m60.rof, 20), m60 && m60.rof);
check('M60.range==4', m60 && near(m60.range, 4), m60 && m60.range);
check('M60.warhead==SA', m60 && m60.warhead === 'SA', m60 && m60.warhead);
const w105 = weapons['105mm'];
check('105mm.damage==65', w105 && near(w105.damage, 65), w105 && w105.damage);
check('105mm.warhead==AP', w105 && w105.warhead === 'AP', w105 && w105.warhead);
check('120mmx.burst==2', weapons['120mmx'] && near(weapons['120mmx'].burst, 2), weapons['120mmx'] && weapons['120mmx'].burst);

// warheads
const sa = warheads.SA;
check('SA.verses.none==1', sa && near(sa.verses.none, 1), sa && sa.verses.none);
check('SA.verses.heavy==.25', sa && near(sa.verses.heavy, 0.25), sa && sa.verses.heavy);
check('SA.verses.special_2==1', sa && near(sa.verses.special_2, 1), sa && sa.verses.special_2);
check('SA.has 11 armor slots', sa && Object.keys(sa.verses).length === 11, sa && Object.keys(sa.verses).length);
const ap = warheads.AP;
check('AP.verses.medium==1', ap && near(ap.verses.medium, 1), ap && ap.verses.medium);
check('AP.verses.none==.25', ap && near(ap.verses.none, 0.25), ap && ap.verses.none);

// buildings
const gapi = buildings.GAPILE;
check('GAPILE.hp==500', gapi && near(gapi.hp, 500), gapi && gapi.hp);
check('GAPILE.factory==InfantryType', gapi && gapi.factory === 'InfantryType', gapi && gapi.factory);
check('GAPILE.display==盟军兵营', gapi && gapi.display_name === '盟军兵营', gapi && gapi.display_name);
check('GAPILE.prereq has GACNST', gapi && gapi.prerequisites.includes('GACNST'), gapi && gapi.prerequisites);
const garefn = buildings.GAREFN;
check('GAREFN.foundation==4x3', garefn && garefn.foundation === '4x3', garefn && garefn.foundation);

// factions
check('sides.allied has Americans', factions.sides.allied.includes('Americans'), factions.sides.allied);
check('sides.soviet has Russians', factions.sides.soviet.includes('Russians'), factions.sides.soviet);
check('roster.allied.infantry nonempty', factions.rosters.allied.infantry.length > 0, factions.rosters.allied.infantry.length);
check('roster.soviet.vehicles nonempty', factions.rosters.soviet.vehicles.length > 0, factions.rosters.soviet.vehicles.length);
check('countries==13', factions.countries.length === 13, factions.countries.length);

// tech tree
check('tech.E1.requires GAPILE', tech.E1 && tech.E1.requires.includes('GAPILE'), tech.E1 && tech.E1.requires);
check('tech.GAPILE.kind==building', tech.GAPILE && tech.GAPILE.kind === 'building', tech.GAPILE && tech.GAPILE.kind);

// meta / counts
check('meta.counts.infantry==45', meta.counts.infantry === 45, meta.counts.infantry);
check('meta.counts.vehicles==55', meta.counts.vehicles === 55, meta.counts.vehicles);
check('meta.counts.aircraft==8', meta.counts.aircraft === 8, meta.counts.aircraft);
check('meta.counts.buildings==295', meta.counts.buildings === 295, meta.counts.buildings);
check('meta.unresolved.aircraft==[APACHE]', JSON.stringify(meta.unresolved.aircraft) === JSON.stringify(['APACHE']), meta.unresolved.aircraft);
check('armor_order len 11', meta.armor_order.length === 11, meta.armor_order.length);

console.log('FAILURES:', failures.length);
for (const f of failures) console.log('  -', f);
console.log(`RA2_SUMMARY ok=${ok} fail=${fail}`);
process.exit(fail === 0 ? 0 : 1);
