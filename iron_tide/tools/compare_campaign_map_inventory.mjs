// Compare independently decoded Structures to read-only snapshots from the real battle.
import fs from 'node:fs';
import path from 'node:path';
const [dir]=process.argv.slice(2);
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const rows=[];
for(const map of read(path.join(dir,'map.json'))){
 const phases=map.map==='yr_sov01'?['opening','jurassic','return']:['opening'];
 const runtime=phases.map(p=>read(path.join(dir,`${map.map}-${p}.json`)));
 const data=read(new URL(`../data/maps/${map.map}.json`,import.meta.url));
 const overrides=map.map==='yr_sov01'?read(new URL('../data/time_shift_assets.json',import.meta.url)).defs:{};
 const evidence=[];
 for(const [id,house,type,hp,x,y,facing,tag] of map.retail_sites){
  const alias=map.map==='yr_sov07'&&type==='NAPSYB'?'SOV07_BEACON':type;
  const anchor=[(x+.5)*55,(y+.5)*55];
  const dims=String(overrides[type]?.foundation??data.site_types[type]?.foundation??'').match(/^(\d+)x(\d+)$/i);
  const center=dims?[anchor[0]+(1-Number(dims[2]))*27.5,anchor[1]+(Number(dims[1])-1)*27.5]:null;
  const matches=Object.fromEntries(phases.map((p,i)=>[p,runtime[i].filter(b=>b.type===alias).filter(b=>{
   const d=b.foundation.match(/^(\d+)x(\d+)$/i);
   const chosen=center??(d?[anchor[0]+(1-Number(d[2]))*27.5,anchor[1]+(Number(d[1])-1)*27.5]:anchor);
   return Math.hypot(b.pos[0]-chosen[0],b.pos[1]-chosen[1])<0.03;
  })]));
  const count=Object.values(matches).map(a=>a.length);
  const status=count.some(n=>n>1)?'重复':Object.values(matches).flat().some(b=>b.render_only)?'光照节点配对':count.some(Boolean)?'坐标配对':hp===0?'零售零耐久未装配':'未匹配';
  evidence.push({id,house,type,hp,cell:[x,y],retailFacing:facing,tag,center,centerSource:overrides[type]?.foundation?'任务覆盖地基':center?'地图地基表':'运行地基回推',status,matches});
 }
 const tally=Object.fromEntries([...new Set(evidence.map(r=>r.status))].map(s=>[s,evidence.filter(r=>r.status===s).length]));
 rows.push({map:map.map,tally,phases,evidence});
 console.log(map.map,tally,'unmatched:',evidence.filter(r=>r.status==='未匹配').map(r=>`${r.type}@${r.cell}/${r.house}`).join(' '));
}
fs.writeFileSync(path.join(dir,'building-comparison.json'),JSON.stringify(rows,null,2)+'\n');
