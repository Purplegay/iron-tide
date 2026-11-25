import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { PROJECT, INPUT } from './paths.mjs';

// Verified against local DLPH.SHP: eight walk blocks, eight standing images,
// eight firing blocks, twelve death images, followed by the shadow half.
export function dolphinSequence(artText, rawFrames) {
  const section = artText.split(/^\[DLPH\][^\r\n]*\r?\n/m)[1]?.split(/^\[/m)[0];
  const read = key => Number(section?.match(new RegExp(`^${key}\\s*=\\s*(\\d+)`, 'mi'))?.[1]);
  const walk = read('WalkFrames'), fire = read('FiringFrames');
  if (walk !== 6 || fire !== 6 || rawFrames !== 232)
    throw new Error('DLPH source layout changed; inspect frame order before exporting');
  return {
    image: 'DLPH', source: 'local art.ini/[DLPH] + inspected DLPH.SHP layout',
    seq: {
      Walk: {start: 0, per: walk, facings: 8},
      Guard: {start: walk * 8, per: 1, facings: 8},
      FireUp: {start: walk * 8 + 8, per: fire, facings: 8},
      Die1: {start: (walk + fire) * 8 + 8, per: 12, facings: 1},
    },
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const meta = JSON.parse(fs.readFileSync(path.join(PROJECT, 'assets/ra2/shp/DLPH.json'), 'utf8'));
  const table = dolphinSequence(fs.readFileSync(path.join(INPUT, 'art.ini'), 'utf8'), meta.count);
  fs.writeFileSync(path.join(PROJECT, 'assets/ra2/shp/DLPH.seq.json'), JSON.stringify(table));
  console.log(JSON.stringify(table));
}
