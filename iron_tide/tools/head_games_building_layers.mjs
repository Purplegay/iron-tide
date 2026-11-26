import fs from 'node:fs';
import {decodeShp, montageIndexed, encodePngIndexed} from '../../ra2pipe/art_lib.mjs';
import {buildingAnimationRange, separateBuildingHealthRanges} from '../../ra2pipe/building_animation_ranges.mjs';

export function writeHeadGamesLayers(section, theater, source, palette) {
  for (const [id, original] of Object.entries({YAPSYT:'YAPSYT', YATECH:'YATECH', CASLAB:'CASLAB', NACLON:'NACLON', SOV07_BEACON:'NAPSYB'})) {
    const art = section(original);
    function state(key) {
      const anim = section(key);
      const image = anim.image || key;
      const hit = theater.shape(image) || source.read(image+'.shp');
      if (!hit) throw Error('Missing SHP '+image);
      const shp = decodeShp(hit.data);
      const shadow = anim.shadow === 'yes';
      const count = shp.frames.length;
      const frames = shadow ? count/2 : count;
      const resource = id === 'SOV07_BEACON' ? 'SOV07_'+image : image;
      const stem = 'assets/ra2/shp/'+resource;
      const cols = Math.min(12,count);
      const sheet = montageIndexed(shp,cols);
      fs.writeFileSync(stem+'.png',encodePngIndexed(sheet.width,sheet.height,sheet.indices,palette));
      fs.writeFileSync(stem+'.json',JSON.stringify({id:resource,image:resource,source:hit.source,cell:[shp.width,shp.height],cols,count,rects:sheet.rects,dmg:1,shadow},null,1)+'\n');
      return {image:resource,...buildingAnimationRange(image,anim,frames),rate:Number(anim.rate||900),shadow,loopCount:-1};
    }
    const layer = {kind:'activeanim',...state(art.activeanim)};
    if (art.activeanimdamaged) layer.dmg = state(art.activeanimdamaged);
    separateBuildingHealthRanges(layer);
    fs.writeFileSync('assets/ra2/bldanim/'+id+'.json',JSON.stringify({id,layers:[layer]},null,1)+'\n');
  }
}
