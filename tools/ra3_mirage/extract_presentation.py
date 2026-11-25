"""Extract original RA3 Mirage UI/FX from an already unpacked static stream."""
import argparse, hashlib, io, json, struct
from pathlib import Path
from PIL import Image

parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(); root=args.source; out=args.output
out.mkdir(parents=True,exist_ok=True)
assets=json.loads((root/'asset-index.json').read_text(encoding='utf-8'))
names={x['name'].lower():x for x in assets}
ids={(x['type'],x['instance']):x for x in assets}
stream=(root/'streams/static.bin').open('rb')
records=[]
def read(asset):
    stream.seek(asset['offset']); data=stream.read(asset['size']); assert len(data)==asset['size']; return data
def record(asset,data,path,**extra):
    records.append(dict(asset=asset['name'],source_sha256=hashlib.sha256(data).hexdigest(),output=path.name,output_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**extra))
def texture(asset):
    raw=read(asset); begin=raw.find(b'DDS '); assert begin>=0,asset['name']
    return Image.open(io.BytesIO(raw[begin:])).convert('RGBA'),raw
for name,filename in [('Button_AlliedAntiVehicleVehicleTech3_on','cameo.png'),('Portrait_AlliedAntiVehicleVehicleTech3','portrait.png'),('AUA_Mirage_GapGenerator','field_on.png'),('AUA_Mirage_StrikeMode','field_off.png')]:
    asset=names[('PackedTextureImage:'+name).lower()];raw=read(asset)
    _,_,w,h,x,y,tw,th,rotated=struct.unpack('<9I',raw);assert rotated==0
    atlas=ids[tuple(asset['references'][0])];im,atlas_raw=texture(atlas)
    assert im.size==(tw,th) and x+w<=tw and y+h<=th
    path=out/filename;im.crop((x,y,x+w,y+h)).save(path)
    record(asset,raw,path,atlas=atlas['name'],atlas_sha256=hashlib.sha256(atlas_raw).hexdigest(),rect=[x,y,w,h])
for name in ['FXAlliedPrismBeam','FXAlliedPrismBeam_Vet','FXLenzFlare01','FXFireScroll3','FXDisotrtionFractal01','FXCloud03','FXFracTileNRM','FXLightStreaks','FXBuzzerRef','EXTireTrack2','EXTnkTrack']:
    asset=names[('Texture:'+name).lower()];im,raw=texture(asset);path=out/(name+'.png');im.save(path);record(asset,raw,path)
for name in ['EXCLOAKINGFIELD.SPHERE02','FXMIRAGERAYS','FXMIRAGEDISGUISE']:
    asset=names[('W3DMesh:'+name).lower()];b=read(asset)
    n,stride,start,declsize,declptr,nb,bptr=struct.unpack_from('<7I',b,struct.unpack_from('<I',b,4)[0])
    decl=b[declptr:declptr+declsize].rstrip(b'\0').decode()
    fields={key:(int(off,16),fmt) for key,off,fmt in (item.split(':') for item in decl.split())}
    vertices=[];normals=[];uv=[]
    for i in range(n):
        p=start+i*stride
        v=struct.unpack_from('<3f',b,p+fields['p0'][0]);vertices.extend([v[0],v[2],-v[1]])
        normal=struct.unpack_from('<3f',b,p+fields['n0'][0]);normals.extend([normal[0],normal[2],-normal[1]])
        uv.extend(struct.unpack_from('<2f',b,p+fields['t0'][0]))
    count,ptr=struct.unpack_from('<2I',b,52);indices=[]
    for i in range(count):
        size,offset=struct.unpack_from('<2I',b,ptr+i*24);assert size==3
        tri=struct.unpack_from('<3I',b,offset);assert max(tri)<n;indices.extend(tri)
    path=out/(name.split('.')[0].lower()+'.json')
    path.write_text(json.dumps(dict(vertices=vertices,normals=normals,uv=uv,indices=indices),separators=(',',':')),encoding='utf-8')
    record(asset,b,path,vertex_layout=decl,source_bounds=struct.unpack_from('<6f',b,12),bone_count=nb)
    print(name,n,count,'bones',nb,'bounds',struct.unpack_from('<6f',b,12))
(out/'presentation_provenance.json').write_text(json.dumps(dict(source='EA official RA3 demo; same archive as ../provenance.json',records=records),ensure_ascii=False,indent=2),encoding='utf-8')
print('EXTRACTED',len(records),'original UI/FX assets')
