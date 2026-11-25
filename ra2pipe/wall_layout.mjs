import fs from 'node:fs';
import path from 'node:path';

export function loadWallDefinitions(input) {
  const sections = {};
  let current = null;
  for (const raw of fs.readFileSync(path.join(input, 'art.ini'), 'utf8').split(/\r?\n/)) {
    const line = raw.split(';')[0].trim();
    const header = line.match(/^\[([^\]]+)\]$/);
    if (header) { current = sections[header[1].toUpperCase()] = {}; continue; }
    const field = line.match(/^([^=]+)=(.*)$/);
    if (current && field) current[field[1].trim().toLowerCase()] = field[2].trim();
  }
  const walls = {};
  for (const [id, section] of Object.entries(sections))
    if (section.tooverlay?.toUpperCase() === id && section.damagelevels)
      walls[id] = Number(section.damagelevels);
  return walls;
}

// Local wall SHPs contain 16 connection variants per damage level, followed
// by equally sized shadow storage. Unused rubble groups may precede shadows.
export function wallLayout(levels, frameCount) {
  if (levels === undefined) return {};
  if (!Number.isInteger(levels) || levels < 1 || levels > 3 ||
      frameCount % 32 !== 0 || frameCount / 2 < 16 * levels)
    throw new Error(`Unsupported wall sheet: levels=${levels}, frames=${frameCount}`);
  return { wall_layout: { variants: 16, damage_levels: levels, shadow_start: frameCount / 2 } };
}
