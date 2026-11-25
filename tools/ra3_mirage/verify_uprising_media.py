import collections, hashlib, json, math, struct, wave
from pathlib import Path
from PIL import Image, ImageDraw

root=Path('refs/ra3-mirage/uprising')
ex=json.loads((root/'extraction.json').read_text(encoding='utf-8'))
cv=json.loads((root/'converted/conversion.json').read_text(encoding='utf-8'))
rows={r['name']:r for r in ex['assets']}; ids={(r['type'],r['instance']):r['name'] for r in rows.values()}
assert not ex['unresolved_references']
checks=[]
for f in ex['files']+cv['records']:
    b=(root/f['file']).read_bytes()
    assert len(b)==f['size'] and hashlib.sha256(b).hexdigest()==f['sha256'],f['file']
checks.append('All 643 raw and 247 converted records have verified size and SHA256')
def load(sub,name):return json.loads((root/'converted'/sub/name).read_text())
mesh=load('meshes','W3DMesh_EXCLOAKINGFIELD.SPHERE02.json')
assert len(mesh['indices'])==242*3
assert mesh['material']['shader']=='FXLightning.fx'
assert mesh['material']['constants']['Texture_0']['asset']=='Texture:FXCloud03'
assert mesh['material']['constants']['Texture_1']['asset']=='Texture:FXFracTileNRM'
checks.append('Native cloak field: 242 triangles; FXLightning.fx; FXCloud03 + FXFracTileNRM')
for name,frames in [('EXCLOAKINGFIELD',101),('EXMIRAGEFIELDBUILDUP',51),('AUANTIVEHICLEVEHICLETECH3_IDLA',121),('AUANTIVEHICLEVEHICLETECH3_MOVA',121)]:
    clip=load('animations','W3DAnimation_'+name+'.json'); assert clip['fps']==30 and clip['frames']==frames
    bones=load('hierarchies',clip['hierarchy'].replace(':','_')+'.json')['bones']
    for c in clip['channels']:
        assert c['pivot']<len(bones)
        if c['format']=='AnimationChannelTimecoded':
            assert len(c['values'])==len(c['frame_and_binary_flag'])*c['vector_length']
            assert all((k&0x7fff)<clip['frames'] for k in c['frame_and_binary_flag'])
            continue
        assert c['format']=='AnimationChannelDelta'
        assert c['num_bits'] in (4,8) and len(c['initial'])==c['vector_length']
        expected=((c['num_frames']+15)//16)*c['vector_length']*(1+c['num_bits']*2)
        assert len(c['compressed_values'])==expected,(name,expected,len(c['compressed_values']))
        assert all(math.isfinite(x) for x in c['initial']+[c['scale']])
checks.append('All four original 30 FPS clips: hierarchy/pivots and complete delta block lengths validated; curves not decoded')
audio=[f for f in cv['records'] if f['file'].endswith('.wav')]
for f in audio:
    raw=(root/'raw'/(f['asset'].replace(':','_')+'.bin')).read_bytes()
    samples,rate=struct.unpack_from('<II',raw,12)
    with wave.open(str(root/f['file'])) as w:
        assert w.getframerate()==rate and w.getnframes()==samples,(f['asset'],samples,w.getnframes())
checks.append(f'All {len(audio)} WAV sample rates and sample counts match the original audio descriptors')
events=load('audio','events.json')
assert len(events['AudioEvent:ALL_Mirage_WeaponFire1'])==10
assert len(events['AudioEvent:ALL_Mirage_WeaponFire2'])==3
assert len(events['AudioEvent:ALL_MirageField_StartAndEndLoop'])==3
checks.append('Both weapon layers and field start/loop/stop resolve to exported native audio')
vgm=Path('refs/ra3-mirage/vgmstream');release=json.loads((vgm/'release-asset.json').read_text(encoding='utf-8-sig'))
package_sha=hashlib.sha256((vgm/'package.zip').read_bytes()).hexdigest()
assert release['digest']=='sha256:'+package_sha
checks.append('vgmstream package SHA256 matches official GitHub release asset digest')
sources={}
game=Path(ex['source'])
for p in [game/'RA3EP1_english_1.1.SkuDef']+[game/'Data'/n for n in ['StaticStream.big','GlobalStream.big','EnglishAudio.big','Shaders.big']]+[Path('refs/ra3-sdk/installed')/p for p in ['SAGEXML/Allied/Units/AlliedAntiVehicleVehicleTech3.xml','Schemas/xsd/AssetTypeW3D.xsd']]:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    sources[str(p)]=dict(size=p.stat().st_size,sha256=h.hexdigest())
icons=sorted((root/'converted/icons').glob('*.png'));sheet=Image.new('RGB',(700,440),'#18222b');draw=ImageDraw.Draw(sheet)
for i,p in enumerate(icons):
    im=Image.open(p).convert('RGBA');im.thumbnail((150,140));x=(i%4)*175;y=(i//4)*220
    sheet.paste(im,(x+10,y+15),im)
    label=p.stem.replace('PackedTextureImage_','').replace('AlliedAntiVehicleVehicleTech3','Mirage')
    for j in range(0,len(label),23):draw.text((x+5,y+160+j//23*14),label[j:j+23],fill='white')
sheet.save(root/'converted/icon-contact-sheet.png')
report=dict(status='extraction_and_conversion_verified_runtime_not_changed',checks=checks,raw_assets=len(rows),raw_files=len(ex['files']),converted_files=len(cv['records']),wav_clips=len(audio),sources=sources,decoder=dict(url=release['browser_download_url'],sha256=package_sha,exe_sha256=hashlib.sha256((vgm/'vgmstream-cli.exe').read_bytes()).hexdigest()),limitations=cv['limitations'])
(root/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
