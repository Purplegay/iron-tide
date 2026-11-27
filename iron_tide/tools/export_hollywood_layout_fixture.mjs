// Export original playable-area Structures for the Hollywood battle layout regression.
import fs from 'node:fs';
import {parseIni} from '../../ra2pipe/lib/ini.mjs';
import {sha256} from '../../ra2pipe/lib/yr_source.mjs';
const [file,out='tests/hollywood_retail_layout.json']=process.argv.slice(2);
const raw=fs.readFileSync(file);
if(sha256(raw)!=='168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303')throw Error('Not retail ALL02UMD');
const map=parseIni(raw.toString('latin1'));
const data=JSON.parse(fs.readFileSync('data/maps/yr_all02umd.json','utf8'));
const [x0,y0]=data.origin;
const inside=new Set(data.cells.map(row=>row.slice(0,2).join(',')));
const rows=[...map.get('structures').keys.values()].map(line=>{
 const [house,id,,x,y]=line.split(',');return [id,Number(x),Number(y),house];
}).filter(([,x,y])=>inside.has([y0-y,x-x0].join(',')));
if(rows.length!==368)throw Error('Unexpected playable-area row count');
fs.writeFileSync(out,'[\n'+rows.map(r=>JSON.stringify(r)).join(',\n')+'\n]\n');
