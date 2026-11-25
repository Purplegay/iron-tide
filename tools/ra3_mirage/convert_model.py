import pathlib,struct,json,math
from PIL import Image
import argparse
parser=argparse.ArgumentParser(description='Convert original RA3 compiled Mirage mesh blocks to Godot geometry.')
parser.add_argument('--source', required=True, type=pathlib.Path, help='Directory containing extracted original .bin and .dds files')
parser.add_argument('--output', required=True, type=pathlib.Path, help='Output directory for geometry.json and decoded textures')
args=parser.parse_args(); src=args.source; dest=args.output; dest.mkdir(parents=True,exist_ok=True)
def vals(b,fmt,p=0): return struct.unpack_from('<'+fmt,b,p)
def rotate(q,v):
 x,y,z,w=q; vx,vy,vz=v; tx=2*(y*vz-z*vy);ty=2*(z*vx-x*vz);tz=2*(x*vy-y*vx)
 return [vx+w*tx+y*tz-z*ty,vy+w*ty+z*tx-x*tz,vz+w*tz+x*ty-y*tx]
def mul(a,b):
 x,y,z,w=a; X,Y,Z,W=b
 return [w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z]
b=(src/'W3DHierarchy__AUANTIVEHICLEVEHICLETECH3_SKL.bin').read_bytes(); bones=[]; bone_hashes=[]; parents=[]
for i in range(vals(b,'I',4)[0]):
 p=12+i*100; bone_hashes.append(vals(b,'I',p)[0]); parent=vals(b,'i',p+4)[0]; parents.append(parent); t=vals(b,'3f',p+8); q=vals(b,'4f',p+20)
 if parent>=0:
  pt,pq=bones[parent]; t=[a+c for a,c in zip(pt,rotate(pq,t))];q=mul(pq,q)
 bones.append((t,q))
# FX_Weapon is SDK WeaponLaunchBone/WeaponFireFXBone. Its name hash resolves
# to pivot 6 (parent 5 -> 2 -> 1 -> 0), not the front headlight pivots 20/21.
muzzle_index=bone_hashes.index(0x09BB1F5D)
assert muzzle_index==6 and parents[6]==5
t=bones[muzzle_index][0]
rig={'muzzle':{'bone':'FX_Weapon','name_hash':'09bb1f5d','pivot':muzzle_index,'position':[t[0],t[2],-t[1]]},'independent_turret':False,'source':'RA3 SDK TruckDraw + WeaponSlotHardpoint (no turret); SKL bind-pose hierarchy'}
(dest/'rig.json').write_text(json.dumps(rig,indent=2),encoding='utf-8')
meshes=[]
for suffix,tex in [('NEWSKIN','AUAntiVehicleVehicleTech3'),('NEWSKIN_TREADS','AUAntiVehicleVehicleTech3_Treads')]:
 b=(src/f'W3DMesh__AUANTIVEHICLEVEHICLETECH3_SKN.{suffix}.bin').read_bytes(); h=vals(b,'7I',vals(b,'I',4)[0]); n,stride,start,declsize,declptr,nb,bptr=h
 decl=b[declptr:declptr+declsize].rstrip(b'\0').decode(); fields={key:(int(off,16),fmt) for key,off,fmt in (item.split(':') for item in decl.split())}; print(suffix,decl)
 palette=vals(b,str(nb)+'H',bptr); vertices=[]; normals=[];uv=[]; groups=[]
 for i in range(n):
  p=start+i*stride; v=vals(b,'3f',p+fields['p0'][0]); nor=vals(b,'3f',p+fields['n0'][0]); uv.extend(vals(b,'2f',p+fields['t0'][0]))
  indices=vals(b,'4B',p+fields['i0'][0]); weights=vals(b,'4B',p+fields['w0'][0]) if 'w0' in fields else (255,0,0,0)
  assert sum(weights)==255,weights
  # All chassis panels and all four track assemblies share one vehicle heading.
  v=[0.,0.,0.]; nor=[0.,0.,0.]
  for j,weight in enumerate(weights):
   if not weight: continue
   t,q=bones[palette[indices[j]]]; vp=vals(b,'3f',p+fields['p'+str(j)][0]); np=vals(b,'3f',p+fields['n'+str(j)][0])
   transformed=[a+c for a,c in zip(t,rotate(q,vp))]; normal=rotate(q,np)
   for k in range(3): v[k]+=transformed[k]*weight/255; nor[k]+=normal[k]*weight/255
  vertices.extend([v[0],v[2],-v[1]]); normals.extend([nor[0],nor[2],-nor[1]])
 count,ptr=vals(b,'2I',52); triangles=[]
 for i in range(count):
  size,offset=vals(b,'2I',ptr+i*24); assert size==3; tri=vals(b,'3I',offset); assert max(tri)<n; triangles.extend(tri)
 assert all(math.isfinite(x) for x in vertices+normals+uv)
 bounds=[[min(vertices[j::3]),max(vertices[j::3])] for j in range(3)]
 original_bounds=vals(b,'6f',12)
 expected=[[original_bounds[0],original_bounds[3]],[original_bounds[2],original_bounds[5]],[-original_bounds[4],-original_bounds[1]]]
 assert max(abs(a-b) for pair,ref in zip(bounds,expected) for a,b in zip(pair,ref)) < 0.0001
 print('bounds validated',suffix,bounds)
 for texture_suffix in ['', '_NRM', '_SPM']: Image.open(src/(tex+texture_suffix+'.dds')).save(dest/(tex+texture_suffix+'.png'))
 meshes.append(dict(name=suffix,turret=False,vertices=vertices,normals=normals,uv=uv,indices=triangles))
(dest/'geometry.json').write_text(json.dumps(meshes,separators=(',',':')),encoding='utf-8')
print('CONVERTED',sum(len(x['vertices'])//3 for x in meshes),'vertices',sum(len(x['indices'])//3 for x in meshes),'triangles')
