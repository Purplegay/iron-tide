// Verify local YR infantry idle sequences against the actual two playable rosters.
// With --write, repair only idle entries, or import the native table if absent.
import fs from 'node:fs';
import path from 'node:path';
import {PROJECT} from './paths.mjs';
import {YrSource} from './lib/yr_source.mjs';
import {parseIni} from './lib/ini.mjs';

const source = new YrSource(process.argv[2]);
const readIni = name => parseIni(source.read(name).data.toString('latin1'));
const rules = readIni('rulesmd.ini'), art = readIni('artmd.ini');
const write = process.argv.includes('--write');
const read = name => JSON.parse(fs.readFileSync(name));
const shp = path.join(PROJECT,'assets/ra2/shp');
const roster = new Set(['CTECH','INIT','ASW','HORNET','SUB']);
for (const pack of ['ra2_allied','yr_allied','yr_robot','yr_fortress','yr_soviet']) {
  for (const unit of read(path.join(PROJECT,'data',pack+'.json')).units) roster.add(unit.id);
}
let clips = 0, mismatches = 0;
for (const id of roster) {
  const raw = rules.get(id === 'DOG' ? 'adog' : id === 'SOV_DOG' ? 'dog' : id.toLowerCase()).keys;
  const image = raw.get('image') || (id === 'DOG' ? 'ADOG' : id === 'SOV_DOG' ? 'DOG' : id);
  const section = art.get(image.toLowerCase())?.keys.get('sequence');
  if (!section) continue;
  const native = art.get(section.toLowerCase());
  const count = read(path.join(shp,id+'.json')).count;
  const file = path.join(shp,id+'.seq.json');
  const existing = fs.existsSync(file);
  const data = existing ? read(file) : {image,source:'artmd.ini/['+section+']',seq:{}};
  let changed = false;
  for (const name of native.keyOrder) {
    const idle = /^(Wet)?Idle[12]$/i.test(name);
    if (existing && !idle) continue;
    const [start,per,stride] = native.keys.get(name.toLowerCase()).split(',').slice(0,3).map(Number);
    if (![start,per,stride].every(Number.isInteger) || per < 1) continue;
    const facings = stride ? 8 : 1;
    if (start < 0 || start + (facings-1)*stride + per > count/2)
      throw Error(id+' '+name+' outside visible SHP frames');
    if (idle && per > 1) clips++;
    const old = data.seq[name];
    if (old?.start === start && old.per === per && old.facings === facings &&
        (facings === 1 || (old.stride ?? per) === stride)) continue;
    data.seq[name] = {start,per,stride,facings};
    changed = true;
  }
  if (changed) {
    console.log(id+' '+section+' '+(write?'updated':'mismatch'));
    mismatches++;
    if (write) fs.writeFileSync(file,JSON.stringify(data, null, id==='SNIPE'?2:0)+'\n');
  }
}
console.log(roster.size+' units, '+clips+' animated native idle clips');
if (!write && mismatches) process.exitCode=1;
