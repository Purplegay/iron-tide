// Westwood Format80 chunks used by OverlayPack (512 by 512 cells).
export function unpackOverlay(encoded) {
 const input=Buffer.from(encoded,'base64'), chunks=[];
 for(let pos=0;pos<input.length;){
  const bytes=input.readUInt16LE(pos),size=input.readUInt16LE(pos+2);pos+=4;
  if(!bytes&&!size)break;
  const src=input.subarray(pos,pos+bytes),dst=Buffer.alloc(size);pos+=bytes;
  let i=0,j=0;
  while(i<src.length){const tag=src[i++];if(tag===128)break;
   let n,from;
   if(tag<128){n=(tag>>4)+3;from=j-(((tag&15)<<8)|src[i++]);}
   else if(tag<192){n=tag&63;src.copy(dst,j,i,i+n);i+=n;j+=n;continue;}
   else if(tag===254){n=src.readUInt16LE(i);i+=2;dst.fill(src[i++],j,j+n);j+=n;continue;}
   else {n=(tag&63)+3;if(tag===255){n=src.readUInt16LE(i);i+=2;}from=src.readUInt16LE(i);i+=2;}
   if(from<0||from>=j||j+n>size)throw Error('Invalid overlay reference');
   while(n--)dst[j++]=dst[from++];
  }
  if(j!==size)throw Error('Incorrect overlay length');chunks.push(dst);
 }
 const result=Buffer.concat(chunks);if(result.length!==512*512)throw Error('Incorrect map size');return result;
}
