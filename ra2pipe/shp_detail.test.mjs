import test from 'node:test';import assert from 'node:assert/strict';
import {decodePng,scaleFrame} from './shp_detail_lib.mjs';import {encodePng,encodePngIndexed} from './art_lib.mjs';
test('RGBA PNG round trip preserves alpha and normalizes hidden transparent RGB',()=>{
 const rgba=new Uint8Array([10,20,30,255,50,60,70,128,0,0,0,0,1,2,3,255]);
 const result=decodePng(encodePng(2,2,rgba));assert.deepEqual(result.rgba,rgba);
});
test('indexed PNG expands original palette and transparency exactly',()=>{
 const pal=new Uint8Array(1024);pal.set([2,8,30,255],4);pal.set([87,168,255,255],8);
 const result=decodePng(encodePngIndexed(3,1,new Uint8Array([0,1,2]),pal));
 assert.deepEqual(Array.from(result.rgba),[0,0,0,0,2,8,30,255,87,168,255,255]);
});
test('edge scaling preserves palette and source alpha footprint, changes corners',()=>{
 const rgba=new Uint8Array(5*5*4);for(const [x,y] of [[1,1],[2,1],[1,2],[2,2],[3,2],[2,3],[3,3]])rgba.set([87,168,255,255],(y*5+x)*4);
 const result=scaleFrame({width:5,height:5,rgba},{x:0,y:0,w:5,h:5});let changes=0;
 for(let y=0;y<5;y++)for(let x=0;x<5;x++){
  let visible=0;for(let q=0;q<4;q++){const a=(((y*2+(q>>1))*10+x*2+(q&1))*4),alpha=result.rgba[a+3];visible+=!!alpha;if(alpha)assert.deepEqual(Array.from(result.rgba.slice(a,a+4)),[87,168,255,255]);if(alpha!==rgba[(y*5+x)*4+3])changes++;}
  assert.equal(visible>0,rgba[(y*5+x)*4+3]>0);
 }
 assert.ok(changes>0);
});
test('adjacent atlas frames never influence each other',()=>{
 const rgba=new Uint8Array(6*3*4);for(let y=0;y<3;y++)for(let x=0;x<6;x++)rgba.set(x<3?[20,30,40,255]:[250,90,10,255],(y*6+x)*4);
 const result=scaleFrame({width:6,height:3,rgba},{x:0,y:0,w:3,h:3});
 for(let i=0;i<result.rgba.length;i+=4)assert.deepEqual(Array.from(result.rgba.slice(i,i+4)),[20,30,40,255]);
});
test('empty frames stay empty and invalid crop input is rejected',()=>{
 const image={width:2,height:2,rgba:new Uint8Array(16)};
 assert.equal(scaleFrame(image,{x:0,y:0,w:2,h:2}).width,0);
 assert.throws(()=>scaleFrame(image,{x:1,y:0,w:2,h:2}),/outside/);
 assert.throws(()=>decodePng(Buffer.from('invalid')),/PNG/);
});
