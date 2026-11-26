import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import crypto from 'node:crypto';
import {decodePng,scaleFrame} from './shp_detail_lib.mjs';import {encodePng} from './art_lib.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),project=path.join(root,'iron_tide');
const out=path.resolve(process.argv[2]||'');
if(!process.argv[2]||out===root||out.startsWith(root+path.sep)||fs.existsSync(out))throw Error('Use a new external candidate directory');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');const audit={inputs:{},files:[],frames:0,pages:0,skipped:[]};
function write(name,bytes){const p=path.join(out,name);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes);audit.files.push({name,sha256:hash(bytes)});}
const selected = new Set(process.argv.slice(3));
const nativeRoot=path.join(project,'assets/ra2/shp');
const names=fs.readdirSync(nativeRoot).filter(n=>n.endsWith('.png') && (!selected.size || selected.has(n.slice(0,-4))));
for(const id of selected){
 if(!id.includes('/'))continue;
 if(!/^theaters\/[a-z]+\/[A-Z0-9_]+$/.test(id))throw Error('Invalid theater sheet '+id);
 names.push(id+'.png');
}
for(const name of names.sort()){
 const id=name.slice(0,-4),prefix='assets/ra2/shp/',raw=fs.readFileSync(path.join(project,prefix+name)),json=fs.readFileSync(path.join(project,prefix+id+'.json'));
 const meta=JSON.parse(json),image=decodePng(raw);if(!Array.isArray(meta.rects))throw Error(id+': no frame map');
 audit.inputs[prefix+name]=hash(raw);audit.inputs[prefix+id+'.json']=hash(json);
 if(!image.width||!image.height){audit.skipped.push({id,reason:'pre-existing zero-size placeholder'});continue;}
 const frames=[],pages=[];let placements=[],cursorX=2,cursorY=2,rowH=0,usedW=0,usedH=0;
 function flush(){
  if(!placements.length)return;const W=usedW+2,H=usedH+2,rgba=new Uint8Array(W*H*4);
  for(const p of placements)for(let y=0;y<p.im.height;y++)rgba.set(p.im.rgba.subarray(y*p.im.width*4,(y+1)*p.im.width*4),((p.y+y)*W+p.x)*4);
  const filename=`${id}_${pages.length}.png`;write('assets/ra2/detail/'+filename,encodePng(W,H,rgba));pages.push({file:filename,width:W,height:H});
  placements=[];cursorX=2;cursorY=2;rowH=0;usedW=0;usedH=0;
 }
 for(const rect of meta.rects){
  const im=scaleFrame(image,rect),entry={source:[rect.x,rect.y,rect.w,rect.h],crop:im.crop,page:-1,rect:[0,0,0,0]};
  if(im.width){
   if(im.width+4>2048||im.height+4>2048)throw Error(id+': oversized frame');
   if(cursorX+im.width+2>2048){cursorX=2;cursorY+=rowH+2;rowH=0;}
   if(cursorY+im.height+2>2048)flush();
   entry.page=pages.length;entry.rect=[cursorX,cursorY,im.width,im.height];placements.push({im,x:cursorX,y:cursorY});
   usedW=Math.max(usedW,cursorX+im.width);usedH=Math.max(usedH,cursorY+im.height);rowH=Math.max(rowH,im.height);cursorX+=im.width+2;
  }
  frames.push(entry);
 }
 flush();audit.frames+=frames.length;audit.pages+=pages.length;
 write('assets/ra2/detail/'+id+'.json',JSON.stringify({id,method:'palette-edge-2x',source_size:[image.width,image.height],source_sha256:hash(raw),pages,frames}));
 console.log(`${id}: ${frames.length} frames / ${pages.length} cropped pages`);
}
if(!selected.size) write('assets/ra2/detail/manifest.json',JSON.stringify({method:'palette-edge-2x',sources:Object.keys(audit.inputs).filter(x=>x.endsWith('.png')&&!audit.skipped.some(s=>x.endsWith('/'+s.id+'.png'))),skipped:audit.skipped,frames:audit.frames,pages:audit.pages}));
fs.writeFileSync(path.join(out,'source-audit.json'),JSON.stringify(audit,null,2));console.log(JSON.stringify({frames:audit.frames,pages:audit.pages,files:audit.files.length}));
