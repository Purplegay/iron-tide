import {writeFileSync} from 'node:fs';
import {encodePng} from './art_lib.mjs';
import {renderSurface} from './voxel_surface.mjs';

// Coordinates use TTNK.VXL's model space (X forward, Z up). Use its native
// projection, depth test and 2x sprites, with one shared pivot for all facings.
const palette = new Uint8Array(1024);
const colors = ['f4c633','ffdd5c','373a37','5e5143','aa752d','f45c36','351e1b','fff6ca','bb4131','778086'];
colors.forEach((hex,i) => palette.set([...Buffer.from(hex,'hex'),255],i*4));
const head = [], tail = [];
const normals = [];
const normalIds = new Map();
function surface(nx,ny,nz) {
  const len = Math.hypot(nx,ny,nz) || 1;
  const n = [nx,ny,nz].map(v => Math.round(v*12/len));
  const key = n.join(',');
  if (!normalIds.has(key)) {
    normalIds.set(key,normals.length);
    normals.push(n.map(v => v/12));
  }
  return normalIds.get(key);
}
function insidePolygon(x,y,points) {
  let inside = false;
  for(let i=0,j=points.length-1;i<points.length;j=i++){
    const [a,b]=points[i], [c,d]=points[j];
    if ((b>y)!=(d>y) && x<(c-a)*(y-b)/(d-b)+a) inside=!inside;
  }
  return inside;
}
const bolt = [[13,7],[16,7],[20,12],[17,13],[23,15],[20,17],[29,22],[27,27],[15,20],[18,17],[11,15],[16,12]];
// Sample in half-model-pixel increments to match the native HD vehicle sheets.
const step=0.5, min=[-31,-15,0], dims=[94,60,75];
for(let iz=0;iz<dims[2];iz++) for(let iy=0;iy<dims[1];iy++) for(let ix=0;ix<dims[0];ix++){
  const x=min[0]+(ix+0.5)*step, y=min[1]+(iy+0.5)*step, z=(iz+0.5)*step;
  const side=Math.sign(y);
  const add=(array,color,nx,ny,nz)=>array.push({x:ix,y:iy,z:iz,colorIndex:color,normalIndex:surface(nx,ny,nz)});
  // Armoured bearing sits down through the hull's roof. Face markings are enamel
  // inset on the curved shell, so cheeks, eye lenses and seams foreshorten together.
  const hx=(x-0.8)/10.8, hy=y/11.2, hz=(z-15.0)/7.2;
  if(hx*hx+hy*hy+hz*hz<=1){
    let paint=hz<-.45?4:0;
    // Recessed copper collars tie the two electrodes into the curved roof.
    const collar=((x+2.9)/2.4)**2+((Math.abs(y)-6.8)/3.0)**2;
    if(z>18 && collar>0.72 && collar<1.30) paint=collar>1.08?4:3;
    if(x<-4.5 && x>-8.6 && Math.abs(y)<3.0 && z>19.4) {
      paint=Math.cos((x+8.6)*4.3)>0.0?3:9;
    }
    if(x>4){
      const eye=((Math.abs(y)-4.2)/1.55)**2+((z-17.15)/1.78)**2;
      const cheek=((Math.abs(y)-7.55)/2.45)**2+((z-13.4)/2.20)**2;
      if(eye<1) paint=(z>17.55 && Math.abs(y)<4.45)?7:6;
      if(cheek<1) paint=cheek>.77?3:(z>13.5?5:8);
      if(Math.abs(y)<1.02 && Math.abs(z-14.75)<0.60) paint=6;
      if(Math.abs(y)<2.8 && Math.abs(z-(13.6-0.46*Math.sin(Math.abs(y)*1.35)))<0.31) paint=3;
    } else if(x<-3 && (Math.abs(z-14.0)<0.55 || Math.abs(z-16.2)<0.45) && Math.abs(y)<8) paint=3;
    add(head,paint,hx/10.8,hy/11.2,hz/7.2);
  } else if(z>=7 && z<=12 && (x/9.8)**2+(y/10.4)**2<1){
    add(head,z<8.5 || z>11?2:9,x/10,y/10,0.3);
  } else {
    // Flattened solid electrodes with coloured inner panels and graphite tips.
    const t=(z-18.5)/15;
    if(t>=0 && t<=1){
      const width=1.75*(1-t)+2.2*Math.sin(Math.PI*t);
      const ex=(x+2.6+2.8*t)/(0.62*width+0.12);
      const ey=(Math.abs(y)-6.4-5.2*t)/(width+0.1);
      if(ex*ex+ey*ey<=1){
        const paint=t>.67+0.09*ey?2:(ex>.46 && Math.abs(ey)<.57 && t>.19?4:1);
        add(head,paint,ex,side*ey,0.23);
      }
    }
  }
  if(Math.abs(y)<1.25 && insidePolygon(-x,z,bolt))
    add(tail,z<12?3:(Math.abs(y)<0.6?4:0),-0.25,side,Math.abs(y)<0.6?0.8:0.23);
  else if(((x+14.7)/3.4)**2+(y/2.85)**2+((z-8)/3.5)**2<1)
    add(tail,3,(x+14.7)/3.4,y/2.85,(z-8)/3.5);
}
const tile=128, sheet=new Uint8Array(8*tile*8*tile*4);
for(const [part,voxels] of [head,tail].entries()){
  const limb={sizeX:dims[0],sizeY:dims[1],sizeZ:dims[2],minBounds:min,maxBounds:min.map((v,i)=>v+dims[i]*step),
              matrix:[1,0,0,0,0,1,0,0,0,0,1,0],normals,voxels};
  for(let i=0;i<32;i++){
    const f=renderSurface({limbs:[limb]},{pal:palette,facing:i,facings:32});
    const left=(i%8)*tile, top=(part*4+Math.floor(i/8))*tile;
    // Both sheets share a ground-space pivot.
    const pivot=32;
    const dx=(pivot+f.minX-1)*2, dy=(42+f.minY-1)*2;
    for(let y=0;y<2*f.height;y++) for(let x=0;x<2*f.width;x++){
      const src=(y*2*f.width+x)*4;
      if(!f.detailRgba[src+3]) continue;
      if(x+dx<0 || x+dx>=tile || y+dy<0 || y+dy>=tile) throw Error('clipped at '+i);
      sheet.set(f.detailRgba.subarray(src,src+4),((top+y+dy)*8*tile+left+x+dx)*4);
    }
  }
}
writeFileSync(new URL('../iron_tide/assets/cosmetics/skins/pikachu_voxel.png',import.meta.url),encodePng(8*tile,8*tile,sheet));
