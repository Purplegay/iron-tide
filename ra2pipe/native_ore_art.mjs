// Export retail overlay rows by variant, columns by density. Spawners have 11 animation frames.
import fs from 'node:fs';
import path from 'node:path';
import {YrSource} from './lib/yr_source.mjs';
import {decodeShp,decodePal,frameToRgba,encodePng} from './art_lib.mjs';
const [directory,out]=process.argv.slice(2);
const source=new YrSource(directory);
fs.mkdirSync(out,{recursive:true});
for(const ext of (process.argv.includes('--expedition') ? ['ubn','des','lun'] : ['tem','sno','urb'])){
  const overlayPalette = {tem:'temperat.pal', sno:'snow.pal', urb:'urban.pal',ubn:'urbann.pal',des:'desert.pal',lun:'lunar.pal'}[ext];
  for(const [stem,rows,cols] of [['tib',12,12],['gem',12,12],['tibtre',3,11]]){
    // TIB/GEM are overlays. Terrain with SpawnsTiberium uses the unit palette.
    if (ext === 'lun' && stem === 'tibtre') continue; // No ore spawners on Moon Patrol.
    const paletteName = stem === 'tibtre' ? 'unit'+ext+'.pal' : overlayPalette;
    const pal=decodePal(source.read(paletteName).data);
    const sprites=[];
    for(let row=0;row<rows;row++){
      const filename=stem+String(row+1).padStart(2,'0')+'.'+ext;
      const hit=source.read(filename);
      if(!hit)throw Error('Missing native ore art '+filename);
      const shp=decodeShp(hit.data);
      if(shp.frames.length<cols)throw Error('Missing density frames '+filename);
      sprites.push(shp);
    }
    const width=Math.max(...sprites.map(s=>s.width));
    const height=Math.max(...sprites.map(s=>s.height));
    const pixels=Buffer.alloc(width*cols*height*rows*4);
    for(let row=0;row<rows;row++){
      const shp=sprites[row];
      for(let col=0;col<cols;col++){
        const bytes=Buffer.from(frameToRgba(shp.frames[col],pal,{canvasW:shp.width,canvasH:shp.height}));
        const dx=Math.floor((width-shp.width)/2),dy=Math.floor((height-shp.height)/2);
        for(let y=0;y<shp.height;y++)bytes.copy(pixels,((row*height+dy+y)*cols*width+col*width+dx)*4,y*shp.width*4,(y+1)*shp.width*4);
      }
    }
    fs.writeFileSync(path.join(out,stem+'_'+ext+'.png'),encodePng(width*cols,height*rows,pixels));
  }
}
