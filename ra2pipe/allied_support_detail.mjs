// Coordinates in the original YR grids. Only the exterior side of a solid
// receives raised detail; retain the original normals and remap paint.
const profiles = {
  FV: [42,31,21], FVTUR: [22,22,24], FVTUR1: [29,22,12],
  FVTUR2: [31,11,31], FVTUR3: [21,21,10], CMIN: [58,29,31], CMON: [60,29,34],
};

function ifvPanel(part, x, z, side, original) {
  if (part === 'FV') {
    if (side <= 2 && z < 9) {
      for (const cx of [6,17,30]) {
        const r = Math.hypot(x-cx,z-4.5);
        if (r <= 1.6) return [89,1];
        if (r <= 3.1) return [92,0];
      }
    }
    if (z === 10 && side < 4) return [94,0];
    if (z === 11 && side < 4 && x>2 && x<38) return [89,1];
    if (x>=3 && x<=13 && side<8 && z>=14 && z<=16)
      return [x%3 === 0 ? 90 : 94,x%3 === 0 ? 1 : 0];
  } else if (part === 'FVTUR') {
    // Missile pod stiffeners follow the inclined launcher, not the chassis.
    const band = x + z;
    if (z>9 && side<3 && (band===23 || band===33)) return [89,1];
    if (z<7 && side<9) return [93,0];
  } else if (part === 'FVTUR1') {
    if (x>19 && z<6) return [x===22 ? 95 : (z>=3 ? 89 : 93),0];
    if (x<18 && z===4 && side<4) return [89,1];
  } else if (part === 'FVTUR2') {
    if (z>6 && z<16 && x<12) return [z===9 || z===14 ? 89 : 92,z===9 ? 1 : 0];
    if (z>17 && z<23 && x>16 && side<5) return [z===20 ? 89 : 93,0];
  } else if (part === 'FVTUR3') {
    if (z===3 && side<4) return [89,1];
    if (z>=6 && x>4 && x<17 && side<6) return [x%4===0 ? 92 : 55,0];
  }
  return [original,0];
}

function minerPanel(x, z, side, original) {
  if (side<4 && x>=2 && x<=20 && z>=14 && z<=24) {
    // Strengthening ribs stand proud of the brown ore hopper.
    if ([4,11,18].includes(x)) return [z===24 ? 76 : 78,1];
    if (z===14) return [79,0];
    if (z===24) return [76,1];
  }
  if (side<4 && x>=8 && x<=35 && z<8) {
    if (z===7) return [55,0];
    for (const cx of [10,16,22,28,34]) {
      const r=Math.hypot(x-cx,z-3.3);
      if (r<=1.35) return [90,1];
      if (r<=2.5) return [55,0];
    }
  }
  if (x>=38 && x<=51 && z>=11 && z<=17 && side<6) {
    if (z===11 || x===40) return [90,1];
    if (original>=88 && original<=95 && z>=15) return [89,0];
  }
  return [original,0];
}

export function detailSupportModel(model, name) {
  const part=name.toUpperCase(), dims=profiles[part];
  if (!dims) return model;
  return {...model,limbs:model.limbs.map(limb=>{
    const {sizeX,sizeY,sizeZ}=limb;
    if (dims[0]!==sizeX || dims[1]!==sizeY || dims[2]!==sizeZ)
      throw new Error('Unexpected original VXL dimensions for '+part);
    const key=(x,y,z)=>(z*sizeY+y)*sizeX+x;
    const occupied=new Set(limb.voxels.map(v=>key(v.x,v.y,v.z)));
    const raised=[];
    const voxels=limb.voxels.map(v=>{
      const {x,y,z,colorIndex}=v;
      const side=Math.min(y,sizeY-1-y), outward=y<sizeY/2 ? -1 : 1;
      if ((colorIndex>=16 && colorIndex<=31) || occupied.has(key(x,y+outward,z)) && side!==0)
        return v;
      // CMON's extended rear shifts the corresponding cab/chassis grid by two cells.
      const [color,relief]=part.startsWith('FV') ? ifvPanel(part,x,z,side,colorIndex)
        : minerPanel(x-(part==='CMON' ? 2 : 0),z,side,colorIndex);
      const face={...v,colorIndex:color};
      if (relief && side>0 && x<sizeX-1) raised.push({...face,y:y+outward});
      return face;
    });
    return {...limb,voxels:voxels.concat(raised)};
  })};
}
