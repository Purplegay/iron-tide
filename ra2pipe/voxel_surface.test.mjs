import test from 'node:test';
import assert from 'node:assert/strict';
import {renderSurface,parseVpl} from './voxel_surface.mjs';
const identity=[1,0,0,0,0,1,0,0,0,0,1,0];
const pal=new Uint8Array(1024);for(let i=0;i<256;i++)pal.set([i,255-i,60,255],i*4);
const limb={matrix:identity,normals:[[0,0,1]],sizeX:1,sizeY:1,sizeZ:1,minBounds:[-3,-3,-3],maxBounds:[3,3,3],voxels:[{x:0,y:0,z:0,colorIndex:100,normalIndex:0}]};
const nonempty=im=>{let n=0;for(let i=3;i<im.length;i+=4)if(im[i])n++;return n;};
test('surface fills projected voxel area rather than a single pixel',()=>{
 const r=renderSurface({limbs:[limb]},{pal});
 assert.ok(nonempty(r.rgba)>25);assert.ok(nonempty(r.detailRgba)>100);
 assert.equal(r.detailRgba.length,r.rgba.length*4);
 assert.ok(Array.from(r.rgba).filter((v,i)=>i%4===3).some(v=>v>0&&v<255));
});
test('VPL dimensions reject truncation; output uses lookup colors instead of arbitrary RGB multiplication',()=>{
 const bytes=Buffer.alloc(784+32*256);bytes.writeUInt32LE(16,0);bytes.writeUInt32LE(31,4);bytes.writeUInt32LE(32,8);bytes.fill(210,784);
 const vpl=parseVpl(bytes);assert.throws(()=>parseVpl(bytes.subarray(0,-1)),/dimensions/);
 const r=renderSurface({limbs:[limb]},{pal,vpl});
 for(let i=0;i<r.detailRgba.length;i+=4)if(r.detailRgba[i+3])assert.deepEqual(Array.from(r.detailRgba.slice(i,i+3)),[210,45,60]);
});
test('depth test hides rear surfaces independent of model order',()=>{
 const rear={...limb,matrix:[...identity],voxels:[{...limb.voxels[0],colorIndex:20}]};rear.matrix[11]=-2;
 const a=renderSurface({limbs:[limb,rear]},{pal}),b=renderSurface({limbs:[rear,limb]},{pal});
 assert.deepEqual(a.detailRgba,b.detailRgba);
});
test('all directions cover surfaces, including rotated HVA and shadow projection',()=>{
 for(let facing=0;facing<32;facing++){
  const r=renderSurface({limbs:[limb]},{pal,facing});assert.ok(nonempty(r.rgba)>20);
  const s=renderSurface({limbs:[limb]},{pal,facing,shadow:true});assert.ok(nonempty(s.rgba)>10);
 }
 const raised={...limb,matrix:[...identity]};raised.matrix[11]=10;
 const a=renderSurface({limbs:[limb]},{pal,shadow:true}),b=renderSurface({limbs:[raised]},{pal,shadow:true});
 assert.equal(a.minY,b.minY);assert.ok(b.minX>a.minX);
});
test('surface culling keeps adjacent solid voxels and empty models bounded',()=>{
 const two={...limb,sizeX:2,voxels:[...limb.voxels,{...limb.voxels[0],x:1}]};
 const r=renderSurface({limbs:[two]},{pal});assert.ok(nonempty(r.rgba)>25);
 const empty=renderSurface({limbs:[]},{pal});assert.equal(nonempty(empty.rgba),0);
});
