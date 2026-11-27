// Scoped, read-only extraction from the user's installed YR. No live table regeneration.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni, getSec } from './lib/ini.mjs';
import { decodeShp, decodePal, montageIndexed, encodePngIndexed } from './art_lib.mjs';

const [game, output, mode] = process.argv.slice(2);
if (mode && mode !== '--with-warp-in') throw new Error('Unknown mode: '+mode);
if (!game || !output) throw new Error('Usage: node ra2pipe/yr_chrono_fx.mjs <YR directory> <new external candidate>');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(fs.realpathSync(path.dirname(path.resolve(output))), path.basename(output));
for (const protectedRoot of [fs.realpathSync(root), fs.realpathSync(game)]) {
  if (out === protectedRoot || out.startsWith(protectedRoot + path.sep)) throw new Error('Candidate must be outside source and repository');
}
if (fs.existsSync(out)) throw new Error('Candidate exists; refusing overwrite');
const source = new YrSource(game);
const provenance = {};
function read(name) {
  const hit = source.read(name);
  if (!hit) throw new Error(`Missing ${name}`);
  provenance[name] = { source: hit.source, sha256: sha256(hit.data) };
  return hit.data;
}
const rules = parseIni(read('rulesmd.ini').toString('latin1'));
const art = parseIni(read('artmd.ini').toString('latin1'));
const pal = decodePal(read('anim.pal'));
const dir = path.join(out, 'assets/ra2/fx');
fs.mkdirSync(dir, { recursive: true });
// CMIN's blue-white warp art is WARPOUT (also used by OpenRA/ra2's
// ChronoResourceDelivery). General.WarpIn is a different brown ground ring;
// do not infer the miner's appearance from that general-purpose tag's name.
for (const key of mode === '--with-warp-in' ? ['warpout', 'warpin'] : ['warpout']) {
  const image = getSec(rules, 'General').keys.get(key).toUpperCase();
  if (!/^[A-Z0-9_]+$/.test(image)) throw new Error(`Invalid image: ${image}`);
  const raw = getSec(art, image).keys;
  const decoded = decodeShp(read(`${image}.shp`));
  if (!decoded.frames.length || decoded.width > 80 || decoded.height > 80) throw new Error('Unexpected unit warp art');
  const montage = montageIndexed(decoded, Math.min(12, decoded.frames.length));
  fs.writeFileSync(path.join(dir, `${image}.png`), encodePngIndexed(montage.width, montage.height, montage.indices, pal));
  // Keep the original canvas/pivot. Rate is preserved as provenance; 15 fps is
  // this engine's explicit presentation adapter, not a claim about YR's clock.
  const metadata = { id: image, image, kind: 'fx', cell: [decoded.width, decoded.height],
    count: decoded.frames.length, rects: montage.rects, fps: 15, rate: Number(raw.get('rate')),
    translucent: raw.get('translucent')?.toLowerCase() === 'yes', flat: raw.get('flat')?.toLowerCase() === 'yes',
    layer: raw.get('layer'), sound: null, source: provenance[`${image}.shp`],
    timing_adapter: '15 frames per second; original art Rate retained separately' };
  fs.writeFileSync(path.join(dir, `${image}.json`), JSON.stringify(metadata, null, 2) + '\n');
}
const economy = {};
for (const section of ['CMIN', 'HARV', 'Riparius', 'Cruentus', 'General']) {
  const keys = getSec(rules, section).keys;
  const names = section === 'General' ? ['purifierbonus', 'chronominimumdelay', 'warpout', 'warpin', 'chronoblast', 'chronoblastdest']
    : section === 'CMIN' || section === 'HARV' ? ['storage', 'cost', 'chronoinsound', 'chronooutsound']
    : ['value', 'growth', 'growthpercentage', 'spread', 'spreadpercentage'];
  economy[section] = Object.fromEntries(names.filter(k => keys.has(k)).map(k => [k, keys.get(k)]));
}
fs.writeFileSync(path.join(out, 'source-audit.json'), JSON.stringify({ source: source.root,
  inputs: source.audit(), resources: provenance, economy }, null, 2) + '\n');
console.log(JSON.stringify({ out, economy }));
