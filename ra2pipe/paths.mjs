import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Resolve relative to this tool, never the terminal's working directory.
export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const PROJECT = path.resolve(process.env.IRON_TIDE_PROJECT || path.join(ROOT, 'iron_tide'));
export const INPUT = path.resolve(process.env.RA2_INPUT_DIR || path.join(ROOT, 'extracted'));
export const CSF = path.resolve(process.env.RA2_CSF || path.join(ROOT, 'refs', 'ts-ra2', 'public', 'general.csf'));
export const MIX = process.env.RA2_MIX_DIR ? path.resolve(process.env.RA2_MIX_DIR) : null;

export function requireMixDirectory() {
  if (!MIX) throw new Error('Set RA2_MIX_DIR to your local game MIX directory before extracting assets.');
  return MIX;
}
