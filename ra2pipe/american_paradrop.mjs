// Export the US support cameo, targeting cursor and temperate parachute from local YR.
import fs from 'node:fs';
import path from 'node:path';
import {YrSource} from './lib/yr_source.mjs';
import {decodePal,decodeShp,montageIndexed,encodePngIndexed} from './art_lib.mjs';
import {parseIni,getSec} from './lib/ini.mjs';
const [game,out] = process.argv.slice(2);
if (!game || !out || fs.existsSync(out)) throw Error('Expected local YR folder and new output directory');
const source = new YrSource(game);
const read = name => source.read(name).data;
const section = (ini,id) => getSec(ini,id).keys;
const rules = parseIni(read('rulesmd.ini').toString('latin1')), art = parseIni(read('artmd.ini').toString('latin1'));
const general = section(rules,'General'), power = section(rules,section(rules,'AMRADR').get('superweapon'));
function save(file,bytes) { const p = path.join(out,file); fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes); }
function sheet(name,pal,cols,frames,file) {
  const shp=decodeShp(read(name)), image=montageIndexed(shp,cols,frames);
  save(file+'.png',encodePngIndexed(image.width,image.height,image.indices,decodePal(read(pal))));
  return {cell:[shp.width,shp.height],rects:image.rects,count:image.rects.length};
}
const canopy=general.get('parachute'), animation=section(art,canopy), end=Number(animation.get('loopend'));
const image=sheet(canopy+'.shp','unittem.pal',8,Array.from({length:end+1},(_,i)=>i),'shp/'+canopy);
save('shp/'+canopy+'.json',JSON.stringify({id:canopy,...image})+'\n');
sheet(power.get('sidebarimage')+'.shp','cameo.pal',1,[0],'cameo/'+power.get('sidebarimage'));
sheet('mouse.shp','mousepal.pal',10,Array.from({length:10},(_,i)=>259+i),'cursors/american_paradrop');
save('american_paradrop.json',JSON.stringify({
  type:power.get('type'),ui_name:'美国大兵空降',sidebar_image:power.get('sidebarimage'),
  recharge_seconds:Number(power.get('rechargetime'))*60, infantry:general.get('amerparadropinf'),
  count:Number(general.get('amerparadropnum')),plane:general.get('paradropplane')||'PDPLANE',
  radius_leptons:Number(general.get('paradropradius')),fall_leptons:Math.abs(Number(general.get('parachutemaxfallrate'))),
  chute:canopy,loop_start:Number(animation.get('loopstart')),loop_end:end,fps:Number(animation.get('rate'))/60
},null,2)+'\n');
