// IronTide's Grizzly art pass. Coordinates below are in the shipped GTNK grids.
// Keep original physical bounds, HVA section and house-colour indices.
export function detailGrizzly(limb, part) {
  const shapes = { hull: [41, 30, 12], turret: [30, 16, 7], barrel: [26, 4, 4] };
  const [sx, sy, sz] = shapes[part];
  if (sx !== limb.sizeX || sy !== limb.sizeY || sz !== limb.sizeZ)
    throw new Error('Unexpected GTNK dimensions for ' + part);
  const cells = new Map();
  const put = (x, y, z, colorIndex, normalIndex) =>
    cells.set((z * sy * 2 + y) * sx * 2 + x, {x,y,z,colorIndex,normalIndex});
  function normal(x, y, z) {
    let best = -Infinity, index = 0;
    limb.normals.forEach(([nx,ny,nz], i) => {
      const dot = nx*x + ny*y + nz*z;
      if (dot > best) { best = dot; index = i; }
    });
    return index;
  }
  for (const voxel of limb.voxels) {
    for (let dz=0; dz<2; dz++) for (let dy=0; dy<2; dy++) for (let dx=0; dx<2; dx++) {
      const x = voxel.x*2+dx, y = voxel.y*2+dy, z = voxel.z*2+dz;
      const X=(x+.5)/2, Y=(y+.5)/2, Z=(z+.5)/2;
      const side=Math.min(Y, sy-Y);
      let color=voxel.colorIndex;
      if (part === 'hull' && (color < 16 || color > 31)) {
        if (side < 3 && Z >= 5 && Z < 6) color = 94; // shadow beneath fenders
        if (side < 2 && Z >= 8.5 && Z < 9.5) color = 89;
        if (Z >= 9 && X > 2 && X < 11 && side > 7 && side < 12)
          color = Math.floor(X) % 2 ? 94 : 90; // paired engine grilles
      }
      if (part === 'turret' && (color < 16 || color > 31)) {
        if (Z < 1.0) color=95;
        if (Z >= 2.5 && Z < 3.5 && side < 2.5) color=89;
        if (Z >= 3 && side < 1.5 && (X < 4 || X > 22)) continue;
      }
      if (part === 'barrel') {
        // Dark underside, lit top and two raised bands on the recoil sleeve.
        color = Z >= 2 ? 89 : 93;
        if ((X > 3 && X < 4) || (X > 10 && X < 11)) color = 95;
        if (X > 23.5 && X < 24.5) color=88;
      }
      put(x,y,z,color,voxel.normalIndex);
    }
  }
  if (part === 'hull') {
    // Five inset road wheels per side. Raised hubs catch light independently
    // of their dark tyres; retaining the enclosing tread connects the assembly.
    for (const cx of [8,14,20,26,32]) for (const sign of [-1,1]) {
      for (let x=2*cx-5; x<2*cx+5; x++) for (let z=1; z<10; z++) {
        const rx=(x+.5)/2-cx, rz=(z+.5)/2-2.65, r=Math.hypot(rx,rz);
        if (r > 2.25) continue;
        const inset=r<.85 ? 2 : (r<1.8 ? 3 : 4);
        const n=normal(rx*.28,sign,rz*.28);
        for (let d=inset; d<=6; d++)
          put(x,sign<0 ? d : sy*2-1-d,z,r<.85 ? 89 : (r<1.8 ? 92 : 58),n);
      }
    }
  }
  return {...limb,sizeX:sx*2,sizeY:sy*2,sizeZ:sz*2,voxels:[...cells.values()]};
}
