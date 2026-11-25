"""Read installed Uprising BIG/manifest v7; retain only Mirage and art dependencies."""
from pathlib import Path, PureWindowsPath
import argparse, hashlib, json, re, struct

def sha(data): return hashlib.sha256(data).hexdigest()
def u(data,offset=0,count=1):
    values=struct.unpack_from('<'+'I'*count,data,offset)
    return values[0] if count==1 else values

def unpack(data):
    if len(data)<2 or data[1]!=0xfb or data[0] not in (0x10,0x90): return data
    width=4 if data[0]&0x80 else 3
    expected=int.from_bytes(data[2:2+width],'big');p=2+width;out=bytearray()
    while p<len(data):
        a=data[p];p+=1;count=offset=0;final=False
        if a<0x80:
            b=data[p];p+=1;literal=a&3;count=((a&0x1c)>>2)+3;offset=((a&0x60)<<3)+b+1
        elif a<0xc0:
            b,c=data[p:p+2];p+=2;literal=b>>6;count=(a&0x3f)+4;offset=((b&0x3f)<<8)+c+1
        elif a<0xe0:
            b,c,d=data[p:p+3];p+=3;literal=a&3;count=((a&0xc)<<6)+d+5;offset=((a&0x10)<<12)+(b<<8)+c+1
        elif a<0xfc:literal=((a&0x1f)<<2)+4
        else:literal=a&3;final=True
        if p+literal>len(data):raise ValueError('Truncated RefPack literal')
        out.extend(data[p:p+literal]);p+=literal
        if count:
            if offset>len(out):raise ValueError('Invalid RefPack distance')
            # Copy only the requested range, not the entire historical window.
            block=out[-offset:][:count]
            out.extend((block*((count+len(block)-1)//len(block)))[:count])
        if len(out)>expected:raise ValueError('RefPack output exceeds header')
        if final:break
    if len(out)!=expected:raise ValueError(('RefPack size mismatch',len(out),expected))
    return bytes(out)

class Big:
    def __init__(self,path):
        self.path=path;self.entries={}
        with path.open('rb') as f:
            h=f.read(16)
            if h[:4] not in (b'BIG4',b'BIGF'):raise ValueError('Not BIG')
            for _ in range(struct.unpack_from('>I',h,8)[0]):
                off,size=struct.unpack('>II',f.read(8));name=bytearray()
                while (b:=f.read(1))!=b'\0':
                    if not b:raise ValueError('Truncated BIG index')
                    name+=b
                name=name.decode('ascii')
                if off+size>path.stat().st_size:raise ValueError('BIG extent exceeds archive')
                self.entries[name]=(off,size)
    def read(self,name):
        off,size=self.entries[name]
        with self.path.open('rb') as f:f.seek(off);data=f.read(size)
        return unpack(data)

def manifest(data,stream):
    # SAGE.Stream/Header7.cs and AssetEntry7.cs document v7's 52/48-byte tables.
    if u(data,4)&0xffff!=7:raise ValueError(('Unsupported manifest',data[:16].hex()))
    count=u(data,16);refs=52+count*48;names=refs+u(data,36)+u(data,40)
    sources=names+u(data,44);offset=relo=imp=8;rows=[]
    for i in range(count):
        a=u(data,52+i*48,12);start=names+a[6]
        name=data[start:data.index(0,start)].decode('utf-8')
        source=sources+a[7];source=data[source:data.index(0,source)].decode('utf-8')
        rows.append(dict(name=name,stream=stream,offset=offset,size=a[8],relo_offset=relo,relo_size=a[9],imp_offset=imp,imp_size=a[10],type=a[0],instance=a[1],type_hash=a[2],instance_hash=a[3],source=source,references=[u(data,refs+a[4]+j*8,2) for j in range(a[5])]))
        offset+=a[8];relo+=a[9];imp+=a[10]
    return rows,dict(binary=offset,relo=relo,imp=imp,manifest_header=data[:52].hex())

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--inventory',action='store_true');p.add_argument('--pattern',help='Explicit asset-name seed regex; dependency traversal remains scoped to presentation types');a=p.parse_args()
    if not (a.game/'RA3EP1_english_1.1.SkuDef').exists():raise ValueError('Expected installed Uprising1.1')
    a.output.mkdir(parents=True,exist_ok=True)
    archives={};rows=[];sizes={};manifest_hashes={}
    for name,stream in [('StaticStream.big','static'),('GlobalStream.big','global'),('EnglishAudio.big','audio')]:
        big=Big(a.game/'Data'/name);archives[stream]=big
        data=big.read('data\\'+stream+'.manifest');rr,size=manifest(data,stream);rows+=rr;sizes[stream]=size;manifest_hashes[name]=sha(data)
        (a.output/(stream+'-manifest-index.json')).write_text(json.dumps(rr,ensure_ascii=False,indent=2),encoding='utf-8')
        print(stream,len(rr),'assets',size,flush=True)
    pattern=re.compile(a.pattern or 'mirage|primage|cloakingfield|(?:au|allied)antivehiclevehicletech3|VeterancyRank[234]_Allies|FXAlliedPrismBeam|FX_AlliedPrism|AlliedPrism',re.I)
    selected={r['name']:r for r in rows if pattern.search(r['name'])}
    byid={(r['type'],r['instance']):r for r in rows}
    print('SEEDS',len(selected),flush=True)
    if a.inventory:return
    pending=list(selected.values());missing=set()
    allowed={'W3DContainer','W3DMesh','W3DAnimation','W3DHierarchy','Texture','FXShader','FXList','FXParticleSystemTemplate','AudioEvent','Multisound','AudioFile','PackedTextureImage'}
    while pending:
        r=pending.pop()
        if r['name'].split(':')[0] not in allowed:continue
        for ref in r['references']:
            target=byid.get(tuple(ref))
            if target is None:missing.add(tuple(ref));continue
            if target['name'] not in selected:selected[target['name']]=target;pending.append(target)
    rawdir=a.output/'raw';rawdir.mkdir(exist_ok=True);files=[]
    for stream,big in archives.items():
        wanted=[r for r in selected.values() if r['stream']==stream]
        for ext,size_key,off_key,len_key in [('bin','binary','offset','size'),('relo','relo','relo_offset','relo_size'),('imp','imp','imp_offset','imp_size')]:
            if not any(r[len_key] for r in wanted):continue
            print('decode',stream,ext,flush=True);data=big.read('data\\'+stream+'.'+ext)
            if len(data)!=sizes[stream][size_key]:raise ValueError((stream,ext,len(data),sizes[stream][size_key]))
            for r in wanted:
                raw=data[r[off_key]:r[off_key]+r[len_key]]
                if not raw:continue
                fn=re.sub(r'[^\w.-]','_',r['name'])+'.'+ext;out=rawdir/fn;out.write_bytes(raw)
                files.append(dict(asset=r['name'],stream=stream,archive=big.path.name,part=ext,file='raw/'+fn,size=len(raw),sha256=sha(raw)))
            del data
    # External payload names are keyed by all four manifest hashes.
    for r in selected.values():
        big=archives[r['stream']]
        suffix='.'.join(f"{r[k]:08x}" for k in ['type','type_hash','instance','instance_hash'])+'.cdata'
        matches=[n for n in big.entries if n.lower().endswith('\\'+suffix)]
        if len(matches)>1:raise ValueError(('Ambiguous cdata',r['name']))
        if matches:
            raw=big.read(matches[0]);fn=re.sub(r'[^\w.-]','_',r['name'])+'.cdata'
            (rawdir/fn).write_bytes(raw)
            files.append(dict(asset=r['name'],stream=r['stream'],archive=big.path.name,entry=matches[0],part='cdata',file='raw/'+fn,size=len(raw),sha256=sha(raw)))
    # Preserve the actual shader program referenced by each mesh, not a guessed effect.
    shaders=Big(a.game/'Data'/'Shaders.big');shader_names=set()
    for f in list(files):
        if f['asset'].startswith('W3DMesh:') and f['part']=='bin':
            shader_names.update(x.decode('ascii').lower() for x in re.findall(rb'[A-Za-z][A-Za-z0-9_]*\.fx', (a.output/f['file']).read_bytes()))
    for name in shaders.entries:
        if any(name.lower().endswith('\\'+fx+suffix) for fx in shader_names for suffix in ['o','.dep']):
            raw=shaders.read(name);fn=PureWindowsPath(name).name
            (rawdir/fn).write_bytes(raw)
            files.append(dict(asset='Shader:'+fn,archive='Shaders.big',entry=name,part='shader',file='raw/'+fn,size=len(raw),sha256=sha(raw)))
    (a.output/'extraction.json').write_text(json.dumps({'source':str(a.game),'game':'RA3 Uprising1.1 Steam','manifest_sha256':manifest_hashes,'assets':list(selected.values()),'files':files,'unresolved_references':list(missing)},ensure_ascii=False,indent=2),encoding='utf-8')
    print('EXTRACTED',len(selected),'assets',len(files),'files',sum(f['size'] for f in files),'bytes',flush=True)

if __name__=='__main__':main()
