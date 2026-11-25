import fs from 'node:fs';
import {decodePng} from './shp_detail_lib.mjs';

// In GGI.SHP the upper house-colour pads mark the shoulders even when the
// weapon extends above the helmet. Bake sockets in native 94x78 frame space.
const project=new URL('../iron_tide/',import.meta.url);
const at=p=>new URL(p,project);
const art=JSON.parse(fs.readFileSync(at('assets/ra2/shp/GGI.json')));
const seq=JSON.parse(fs.readFileSync(at('assets/ra2/shp/GGI.seq.json'))).seq;
const image=decodePng(fs.readFileSync(at('assets/ra2/shp/GGI.png')));
const pins=[];
for(const name of ['Guard','Walk','Idle1','Idle2','Down','Up','FireUp','Deployed','DeployedFire']){
  const {start,per,facings}=seq[name];
  for(let frame=start;frame<start+per*facings;frame++){
    const cell=art.rects[frame],samples=[];
    for(let y=0;y<cell.h;y++)for(let x=0;x<cell.w;x++){
      const off=((cell.y+y)*image.width+cell.x+x)*4;
      const [r,g,b,a]=image.rgba.subarray(off,off+4);
      if(a>128&&b>75&&b>1.6*r&&b>1.25*g)samples.push([x,y]);
    }
    if(!samples.length)throw Error('Missing shoulder pads at '+frame);
    const upper=samples.filter(p=>p[1]<=samples[0][1]+5);
    pins[frame]=[0,1].map(axis=>Math.round(2*(.5+upper.reduce((n,p)=>n+p[axis],0)/upper.length))/2);
  }
}
fs.writeFileSync(at('assets/cosmetics/skins/ggi_shoulder_sockets.json'),JSON.stringify(pins)+'\n');
