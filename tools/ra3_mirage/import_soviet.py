"""Build the three Soviet unit skins from extract_uprising/convert_uprising_media output."""
from pathlib import Path
import json,re,struct,shutil,hashlib
import xml.etree.ElementTree as ET
from import_expansion import cv,rotate,mul,poid
from import_uprising_runtime import decode_delta
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'refs/ra3-soviet/retail'
C=SRC/'converted'
OUT=ROOT/'iron_tide/assets/ra3/soviet'
SDK=ROOT/'refs/ra3-sdk/installed/SAGEXML'
EP=ROOT/'refs/ea-modding-support/Uprising/Xml/EP1'
UNITS=[
 ('R3TESLA','磁暴坦克',SDK/'Soviet/Units/SovietAntiVehicleVehicleTech2.xml','RVTESLATANK','RVTESLATANK','RVTESLATANK'),
 ('R3APOC','天启坦克',SDK/'Soviet/Units/SovietAntiVehicleVehicleTech3.xml','SUANTIVEHICLEVEHICLETECH3','SUANTIVEHICLEVEHICLETECH3_SKN','SUANTIVEHICLEVEHICLETECH3_SKL'),
 ('R3REAPER','收割者',EP/'Soviet/Units/SovietHeavyWalkerVehicle.xml','SUHEAVYWALKERVEHICLE','SUHEAVYWALKERVEHICLE_SKN','SUHEAVYWALKERVEHICLE_SKL')]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
def main():
    ex=read(SRC/'extraction.json');rows={a['name']:a for a in ex['assets']}
    ids={(a['type'],a['instance']):a['name'] for a in rows.values()}
    raw={(a['asset'],a['part']):a['file'] for a in ex['files']}
    for uid,label,xml,stem,container,skel in UNITS:
        out=OUT/uid;out.mkdir(parents=True,exist_ok=True)
        obj=ET.parse(xml).find('.//{*}GameObject')
        words=set(re.findall(r'[a-zA-Z][a-zA-Z0-9_]+',xml.read_text(encoding='utf-8-sig')))
        names={poid(s):s for s in words}
        for w in list(words):
            for i in range(1,11):
                for s in [w+str(i),w+str(i).zfill(2)]:names.setdefault(poid(s),s)
        rawbones=read(C/'hierarchies'/('W3DHierarchy_'+skel+'.json'))['bones'];bones=[];poses=[]
        for b in rawbones:
            t,q=b['translation'],b['rotation_xyzw'];parent=b['parent'];h=b['name_hash']
            bones.append(dict(name=names.get(h,'bone_'+h),position=cv(t),rotation=cv(q[:3])+[q[3]],parent=parent))
            if parent>=0:
                pt,pq=poses[parent];t=[x+y for x,y in zip(pt,rotate(pq,t))];q=mul(pq,q)
            poses.append((t,q))
        name='W3DContainer:'+container;data=(SRC/raw[name,'bin']).read_bytes()
        count,ptr=struct.unpack_from('<II',data,8);attach={}
        for i in range(count):
            bone,_,_,ref=struct.unpack_from('<4I',data,ptr+16*i);attach[ids[tuple(rows[name]['references'][ref-1])]]=bone
        meshes=[]
        for name,bn in attach.items():
            if not name.startswith('W3DMesh:'):continue
            meshid=name.split(':')[1];r=read(C/'meshes'/('W3DMesh_'+meshid+'.json'))
            a=r['attributes'];pal=r['bone_palette'];verts=[];normals=[];joints=[];weights=[]
            for i,p in enumerate(a['p0']):
                ws=a['w0'][i] if 'w0' in a else [1,0,0,0]
                total=sum(ws);assert total>0
                pos=[0.,0.,0.];nrm=[0.,0.,0.]
                for j,w in enumerate(ws):
                    k=(pal[a['i0'][i][j]] if pal else bn) if w else 0
                    joints.append(k);weights.append(w/total)
                    if not w:continue
                    t,q=poses[k];v=rotate(q,a.get('p'+str(j),a['p0'])[i]);n=rotate(q,a.get('n'+str(j),a['n0'])[i])
                    for axis in range(3):pos[axis]+=(t[axis]+v[axis])*w/total;nrm[axis]+=n[axis]*w/total
                verts.extend(cv(pos));normals.extend(cv(nrm))
            material={}
            for channel,val in r['material']['constants'].items():
                if not isinstance(val,dict) or not val.get('asset','').startswith('Texture:'):continue
                tex=val['asset'].split(':')[1];shutil.copyfile(C/'textures'/('Texture_'+tex+'.png'),out/(tex+'.png'));material[channel]=tex+'.png'
            meshes.append(dict(name=meshid,vertices=verts,normals=normals,uv=sum(a['t0'],[]),uv2=sum(a.get('t1',a['t0']),[]),colors=a.get('c0',[]),bones=joints,weights=weights,indices=r['indices'],material=material,native_material=r['material']))
        clips={}
        for path in (C/'animations').glob('W3DAnimation_*.json'):
            r=read(path)
            if r['hierarchy'].split(':')[-1]!=skel:continue
            channels=[]
            for c in r['channels']:
                if c['format']=='AnimationChannelDelta':v=decode_delta(c,r['frames'])
                else:
                    keys=c['frame_and_binary_flag'];sz=c['vector_length'];v=[]
                    for f in range(r['frames']):
                        i=next((i for i in reversed(range(len(keys))) if keys[i]&0x7fff<=f),0);v.append(c['values'][i*sz:(i+1)*sz])
                channels.append(dict(bone=c['pivot'],type=c['channel_type_name'],frames=v if c['vector_length']>1 else [x[0] for x in v]))
            key=path.stem.removeprefix('W3DAnimation_').removeprefix(stem+'_');clips[key]=dict(fps=r['fps'],frames=r['frames'],channels=channels)
        dump(out/'skin.json',dict(bones=bones,meshes=meshes));dump(out/'animations.json',clips)
        for prop,key in [('SelectPortrait','portrait'),('ButtonImage','button')]:
            shutil.copyfile(C/'icons'/('PackedTextureImage_'+obj.get(prop)+'.png'),out/(key+'.png'))
        print(uid,len(meshes),len(bones),list(clips),[b['name'] for b in bones if not b['name'].startswith('bone_')],flush=True)

def catalog():
    pack=dict(units=[],art={},sounds=dict(specs={},entries={}))
    extract=read(SRC/'extraction.json');rows={r['name']:r for r in extract['assets']}
    ids={(r['type'],r['instance']):r['name'] for r in rows.values()}
    for uid,label,path,stem,_,_ in UNITS:
        obj=ET.parse(path).find('.//{*}GameObject');base=EP if uid=='R3REAPER' else SDK
        exp=ET.parse(base/('GlobalData/ExperienceLevels_EP1.xml' if base==EP else 'GlobalData/ExperienceLevels.xml'))
        levels=[exp.find(".//{*}ExperienceLevelTemplate[@id='%sExperienceLevel_%d']"%(obj.get('id'),i)) for i in range(1,5)]
        ranks=dict(experience=[int(n.get('RequiredExperience')) for n in levels[1:]],experience_award=[int(n.get('ExperienceAward')) for n in levels])
        weaponid={'R3TESLA':'SovietAntiVehicleVehicleTech2TeslaGun','R3APOC':'SovietAntiVehicleVehicleTech3Cannon','R3REAPER':'SovietHeavyWalkerGrenadeWeapon'}[uid]
        wr=ET.parse(base/('GlobalData/Weapon_EP1.xml' if base==EP else 'GlobalData/Weapon.xml'))
        w=wr.find(".//{*}WeaponTemplate[@id='%s']"%weaponid)
        wh=w.find('.//{*}ProjectileNugget')
        nug=(wr.find(".//{*}WeaponTemplate[@id='%s']"%wh.get('WarheadTemplate')) if wh is not None else w).find('.//{*}DamageNugget')
        seconds=lambda tag:float(w.find('{*}'+tag).get('MinSeconds').rstrip('s'))
        speed=float(obj.find('.//{*}LocomotorSet').get('Speed'))*1.5
        locomotor=obj.find('.//{*}LocomotorSet').get('Locomotor')
        loc=ET.parse(path).find(".//{*}LocomotorTemplate[@id='%s']"%locomotor)
        if loc is None:loc=ET.parse(SDK/'GlobalData/Locomotor.xml').find(".//{*}LocomotorTemplate[@id='%s']"%locomotor)
        pathbase='res://assets/ra3/soviet/'+uid+'/'
        pack['art'][uid]=dict(cameo=pathbase+'button.png',portrait=pathbase+'portrait.png')
        voice={}
        for entry in obj.findall('.//{*}AudioEntry'):
            key={'voiceSelect':'select','voiceMove':'move','voiceAttack':'attack'}.get(entry.get('AudioType'))
            if not key:continue
            event=entry.get('Sound')
            seeds=[n for n in rows if n.split(':')[-1].lower()==event.lower()];seen=set(); sounds=[]
            while seeds:
                n=seeds.pop()
                if n in seen:continue
                seen.add(n)
                if n.startswith('AudioFile:'):
                    wav='AudioFile_'+n.split(':')[1]+'.wav';sound=('ra3_'+n.split(':')[1]).lower()
                    import wave
                    src=C/'audio'/wav;shutil.copyfile(src,OUT/uid/wav)
                    with wave.open(str(src)) as f:pack['sounds']['entries'][sound]=dict(file=pathbase+wav,sampleRate=f.getframerate(),channels=f.getnchannels(),durMs=round(1000*f.getnframes()/f.getframerate()))
                    sounds.append(sound)
                else:seeds.extend(ids[tuple(ref)] for ref in rows[n]['references'] if tuple(ref) in ids)
            if sounds:
                v='RA3_'+uid+'_'+key;voice[key]=v;pack['sounds']['specs'][v]=dict(sounds=sorted(sounds),volume=85,priority=10,loop=False)
        desc={'R3TESLA':'双发磁暴炮。切换短路模式后停止移动，使附近敌方地面载具瘫痪。','R3APOC':'双联主炮。切换磁力鱼叉牵引敌军载具，接触后碾碎，靠近建筑持续研磨。','R3REAPER':'三门榴弹炮对地，火箭可对空。指定地点跳跃并永久部署为固定炮塔。'}[uid]
        armor=obj.find('.//{*}ArmorSet').get('Armor')
        lib={n.get('id'):n for n in ET.parse(SDK/'GlobalData/Armor.xml').findall('.//{*}ArmorTemplate')}
        lib.update({n.get('id'):n for n in ET.parse(path).findall('.//{*}ArmorTemplate')})
        chain=[];name=armor
        while name in lib:
            n=lib[name];chain.append(n);name=n.get('inheritFrom')
        ranks['max_speed_damaged']=float(loc.get('MaxSpeedDamaged').rstrip('%'))/100
        ranks['vision_native']=float(obj.find(".//*[@VisionRange]").get('VisionRange'))
        ranks['armor']={n.get('Damage'):float(n.get('Percent'))/100 for a in reversed(chain) for n in a.findall('{*}Armor')}
        pack['units'].append(dict(id=uid,name=label+'（RA3）',faction='soviet',role='vehicle',role_name=label,extension_only=True,expansion='ra3_uprising',ra3_native=True,soviet_ra3=ranks,
          cost=int(obj.find('.//{*}BuildCost').get('Amount')),build_time=float(obj.get('BuildTime')),production_seconds_native=True,hp=float(obj.find('.//{*}ActiveBody').get('MaxHealth')),
          armor='heavy',ra2_armor='heavy',ra3_armor=armor,speed=speed,radius=30 if uid=='R3APOC' else 22,sight=float(obj.get('VisionRange','500'))*1.5,tags=['vehicle'],built_at='NAWEAP',ra2_prereq=['NAWEAP'],
          move=dict(speed=speed,rot=180/float(loc.get("TurnTimeSeconds").rstrip("s")),accel_time=float(loc.get("AccelerationSeconds").rstrip("s")),accelerates=True,turret=True,crusher=uid!='R3REAPER',movement_zone='Normal'),voice=voice,desc=desc,
          weapon=dict(damage=float(nug.get('Damage')),cooldown=seconds('ClipReloadTime'),range=float(w.get('AttackRange'))*1.5,min_range=0,projectile_speed=0,attack_type='cannon',ra2_aa=uid=='R3REAPER',ra2_ag=True,ra2_warhead='RA3_EXPANSION',burst=int(w.get('ClipSize')),burst_delay=seconds('FiringDuration'))))
        skill_icons={'R3TESLA':['SUA_TeslaTrooper_EMP','SUA_TeslaTank_MainGuns'],'R3APOC':['SUA_Apoctank_MagneticHarpoon','SUA_Apoctank_Cannons'],'R3REAPER':['SUA_Reaper_Jump']}
        for index,image in enumerate(skill_icons[uid]):
            shutil.copyfile(SRC.parent/'icons/converted/icons'/('PackedTextureImage_'+image+'.png'),OUT/uid/('q_off.png' if index else 'q.png'))
        ranks['aim_degrees']=float(w.get('AcceptableAimDelta','2d').rstrip('d'))
        pack['units'][-1]['deployed_prone']=False
        if uid=='R3TESLA':
            charge=wr.find(".//{*}WeaponTemplate[@id='SovietHeavyAntiVehicleInfantryTeslaLinkGun']")
            pack['units'][-1]['charge_weapon']=dict(range=float(charge.get('AttackRange'))*1.5,cooldown=float(charge.find('{*}FiringDuration').get('MinSeconds').rstrip('s')))
    fire=SRC.parent/'fire'
    fx=read(fire/'extraction.json')
    sources={row['name']:row for row in fx['assets']}
    lookup={(row['type'],row['instance']):row['name'] for row in sources.values()}
    import wave
    for key,unit,event in [('R3TESLA','R3TESLA','SOV_TeslaTank_WeaponFire'),('R3APOC','R3APOC','SOV_ApocalypseTank_CannonFire'),('grenade','R3REAPER','SOV_ProtoSickle_WeaponGrenadeFire'),('rocket','R3REAPER','SOV_ProtoSickle_WeaponRocketFire')]:
        stack=[n for n in sources if n.split(':')[-1].lower()==event.lower()];visited=set();sounds=[]
        while stack:
            n=stack.pop()
            if n in visited:continue
            visited.add(n)
            if n.startswith('AudioFile:'):
                wav=n.replace(':','_')+'.wav';src=fire/'converted/audio'/wav;shutil.copyfile(src,OUT/unit/wav);sound=('ra3_'+n.split(':')[1]).lower();sounds.append(sound)
                with wave.open(str(src)) as f:pack['sounds']['entries'][sound]=dict(file='res://assets/ra3/soviet/'+unit+'/'+wav,sampleRate=f.getframerate(),channels=f.getnchannels(),durMs=round(1000*f.getnframes()/f.getframerate()))
            else:stack.extend(lookup[tuple(ref)] for ref in sources[n]['references'] if tuple(ref) in lookup)
        assert sounds,event
        pack['sounds']['specs']['RA3_SOV_FIRE_'+key]=dict(sounds=sorted(sounds),volume=90,priority=9,loop=False)
    deployed=ET.parse(EP/'Soviet/Units/SovietHeavyWalkerDeployedTurret.xml').find('.//{*}GameObject')
    walker=pack['units'][-1]
    pack['emplacement']=dict(id='R3REAPERTURRET',name='收割者固定炮塔（RA3）',faction='soviet',cost=1200,build_time=0,hp=float(deployed.find('.//{*}ActiveBody').get('MaxHealth')),armor='structure',radius=22,sight=walker['sight'],tags=['defense'],weapon=walker['weapon'],footprint=[1,1],power=0)
    pack['art']['R3REAPERTURRET']=pack['art']['R3REAPER']
    pack['production_prerequisites']={'R3TESLA':['NAWEAP','NANRCT'],'R3APOC':['NAWEAP','NATECH'],'R3REAPER':['NAWEAP','NANRCT']}
    pack['source']='RA3 SDK Soviet units and EA Uprising EP1 Reaper; Steam Uprising 1.1 media.'
    (ROOT/'iron_tide/data/ra3_soviet.json').write_text(json.dumps(pack,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
def wreck(uid, xml, stem, profile_path, burnt):
    root=ET.parse(profile_path);draw=root.find('.//{*}DynamicsDraw');ttl=root.find('.//{*}LifetimeUpdate')
    fade=draw.find('.//{*}Lifetime');sink=root.find('.//{*}SlowDeath')
    seconds=lambda n,k:float(n.get(k).rstrip('s'))
    bodies={poid(n.get('BoneName')).upper():dict(mass=float(n.get('Mass')),spinniness=float(n.get('Spinniness','0'))) for n in draw.findall('.//{*}BoneVolume')}
    profile=dict(bodies=bodies,min_lifetime=seconds(ttl,'MinLifetime'),max_lifetime=seconds(ttl,'MaxLifetime'),fling_perturbation=float(draw.get('FlingPerturbation')),explodiness=float(draw.get('Explodiness')))
    bones=read(C/'hierarchies'/('W3DHierarchy_'+stem+'_COL.json'))['bones'];poses=[];pieces=[]
    for b in bones:
        t,q=b['translation'],b['rotation_xyzw']
        if b['parent']>=0:
            pt,pq=poses[b['parent']];t=[a+b for a,b in zip(pt,rotate(pq,t))];q=mul(pq,q)
        poses.append((t,q))
    out=OUT/uid
    for path in sorted((C/'meshes').glob('W3DMesh_'+stem+'_COL.*.json')):
        r=read(path);a=r['attributes'];owners=[];pos=[];norm=[]
        for i,v in enumerate(a['p0']):
            bone=r['bone_palette'][a['i0'][i][0]];t,q=poses[bone]
            pos.append(cv([x+y for x,y in zip(t,rotate(q,v))]));norm.append(cv(rotate(q,a['n0'][i])))
            while bone>=0 and bones[bone]['name_hash'].upper() not in bodies:bone=bones[bone]['parent']
            assert bone>=0,(path,i);owners.append(bone)
        groups={}
        for i in range(0,len(r['indices']),3):
            tri=r['indices'][i:i+3];assert len({owners[v] for v in tri})==1
            groups.setdefault(owners[tri[0]],[]).extend(tri)
        material={}
        for k in ['DiffuseTexture','NormalMap','SpecMap','Texture_0']:
            tex=r['material']['constants'].get(k,{}).get('asset','').removeprefix('Texture:')
            if tex:shutil.copyfile(C/'textures'/('Texture_'+tex+'.png'),out/(tex+'.png'));material[k]=tex+'.png'
        for b,ix in groups.items():
            used=sorted(set(ix));remap={v:i for i,v in enumerate(used)};center=cv(poses[b][0])
            pieces.append(dict(name=bones[b]['name_hash'].upper(),center=center,treads='TREAD' in path.name,material=material,
                vertices=[pos[v][k]-center[k] for v in used for k in range(3)],normals=sum([norm[v] for v in used],[]),uv=sum([a['t0'][v] for v in used],[]),indices=[remap[v] for v in ix]))
    dump(out/'wreck.json',dict(pieces=pieces,profile=profile,draw_delay=seconds(fade,'Delay'),fade_seconds=seconds(fade,'FadeTime'),sink_delay=seconds(sink,'SinkDelay'),sink_rate=float(sink.get('SinkRate'))))
    shutil.copyfile(C/'textures'/('Texture_'+burnt+'.png'),out/'burnt.png')
if __name__=='__main__':
    main();catalog()
    for level in [1,2,3]:shutil.copyfile(SRC.parent/'ranks/converted/icons'/('PackedTextureImage_VeterancyRank%d_Soviets.png'%(level+1)),OUT/('rank%d.png'%level))

    for unit,prop,tex in zip(UNITS,[SDK/'Soviet/Props/SVTeslaTank_Collapse.xml',SDK/'Soviet/Props/SovietAntiVehicleVehicleTech3_Collapse.xml',EP/'Soviet/Props/SovietHeavyWalker_Collapse.xml'],['RUTeslaTank_D','SUAntiAirVehicleTech3_D','SUHeavyWalkerVehicle_D']):
        wreck(unit[0],unit[2],unit[3],prop,tex)

    (OUT/"R3REAPERTURRET").mkdir(exist_ok=True)
    wreck("R3REAPERTURRET",None,"SUHEAVYWALKERTURRET",EP/"Soviet/Props/SovietHeavyWalkerTurret_Collapse.xml","SUHeavyWalkerVehicle_D")
    inputs=[u[2] for u in UNITS]+[SDK/'GlobalData'/p for p in ['Weapon.xml','Armor.xml','Locomotor.xml','ExperienceLevels.xml','AttributeModifier.xml']]+[EP/'GlobalData'/p for p in ['Weapon_EP1.xml','ExperienceLevels_EP1.xml']]+[EP/'Includes/SovietHeavyWalkerWeaponSet.xml',EP/'Soviet/Units/SovietHeavyWalkerDeployedTurret.xml',SDK/'Soviet/Props/SVTeslaTank_Collapse.xml',SDK/'Soviet/Props/SovietAntiVehicleVehicleTech3_Collapse.xml',EP/'Soviet/Props/SovietHeavyWalker_Collapse.xml',EP/'Soviet/Props/SovietHeavyWalkerTurret_Collapse.xml']
    inputs += [SRC.parent/k/'extraction.json' for k in ['retail','icons','fire','ranks']]
    dump(OUT/'provenance.json',{'sources':{str(p.relative_to(ROOT)).replace(chr(92),'/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'media':'Steam Uprising 1.1, static/global/EnglishAudio streams','world_distance_scale':1.5})
