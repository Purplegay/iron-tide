// Runtime animation intervals are inclusive. Keep each original health variant
// within its own SHP segment, including animations specified by Start/End only.
export function buildingAnimationRange(image, section, frames) {
  const number = (key, fallback) => {
    const value = Number.parseInt(section?.[key], 10);
    return Number.isFinite(value) && value >= 0 ? value : fallback;
  };
  // These original crane/light sheets contain equal healthy and damaged runs.
  // Some artmd endpoints include a shadow or the first pose of the other run.
  const half = {GACNST_A:3, NACNST_B:21, GAYARD_C:15, GAYARD_D:42,
    NAREFNL1:3, NAREFNL2:3, NAREFNL3:3, NAREFNL4:3}[image.toUpperCase()];
  if (half && [half * 2, half * 4].includes(frames)) {
    const damaged = number('loopstart', number('start', 0)) > 0;
    const first = damaged ? half : 0;
    return {loopStart:first, loopEnd:first + half - 1, frames:half * 2};
  }
  // The installed GAWEAP_A has 15 upright + 15 damaged images, then shadows.
  // Legacy art.ini's 0..15 / 16..29 crosses the actual health boundary at 15.
  if (image.toUpperCase() === 'GAWEAP_A' && [30, 60].includes(frames)) {
    const damaged = number('loopstart', number('start', 0)) >= 15;
    return {loopStart: damaged ? 15 : 0, loopEnd: damaged ? 29 : 14, frames: 30};
  }
  // Original GAPOWR_A: 8 healthy + 8 damaged frames, then 16 shadow frames.
  // art.ini omits Shadow and has LoopEnd on the next segment's first frame.
  const visible = image.toUpperCase() === 'GAPOWR_A' && frames === 32 ? 16 : frames;
  const start = Math.min(visible - 1, number('loopstart', number('start', 0)));
  // GADEPT A/C explicitly document End=10 as a frame count for both health
  // segments (Start=0/10), unlike the inclusive endpoints in other legacy art.
  const repairArm = ['GADEPT_A', 'GADEPT_C', 'NADEPT_C'].includes(image.toUpperCase());
  const fallbackEnd = repairArm ? start + number('end', 1) - 1 : number('end', visible - 1);
  const end = Math.max(start, Math.min(visible - 1, number('loopend', fallbackEnd)));
  return {loopStart: start, loopEnd: end, frames: visible};
}

export function separateBuildingHealthRanges(layer) {
  const damaged = layer.dmg;
  if (damaged && layer.image === damaged.image && damaged.loopStart > layer.loopStart) {
    layer.loopEnd = Math.min(layer.loopEnd, damaged.loopStart - 1);
  }
}
