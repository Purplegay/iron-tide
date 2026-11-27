// Export retail snow-theater props and civilian building sheets for ALL07SMD.
import fs from 'node:fs';
import {YrSource,sha256} from '../../ra2pipe/lib/yr_source.mjs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {decodeShp,decodePal,frameToRgba,encodePng,montageIndexed,encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {theaterReader} from './theater_shapes.mjs';
import {decodePng,scaleFrame} from '../../ra2pipe/shp_detail_lib.mjs';
const [dir,audit,mode]=process.argv.slice(2);
const oilOnly=mode==='--oil-only';
const source=new YrSource(dir), theater=theaterReader(source,'SNOW');
const mission=JSON.parse(fs.readFileSync(audit,'utf8'));
const map=JSON.parse(fs.readFileSync('data/maps/yr_all07smd.json'));
const rules=parseIni(source.read('rulesmd.ini').data.toString('latin1'));
const iso=decodePal(source.read('isosno.pal').data), unit=decodePal(theater.palette().data);
const folder='assets/maps/yr/allied_finale';fs.mkdirSync(folder,{recursive:true});
const cells=new Set(map.cells.map(r=>r.slice(0,2).join())), [x0,y0]=map.retail_origin;
const point=(x,y)=>[y0-y+0.5,x-x0+0.5];
const props=[], files={}, missing=[];
for(const [cell,id]of oilOnly?[]:Object.entries(mission.tables.Terrain)){
 const p=point(Number(cell)%1000,Math.floor(Number(cell)/1000));if(!cells.has(p.map(Math.floor).join()))continue;
 if(!files[id]){
  const hit=theater.read(id+'.sno')||theater.read(id+'.shp')||source.read(id+'.shp');
  if(!hit){if(!missing.includes(id))missing.push(id);continue;}
  const shp=decodeShp(hit.data),frame=shp.frames[0];
  fs.writeFileSync(`${folder}/${id}.png`,encodePng(shp.width,shp.height,frameToRgba(frame,iso,{canvasW:shp.width,canvasH:shp.height})));
  files[id]={source:hit.source,sha256:sha256(hit.data)};
 }
 props.push([id,...p]);
}
const sites={};
const detailSites=new Set(['CAARMY01','CAARMY02','CARUFGL','CARUFGL_A','CAOILD']);
function writeSheet(id,hit,damageFrames){
 const shp=decodeShp(hit.data), cols=Math.min(8,shp.frames.length), atlas=montageIndexed(shp,cols);
 const shadowStart=shp.frames.length/2;
 if(!Number.isInteger(shadowStart)||!shp.frames.slice(shadowStart).every(f=>f.data.every(p=>p<=1)))throw Error('Unexpected shadow layout '+id);
 const base=`${folder}/${id}`;
 const palette=Buffer.from(unit);
 // Use the same ownership-ramp encoding as the shared oil pump/flag art.
 if(id==='CAOILD')for(let i=16;i<=31;i++){
  const level=unit[i*4]/252;
  [87,168,255].forEach((value,k)=>palette[i*4+k]=Math.round(value*level));
 }
 const png=encodePngIndexed(atlas.width,atlas.height,atlas.indices,palette);
 fs.writeFileSync(base+'.png',png);
 fs.writeFileSync(base+'.json',JSON.stringify({id,source:hit.source,cell:[shp.width,shp.height],cols,count:shp.frames.length,rects:atlas.rects,dmg:damageFrames,shadow_start:shadowStart}));
 if(detailSites.has(id)){
  // Scale each frame in isolation; preserve palette shading and the native alpha silhouette.
  const image=decodePng(png), width=atlas.width*2, height=atlas.height*2, rgba=new Uint8Array(width*height*4);
  for(const rect of atlas.rects){
   const frame=scaleFrame(image,rect), x=2*(rect.x+frame.crop[0]), y=2*(rect.y+frame.crop[1]);
   for(let i=0;i<frame.height;i++)rgba.set(frame.rgba.subarray(i*frame.width*4,(i+1)*frame.width*4),((y+i)*width+x)*4);
  }
  fs.writeFileSync(base+'_detail.png',encodePng(width,height,rgba));
 }
}
for(const row of Object.values(mission.tables.Structures)){
 const [house,id]=row.split(',');if((oilOnly&&id!=='CAOILD')||!['Neutral','Russians'].includes(house)||sites[id])continue;
 const rule=rules.get(id.toLowerCase())?.keys; if(rule?.get('invisibleingame')?.toLowerCase()==='yes')continue;
 const image=rule?.get('image')||id;const hit=theater.shape(image)||source.read(image+'.shp');
 if(!hit){if(!missing.includes(id))missing.push(id);continue;}
 // Live buildings use intact/damaged poses; extra body frames don't set the shadow stride.
 writeSheet(id,hit,2);
 sites[id]={source:hit.source,sha256:sha256(hit.data)};
}
if(oilOnly){
 if(!sites.CAOILD)throw Error('Missing retail snow oil derrick');
 console.log(sites.CAOILD);
 process.exit(0);
}
const flag=theater.shape('CARUFGL_A');
if(!flag)throw Error('Missing retail flag animation');
writeSheet('CARUFGL_A',flag,1);
const layers={CARUFGL_A:{source:flag.source,sha256:sha256(flag.data)}};
fs.writeFileSync('data/ra2/allied_finale_scenery.json',JSON.stringify({props,files,sites,layers,missing},null,1)+'\n');
console.log(props.length,Object.keys(files),Object.keys(sites),missing);
