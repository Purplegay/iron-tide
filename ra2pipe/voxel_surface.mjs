// Independent orthographic surface rasterizer. Native logical pixels plus 2x detail.
// Original VPL tables are consumed; selecting lighting levels remains a Godot adapter.
export function parseVpl(bytes) {
 if(bytes.length<784) throw Error('Truncated VPL header/palette');
 const first=bytes.readUInt32LE(0),last=bytes.readUInt32LE(4),count=bytes.readUInt32LE(8);
 if(first>last||last>255||count<9||count>256||bytes.length!==784+count*256) throw Error('Invalid VPL dimensions');
 return {first,last,count,tables:bytes.subarray(784)};
}
const faces=[[[1,0,0],[1,3,7,5]],[[-1,0,0],[0,4,6,2]],[[0,1,0],[2,6,7,3]],[[0,-1,0],[0,1,5,4]],[[0,0,1],[4,5,7,6]],[[0,0,-1],[0,2,3,1]]];
const apply=(m,p)=>[0,4,8].map(i=>m[i]*p[0]+m[i+1]*p[1]+m[i+2]*p[2]+m[i+3]);
const edge=(a,b,x,y)=>(b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]);
export function renderSurface(model,opts={}) {
 const scale=2,pal=opts.pal,vpl=opts.vpl,shadow=!!opts.shadow;
 if(!pal||pal.length!==1024) throw Error('RGBA palette required');
 const az=Math.PI/4-(opts.facing||0)*Math.PI*2/(opts.facings||32),c=Math.cos(az),s=Math.sin(az),ce=Math.sqrt(3)/2;
 const right=[-s,c,0],up=[-c*.5,-s*.5,ce],toward=[c*ce,s*ce,.5];
 const dot=(a,b)=>a.reduce((v,n,i)=>v+n*b[i],0);
 const project=p=>{
  let x=dot(p,right),y=-dot(p,up);
  if(shadow){const h=p[2]-(opts.shadowGround||0);x+=Math.max(0,h)*1.10;y+=h*ce;}
  return [x,y,dot(p,toward)];
 };
 const triangles=[];
 let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
 for(const limb of model.limbs){
  const dims=[limb.sizeX,limb.sizeY,limb.sizeZ],steps=dims.map((n,i)=>(limb.maxBounds[i]-limb.minBounds[i])/n);
  const occupied=new Set(limb.voxels.map(v=>`${v.x},${v.y},${v.z}`));
  for(const voxel of limb.voxels){
   const xyz=[voxel.x,voxel.y,voxel.z],normal=limb.normals[voxel.normalIndex]||[0,0,1],m=limb.matrix;
   const n=[0,4,8].map(i=>m[i]*normal[0]+m[i+1]*normal[1]+m[i+2]*normal[2]);
   const length=Math.hypot(...n)||1;n.forEach((v,i)=>n[i]=v/length);
   const illumination=Math.max(0,Math.min(1,(-.45*dot(n,right)+.80*dot(n,up))/Math.hypot(.45,.80)));
   // Table 8 is the local VPL's neutral ramp; tables 0..7 supply its dark ramps.
   // Do not invent overbright colors or multiply a second RGB shade over VPL output.
   const index=vpl?vpl.tables[Math.round(illumination*8)*256+voxel.colorIndex]:voxel.colorIndex;
   const rgb=shadow?[0,0,0]:[0,1,2].map(i=>pal[index*4+i]*(vpl?1:(.42+.58*illumination)));
   const vertices=Array.from({length:8},(_,bits)=>project(apply(m,xyz.map((v,i)=>limb.minBounds[i]+(v+((bits>>i)&1))*steps[i]))));
   for(const [delta,indices] of faces){
    if(occupied.has(xyz.map((v,i)=>v+delta[i]).join(',')))continue;
    const q=indices.map(i=>vertices[i]);
    for(const p of q){minX=Math.min(minX,p[0]);minY=Math.min(minY,p[1]);maxX=Math.max(maxX,p[0]);maxY=Math.max(maxY,p[1]);}
    triangles.push({p:[q[0],q[1],q[2]],rgb},{p:[q[0],q[2],q[3]],rgb});
   }
  }
 }
 if(!triangles.length)return {width:1,height:1,minX:0,minY:0,rgba:new Uint8Array(4),detailRgba:new Uint8Array(16)};
 minX=Math.floor(minX);minY=Math.floor(minY);
 const width=Math.ceil(maxX-minX)+3,height=Math.ceil(maxY-minY)+3,W=width*scale,H=height*scale;
 const detailRgba=new Uint8Array(W*H*4),zbuffer=new Float64Array(W*H).fill(-Infinity);
 for(const triangle of triangles){
  const [a,b,d]=triangle.p.map(p=>[(p[0]-minX+1)*scale,(p[1]-minY+1)*scale,p[2]]);
  const area=edge(a,b,d[0],d[1]);if(Math.abs(area)<1e-9)continue;
  const x0=Math.max(0,Math.floor(Math.min(a[0],b[0],d[0]))),x1=Math.min(W-1,Math.ceil(Math.max(a[0],b[0],d[0])));
  const y0=Math.max(0,Math.floor(Math.min(a[1],b[1],d[1]))),y1=Math.min(H-1,Math.ceil(Math.max(a[1],b[1],d[1])));
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
   const u=edge(b,d,x+.5,y+.5)/area,v=edge(d,a,x+.5,y+.5)/area,w=1-u-v;
   if(u< -1e-7||v< -1e-7||w< -1e-7)continue;
   const at=y*W+x,depth=u*a[2]+v*b[2]+w*d[2];// Coplanar faces from overlapping limbs have no unique front face. Resolve
   // equal depths by color, not traversal order; retain double precision depth.
   const previous=zbuffer[at];
   if(depth<previous-1e-8)continue;
   if(Math.abs(depth-previous)<=1e-8){
    const incoming=triangle.rgb.reduce((v,n)=>v*256+Math.trunc(n),0);
    const existing=detailRgba[at*4]*65536+detailRgba[at*4+1]*256+detailRgba[at*4+2];
    if(incoming<=existing)continue;
   }
   zbuffer[at]=depth;for(let k=0;k<3;k++)detailRgba[at*4+k]=triangle.rgb[k];detailRgba[at*4+3]=255;
  }
 }
 // Coverage-aware native image is also the authoritative logical hit mask.
 const rgba=new Uint8Array(width*height*4);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const sum=[0,0,0];let covered=0;
  for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++){
   const p=((y*2+dy)*W+x*2+dx)*4;if(!detailRgba[p+3])continue;
   covered++;for(let k=0;k<3;k++)sum[k]+=detailRgba[p+k];
  }
  const p=(y*width+x)*4;if(!covered)continue;
  for(let k=0;k<3;k++)rgba[p+k]=Math.round(sum[k]/covered);rgba[p+3]=Math.round(255*covered/4);
 }
 return {width,height,minX,minY,rgba,detailRgba,...(opts.keepDepth ? {depth:zbuffer} : {})};
}
