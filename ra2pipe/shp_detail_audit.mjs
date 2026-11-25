import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';import crypto from 'node:crypto';
import {decodePng} from './shp_detail_lib.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../iron_tide'),candidate=path.resolve(process.argv[2]);
const audit=JSON.parse(fs.readFileSync(path.join(candidate,'source-audit.json'))),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
for(const [name,digest] of Object.entries(audit.inputs))assert.equal(hash(fs.readFileSync(path.join(project,name))),digest,name);
for(const item of audit.files)assert.equal(hash(fs.readFileSync(path.join(candidate,item.name))),item.sha256,item.name);
let frames=0,pages=0,pixels=0,changed=0;
const packed=(a,i)=>((a[i]<<24)|(a[i+1]<<16)|(a[i+2]<<8)|a[i+3])>>>0;
for(const file of audit.files.filter(x=>x.name.endsWith('.json')&&!x.name.endsWith('/manifest.json'))){
 const meta=JSON.parse(fs.readFileSync(path.join(candidate,file.name))),native=decodePng(fs.readFileSync(path.join(project,'assets/ra2/shp/'+meta.id+'.png')));
 const original=JSON.parse(fs.readFileSync(path.join(project,'assets/ra2/shp/'+meta.id+'.json')));
 const images=meta.pages.map(p=>{const im=decodePng(fs.readFileSync(path.join(candidate,'assets/ra2/detail/'+p.file)));assert.equal(im.width,p.width);assert.equal(im.height,p.height);return im;});
 pages+=images.length;assert.equal(meta.frames.length,original.rects.length);
 for(let f=0;f<meta.frames.length;f++){
  const e=meta.frames[f],r=original.rects[f];assert.deepEqual(e.source,[r.x,r.y,r.w,r.h]);frames++;
  if(e.page<0){for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++)assert.equal(native.rgba[((r.y+y)*native.width+r.x+x)*4+3],0);continue;}
  const [cx,cy,cw,ch]=e.crop,[px,py,pw,ph]=e.rect,im=images[e.page];assert.equal(pw,cw*2);assert.equal(ph,ch*2);
  assert.ok(px>=0&&py>=0&&px+pw<=im.width&&py+ph<=im.height&&cx>=0&&cy>=0&&cx+cw<=r.w&&cy+ch<=r.h);
  const colors=new Set();
  for(let y=0;y<ch;y++)for(let x=0;x<cw;x++){const p=((r.y+cy+y)*native.width+r.x+cx+x)*4;if(native.rgba[p+3])colors.add(packed(native.rgba,p));}
  for(let y=0;y<ch;y++)for(let x=0;x<cw;x++){
   const at=((r.y+cy+y)*native.width+r.x+cx+x)*4,source=packed(native.rgba,at);let visible=false;
   for(let q=0;q<4;q++){const p=((py+y*2+(q>>1))*im.width+px+x*2+(q&1))*4,n=packed(im.rgba,p);if(n&255){visible=true;assert.ok(colors.has(n),meta.id+' palette');}if(n!==source)changed++;}
   assert.equal(visible,!!native.rgba[at+3],meta.id+' alpha footprint');pixels++;
  }
 }
}
assert.ok(changed>0);const result={frames,pages,native_pixels_checked:pixels,changed_subpixels:changed,source_hashes_verified:true,output_hashes_verified:true};
fs.writeFileSync(path.join(candidate,'pixel-audit.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
