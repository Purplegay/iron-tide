import fs from 'node:fs';
import {YrSource} from './lib/yr_source.mjs';
import {parseVxl,parseHva,poseVxl} from './vxl_lib.mjs';
import {renderSurface} from './voxel_surface.mjs';
import {encodePng} from './art_lib.mjs';

// Paint the SREF hull surface before the independent emitter/turret is drawn.
// XYZ comes from the frontmost visible VXL surface, keeping grooves off empty pixels.
const project=new URL('../iron_tide/',import.meta.url);
const art=JSON.parse(fs.readFileSync(new URL('assets/ra2/unitweapon/SREF.json',project)));
const source=new YrSource(process.argv[2]);
const body=poseVxl(parseVxl(source.read('SREF.VXL').data),parseHva(source.read('SREF.HVA').data),0);
const arteries=[
  [1.15,[[3,5],[-1,8],[-5,8.6],[-8,11.5],[-13,10.4],[-18,12.3],[-24,11.6]]],
  [.63,[[-8,11.5],[-10,13.7],[-15,15]]],
  [.50,[[-18,12.3],[-20,9],[-23,8.1]]],
  [.94,[[-1,8],[4,10],[7,11.9],[10,11],[16,13.5]]],
  [.51,[[7,11.9],[8.5,14.7],[11,15.5]]],
  [.65,[[4,10],[8,7],[11,6.4],[15,3.5]]],
];
const segments=[];
for(const sign of [-1,1])for(const [width,path] of arteries){
  const points=path.map(([x,y])=>[x+(sign<0?1.4*Math.sin(y*.54):0),sign*y]);
  for(let i=1;i<points.length;i++)segments.push([points[i-1],points[i],width*(1-.45*(i-1)/(points.length-1))]);
}
const w=art.frameW*2,h=art.frameH*2,atlasW=w*8,bankH=h*4;
const rgba=new Uint8Array(atlasW*bankH*4*4);
const ce=Math.sqrt(.75),pal=new Uint8Array(1024);
for(let facing=0;facing<32;facing++){
  const im=renderSurface(body,{facing,keepDepth:true,pal});
  const a=Math.PI/4-facing*Math.PI/16,c=Math.cos(a),s=Math.sin(a);
  const [ox,oy]=art.origins[facing];
  let visible=0;
  for(let j=0;j<im.height*2;j++)for(let i=0;i<im.width*2;i++){
    const d=im.depth[j*im.width*2+i];if(!Number.isFinite(d))continue;
    const u=(i+.5)/2+im.minX-1,v=(j+.5)/2+im.minY-1;
    const z=-v*ce+d*.5;if(z<9.5)continue;
    const x=-s*u+c*(.5*v+ce*d),y=c*u+s*(.5*v+ce*d);
    let dist=Infinity;
    for(const [[ax,ay],[bx,by],width] of segments){
      const dx=bx-ax,dy=by-ay;
      const t=Math.max(0,Math.min(1,((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)));
      dist=Math.min(dist,Math.hypot(x-ax-t*dx,y-ay-t*dy)/width);
    }
    if(dist>2.1)continue;
    const px=Math.floor((ox+u)*2),py=Math.floor((oy+v)*2);
    if(px<0||px>=w||py<0||py>=h)throw Error('scar outside hull canvas');
    const at=((Math.floor(facing/8)*h+py)*atlasW+(facing%8)*w+px)*4;
    const core=Math.exp(-dist*dist*1.9),coverage=Math.min(1,(2.1-dist)*1.6);
    rgba.set([80+105*core,17+26*core,25+2*core,Math.round(230*coverage)],at);
    // Three contiguous zones lead from the skirt branches to the emitter socket.
    const zone=Math.min(2,Math.floor(Math.hypot(x-3,y)/9));
    rgba.set([255,105+120*core,34+90*core,Math.round(255*coverage*(.26+.74*core))],at+(zone+1)*atlasW*bankH*4);
    visible++;
  }
  if(visible<50)throw Error('missing solar veins on facing '+facing);
}
fs.writeFileSync(new URL('assets/cosmetics/skins/sref_solar_veins.png',project),encodePng(atlasW,bankH*4,rgba));
