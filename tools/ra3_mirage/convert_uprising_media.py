"""Convert scoped Uprising extraction; no runtime/game resource replacement.

Runtime animation fields follow official AssetTypeW3D.xsd. Delta payloads are
preserved losslessly, NOT interpreted using an older W3D codec or guessed curve.
"""
import argparse, hashlib, io, json, math, re, struct, subprocess, wave
from pathlib import Path
from PIL import Image

def uint(b,p=0,n=1):
    v=struct.unpack_from('<'+'I'*n,b,p)
    return v[0] if n==1 else list(v)
def floats(b,p,n): return list(struct.unpack_from('<'+'f'*n,b,p))
def safe(s): return re.sub(r'[^\w.-]','_',s)
def digest(b): return hashlib.sha256(b).hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source',type=Path,required=True)
    ap.add_argument('--audio-decoder',type=Path,required=True)
    a=ap.parse_args(); root=a.source; out=root/'converted'; out.mkdir(exist_ok=True)
    manifest=json.loads((root/'extraction.json').read_text(encoding='utf-8'))
    rows={r['name']:r for r in manifest['assets']}
    ids={(r['type'],r['instance']):r['name'] for r in rows.values()}
    files={(f['asset'],f['part']):f for f in manifest['files']}
    records=[]; textures={}
    for f in manifest['files']:
        b=(root/f['file']).read_bytes()
        assert len(b)==f['size'] and digest(b)==f['sha256'],f['file']
    def raw(name,part='bin'):return (root/files[name,part]['file']).read_bytes()
    def refs(name):return [ids[tuple(k)] for k in rows[name]['references']]
    def save(name,kind,filename,data,**extra):
        folder=out/kind;folder.mkdir(exist_ok=True);path=folder/filename
        if isinstance(data,dict):data=json.dumps(data,ensure_ascii=False,separators=(',',':')).encode()
        path.write_bytes(data)
        records.append(dict(asset=name,file=str(path.relative_to(root)).replace('\\','/'),sha256=digest(data),size=len(data),**extra))
    def png(name,kind,im,**extra):
        buf=io.BytesIO();im.save(buf,format='PNG');save(name,kind,safe(name)+'.png',buf.getvalue(),width=im.width,height=im.height,**extra)
    for name in rows:
        if not name.startswith('Texture:'):continue
        b=raw(name);offset=b.find(b'DDS ');assert offset>=0,name
        dds=b[offset:]
        if uint(dds,84)==113: # D3DFMT_A16B16G16R16F; retain original HDR DDS too.
            h,w=uint(dds,12,2)
            values=struct.unpack_from('<'+'e'*(w*h*4),dds,128)
            im=Image.frombytes('RGBA',(w,h),bytes(round(max(0.0,min(1.0,v))*255) for v in values))
        else:
            im=Image.open(io.BytesIO(dds)).convert('RGBA')
        textures[name]=im
        save(name,'dds',safe(name)+'.dds',dds);png(name,'textures',im)
    for name in rows:
        if not name.startswith('PackedTextureImage:'):continue
        _,_,w,h,x,y,tw,th,rot=uint(raw(name),0,9)
        assert rot==0,(name,rot)
        atlas=refs(name)[0];im=textures[atlas]
        assert im.size==(tw,th) and x+w<=tw and y+h<=th,(name,im.size)
        png(name,'icons',im.crop((x,y,x+w,y+h)),atlas=atlas,rect=[x,y,w,h])
    for name in rows:
        if not name.startswith('W3DHierarchy:'):continue
        b=raw(name);count,ptr=uint(b,4,2);bones=[]
        for i in range(count):
            p=ptr+i*100;parent=struct.unpack_from('<i',b,p+4)[0]
            assert -1<=parent<i,(name,i,parent)
            bones.append(dict(name_hash=f'{uint(b,p):08x}',parent=parent,translation=floats(b,p+8,3),rotation_xyzw=floats(b,p+20,4),remaining_transform_bytes=b[p+36:p+100].hex()))
        save(name,'hierarchies',safe(name)+'.json',dict(coordinates='SAGE source XYZ; no axis/bind conversion',bones=bones))
    for name in rows:
        if not name.startswith('W3DMesh:'):continue
        b=raw(name);n,stride,start,ds,dp,nb,bp=uint(b,uint(b,4),7)
        decl=b[dp:dp+ds].rstrip(b'\0').decode();fields={k:(int(o,16),f) for k,o,f in (s.split(':') for s in decl.split())}
        attrs={}
        for k,(offset,fmt) in fields.items():
            values=[]
            for i in range(n):
                p=start+i*stride+offset
                if fmt.endswith('f32'):
                    size=int(fmt[:-3]);v=floats(b,p,size)
                    assert all(math.isfinite(x) for x in v),(name,k,i)
                elif k.startswith(('i','w','c')):v=list(b[p:p+4])
                else:raise ValueError(('Unsupported vertex semantic',name,k,fmt))
                values.append(v)
            attrs[k]=values
        palette=list(struct.unpack_from('<'+'H'*nb,b,bp)) if nb else []
        count,ptr=uint(b,52,2);indices=[]
        for i in range(count):
            size,offset=uint(b,ptr+i*24,2);assert size==3
            tri=uint(b,offset,3);assert max(tri)<n;indices.extend(tri)
        sl,sp,tl,tp,cc,cp=uint(b,60,6);constants={};rr=refs(name)
        # The .imp relocation table explicitly identifies imported reference slots.
        imports=raw(name,'imp') if (name,'imp') in files else b''
        slots=set(uint(imports,0,len(imports)//4)) if imports else set()
        for p in uint(b,cp,cc) if cc>1 else ([uint(b,cp)] if cc else []):
            typ,nl,np=uint(b,p,3);key=b[np:np+nl].rstrip(b'\0').decode()
            if typ==0xa59096a6:
                idx=uint(b,p+12);assert p+12 in slots and 1<=idx<=len(rr),(name,key,idx,rr)
                val=dict(import_index=idx,asset=rr[idx-1])
            elif typ==0xdf08df25:
                length,offset=uint(b,p+12,2);val=floats(b,offset,length)
            elif typ==0x89181982:val=struct.unpack_from('<i',b,p+12)[0]
            elif typ==0xa3f84c3d:val=bool(b[p+12])
            else:raise ValueError(('Unknown shader constant',name,hex(typ)))
            constants[key]=val
        material=dict(shader=b[sp:sp+sl].rstrip(b'\0').decode(),technique=b[tp:tp+tl].rstrip(b'\0').decode(),technique_index=b[84],constants=constants)
        save(name,'meshes',safe(name)+'.json',dict(coordinates='SAGE source XYZ; bone-local weighted positions retained',vertex_layout=decl,attributes=attrs,bone_palette=palette,indices=indices,source_bounds=floats(b,12,6),material=material,references=rr),vertices=n,triangles=count)
    for name in rows:
        if not name.startswith('W3DAnimation:'):continue
        b=raw(name);hierarchy_index,nframes,fps,count,ptr=uint(b,4,5);channels=[]
        pointers=uint(b,ptr,count) if count>1 else [uint(b,ptr)]
        for p in pointers:
            typ,kind,padded,vector,pivot=uint(b,p,5)
            ch=dict(type_hash=f'{typ:08x}',channel_type=kind,channel_type_name=['XTranslation','YTranslation','ZTranslation','Orientation','Visibility'][kind],num_frames=padded,vector_length=vector,pivot=pivot)
            if typ==0x77f97305:
                scale=floats(b,p+20,1)[0];init_count,init_ptr,bits,compressed_count,compressed_ptr=uint(b,p+24,5)
                payload=b[compressed_ptr:compressed_ptr+compressed_count];assert len(payload)==compressed_count
                ch.update(format='AnimationChannelDelta',scale=scale,initial=floats(b,init_ptr,init_count),num_bits=bits,compressed_values=list(payload),decode_status='native compressed channel preserved; interpolation not yet ported')
            elif typ==0x60d8cf69:
                kc,kp,vc,vp=uint(b,p+20,4)
                keys=list(struct.unpack_from('<'+'H'*kc,b,kp));values=floats(b,vp,vc)
                assert vc==kc*vector and all(math.isfinite(v) for v in values)
                ch.update(format='AnimationChannelTimecoded',frame_and_binary_flag=keys,values=values,decode_status='native keyframes decoded; playback not integrated')
            else:
                # Preserve an unknown channel losslessly through raw file, never guess.
                ch.update(format='unknown',source_offset=p,decode_status='raw retained; decoder required')
            channels.append(ch)
        save(name,'animations',safe(name)+'.json',dict(hierarchy=refs(name)[hierarchy_index-1],frames=nframes,fps=fps,last_key_seconds=(nframes-1)/fps,frame_count_seconds=nframes/fps,channels=channels,source_runtime_schema='RA3 SDK Schemas/xsd/AssetTypeW3D.xsd',raw_file=files[name,'bin']['file']))
    decoder=a.audio_decoder.resolve()
    for name in rows:
        if not name.startswith('AudioFile:'):continue
        b=raw(name,'cdata');header=raw(name);hp,hl=uint(header,20,2)
        if hl:
            save(name,'snr',safe(name)+'.sns',b);b=header[hp:hp+hl];assert len(b)==hl
        save(name,'snr',safe(name)+'.snr',b)
        snr=out/'snr'/(safe(name)+'.snr');wav=out/'audio'/(safe(name)+'.wav');wav.parent.mkdir(exist_ok=True)
        proc=subprocess.run([str(decoder),'-i','-o',str(wav),str(snr)],capture_output=True,text=True)
        if proc.returncode:raise RuntimeError((name,proc.stdout,proc.stderr))
        with wave.open(str(wav)) as w:
            rate=w.getframerate();frames=w.getnframes();channels=w.getnchannels();width=w.getsampwidth()
            assert rate>0 and frames>0 and channels>0 and width==2
        save(name,'audio',wav.name,wav.read_bytes(),rate=rate,frames=frames,channels=channels,duration=frames/rate)
    audio_events={name:refs(name) for name in rows if name.startswith(('AudioEvent:','Multisound:'))}
    save('Uprising audio event dependencies','audio','events.json',audio_events)
    report=dict(source='Installed Steam RA3 Uprising1.1; no demo source',input_manifest_sha256=digest((root/'extraction.json').read_bytes()),validated_raw_files=len(manifest['files']),records=records,limitations=['No game runtime resources replaced.','AnimationChannelDelta data is preserved losslessly, not claimed decoded into playback curves.','FXO is compiled D3D shader bytecode, not portable Godot/HLSL source.','Binary FX/weapon records retained; complete semantic decompilation is separate.'])
    (out/'conversion.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('CONVERTED',len(records),'files',flush=True)
    print(json.dumps({kind:sum('/'+kind+'/' in r['file'] for r in records) for kind in ['textures','icons','hierarchies','meshes','animations','audio']},indent=2))

if __name__=='__main__':main()
