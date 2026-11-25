// Independent four-pose rotor animation from the local SHAD voxel limbs.
// Only rotor transforms change; the fuselage and shared canvas remain fixed.
import fs from 'node:fs';
import path from 'node:path';
import { readFileFromMix, decodePal, encodePng } from './art_lib.mjs';
import { parseVxl, renderVxl } from './vxl_lib.mjs';

export function rotorPose(model, pose, rotorNames) {
  const angle = pose * Math.PI / 8, c = Math.cos(angle), s = Math.sin(angle);
  const limbs = model.limbs.map(limb => {
    if (!rotorNames.includes(limb.name)) return limb;
    const m = limb.matrix, matrix = [...m];
    for (const row of [0, 4, 8]) {
      matrix[row] = m[row] * c + m[row + 1] * s;
      matrix[row + 1] = -m[row] * s + m[row + 1] * c;
    }
    return { ...limb, matrix };
  });
  return { limbs };
}

export function exportTransportRotors(project) {
  const bytes = readFileFromMix('SHAD.VXL');
  if (!bytes) throw new Error('Missing local SHAD.VXL');
  const model = parseVxl(bytes);
  const rotorNames = ['CYLINDER18', 'CYLINDER09'];
  if (!rotorNames.every(name => model.limbs.some(l => l.name === name)))
    throw new Error('SHAD rotor limb contract changed');
  const pal = decodePal(readFileFromMix('UNITTEM.PAL'));
  for (let i = 16; i < 32; i++) {
    const level = pal[i * 4] / 252;
    [0x57, 0xa8, 0xff].forEach((c, channel) => { pal[i * 4 + channel] = Math.round(c * level); });
    pal[i * 4 + 3] = 0;
  }
  const bodies = [], shadows = [];
  for (let pose = 0; pose < 4; pose++) {
    const { limbs } = rotorPose(model, pose, rotorNames);
    for (let facing = 0; facing < 8; facing++) {
      bodies.push(renderVxl({ limbs }, { pal, facing, facings: 8 }));
      shadows.push(renderVxl({ limbs }, { pal, facing, facings: 8, shadow: true }));
    }
  }
  const all = [...bodies, ...shadows];
  const minX = Math.min(...all.map(f => f.minX)), minY = Math.min(...all.map(f => f.minY));
  const frameW = Math.ceil(Math.max(...all.map(f => f.minX + f.width)) - minX) + 4;
  const frameH = Math.ceil(Math.max(...all.map(f => f.minY + f.height)) - minY) + 4;
  const width = 8 * (frameW + 2) + 2, height = 4 * (frameH + 2) + 2;
  const out = path.join(project, 'assets/ra2/vxl');
  for (const [id, frames] of [['SHAD', bodies], ['SHAD_shd', shadows]]) {
    const pixels = new Uint8Array(width * height * 4);
    frames.forEach((frame, i) => {
      const x = 2 + i % 8 * (frameW + 2) + Math.round(frame.minX - minX);
      const y = 2 + Math.floor(i / 8) * (frameH + 2) + Math.round(frame.minY - minY);
      for (let row = 0; row < frame.height; row++)
        pixels.set(frame.rgba.subarray(row * frame.width * 4, (row + 1) * frame.width * 4),
          ((y + row) * width + x) * 4);
    });
    fs.writeFileSync(path.join(out, id + '.png'), encodePng(width, height, pixels));
    fs.writeFileSync(path.join(out, id + '.json'), JSON.stringify({
      id, image: 'SHAD', vxl: 'SHAD.VXL', facings: 8, facing_offset: 4,
      frameW, frameH, poses: 4, fps: 20, source: 'local SHAD.VXL',
      animated_limbs: rotorNames, adaptation: 'independent rotor loop; original HVA timing not reproduced',
    }));
  }
  console.log('SHAD: 4 rotor poses x 8 facings, fixed fuselage/shared shadow canvas');
}
