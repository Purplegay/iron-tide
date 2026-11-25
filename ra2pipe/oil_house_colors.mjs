// Re-export only the oil derrick's ownership markings from the installed urban SHPs.
import fs from 'node:fs';
import path from 'node:path';
import {YrSource} from './lib/yr_source.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed} from './art_lib.mjs';
const [game,out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw Error('Expected local YR folder and new output directory');
const source = new YrSource(game);
fs.mkdirSync(out,{recursive:true});
for (const id of ['CAOILD','CAOILD_F']) {
  const palette = decodePal(source.read('unittem.pal').data);
  const indices = id === 'CAOILD' ? Array.from({length:16},(_,i)=>16+i) : [5,7,184,185,186,187,189,190];
  for (const i of indices) {
    const [r,g,b] = palette.slice(i*4,i*4+3);
    const shade = id === 'CAOILD' ? r/252 : (0.299*r + 0.587*g + 0.114*b)/233;
    [87,168,255].forEach((value,k)=>palette[i*4+k]=Math.round(value*Math.min(1,shade)));
  }
  const shape = decodeShp(source.read(id.replace('CA','CU')+'.shp').data);
  const meta = JSON.parse(fs.readFileSync(new URL('../iron_tide/assets/ra2/shp/'+id+'.json',import.meta.url)));
  if(shape.frames.length!==meta.count || shape.width!==meta.cell[0] || shape.height!==meta.cell[1]) throw Error('Unexpected geometry for '+id);
  if (id === 'CAOILD') {
    // LeaveRubble uses the fourth visible SHP frame with the map's ISO palette.
    const frame = montageIndexed(shape,1,[3]);
    for (const theater of ['tem','sno','urb']) {
      const iso = decodePal(source.read('iso'+theater+'.pal').data);
      fs.writeFileSync(path.join(out,'CAOILD_RUBBLE_'+theater+'.png'),encodePngIndexed(frame.width,frame.height,frame.indices,iso));
    }
  }
  const sheet = montageIndexed(shape,meta.cols);
  fs.writeFileSync(path.join(out,id+'.png'),encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
}
