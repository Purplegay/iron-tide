"""Import Mirage W3X/PCM media from the credited community art/sound packs."""
import argparse, hashlib, json, math, shutil, wave
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image

NS = {'s': 'uri:ea.com:eala:asset'}

def vec(e, keys='XYZ'):
    return [float(e.get(k)) for k in keys]

def cv(v):
    return [v[0], v[2], -v[1]]

def rotate(q, v):
    x,y,z,w=q; vx,vy,vz=v
    tx=2*(y*vz-z*vy); ty=2*(z*vx-x*vz); tz=2*(x*vy-y*vx)
    return [vx+w*tx+y*tz-z*ty, vy+w*ty+z*tx-x*tz, vz+w*tz+x*ty-y*tx]

def mul(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return [w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--art',type=Path,required=True)
    parser.add_argument('--audio',type=Path,required=True)
    parser.add_argument('--repo',type=Path,required=True)
    parser.add_argument('--sdk',type=Path,required=True)
    a=parser.parse_args(); output=a.repo/'iron_tide/assets/ra3/mirage/native'; output.mkdir(parents=True,exist_ok=True)
    hashes={}
    def read(name):
        p=a.art/name; hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest(); return ET.parse(p).getroot()[0]
    def bones(name):
        local=[]; glob=[]
        for n in read(name).findall('s:Pivot',NS):
            t=vec(n.find('s:Translation',NS)); q=vec(n.find('s:Rotation',NS),'XYZW'); parent=int(n.get('Parent'))
            local.append({'name':n.get('Name'),'parent':parent,'position':cv(t),'rotation':cv(q[:3])+[q[3]]})
            if parent>=0:
                pt,pq=glob[parent]; t=[x+y for x,y in zip(pt,rotate(pq,t))]; q=mul(pq,q)
            glob.append((t,q))
        return local,glob
    local,glob=bones('AUANTIVEHICLEVEHICLETECH3_SKL.w3x')
    def mesh(name,transforms):
        e=read(name); vv=e.findall('s:Vertices',NS); nn=e.findall('s:Normals',NS); ii=e.findall('s:BoneInfluences',NS)
        vv=[[vec(v) for v in group] for group in vv]; nn=[[vec(v) for v in group] for group in nn]
        ii=[[(int(n.get('Bone')),float(n.get('Weight'))) for n in group] for group in ii]
        verts=[]; normals=[]; joints=[]; weights=[]; agreement=0
        for i in range(len(vv[0])):
            v=[0.,0.,0.]; normal=[0.,0.,0.]; js=[]; ws=[]; positions=[]
            for k in range(len(ii)):
                bone,weight=ii[k][i]; js.append(bone); ws.append(weight)
                if weight<=0: continue
                t,q=transforms[bone]; p=[x+y for x,y in zip(t,rotate(q,vv[k][i]))]; n=rotate(q,nn[k][i])
                positions.append(p)
                for axis in range(3): v[axis]+=p[axis]*weight; normal[axis]+=n[axis]*weight
            assert abs(sum(ws)-1)<1e-5
            if len(positions)>1: agreement=max(agreement,max(abs(x-y) for x,y in zip(*positions)))
            verts.extend(cv(v)); normals.extend(cv(normal)); joints.extend((js+[0]*4)[:4]); weights.extend((ws+[0.]*4)[:4])
        triangles=[int(v.text) for t in e.findall('s:Triangles/s:T',NS) for v in t.findall('s:V',NS)]
        uv=[v for n in e.find('s:TexCoords',NS) for v in (float(n.get('X')),1.0-float(n.get('Y')))]
        assert agreement<0.001, ('skin coordinate disagreement',agreement)
        return {'vertices':verts,'normals':normals,'indices':triangles,'uv':uv,'bones':joints,'weights':weights}
    live=[]
    previous=json.loads((a.repo/'iron_tide/assets/ra3/mirage/geometry.json').read_text(encoding='utf-8'))
    for k,suffix in enumerate(['NEWSKIN','NEWSKIN_TREADS']):
        row=mesh('AUANTIVEHICLEVEHICLETECH3_SKN.'+suffix+'.w3x',glob); row['name']=suffix
        assert len(row['vertices'])==len(previous[k]['vertices'])
        error=max(abs(x-y) for x,y in zip(row['vertices'],previous[k]['vertices']))
        assert error<0.001, ('existing bind pose mismatch',error)
        assert row['indices']==previous[k]['indices']
        assert max(abs(x-y) for x,y in zip(row['uv'],previous[k]['uv']))<0.00001, 'texture coordinate convention mismatch'
        live.append(row)
    clips={}
    for name in ['IDLA','MOVA']:
        e=read('AUANTIVEHICLEVEHICLETECH3_'+name+'.w3x'); channels=[]
        for c in e.find('s:Channels',NS):
            frames=[vec(f,'XYZW') if c.get('Type')=='Orientation' else float(f.text) for f in c]
            assert all(math.isfinite(v) for f in frames for v in (f if isinstance(f,list) else [f]))
            channels.append({'bone':int(c.get('Pivot')),'type':c.get('Type'),'first':int(c.get('FirstFrame')),'frames':frames})
        clips[name]={'frames':int(e.get('NumFrames')),'fps':float(e.get('FrameRate')),'channels':channels}
    wreck_local,wreck_global=bones('AUANTIVEHICLEVEHICLETECH3_COL_HRC.w3x'); pieces=[]
    for suffix in ['NEWSKIN','NEWSKIN_TREADS']:
        row=mesh('AUANTIVEHICLEVEHICLETECH3_COL.'+suffix+'.w3x',wreck_global)
        groups={}
        for i in range(0,len(row['indices']),3):
            triangle=row['indices'][i:i+3]
            def owner(b):
                while not wreck_local[b]['name'].startswith('BONE_D_'):
                    b=wreck_local[b]['parent']; assert b>=0
                return b
            boneset={owner(row['bones'][v*4]) for v in triangle}; assert len(boneset)==1, boneset
            groups.setdefault(next(iter(boneset)),[]).extend(triangle)
        for b,indices in sorted(groups.items()):
            center=cv(wreck_global[b][0]); used=sorted(set(indices)); remap={old:new for new,old in enumerate(used)}
            pieces.append({'name':wreck_local[b]['name'],'treads':'TREADS' in suffix,'center':center,
                'vertices':[row['vertices'][i*3+j]-center[j] for i in used for j in range(3)],
                'normals':[row['normals'][i*3+j] for i in used for j in range(3)],
                'uv':[row['uv'][i*2+j] for i in used for j in range(2)],'indices':[remap[i] for i in indices]})
    sdk_collapse=a.sdk/'SAGEXML/Allied/Props/AlliedAntiVehicleVehicleTech3_Collapse.xml'
    collapse=ET.parse(sdk_collapse).getroot()
    masses={n.get('BoneName').upper():float(n.get('Mass')) for n in collapse.findall('.//s:BoneVolume',NS)}
    for piece in pieces: piece['mass']=masses[piece['name']]
    for filename,data in [('skin.json',{'bones':local,'meshes':live,'muzzle_bone':next(i for i,b in enumerate(local) if b['name']=='FX_WEAPON')}),('animations.json',clips),('wreck.json',{'pieces':pieces,'draw_delay':5.,'fade_seconds':4.,'death_age':4.5,'sink_delay':1.,'sink_rate':1.5,'destruction_delay':8.,'note':'SDK lifetime modules retained; deterministic cosmetic impulse/gravity adapter; no gameplay collision'})]:
        (output/filename).write_text(json.dumps(data,separators=(',',':')),encoding='utf-8')
    Image.open(a.art/'AUAntiVehicleVehicleTech3_D.dds').save(output/'burnt.png')
    hashes['AUAntiVehicleVehicleTech3_D.dds']=hashlib.sha256((a.art/'AUAntiVehicleVehicleTech3_D.dds').read_bytes()).hexdigest()
    hashes['SDK_Collapse.xml']=hashlib.sha256(sdk_collapse.read_bytes()).hexdigest()
    manifest={'art_url':'https://www.moddb.com/mods/red-alert-3-entropy/addons/complete-allied-art-source-pack',
        'art_archive_md5':'2672e16186da69fe919c86bff93e3020','credit':'EA assets; community extraction by Ace.of.Spades using Bibber Asset Extractor',
        'audio_url':'https://sounds.spriters-resource.com/pc_computer/commandconquerredalert3uprising/asset/440577/',
        'audio_credit':'EA assets; Allied Vehicles pack uploaded by CoffeeMaus','source_sha256':hashes,
        'animation_warning':'Pack author does not guarantee extracted animation accuracy; bind pose, channel bounds and playback validated separately',
        'outputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.suffix in ['.json','.png'] and p.name!='provenance.json'}}
    (output/'provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    from import_audio import integrate
    integrate(a.repo,a.audio,a.sdk)
    print('IMPORTED',len(local),'bones;',sum(len(m['vertices'])//3 for m in live),'vertices;',len(pieces),'wreck surfaces;', {k:v['frames'] for k,v in clips.items()})

if __name__=='__main__': main()
