// Bake barrel translation together with the stationary turret for correct occlusion.
import fs from 'node:fs';
import path from 'node:path';
import { renderVxl } from './vxl_lib.mjs';
import { encodePng } from './art_lib.mjs';

export function exportDefenseRecoil(out, id, config, models, palette, descriptor) {
  if (id !== 'GTGCAN') return;
  const meta = JSON.parse(fs.readFileSync(path.join(out, 'vxl', `${descriptor.image}.json`), 'utf8'));
  const { frameW, frameH, facings } = meta;
  const steps = 8, pad = 2;
  const travel = Number(config.extra.BarrelTravel || 0);
  if (!(travel > 0) || models.length !== 2) throw new Error('Expected turret plus recoiling barrel');
  const width = facings * (frameW + pad) + pad;
  const height = steps * (frameH + pad) + pad;
  const rgba = new Uint8Array(width * height * 4);
  const poses = [];
  for (let step = 1; step <= steps; step++) {
    const distance = travel * step / steps;
    const model = { limbs: [...models[0].limbs, ...models[1].limbs.map(limb => {
      const matrix = [...limb.matrix];
      matrix[3] -= distance;
      return { ...limb, matrix };
    })] };
    const origins = [], muzzles = [];
    for (let facing = 0; facing < facings; facing++) {
      const frame = renderVxl(model, { pal: palette, facing, facings });
      const x = Math.round(descriptor.origins[facing][0] + frame.minX - 1);
      const y = Math.round(descriptor.origins[facing][1] + frame.minY - 1);
      if (x < 0 || y < 0 || x + frame.width > frameW || y + frame.height > frameH)
        throw new Error(`${id} recoil exceeds existing canvas: ${step}/${facing}`);
      const origin = [x + 1 - frame.minX, y + 1 - frame.minY];
      origins.push(origin);
      const az = Math.PI / 4 - facing * Math.PI * 2 / facings;
      muzzles.push([
        descriptor.muzzles[facing][0] - descriptor.origins[facing][0] + origin[0] + distance * Math.sin(az),
        descriptor.muzzles[facing][1] - descriptor.origins[facing][1] + origin[1] - distance * 0.5 * Math.cos(az),
      ]);
      for (let row = 0; row < frame.height; row++) {
        const dest = ((pad + (step - 1) * (frameH + pad) + y + row) * width
          + pad + facing * (frameW + pad) + x) * 4;
        rgba.set(frame.rgba.subarray(row * frame.width * 4, (row + 1) * frame.width * 4), dest);
      }
    }
    poses.push({ origins, muzzles });
  }
  const filename = `${id}_recoil.png`;
  fs.writeFileSync(path.join(out, 'bldturret', filename), encodePng(width, height, rgba));
  descriptor.recoil = {
    image: `res://assets/ra2/bldturret/${filename}`, travel, steps,
    compress_seconds: Number(config.extra.BarrelCompressFrames || 3) / 15,
    hold_seconds: Number(config.extra.BarrelHoldFrames || 3) / 15,
    recover_seconds: Number(config.extra.BarrelRecoverFrames || 40) / 15,
    poses, source: 'LOCAL.MIX/GTGCANBARL.VXL', translation_axis: 'model -X',
  };
  fs.writeFileSync(path.join(out, 'bldturret', `${id}.json`), JSON.stringify(descriptor));
  console.log(`${id}: ${steps} barrel positions x ${facings} facings; turret stays fixed`);
}
