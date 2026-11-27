// A Tag attached to a map object activates the whole linked trigger chain.
export function triggerBindings(map,id){
 const rows=section=>map.get(section)?.keys??new Map();
 const chain=new Set([id.toLowerCase()]);
 for(let previous=-1;previous!==chain.size;){
  previous=chain.size;
  for(const [key,definition] of rows('triggers')){
   if(chain.has(definition.split(',')[1].toLowerCase()))chain.add(key);
  }
 }
 const tags=[...rows('tags')].filter(([,definition])=>chain.has(definition.split(',').at(-1).toLowerCase())).map(([key])=>key);
 const uses=[];
 for(const [section,record] of map){
  if(section==='tags')continue;
  for(const [key,value] of record.keys){
   const fields=value.split(',');
   if(fields.some(f=>tags.includes(f.trim().toLowerCase())))uses.push({section,key,fields});
  }
 }
 return {tags,uses};
}
