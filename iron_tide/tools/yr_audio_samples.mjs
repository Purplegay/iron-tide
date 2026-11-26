import fs from 'node:fs';
export function audioSamples(src,pack,prefix){
const dir='assets/ra2/sfx/'+prefix;fs.mkdirSync(dir,{recursive:true});
const idx=src.read('audio.idx').data,bag=src.read('audio.bag').data;
const records=new Map();for(let o=12;o+36<=idx.length;o+=36)records.set(idx.subarray(o,o+16).toString('ascii').split('\0')[0].toLowerCase(),[16,20,24,28,32].map(k=>idx.readUInt32LE(o+k)));
const steps=[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];
function sample(name){const key=(prefix==='hollywood'?'hol':prefix)+'_'+name;if(pack.entries[key])return key;
 const [off,len,rate,flags,block]=records.get(name),bytes=bag.subarray(off,off+len);let pcm=bytes;
 if(flags&1)throw Error('Unexpected stereo '+name);
 if(flags&8){let samples=[];for(let p=0;p<len;p+=block){let v=bytes.readInt16LE(p),i=bytes[p+2];samples.push(v);for(const b of bytes.subarray(p+4,Math.min(len,p+block)))for(const n of [b&15,b>>4]){let s=steps[i];let d=(s>>3)+((n&1)?s>>2:0)+((n&2)?s>>1:0)+((n&4)?s:0);v=Math.max(-32768,Math.min(32767,v+((n&8)?-d:d)));i=Math.max(0,Math.min(88,i+[-1,-1,-1,-1,2,4,6,8][n&7]));samples.push(v);}}pcm=Buffer.alloc(samples.length*2);samples.forEach((v,i)=>pcm.writeInt16LE(v,i*2));}
 else if(!(flags&2))throw Error('Unexpected encoding '+name);
 const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(36+pcm.length,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(rate,24);h.writeUInt32LE(rate*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(pcm.length,40);fs.writeFileSync(`${dir}/${name}.wav`,Buffer.concat([h,pcm]));pack.entries[key]={file:`${prefix}/${name}.wav`,sampleRate:rate,channels:1,frames:pcm.length/2,durMs:Math.round(pcm.length*500/rate)};return key;
}
return sample;
}
