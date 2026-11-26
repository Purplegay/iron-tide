import {MixFile, MixEntry, DataStream} from '../../tools/ra2bundle.mjs';

// Only mount this theater's archives. Several theaters publish the same filename.
const theaters = {
 NEWURBAN: ['N', 'ubn', ['isoubnmd','isoubn','ubn','urbann']],
 SNOW: ['A', 'sno', ['isosnomd','snowmd','isosnow','snow','sno']],
 TEMPERATE: ['T', 'tem', ['isotemp','isotemmd','temperat','tem']],
 URBAN: ['U', 'urb', ['isourbmd','isourb','urb','urban']],
 DESERT: ['D', 'des', ['isodesmd','desert','des','isodes']],
 LUNAR: ['L', 'lun', ['isolunmd','isolun','lun','lunar']],
};
export const theaterNames = Object.keys(theaters);

export function theaterReader(source, theater) {
 const [letter, suffix, names] = theaters[theater];
 const archives = [...names,'genermd','generic'].flatMap(name => {
  const hit = source.read(name+'.mix');
  if (!hit) return [];
  const bytes = hit.data;
  const mix = new MixFile(new DataStream(new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength)));
  return [{bytes,mix,path:hit.source.replace(/0x[0-9a-f]+$/i,name+'.mix')}];
 });
 function read(filename) {
  const hash = MixEntry.hashFilename(filename.toUpperCase()) >>> 0;
  for (const {bytes,mix,path} of archives) {
   const entry = mix.getEntry(hash);
   if (!entry) continue;
   const offset = mix.getDataStart()+entry.offset;
   if (offset+entry.length>bytes.length) throw Error('Invalid MIX entry '+path+' > '+filename);
   return {data:bytes.subarray(offset,offset+entry.length),source:path+' > '+filename};
  }
  return null;
 }
 return {
  read,
  palette: () => read('unit'+suffix+'.pal') || source.read('unit'+suffix+'.pal'),
  shape(id) {
   const stem = char => id[0]+char+id.slice(2)+'.shp';
   // Some U-prefixed files (e.g. YUGGUN) actually ship inside URBANN.MIX.
   const letters = theater==='NEWURBAN' ? [letter,'U','G',id[1]] : [letter,'G',id[1]];
   for (const char of new Set(letters)) {
    const hit = read(stem(char));
    if (hit) return hit;
   }
   return null;
  },
 };
}
