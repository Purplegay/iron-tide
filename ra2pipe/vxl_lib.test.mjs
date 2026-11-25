import assert from 'node:assert/strict';
import test from 'node:test';
import { parseVxl, parseHva, poseVxl, renderVxl } from './vxl_lib.mjs';

const identity = [1,0,0,0,0,1,0,0,0,0,1,0];
test('HVA reads filename, counts, all names, then frame-major transforms', () => {
  const b = Buffer.alloc(24 + 32 + 4 * 48);
  b.write('test-file'); b.writeUInt32LE(2,16); b.writeUInt32LE(2,20);
  b.write('body',24); b.write('turret',40);
  for(let frame=0;frame<2;frame++) for(let section=0;section<2;section++) {
    const m=[...identity]; m[3]=frame*100+section*10;
    m.forEach((n,i)=>b.writeFloatLE(n,56+(frame*2+section)*48+i*4));
  }
  const hva=parseHva(b);
  assert.equal(hva.sections[1].matrices[1][3],110);
  const model={limbs:[{name:'alias0',matrix:[...identity],hvaMultiplier:.1},{name:'alias1',matrix:[...identity],hvaMultiplier:.1}]};
  model.limbs[1].matrix[3]=99;
  assert.equal(poseVxl(model,hva,1).limbs[1].matrix[3],11, 'HVA replaces, not doubles static translation');
  assert.throws(()=>parseHva(b.subarray(0,b.length-1)),/dimensions/);
  assert.throws(()=>poseVxl({limbs:[]},hva),/count mismatch/);
});

test('VXL spans use declared offsets, including noncontiguous reordered columns', () => {
  const bodySize=30,b=Buffer.alloc(802+28+bodySize+92);
  b.write('Voxel Animation'); b.writeUInt32LE(1,16); b.writeUInt32LE(1,20); b.writeUInt32LE(1,24); b.writeUInt32LE(bodySize,28);
  b.write('body',802);
  const body=830,tail=body+bodySize;
  b.writeInt32LE(7,body); b.writeInt32LE(0,body+4);
  b.writeInt32LE(11,body+8); b.writeInt32LE(4,body+12);
  b.set([0,1,41,0,1],body+16); b.set([0,1,82,0,1],body+23);
  b.writeUInt32LE(0,tail);b.writeUInt32LE(8,tail+4);b.writeUInt32LE(16,tail+8);b.writeFloatLE(1/12,tail+12);
  identity.forEach((n,i)=>b.writeFloatLE(n,tail+16+i*4));
  [0,0,0,2,1,1].forEach((n,i)=>b.writeFloatLE(n,tail+64+i*4));b.set([2,1,1,4],tail+88);
  const model=parseVxl(b);
  assert.deepEqual(model.limbs[0].voxels.map(v=>v.colorIndex),[82,41]);
  b.writeInt32LE(999,body);
  assert.throws(()=>parseVxl(b),/span outside/);
});

test('shadow cancels projected height before casting onto a common ground plane', () => {
  const pal=new Uint8Array(1024).fill(255);
  const limb={name:'p',matrix:identity,hvaMultiplier:1,normals:[[0,0,1]],sizeX:1,sizeY:1,sizeZ:1,minBounds:[0,0,0],maxBounds:[1,1,1],voxels:[{x:0,y:0,z:0,colorIndex:1,normalIndex:0}]};
  const up={...limb,matrix:[...identity]};up.matrix[11]=10;
  const ground=renderVxl({limbs:[limb]},{pal,shadow:true});
  const raised=renderVxl({limbs:[up]},{pal,shadow:true});
  assert.ok(Math.abs(raised.minY-ground.minY)<1e-10);
  assert.ok(Math.abs(raised.minX-ground.minX-11)<1e-10);
  const body=renderVxl({limbs:[up]},{pal});
  assert.ok(body.minY<raised.minY-8);
});

test('section rotation also rotates lighting normals', () => {
  const pal=new Uint8Array(1024).fill(255);
  const limb={name:'p',matrix:identity,hvaMultiplier:1,normals:[[1,0,0]],sizeX:1,sizeY:1,sizeZ:1,minBounds:[-.5,-.5,-.5],maxBounds:[.5,.5,.5],voxels:[{x:0,y:0,z:0,colorIndex:1,normalIndex:0}]};
  const rotated={...limb,matrix:[-1,0,0,0,0,-1,0,0,0,0,1,0]};
  const pixels=[limb,rotated].map(l=>renderVxl({limbs:[l]},{pal}).rgba);
  assert.notDeepEqual(pixels[0],pixels[1]);
});
