"""Install scoped Uprising presentation assets; rules remain SDK-authoritative."""
from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib,json,math,shutil

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'refs/ra3-mirage/uprising/converted'
DEST=ROOT/'iron_tide/assets/ra3/mirage'
SDK=ROOT/'refs/ra3-sdk/installed'
NS={'s':'uri:ea.com:eala:asset'}

def decode_delta(c,frames):
    # SAGE adaptive delta: 16-sample blocks; table index then signed deltas.
    # Unlike older W3D variants, these runtime 8-bit deltas are signed, not biased.
    # Layout: official AssetTypeW3D.xsd AnimationChannelDelta. Table algorithm:
    # OpenSAGE W3dAdaptiveDeltaCodec; independently checked against W3X samples.
    value=c['initial'][:];result=[value[:]];data=c['compressed_values'];p=0
    bits=c['num_bits'];size=c['vector_length'];assert bits in (4,8)
    for _ in range((c['num_frames']+15)//16):
        vectors=[]
        for axis in range(size):
            index=data[p];p+=1
            scale=(10**(index-8) if index<16 else 1-math.sin((index-16)/240*math.pi/2))*c['scale']
            block=data[p:p+bits*2];p+=bits*2
            if bits==8:deltas=[(b-256 if b>127 else b)/16 for b in block]
            else:deltas=[v-16 if v>7 else v for b in block for v in (b&15,b>>4)]
            vectors.append([v*scale for v in deltas])
        for frame in range(16):
            value=[value[i]+vectors[i][frame] for i in range(size)];result.append(value[:])
    assert p==len(data) and len(result)>=frames
    return result[:frames]

def main():
    provenance={};runtime=DEST/'uprising';runtime.mkdir(exist_ok=True)
    def copy(source,target):
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        provenance[str(target.relative_to(DEST))]={'source':str(source.relative_to(ROOT)),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    def read(kind,name):return json.loads((SRC/kind/name).read_text())
    def mesh(name,target):
        r=read('meshes','W3DMesh_'+name+'.json');attrs=r['attributes']
        assert not r['bone_palette']
        cv=lambda v:[v[0],v[2],-v[1]]
        out=dict(vertices=[x for v in attrs['p0'] for x in cv(v)],normals=[x for v in attrs['n0'] for x in cv(v)],uv=[x for v in attrs['t0'] for x in v],indices=r['indices'],material=r['material'])
        if 'c0' in attrs: out['colors']=[x/255.0 for v in attrs['c0'] for x in v]
        if 't1' in attrs: out['uv2']=[x for v in attrs['t1'] for x in v]
        (runtime/target).write_text(json.dumps(out,separators=(',',':')))
        return r
    field=mesh('EXCLOAKINGFIELD.SPHERE02','excloakingfield.json')
    mesh('FXMIRAGEDISGUISE','fxmiragedisguise.json')
    mesh('AP_MIRAGETREE01','disguise_tree.json')
    clip=read('animations','W3DAnimation_EXCLOAKINGFIELD.json')
    assert len(clip['channels'])==1 and clip['channels'][0]['channel_type_name']=='Visibility'
    curve=[v[0] for v in decode_delta(clip['channels'][0],clip['frames'])]
    assert abs(curve[0])<1e-6 and abs(curve[50]-1)<0.0001 and abs(curve[-1]-1)<0.0001
    assert all(a<=b+0.00001 for a,b in zip(curve,curve[1:]))
    # Cross-check independent community W3X, allowing original compression tolerance.
    comparison={}
    for stem in ['IDLA','MOVA']:
        source=ROOT/'refs/ra3-community/art/Allied Art Pack/Vehicles/Mirage Tank'/('AUANTIVEHICLEVEHICLETECH3_'+stem+'.w3x')
        xml=ET.parse(source).getroot()[0];reference={}
        for c in xml.find('s:Channels',NS):
            reference[int(c.get('Pivot')),c.get('Type')]=[[float(f.get(k)) for k in 'XYZW'] if c.get('Type')=='Orientation' else [float(f.text)] for f in c]
        body=read('animations','W3DAnimation_AUANTIVEHICLEVEHICLETECH3_'+stem+'.json');errors=[]
        for c in body['channels']:
            if c['format']!='AnimationChannelDelta':continue
            values=decode_delta(c,body['frames']);expected=reference[c['pivot'],c['channel_type_name']]
            errors.append(max(abs(x-y) for a,b in zip(values,expected) for x,y in zip(a,b)))
        assert max(errors)<0.03,(stem,errors)
        comparison[stem]=max(errors)
    config={'source':'Installed RA3 Uprising 1.1; SDK ShieldDraw ONCE/ONCE_BACKWARDS','fps':clip['fps'],'frames':clip['frames'],'visibility':curve,'material':field['material'],'delta_crosscheck_max_error':comparison,'adapter':{'distance_scale':1.5,'loop_stop_fade_seconds':0.2,'shader':'Godot FXLightning adaptation using original parameters; not SAGE shader binary execution','restart_on_restore':True}}
    events=ET.parse(SDK/'SAGEXML/Sounds/SoundEffects.xml').getroot()
    base=ET.parse(SDK/'SAGEXML/Sounds/BaseSoundEffect.xml').getroot().find('s:AudioEvent[@id="BaseSoundEffect"]',NS)
    names=['ALL_Mirage_WeaponFire1','ALL_Mirage_WeaponFire2','ALL_MirageField_Start','ALL_MirageField_Stop','ALL_MirageField_StartPlayer','ALL_MirageField_StopPlayer','ALL_MirageField_StartAndEndLoop']
    audio={};lookup={p.stem.removeprefix('AudioFile_').lower():p for p in (SRC/'audio').glob('*.wav')}
    for name in names:
        e=events.find('s:AudioEvent[@id="'+name+'"]',NS);values=dict(base.attrib);values.update(e.attrib)
        volume=values['Volume'];volume=float(volume.replace('=$WEAPON_FIRE - ','-'))+50 if volume.startswith('=$') else float(volume)
        row={'volume':volume,'volume_shift':float(values.get('VolumeShift',0)),'limit':int(values['Limit']),'max_range':float(values['MaxRange']),'min_range':float(values['MinRange']),'control':values.get('Control',''),'type':values['Type'],'sounds':[]}
        for tag in ['PitchShift','Delay']:
            n=e.find('s:'+tag,NS);row[tag]=[float(n.get(k)) for k in ['Low','High']] if n is not None else [0.,0.]
        for n in e.findall('s:Sound',NS):
            p=lookup[n.text.strip().lower()];filename=p.stem.removeprefix('AudioFile_')+'.wav'
            copy(p,runtime/'audio'/filename);row['sounds'].append(filename)
        audio[name]=row
    config['audio']=audio
    (runtime/'field.json').write_text(json.dumps(config,indent=2))
    for name in ['FXCloud03','FXFracTileNRM','FXBuzzerRef','FXAlliedPrismBeam','FXAlliedPrismBeam_Vet']:
        copy(SRC/'textures'/('Texture_'+name+'.png'),runtime/(name+'.png'))
        copy(SRC/'textures'/('Texture_'+name+'.png'),DEST/'presentation'/(name+'.png'))
    copy(SRC/'textures/Texture_AP_MirageDisguises01.png',runtime/'AP_MirageDisguises01.png')
    for source,target in [('AUA_Mirage_GapGenerator','field_on'),('AUA_Mirage_StrikeMode','field_off'),('Button_AlliedAntiVehiclevehicleTech3_on','cameo'),('Portrait_AlliedAntiVehicleVehicleTech3','portrait')]:
        copy(SRC/'icons'/('PackedTextureImage_'+source+'.png'),DEST/'presentation'/(target+'.png'))
    for rank in [2,3,4]:copy(SRC/'icons'/('PackedTextureImage_VeterancyRank'+str(rank)+'_Allies.png'),runtime/('rank'+str(rank-1)+'.png'))
    # Existing voice mappings stay intact; replace their PCM with retail Uprising bytes.
    for p in (DEST/'native/audio').glob('*.wav'):
        if p.stem.lower() in lookup:copy(lookup[p.stem.lower()],p)
    for p in runtime.glob('*.json'):
        provenance[str(p.relative_to(DEST))]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source':'uprising converted mesh/animation and official SDK XML'}
    (runtime/'provenance.json').write_text(json.dumps({'source':'Steam RA3 Uprising1.1','assets':provenance,'runtime_shader_is_adapter':True,'field_animation_channel':'Visibility, 101 frames at 30 FPS; no scale channel','not_activated':'EXMIRAGEFIELDBUILDUP: present in Uprising, not referenced by SDK ShieldDraw; no invented trigger'},indent=2))
    print('Installed native field curve, mesh, textures, icons, 18 sound samples and existing voices',comparison)

if __name__=='__main__':main()
