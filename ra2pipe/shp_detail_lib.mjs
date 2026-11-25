import {inflateSync} from 'node:zlib';

// Read the 8-bit, non-interlaced PNG forms emitted by this project's exporters.
export function decodePng(bytes) {
 if(bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error('Not PNG');
 let width,height,type,palette,alpha;const compressed=[];
 for(let p=8;p<bytes.length;){
  const size=bytes.readUInt32BE(p),kind=bytes.toString('ascii',p+4,p+8),data=bytes.subarray(p+8,p+8+size);
  if(p+12+size>bytes.length)throw Error('Truncated PNG');
  if(kind==='IHDR'){
   width=data.readUInt32BE(0);height=data.readUInt32BE(4);type=data[9];
   if(data[8]!==8||data[12]!==0||![2,3,6].includes(type)||width*height>40000000)throw Error('Unsupported PNG layout');
  }else if(kind==='PLTE')palette=data;else if(kind==='tRNS')alpha=data;else if(kind==='IDAT')compressed.push(data);
  p+=size+12;
 }
 const channels=type===6?4:type===2?3:1,stride=width*channels,raw=inflateSync(Buffer.concat(compressed));
 if(raw.length!==(stride+1)*height)throw Error('PNG scanline size mismatch');
 const pixels=new Uint8Array(stride*height);
 const paeth=(a,b,c)=>{const p=a+b-c,A=Math.abs(p-a),B=Math.abs(p-b),C=Math.abs(p-c);return A<=B&&A<=C?a:B<=C?b:c;};
 for(let y=0;y<height;y++){
  const filter=raw[y*(stride+1)];if(filter>4)throw Error('Unknown PNG filter');
  for(let x=0;x<stride;x++){
   const at=y*stride+x,a=x>=channels?pixels[at-channels]:0,b=y?pixels[at-stride]:0,c=y&&x>=channels?pixels[at-stride-channels]:0;
   pixels[at]=raw[y*(stride+1)+x+1]+[0,a,b,Math.floor((a+b)/2),paeth(a,b,c)][filter];
  }
 }
 const rgba=new Uint8Array(width*height*4);
 for(let i=0;i<width*height;i++){
  if(type===3){const n=pixels[i];if(!palette||n*3+2>=palette.length)throw Error('Invalid palette');rgba.set([palette[n*3],palette[n*3+1],palette[n*3+2],alpha?.[n]??255],i*4);}
  else rgba.set([pixels[i*channels],pixels[i*channels+1],pixels[i*channels+2],channels===4?pixels[i*channels+3]:255],i*4);
  if(!rgba[i*4+3])rgba.fill(0,i*4,i*4+3);
 }
 return {width,height,rgba};
}

// Palette-preserving edge decisions based on the published Scale2x algorithm:
// https://www.scale2x.it/algorithm . Transparent source pixels stay transparent
// so the original sprite's logical footprint and hit-mask bounds are preserved.
export function scaleFrame(image,rect) {
 const {x,y,w,h}=rect;
 if(![x,y,w,h].every(Number.isInteger)||x<0||y<0||w<=0||h<=0||x+w>image.width||y+h>image.height)throw Error('Frame outside atlas');
 let left=w,top=h,right=-1,bottom=-1;
 for(let v=0;v<h;v++)for(let u=0;u<w;u++)if(image.rgba[((y+v)*image.width+x+u)*4+3]){left=Math.min(left,u);top=Math.min(top,v);right=Math.max(right,u);bottom=Math.max(bottom,v);}
 if(right<0)return {crop:[0,0,0,0],width:0,height:0,rgba:new Uint8Array()};
 left=Math.max(0,left-1);top=Math.max(0,top-1);right=Math.min(w-1,right+1);bottom=Math.min(h-1,bottom+1);
 const cw=right-left+1,ch=bottom-top+1,W=cw*2,H=ch*2,out=new Uint8Array(W*H*4);
 const pixel=(u,v)=>{
  u=Math.max(0,Math.min(w-1,u));v=Math.max(0,Math.min(h-1,v));const at=((y+v)*image.width+x+u)*4;
  return ((image.rgba[at]<<24)|(image.rgba[at+1]<<16)|(image.rgba[at+2]<<8)|image.rgba[at+3])>>>0;
 };
 for(let v=top;v<=bottom;v++)for(let u=left;u<=right;u++){
  const center=pixel(u,v);if(!(center&255))continue;
  const north=pixel(u,v-1),south=pixel(u,v+1),west=pixel(u-1,v),east=pixel(u+1,v);
  const colors=[center,center,center,center];
  if(north!==south&&west!==east){
   if(west===north)colors[0]=west;if(north===east)colors[1]=east;
   if(west===south)colors[2]=west;if(south===east)colors[3]=east;
  }
  for(let q=0;q<4;q++){const n=colors[q],at=(((v-top)*2+(q>>1))*W+(u-left)*2+(q&1))*4;out.set([n>>>24,(n>>>16)&255,(n>>>8)&255,n&255],at);}
 }
 return {crop:[left,top,cw,ch],width:W,height:H,rgba:out};
}
