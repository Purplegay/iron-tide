// Minimal RA2/Westwood INI parser.
// Handles: [Section] headers, Key=Value pairs, ; comments, blank lines,
// duplicate keys (kept as last-wins), and $include directives are NOT resolved
// (rules.ini here is already a flat single file).
import fs from 'node:fs';

export function parseIni(text) {
  const sections = new Map(); // name(lower) -> { name, order, keys: Map, keyOrder: [] }
  let cur = null;
  const lines = text.split(/\r?\n/);
  for (let raw of lines) {
    // strip trailing CR already handled; strip comments (';' Westwood style and '//'
    // which a few RA2 lines use, e.g. "[MirageWH]\t// Supposed to be a heat ray.")
    const cuts = [raw.indexOf(';'), raw.indexOf('//')].filter((i) => i >= 0);
    let line = cuts.length ? raw.slice(0, Math.min(...cuts)) : raw;
    line = line.trim();
    if (!line) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      const name = line.slice(1, -1).trim();
      const key = name.toLowerCase();
      if (!sections.has(key)) {
        sections.set(key, { name, order: sections.size, keys: new Map(), keyOrder: [] });
      }
      cur = sections.get(key);
      continue;
    }
    const eq = line.indexOf('=');
    if (eq < 0) continue;
    const k = line.slice(0, eq).trim();
    const v = line.slice(eq + 1).trim();
    if (!cur) continue;
    const kl = k.toLowerCase();
    if (!cur.keys.has(kl)) cur.keyOrder.push(k);
    cur.keys.set(kl, v);
  }
  return sections;
}

export function readIni(path) {
  return parseIni(fs.readFileSync(path, 'utf8'));
}

// Helpers on a parsed section map -----------------------------------------
export function getSec(sections, name) {
  return sections.get(String(name).toLowerCase()) || null;
}

// A "list section" like [InfantryTypes] has keys 0..N -> type id
export function listSection(sections, name) {
  const s = getSec(sections, name);
  if (!s) return [];
  const out = [];
  for (const k of s.keyOrder) {
    const idx = Number(k);
    if (!Number.isFinite(idx)) continue;
    const v = s.keys.get(k.toLowerCase());
    if (v) out.push({ index: idx, id: v });
  }
  out.sort((a, b) => a.index - b.index);
  return out;
}

// parse "a,b,c" into array
export function csv(v) {
  if (v == null) return [];
  return String(v)
    .split(',')
    .map((x) => x.trim())
    .filter((x) => x.length > 0);
}

// parse numeric value possibly with trailing '%'
export function numOf(v, def = null) {
  if (v == null) return def;
  const t = String(v).trim();
  if (t === '') return def;
  if (t.endsWith('%')) {
    const n = Number(t.slice(0, -1));
    return Number.isFinite(n) ? n / 100 : def;
  }
  const n = Number(t);
  return Number.isFinite(n) ? n : def;
}

export function boolOf(v, def = false) {
  if (v == null) return def;
  const t = String(v).trim().toLowerCase();
  if (['yes', 'true', '1', 'on'].includes(t)) return true;
  if (['no', 'false', '0', 'off'].includes(t)) return false;
  return def;
}
