// Westwood CSF (string table) parser.
// Header: magic 'CSF ' (0x43534620), version u32, numLabels u32, numStrings u32,
//         unused u32, language u32.
// Label:  magic 'LBL ', numPairs u32, nameLen u32 (chars), name(nameLen bytes)
// Value:  magic 'STR ' (0x53545220) or 'STRW' (0x53545257), len u32 (chars),
//         value bytes (len*2) XOR 0xFF, then UTF-16LE. STRW adds 4 extra bytes.
import fs from 'node:fs';

const LBL = 0x4c424c20;
const STRW = 0x53545257;

function csfDecodeString(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 2) {
    const lo = bytes[i] ^ 0xff;
    const hi = bytes[i + 1] ^ 0xff;
    s += String.fromCharCode(lo | (hi << 8));
  }
  return s;
}

export function parseCsf(buf) {
  if (buf.readUInt32LE(0) !== 0x43534620) throw new Error('bad CSF magic');
  const version = buf.readUInt32LE(4);
  const numLabels = buf.readUInt32LE(8);
  const numStrings = buf.readUInt32LE(12);
  const language = buf.readUInt32LE(20);
  let p = 24;
  const map = new Map(); // UPPERCASE label -> value
  const order = [];
  for (let i = 0; i < numLabels; i++) {
    if (p + 4 > buf.length) break;
    const m = buf.readUInt32LE(p);
    if (m !== LBL) throw new Error(`expected LBL at ${p}, got 0x${m.toString(16)}`);
    p += 4;
    const numPairs = buf.readUInt32LE(p); p += 4;
    const nameLen = buf.readUInt32LE(p); p += 4;
    const name = buf.toString('latin1', p, p + nameLen); p += nameLen;
    const key = name.toUpperCase();
    if (numPairs !== 1) { map.set(key, ''); if (!order.includes(key)) order.push(key); continue; }
    const sm = buf.readUInt32LE(p); p += 4;
    const vLen = buf.readUInt32LE(p); p += 4;
    let val = '';
    if (vLen > 0) {
      val = csfDecodeString(buf.subarray(p, p + vLen * 2));
      p += vLen * 2;
    }
    val = val.replace(/\u0000+$/g, '');
    if (sm === STRW) {
      const extraLen = buf.readUInt32LE(p); p += 4;
      if (extraLen > 0) p += extraLen;
    }
    if (!map.has(key)) order.push(key);
    map.set(key, val);
  }
  return { version, numLabels, numStrings, language, map, order };
}

export function readCsf(path) {
  return parseCsf(fs.readFileSync(path));
}
