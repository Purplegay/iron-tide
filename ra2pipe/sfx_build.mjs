import { PROJECT, INPUT, requireMixDirectory } from './paths.mjs';
// sfx_build.mjs — 提取 RA2 音效（LANGUAGE.MIX > 0xad29acfa 的 audio.idx + audio.bag）。
// Godot 不支持 IMA ADPCM WAV → 统一解码为 PCM16。
// 用法: node ra2pipe/sfx_build.mjs needed | all | stats
import { readFileSync, mkdirSync, writeFileSync, readdirSync } from 'node:fs';
import { MixFile, DataStream } from '../tools/ra2bundle.mjs';
const MODE=process.argv[2]||'stats';
function silence(fn){const o=console.log;console.log=()=>{};try{return fn();}finally{console.log=o;}}

// ===== IMA ADPCM 解码 =====
const STEP=[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767];
const ADJ=[-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8];
function nib(pred,idx,nibble,out){
  const step=STEP[idx]; const d=nibble&7; const diff=((2*d+1)*step)>>3;
  if(nibble&8) pred-=diff; else pred+=diff;
  if(pred>32767)pred=32767; else if(pred<-32768)pred=-32768;
  idx+=ADJ[nibble]; if(idx<0)idx=0; else if(idx>88)idx=88;
  out[0]=pred; out[1]=idx; return pred;
}
function decodeIma(data, blockAlign, channels){
  const hdr=4*channels;
  const est=Math.ceil(data.length/blockAlign)*1017*channels;
  const pcm=new Int16Array(est); let o=0;
  const tmp=[0,0];
  for(let bo=0; bo+hdr<=data.length; bo+=blockAlign){
    const end=Math.min(bo+blockAlign,data.length);
    const pred=[],idx=[];
    for(let c=0;c<channels;c++){pred[c]=data.readInt16LE(bo+c*4); idx[c]=data[bo+c*4+2]; if(idx[c]<0)idx[c]=0; if(idx[c]>88)idx[c]=88;}
    for(let c=0;c<channels;c++) pcm[o++]=pred[c];
    if(channels===1){
      for(let i=bo+hdr;i<end;i++){const b=data[i];
        for(const nb of [b&0xf,(b>>4)&0xf]){tmp[0]=pred[0];tmp[1]=idx[0];pcm[o++]=nib(pred[0],idx[0],nb,tmp);pred[0]=tmp[0];idx[0]=tmp[1];}}
    } else {
      for(let i=bo+hdr;i+4<=end;i+=4){
        for(let c=0;c<channels;c++){for(let k=0;k<4;k++){const b=data[i+k];
          for(const nb of [b&0xf,(b>>4)&0xf]){tmp[0]=pred[c];tmp[1]=idx[c];pcm[o++]=nib(pred[c],idx[c],nb,tmp);pred[c]=tmp[0];idx[c]=tmp[1];}}}}
    }
  }
  return pcm.subarray(0,o);
}
function pcm16Wav(pcm, sampleRate, channels){
  const db=pcm.length*2; const b=Buffer.alloc(44+db);
  b.write('RIFF',0,'latin1');b.writeUInt32LE(36+db,4);b.write('WAVE',8,'latin1');
  b.write('fmt ',12,'latin1');b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(channels,22);
  b.writeUInt32LE(sampleRate,24);b.writeUInt32LE(sampleRate*channels*2,28);b.writeUInt16LE(channels*2,32);b.writeUInt16LE(16,34);
  b.write('data',36,'latin1');b.writeUInt32LE(db,40);
  for(let i=0;i<pcm.length;i++)b.writeInt16LE(pcm[i],44+i*2);
  return b;
}

// ===== 解包 =====
const lBuf=readFileSync(`${requireMixDirectory()}/LANGUAGE.MIX`);
let root; silence(()=>{root=new MixFile(new DataStream(new DataView(lBuf.buffer,lBuf.byteOffset,lBuf.length)));});
const ds=root.getDataStart();
let e; for(const h of root.getEntryHashes()) if((h>>>0)===0xad29acfa){e=root.getEntry(h);break;}
const off=ds+e.offset;
let sub; silence(()=>{sub=new MixFile(new DataStream(new DataView(lBuf.buffer,lBuf.byteOffset+off,e.length)));});
const sds=sub.getDataStart();
let idxOff=0,idxLen=0,bagOff=0,bagLen=0;
for(const h of sub.getEntryHashes()){const ce=sub.getEntry(h);const o=off+sds+ce.offset;const mag=lBuf.toString('latin1',o,o+4);
  if(mag==='GABA'){idxOff=o;idxLen=ce.length;} else if(ce.length>1_000_000&&mag!=='RIFF'){bagOff=o;bagLen=ce.length;}}
const idxBuf=lBuf.subarray(idxOff,idxOff+idxLen);
const num=idxBuf.readInt32LE(8);
const entries=[]; let p=12;
for(let i=0;i<num;i++){let z=idxBuf.indexOf(0,p);if(z<0||z>p+16)z=p+16;
  const name=idxBuf.toString('latin1',p,z);p+=16;
  const offset=idxBuf.readUInt32LE(p);p+=4;const length=idxBuf.readUInt32LE(p);p+=4;
  const sampleRate=idxBuf.readUInt32LE(p);p+=4;const flags=idxBuf.readUInt32LE(p);p+=4;
  const chunkSize=idxBuf.readUInt32LE(p);p+=4;
  entries.push({name,offset,length,sampleRate,flags,chunkSize});}
const byName=new Map(entries.map(en=>[en.name.toLowerCase(),en]));

// ===== sound.ini =====
const lib=await import('./art_lib.mjs');
const inTxt=lib.readFileFromMix('sound.ini').toString('latin1');
const sec={};let cur=null;
for(const raw of inTxt.split(/\r?\n/)){const ln=raw.trim();if(!ln||ln.startsWith(';'))continue;const m=ln.match(/^\[(.+?)\]$/);if(m){cur=m[1];sec[cur]=sec[cur]||{};continue;}const kv=ln.match(/^([^=]+?)=(.*)$/);if(kv&&cur)sec[cur][kv[1].trim()]=kv[2].trim();}

// ===== 引用集合 =====
function collectIds(o,out){ if(o==null)return;
  if(Array.isArray(o)){o.forEach(x=>collectIds(x,out));return;}
  if(typeof o==='object'){for(const k of Object.keys(o)){const v=o[k];
    if(typeof v==='string'){ if(/(report|sound|startsound|voicesound|movesound|deploysound)/i.test(k)) out.add(v); }
    else collectIds(v,out);} } }
// 单位语音：ra2_allied.json 的 voice={select:GISelect, move:GIMove, ...}
// 值即 rules.ini 的 VoiceSelect/VoiceMove/VoiceAttack/VoiceFeedback/VoiceSpecialAttack/
// DieSound/CrushSound/DeploySound/UndeploySound → [sound.ini] 的条目名。
// （原版这些条目的 Sounds= 带 '$' 前缀，表「单位语音」；与武器开火音是两套。）
function collectVoices(o,out){ if(o==null)return;
  if(Array.isArray(o)){o.forEach(x=>collectVoices(x,out));return;}
  if(typeof o==='object'){const v=o.voice;
    if(v&&typeof v==='object'&&!Array.isArray(v))for(const x of Object.values(v))if(typeof x==='string'&&x.trim())out.add(x.trim());
    for(const k of Object.keys(o)) if(k!=='voice') collectVoices(o[k],out);} }
const dir=`${PROJECT}/data/ra2`;
const ids=new Set();
// data/ra2/*.json（Step A 产物） + data/ra2_*.json（阵营产物，如 ra2_allied.json）
const scanFiles=[...readdirSync(dir).filter(f=>f.endsWith('.json')).map(f=>`${dir}/${f}`),
  ...readdirSync(`${PROJECT}/data`).filter(f=>/^ra2_.*\.json$/.test(f)).map(f=>`${PROJECT}/data/${f}`)];
for(const p of scanFiles){try{const j=JSON.parse(readFileSync(p,'utf8'));collectIds(j,ids);collectVoices(j,ids);}catch{}}
const needTokens=new Set(); const usedIds=new Set();
for(const id of ids){const s=sec[id]; if(!s)continue; usedIds.add(id);
  if(s.Sounds) for(const t of s.Sounds.split(/\s+/)) needTokens.add(t.replace(/^\$/,'').toLowerCase());}
console.log(`referenced ids=${ids.size} resolved=${usedIds.size} tokens=${needTokens.size}`);
const missing=[...needTokens].filter(t=>!byName.has(t));
console.log(`token hits=${needTokens.size-missing.length} miss=${missing.length} sample=${missing.slice(0,8).join(', ')}`);

const OUT=`${PROJECT}/assets/ra2/sfx`; mkdirSync(OUT,{recursive:true});
const manifest={}; let ok=0,fail=0,bytes=0;
function emit(en){
  if(!en||en.length<=0||en.sampleRate<8000) {fail++;return;}
  const channels=(en.flags&0x01)?2:1;
  const raw=lBuf.subarray(bagOff+en.offset,bagOff+en.offset+en.length);
  if(raw.length!==en.length){fail++;return;}
  let pcm;
  if(en.flags&0x02){pcm=new Int16Array((raw.length/2)|0);for(let i=0;i<pcm.length;i++)pcm[i]=raw.readInt16LE(i*2);}
  else if(en.flags&0x08){pcm=decodeIma(raw, en.chunkSize||512, channels);}
  else {fail++;return;}
  const wav=pcm16Wav(pcm, en.sampleRate, channels);
  const fn=en.name.toLowerCase().replace(/[^a-z0-9_.-]/g,'_')+'.wav';
  writeFileSync(`${OUT}/${fn}`, wav);
  manifest[en.name.toLowerCase()]={file:fn, sampleRate:en.sampleRate, channels, frames:(pcm.length/channels)|0, durMs:Math.round((pcm.length/channels)/en.sampleRate*1000), bytes:wav.length};
  ok++;bytes+=wav.length;
}

if(MODE==='needed'||MODE==='all'){
  if(MODE==='all'){ for(const en of entries) emit(en); }
  else { for(const t of needTokens){ emit(byName.get(t)); } }
  // sound_specs.json：所有被引用的 id 的规格
  const specs={};
  for(const id of usedIds){ const s=sec[id]; specs[id]={sounds:(s.Sounds||'').split(/\s+/).filter(Boolean).map(x=>x.replace(/^\$/,'').toLowerCase()),
    volume:s.Volume!==undefined?Number(s.Volume):1.0, range:s.Range!==undefined?Number(s.Range):10,
    volumeShift:s.VolumeShift, priority:s.Priority, loop:!!Number(s.Loop||0), control:Number(s.Control||0), type:(s.Type||'')}; }
  writeFileSync(`${PROJECT}/data/ra2/sound_specs.json`, JSON.stringify({count:Object.keys(specs).length, specs}));
  writeFileSync(`${PROJECT}/data/ra2/sfx_index.json`, JSON.stringify({count:ok, entries:manifest}));
  console.log(`WRITE ok=${ok} fail=${fail} total=${(bytes/1048576).toFixed(2)}MB -> ${OUT}`);
}
