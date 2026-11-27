// Export the sound controls referenced by ALL01's positional audio actions.
import fs from 'node:fs';
const [mapPath, soundPath, out] = process.argv.slice(2);
const map = JSON.parse(fs.readFileSync(mapPath,'utf8'));
if(map.audit.id!=='yr_all01umd') throw Error('Expected ALL01UMD');
const ini = {};
let section;
for (const raw of fs.readFileSync(soundPath,'latin1').split(/\r?\n/)) {
  const line=raw.split(';')[0].trim();
  if(line.startsWith('[')) section=ini[line.slice(1,-1).toLowerCase()]={};
  else if(section && line.includes('=')) {
    const i=line.indexOf('=');
    section[line.slice(0,i).trim().toLowerCase()]=line.slice(i+1).trim();
  }
}
const sounds={};
for(const row of Object.values(map.triggers)){
  const a=row.actions.split(',');
  for(let i=1;i<a.length;i+=8) if(a[i]==='99'){
    const name=a[i+2], spec=ini[name.toLowerCase()];
    const list=spec.sounds.trim().toLowerCase().split(/\s+/);
    for(const wav of list) if(!fs.existsSync('assets/ra2/sfx/'+wav+'.wav')) throw Error('Missing '+wav);
    sounds[name]={files:list, volume:Number(spec.volume??100)/100, range:Number(spec.range??10), delay:(spec.delay??'0 0').split(/\s+/).map(Number),pitch:(spec.fshift??'0 0').split(/\s+/).map(Number),limit:Number(spec.limit??1)};
  }
}
fs.writeFileSync(out,JSON.stringify(sounds,null,1)+'\n');