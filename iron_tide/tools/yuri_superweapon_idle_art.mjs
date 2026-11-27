import { buildingAnimationRange, separateBuildingHealthRanges } from '../../ra2pipe/building_animation_ranges.mjs';

// The runtime uses inclusive ranges. SHP foreground and shadow each occupy
// one half of these sheets; neither health state may sample a shadow frame.
export function yuriSuperweaponIdleArt(id, section, exportSheet) {
 const art = section(id);
 const layers = [];
 const counts = new Map();
 for (const [prop, kind] of [['activeanim', 'activeanim'], ['superanim', 'idleanim'],
  ['superanimtwo', 'superanimtwo'], ['superanimthree', 'superanimthree'], ['superanimfour', 'superanimfour']]) {
  if (!art[prop]) continue;
  const key = art[prop], spec = section(key), image = spec.image || key;
  if (!counts.has(image)) counts.set(image, exportSheet(image));
  const count = counts.get(image);
  const variant = name => {
   const anim = section(name);
   if ((anim.image || name) !== image || anim.shadow !== 'yes' || count % 2 !== 0) {
    throw Error(`Unexpected Yuri superweapon SHP layout: ${name} / ${image} (${count})`);
   }
   return { image, ...buildingAnimationRange(image, anim, count / 2), rate: Number(anim.rate), shadow: true };
  };
  const layer = { kind, ...variant(key), dmg: variant(art[prop + 'damaged']) };
  separateBuildingHealthRanges(layer);
  if (['superanimtwo', 'superanimthree', 'superanimfour'].includes(kind)) {
   // Retail End/LoopEnd occasionally points at the next pose group. The
   // decoded staged sheets contain equal healthy and damaged foreground runs.
   layer.loopEnd = Math.min(layer.loopEnd, count / 4 - 1);
  }
  if (kind === 'activeanim' && image === 'YAPPET_A') {
   // The first five of the ten foreground frames are healthy lights; frame 5
   // already has the damaged lights. Keep the retail damaged start (6).
   layer.loopEnd = Math.min(layer.loopEnd, 4);
  }
  layers.push(layer);
 }
 return { id, layers };
}
