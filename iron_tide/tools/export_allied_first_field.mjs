// Run from the project directory after the allied-ends retail audit.
import fs from 'node:fs';
const [audit, map, output] = process.argv.slice(2);
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const {tables, audit: proof} = read(audit);
const layout = read(map);
if (layout.id !== 'yr_all01umd' || proof.id !== layout.id) throw Error('Wrong retail map');
const [x0, y0] = layout.retail_origin;
const cells = new Set(layout.cells.map(([u, v]) => `${u},${v}`));
const pos = (x, y) => [y0-y+.5, x-x0+.5];
const inside = (u, v) => cells.has(`${Math.floor(u)},${Math.floor(v)}`);
const rows = section => Object.entries(tables[section]).map(([key, line]) => {
  const [house, id, hp, x, y, a, b, c] = line.split(',');
  const [u, v] = pos(Number(x), Number(y));
  const facing = Number(section === 'Infantry' ? c : a);
  return [key, house, id, Number(hp), u, v, facing, b, inside(u, v)];
});
if (!output) throw Error('Supply destination');
fs.writeFileSync(output, JSON.stringify({source:layout.sha256, structures:rows('Structures'), units:rows('Units'), infantry:rows('Infantry')},null,1)+'\n');
