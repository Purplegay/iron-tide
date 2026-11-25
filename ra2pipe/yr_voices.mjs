// Read-only original YR voice inputs. Export only to a fresh external candidate.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { YrSource, sha256 } from './lib/yr_source.mjs';

const [game, output] = process.argv.slice(2);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_voices.mjs <local YR directory> <new external candidate>');
const root = fs.realpathSync(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
const out = path.join(fs.realpathSync(path.dirname(path.resolve(output))), path.basename(output));
for (const protectedRoot of [root, fs.realpathSync(game)]) {
  const rel = path.relative(protectedRoot, out);
  if (!rel || (!rel.startsWith('..' + path.sep) && rel !== '..' && !path.isAbsolute(rel))) {
    throw new Error('Candidate must be outside source and repository');
  }
}
if (fs.existsSync(out)) throw new Error('Candidate exists; refusing overwrite');
const source = new YrSource(game);
const files = {};
for (const name of ['rulesmd.ini', 'soundmd.ini', 'audio.idx', 'audio.bag']) {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing ${name}`);
  files[name] = hit;
}
const input = path.join(out, 'input');
fs.mkdirSync(input, { recursive: true });
const provenance = {};
for (const [name, hit] of Object.entries(files)) {
  fs.writeFileSync(path.join(input, name), hit.data);
  provenance[name] = { source: hit.source, sha256: sha256(hit.data), bytes: hit.data.length };
}
fs.writeFileSync(path.join(out, 'source-audit.json'), JSON.stringify({
  source: fs.realpathSync(game), files: provenance, archives: source.audit()
}, null, 2) + '\n');
console.log(JSON.stringify({ candidate: out, inputs: Object.keys(files) }));
