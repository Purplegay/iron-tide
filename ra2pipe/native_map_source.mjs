// Read the user's installed retail maps and terrain; never edits the installation.
import fs from 'node:fs';
import path from 'node:path';
import { YrSource, sha256 } from './lib/yr_source.mjs';
import { parseIni } from './lib/ini.mjs';
import { MixFile, MixEntry, DataStream } from '../tools/ra2bundle.mjs';
import {decodeShp,decodePal,frameToRgba,encodePng} from './art_lib.mjs';

const [directory, destination] = process.argv.slice(2);
if (!directory || !destination) throw new Error('Usage: node native_map_source.mjs GAME_DIR OUTPUT_DIR');
fs.mkdirSync(destination, {recursive:true});
const source = new YrSource(directory);
for (const name of ['isotemp.mix','isosnow.mix','isourb.mix','isotemmd.mix','isosnomd.mix','isourbmd.mix','isodes.mix','isodesmd.mix','isolun.mix','isolunmd.mix','isoubn.mix','isoubnmd.mix']) {
  const file = source.read(name);
  if (file) source.indexMix(file.data,file.source,0);
}
const maps = [['IsleLand.yro','Islands on the Land','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['Ice_Age.yro','Ice Age','SNOW','snowmd.ini','sno','isosno.pal'],
  ['CrctBrd.yro','Circuit Board','URBAN','urbanmd.ini','urb','isourb.pal'],
  ['DeepFrze.yro','Deep Freeze','SNOW','snowmd.ini','sno','isosno.pal'],
  ['RiverRam.yro','River Rampage','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['MojoSprt.yro','Spirit of Mojo One','SNOW','snowmd.ini','sno','isosno.pal']];
const expansionMaps = [
  ['Unrepent.yro','Unrepentant','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['IrvineCa.yro','Irvine, California','NEWURBAN','urbannmd.ini','ubn','isoubn.pal'],
  ['MonsterM.yro','Monster Movie','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['Transylv.yro','Transylvania','NEWURBAN','urbannmd.ini','ubn','isoubn.pal'],
  ['HighExpR.yro','High Explosive Round','DESERT','desertmd.ini','des','isodes.pal'],
  ['MoonPatr.yro','Moon Patrol','LUNAR','lunarmd.ini','lun','isolun.pal']
];
const multiplayerMaps = [
  ['HidVally.map','Hidden Valley','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['DunePatr.map','Dune Patrol','DESERT','desertmd.ini','des','isodes.pal'],
  ['DryHeat.map','Dry Heat','DESERT','desertmd.ini','des','isodes.pal'],
  ['GroundZe.map','Ground Zero','NEWURBAN','urbannmd.ini','ubn','isoubn.pal'],
  ['FourCorners.map','Four Corners','TEMPERATE','temperatmd.ini','tem','isotem.pal'],
  ['TourOfEgypt.map','Tour of Egypt','DESERT','desertmd.ini','des','isodes.pal']
];
const retailMaps = [
  ['BayOPigs','Bay of Pigs','URBAN'], ['Pacific','Pacific Heights','TEMPERATE'],
  ['SeaofIso','Sea of Isolation','TEMPERATE'], ['Tsunami','Tsunami','TEMPERATE'],
  ['Potomac','Potomac Divide','URBAN'], ['amazon','Amazonas Delta','TEMPERATE'],
  ['Lostlake','Lost Lake','TEMPERATE'], ['Shrapnel','Shrapnel Mountain','SNOW'],
  ['Arena','Arena','URBAN'], ['Oceansid','Oceanside','URBAN'],
  ['Hills','The Hills Have Eyes','TEMPERATE'], ['Valley','Valley of Gems','TEMPERATE'],
  ['Dustbowl','Dust Bowl','TEMPERATE'], ['NewHghts','New Heights','TEMPERATE'],
  ['HailMary','Hail Mary','URBAN'], ['Grinder','Meat Grinder','TEMPERATE']
].map(([id,title,theater]) => [id+'.mmx',title,theater,...({TEMPERATE:['temperatmd.ini','tem','isotem.pal'],SNOW:['snowmd.ini','sno','isosno.pal'],URBAN:['urbanmd.ini','urb','isourb.pal']}[theater])]);
const alliedEnds = process.argv.includes('--allied-ends');
const alliedMaps = [
  ['all01umd.map','Time Lapse','NEWURBAN','urbannmd.ini','ubn','isoubn.pal'],
  ['all07smd.map','Brain Dead','SNOW','snowmd.ini','sno','isosno.pal']
];
const multiplayer=process.argv.includes('--multimd');
if (alliedEnds && (multiplayer || process.argv.includes('--retail16') || process.argv.includes('--expedition'))) {
  throw new Error('--allied-ends cannot be combined with other map sets');
}
const archiveName = alliedEnds ? 'mapsmd03.mix' : multiplayer ? 'multimd.mix' : null;
const container=archiveName ? source.loose(archiveName) : null;
if(archiveName && !container)throw new Error('Missing map archive '+archiveName);
const selectedMaps=alliedEnds ? alliedMaps : process.argv.includes('--retail16') ? retailMaps : multiplayer ? multiplayerMaps : process.argv.includes('--expedition') ? expansionMaps : maps;
const manifest=[];
for (const [archive,title,theater,ini,ext,pal] of selectedMaps) {
  const only=process.argv.find(arg=>arg.startsWith('--map='))?.slice(6);
  if(only && only!=='yr_'+archive.split('.')[0].toLowerCase())continue;
  const bytes=container ? container.data : fs.readFileSync(path.join(directory,archive));
  const log=console.log;let mix;
  try {console.log=()=>{};mix=new MixFile(new DataStream(new DataView(bytes.buffer,bytes.byteOffset,bytes.length)));} finally {console.log=log;}
  let raw;
  for (const hash of (container ? [MixEntry.hashFilename(archive)] : mix.getEntryHashes())) {
    const entry=mix.getEntry(hash);
    if(!entry)throw new Error('Missing map member '+archive);
    const offset=mix.getDataStart()+entry.offset;
    const data=bytes.subarray(offset,offset+entry.length);
    if (data.includes(Buffer.from('[IsoMapPack5]'))) {if(raw)throw new Error('Ambiguous map');raw=data;}
  }
  if(!raw)throw new Error('Missing map '+archive);
  if(parseIni(raw.toString('latin1')).get('map').keys.get('theater').toUpperCase()!==theater)throw new Error('Theater mismatch '+archive);
  fs.writeFileSync(path.join(destination,archive+'.map'),raw);
  const config=source.read(ini),palette=source.read(pal);
  if(!config||!palette)throw new Error('Missing theater '+theater);
  fs.writeFileSync(path.join(destination,ini),config.data);
  fs.writeFileSync(path.join(destination,pal),palette.data);
  // High overlays reference Image=BRIDGE/BRIDGB, not a file named BRIDGE1.
  const bridges={};
  const bridgeIds=Array.from({length:28},(_,n)=>'LOBRDG'+String(n+1).padStart(2,'0')).concat(['BRIDGE1','BRIDGE2','BRIDGEB1','BRIDGEB2']);
  for(const id of bridgeIds) {
    const high=!id.startsWith('LOBRDG');
    const image=high?(id.startsWith('BRIDGEB')?'BRIDGB':'BRIDGE'):id;
    const hit=source.read(image+'.'+ext);
    if(!hit)continue;
    const shp=decodeShp(hit.data);const frames=[];
    for(let i=0;i<shp.frames.length;i++) {
      const start=high && id.endsWith('2')?9:0;
      if(high && (i<start || i>=start+9))continue;
      const frame=shp.frames[i];if(!frame.w||!frame.h)continue;
      const filename=`${archive}_${id}_${i}.png`;
      fs.writeFileSync(path.join(destination,filename),encodePng(shp.width,shp.height,frameToRgba(frame,decodePal(palette.data),{canvasW:shp.width,canvasH:shp.height})));
      frames.push({index:high?i-start:i,file:filename});
    }
    bridges[id]={width:shp.width,height:shp.height,frames};
    // The high-deck SHP plane sits 45 px above the canvas centre. Flatten it
    // onto the same navigation plane as the imported road/TMP bridge heads.
    if(high)bridges[id].anchor_y=shp.height/2-45;
  }
  const tiles=[];
  for(const section of parseIni(config.data.toString('latin1')).values()) {
    if(!/^tileset\d+$/i.test(section.name))continue;
    const count=Number(section.keys.get('tilesinset')||0),stem=section.keys.get('filename');
    for(let i=1;i<=count;i++) {
      const name=stem+String(i).padStart(2,'0')+'.'+ext;
      const file=source.read(name);
      tiles.push({name,set:section.name,exists:!!file});
      if(file)fs.writeFileSync(path.join(destination,name),file.data);
    }
  }
  manifest.push({archive,title,theater,ini,pal,tiles,bridges,sha256:sha256(raw),archive_sha256:sha256(bytes),...(container ? {container:archiveName} : {}),...(alliedEnds ? {campaign:true} : {})});
  console.log(archive,tiles.length,'tiles',tiles.filter(t=>t.exists).length,'available');
}
if (!manifest.length) throw new Error('No maps matched the selected map set');
const rules=source.read('rulesmd.ini');fs.writeFileSync(path.join(destination,'rulesmd.ini'),rules.data);
fs.writeFileSync(path.join(destination,'artmd.ini'),source.read('artmd.ini').data);
fs.writeFileSync(path.join(destination,'manifest.json'),JSON.stringify(manifest,null,2));
fs.writeFileSync(path.join(destination,'source_inputs.json'),JSON.stringify(source.audit(),null,2));
