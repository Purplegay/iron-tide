// Read-only YR intake. Reuses the inherited MIX decoder; never executes reference code.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { MixFile, MixEntry, DataStream } from '../../tools/ra2bundle.mjs';

const ROOT_ARCHIVES = ['ra2.mix', 'language.mix', 'ra2md.mix', 'langmd.mix', 'expandmd01.mix'];
const containers = new Map();
for (const stem of ['local', 'conquer', 'conq', 'cameo', 'generic', 'cache', 'ecache', 'art',
  'temperat', 'snow', 'urban', 'urbann', 'desert', 'lunar', 'newurban', 'isotem', 'isosno',
  'isourb', 'isoubn', 'isodes', 'isolun', 'sidec', 'siden', 'side', 'sounds', 'audio']) {
  for (const suffix of ['', 'md', '01', '02', '03', 'md01', 'md02', 'md03', 'c01', 'c02']) {
    const name = `${stem}${suffix}.mix`;
    containers.set(MixEntry.hashFilename(name) >>> 0, name);
  }
}
export const sha256 = data => crypto.createHash('sha256').update(data).digest('hex');

export class YrSource {
  constructor(directory) {
    this.root = fs.realpathSync(directory);
    this.files = new Map();
    this.entries = new Map();
    this.inputs = new Map();
    for (const entry of fs.readdirSync(this.root, { withFileTypes: true })) {
      if (entry.isFile()) {
        const key = entry.name.toLowerCase();
        if (this.files.has(key)) throw new Error(`Ambiguous file casing: ${entry.name}`);
        this.files.set(key, entry.name);
      }
    }
    // Later archives override earlier ones, irrespective of payload size.
    for (const name of ROOT_ARCHIVES) {
      const data = this.loose(name);
      if (data) this.indexMix(data.data, data.source, 0);
    }
  }

  loose(name) {
    if (!/^[a-z0-9_ .-]+$/i.test(name) || name.includes('..')) throw new Error(`Unsafe resource name: ${name}`);
    const actual = this.files.get(name.toLowerCase());
    if (!actual) return null;
    const file = path.join(this.root, actual);
    const data = fs.readFileSync(file);
    const fingerprint = { bytes: data.length, sha256: sha256(data) };
    if (this.inputs.has(actual) && this.inputs.get(actual).sha256 !== fingerprint.sha256) {
      throw new Error(`Source changed during intake: ${actual}`);
    }
    this.inputs.set(actual, fingerprint);
    return { data, source: actual };
  }

  indexMix(data, source, depth) {
    if (depth > 4) throw new Error(`Nested MIX depth exceeds intake limit: ${source}`);
    const savedLog = console.log;
    let mix;
    let malformed = false;
    try {
      console.log = (...parts) => { if (/not enough|error|duplicate hash/i.test(parts.join(' '))) malformed = true; };
      mix = new MixFile(new DataStream(new DataView(data.buffer, data.byteOffset, data.length)));
    } finally { console.log = savedLog; }
    if (malformed) throw new Error(`Malformed MIX index: ${source}`);
    const start = mix.getDataStart();
    if (start > data.length) throw new Error(`Truncated MIX header: ${source}`);
    for (const hash of mix.getEntryHashes()) {
      const entry = mix.getEntry(hash);
      const begin = start + entry.offset;
      if (begin < start || begin + entry.length > data.length) throw new Error(`MIX entry outside file: ${source}`);
      const payload = data.subarray(begin, begin + entry.length);
      this.entries.set(hash >>> 0, { data: payload, source: `${source} > 0x${(hash >>> 0).toString(16)}` });
      const child = containers.get(hash >>> 0);
      if (child) this.indexMix(payload, `${source} > ${child}`, depth + 1);
    }
  }

  read(name) {
    // Loose developer exports are intentionally highest priority, and recorded as such.
    return this.loose(name) || this.entries.get(MixEntry.hashFilename(name.toUpperCase()) >>> 0) || null;
  }

  audit() {
    const inputs = Object.fromEntries(this.inputs);
    for (const [name, expected] of this.inputs) {
      if (sha256(fs.readFileSync(path.join(this.root, name))) !== expected.sha256) {
        throw new Error(`Source changed during intake: ${name}`);
      }
    }
    return inputs;
  }
}
