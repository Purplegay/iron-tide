// Per-corner light continuity on round optics, wheels and hydraulic cylinders.
// Retain hard edges at paint boundaries, panel seams and bevels.
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const normalized=v=>{const l=Math.hypot(...v)||1;return v.map(x=>x/l);};
export function smoothCorners(mesh){
 const byVertex=new Map();
 const key=(p,m)=>m+'|'+p.map(x=>Math.round(x*1000)).join(',');
 for(const f of mesh.faces)for(const p of f.p){
  const k=key(p,f.material);if(!byVertex.has(k))byVertex.set(k,[]);
  const list=byVertex.get(k);if(!list.some(n=>dot(n,f.normal)>.99995))list.push(f.normal);
 }
 for(const f of mesh.faces)f.cornerNormals=f.p.map(p=>{
  const close=byVertex.get(key(p,f.material)).filter(n=>dot(n,f.normal)>.85);
  return normalized(close.reduce((v,n)=>v.map((q,i)=>q+n[i]),[0,0,0]));
 });
}
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const spec={glass:[76,105],silver:[48,105],gold:[34,92],copper:[28,75],metal:[35,82],
 ivory:[48,51],blue:[46,57],oxide:[14,35],ochre:[18,46],rubber:[8,10],ore:[11,38]};
export function finish(face,indices,cs,sn,key,half,sampleSurface){
 const m=face.material,glass=m==='glass',metal=['silver','gold','copper','metal'].includes(m);
 const [power,strength]=spec[m]||[22,35];
 const corners=indices.map(i=>{
  const n=face.cornerNormals[i],v=[n[0]*cs-n[1]*sn,n[0]*sn+n[1]*cs,n[2]];
  if(v[1]*.866+v[2]*.5<0)for(let k=0;k<3;k++)v[k]*=-1;
  return [Math.max(0,dot(v,key)),Math.max(0,dot(v,half)),v[2],v[0]];
 });
 const [a,b,c]=corners,emissive=m==='optic'||m==='lamp';
 return (rgba,at,base,p,A,B,C,shadow)=>{
  const nl=A*a[0]+B*b[0]+C*c[0],nh=A*a[1]+B*b[1]+C*c[1],up=A*a[2]+B*b[2]+C*c[2];
  const fresnel=1-Math.abs(up);
  const blend=shadow?.34:1;
  const light=.40+.60*nl*blend+.10*Math.max(0,up);
  const brushing=metal?.017*Math.sin(p[2]*49+p[0]*.85):0;
  const sheen=Math.pow(nh,power)*strength*(shadow?.23:1);
  const glassBand=glass?Math.exp(-Math.pow((p[0]*.063+p[2]*.12+(A*a[3]+B*b[3]+C*c[3])*.55)%1-.48,2)*38):0;
  const wear=m==='oxide'||m==='ochre'?.015*Math.sin(p[0]*4.3+p[1]*.8)*Math.sin(p[2]*5.6):0;
  const tex=emissive||glass?.3:sampleSurface(p,face.normal);
  const fine=(Math.sin(p[0]*26.7+p[1]*18.1+p[2]*33.1)+Math.sin(p[1]*49.2-p[2]*9.9))*.005;
  const finishVariation=clamp(.72+tex*1.13+fine,.71,1.27);
  const scratch=metal?Math.max(0,tex-.47)*63:Math.max(0,tex-.5)*37;
  for(let k=0;k<3;k++){
   let channel=base[k]*(light+brushing+wear)*finishVariation+sheen+scratch;
   if(glass)channel+=[18,43,62][k]*glassBand+[8,15,20][k]*fresnel;
   if(m==='silver')channel+=[7,10,15][k]*fresnel;
   if(emissive)channel=base[k]*(.81+.19*nh)+18*Math.pow(nh,8);
   rgba[at+k]=clamp(channel,0,255);
  }
  rgba[at+3]=255;
 };
}

