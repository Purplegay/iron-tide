// Run from the Godot project with RA2_MIX_DIR set to the installed game.
import fs from 'node:fs';
import {readFileFromMix, decodeShp, decodePal, montageIndexed, encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {buildingSheet} from '../../ra2pipe/building_shapes.mjs';
const read = name => decodeShp(readFileFromMix(name + '.SHP'));
const palette = decodePal(readFileFromMix('UNITTEM.PAL'));
for (let i = 16; i < 32; i++) {
  const level = palette[i * 4] / 252;
  [87,168,255].forEach((v,c) => palette[i*4+c] = Math.round(v*level));
}
for (const suffix of ['', '_A', '_B', '_C', '_D', '_F']) {
  const id = 'CAOUTP' + suffix, source = 'CTOUTP' + suffix;
  const shp = read(source), count = shp.frames.length, cols = Math.min(count, 12);
  const {sheet, metadata} = suffix ? {sheet:montageIndexed(shp,cols), metadata:{}} : buildingSheet(shp, source, {CTOUTP:'CTOUTPBB'}, name => ({buf:readFileFromMix(name+'.SHP'),mix:'RA2.MIX'}));
  const dest = 'assets/ra2/shp/' + id;
  fs.writeFileSync(dest+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
  fs.writeFileSync(dest+'.json',JSON.stringify({id,image:id,source:'RA2.MIX/'+source+'.SHP',palette:'UNITTEM.PAL',cell:[shp.width,shp.height],cols,count,rects:sheet.rects,shadow:suffix!=='_F',...(suffix?{}:{dmg:3}),...metadata}));
}
