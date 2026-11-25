"""Author the two Uprising units from EA XML and extracted retail media."""
from pathlib import Path
from xml.etree import ElementTree as ET
import json, shutil, hashlib, wave
ROOT=Path(__file__).resolve().parents[2]
XML=ROOT/'refs/ea-modding-support/Uprising/Xml'
MEDIA=ROOT/'refs/ra3-expansion/uprising/converted'
NS={'s':'uri:ea.com:eala:asset'}

def main():
    sources={}
    def read(path):
        p=XML/path;sources[path]=hashlib.sha256(p.read_bytes()).hexdigest();return ET.parse(p).getroot()
    armors={}
    for path in ['GlobalData/Armor.xml','EP1/Allied/Units/AlliedFutureTank.xml','EP1/Allied/Units/AlliedGunshipAircraft.xml']:
        armors.update({e.get('id'):e for e in read(path) if e.get('id')})
    def armor(name,kind):
        row=armors[name];own=row.find("s:Armor[@Damage='"+kind+"']",NS)
        if own is not None:return float(own.get('Percent').rstrip('%'))/100
        return armor(row.get('inheritFrom'),kind) if row.get('inheritFrom') else float(row.get('Default','100').rstrip('%'))/100
    events=json.loads((MEDIA/'audio/events.json').read_text())
    specs={};entries={}
    def audio(event,key):
        layers=events.get('Multisound:'+event,[])
        if layers:
            assert all(ref.startswith('AudioEvent:') for ref in layers), event
            audio(layers[0].split(':',1)[1],key)
            specs[key]['layers']=[audio(ref.split(':',1)[1],key+'_layer'+str(i)) for i,ref in enumerate(layers[1:],1)]
            return key
        refs=events.get('AudioEvent:'+event,events.get('Multisound:'+event,[]));sounds=[]
        for ref in refs:
            if ref.startswith('AudioFile:'):sounds.append(ref.split(':',1)[1])
            else:sounds.extend(x.split(':',1)[1] for x in events.get(ref,[]) if x.startswith('AudioFile:'))
        ids=[]
        for name in dict.fromkeys(sounds):
            p=MEDIA/'audio'/('AudioFile_'+name+'.wav');dest=ROOT/'iron_tide/assets/ra3/expansion/audio'/p.name
            dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
            sound='ra3_exp_'+name.lower();ids.append(sound)
            with wave.open(str(p)) as w:entries[sound]={'file':'res://assets/ra3/expansion/audio/'+p.name,'sampleRate':w.getframerate(),'channels':w.getnchannels(),'durMs':round(w.getnframes()/w.getframerate()*1000)}
        if event=='ALL_FutureTank_PreFireChargeUp' and not refs:
            # Retail event and official SoundEffects.xml deliberately have no samples.
            specs[key]={'sounds':[],'volume':0,'range':20,'loop':False,'priority':10}
            return key
        assert ids,event
        specs[key]={'sounds':ids,'volume':85,'range':20,'loop':False,'priority':10}
        return key
    units=[];art={};native={};weapons=read('EP1/GlobalData/Weapon_EP1.xml')
    experience=read('EP1/GlobalData/ExperienceLevels_EP1.xml')
    modifiers=read('GlobalData/AttributeModifier.xml')
    for uid,name,zh,folder,factory,damage,rate,range_ in [
        ('R3FUTURE','AlliedFutureTank','未来坦克 X-1','future','GAWEAP',10,3,250),
        ('R3HARBINGER','AlliedGunshipAircraft','先锋武装炮艇','harbinger','GAAIRC',100,2,400)]:
        root=read('EP1/Allied/Units/'+name+'.xml');obj=root.find('s:GameObject',NS)
        health=float(obj.find('.//s:ActiveBody',NS).get('MaxHealth'))
        armor_name=obj.find('s:ArmorSet',NS).get('Armor')
        locomotor=root.find('s:LocomotorTemplate',NS)
        speed=float(obj.find('s:LocomotorSet',NS).get('Speed'))
        air=uid=='R3HARBINGER';voice={}
        source_voices={e.get('AudioType'):e.get('Sound') for e in obj.findall('s:AudioArrayVoice/s:AudioEntry',NS)}
        for kind,audio_type in [('select','voiceSelect'),('move','voiceMove'),('attack','voiceAttack'),('created','voiceCreated'),('move_attack','voiceAttackAfterMoving'),('select_battle','voiceSelectBattle'),('select_under_fire','voiceSelectUnderFire')]:
            voice[kind]=audio(source_voices[audio_type],'RA3_'+uid+'_'+kind)
        if air:voice['attack_special']=audio('ALL_HarbingerGunship_VoiceAttackSpecial','RA3_'+uid+'_attack_special')
        else:voice['attack_beam']=audio('ALL_FutureTank_VoiceAttackBeam','RA3_'+uid+'_attack_beam')
        unit=dict(id=uid,name=zh+'（RA3）',faction='allied',role='air' if air else 'vehicle',role_name='武装炮艇' if air else '突击坦克',extension_only=True,expansion='ra3_uprising',
            cost=int(obj.find('s:ObjectResourceInfo/s:BuildCost',NS).get('Amount')),build_time=float(obj.get('BuildTime').rstrip('s')),production_seconds_native=True,hp=health,armor='air' if air else 'heavy',ra2_armor='heavy',speed=speed*1.5,radius=30 if air else 26,sight=750.,tags=['air'] if air else ['vehicle'],built_at=factory,ra2_prereq=[factory,'GATECH'],ra3_clearance=3,
            move=dict(speed=speed*1.5,rot=180/float(locomotor.get('TurnTimeSeconds').rstrip('s')),accel_time=float(locomotor.get('AccelerationSeconds').rstrip('s')),accelerates=True,turret=True,crusher=not air,crushable=False,weight=0,movement_zone='Fly' if air else 'Normal'),
            ra3_native=True,ra3_armor=armor_name,voice=voice,
            desc='需要附近基地最高许可＋作战实验室（兼防卫局）。'+('两门对地对撞炮；Q 切换前部机炮。不防空，弹匣自动装填。' if air else '中子扰乱炮产生扩散伤害。Q 暴乱光束：指定位置，展开并交叉扫射，冷却15秒。'),
            weapon=dict(damage=damage,cooldown=rate,range=range_*1.5,min_range=75.0 if air else 0.0,projectile_speed=0,attack_type='cannon',ra2_aa=False,ra2_warhead='RA3_EXPANSION',burst=1))
        units.append(unit);art[uid]={'cameo':'res://assets/ra3/expansion/'+folder+'/button.png','portrait':'res://assets/ra3/expansion/'+folder+'/portrait.png'}
        native[uid]={'object':obj.attrib,'locomotor':locomotor.attrib,'armor':{kind:armor(armor_name,kind) for kind in ['PRISM','NEUTRON','EXPLOSIVE','AUTO_CANNON']}}
        native[uid]['passive_heal']=dict(obj.find("s:Behaviors/s:AutoHealBehavior[@id='Upgrade_PassiveHeal']",NS).attrib)
        if air:
            modifier=modifiers.find("s:AttributeModifier[@id='AttributeMod_HarbingerGunshipVision_GunMode']",NS)
            native[uid]['gun_mode_modifier']={'id':modifier.get('id'),'attributes':modifier.attrib,
                'modifiers':[e.attrib for e in modifier]}
        native[uid]['experience']=[int(experience.find("s:ExperienceLevelTemplate[@id='"+name+'ExperienceLevel_'+str(rank)+"']",NS).get('RequiredExperience')) for rank in [2,3,4]]
        native[uid]['experience_award']=[int(experience.find("s:ExperienceLevelTemplate[@id='"+name+'ExperienceLevel_'+str(rank)+"']",NS).get('ExperienceAward')) for rank in [1,2,3,4]]
    for event in ['ALL_FutureTank_Weapon1FireMS','ALL_FutureTank_DeathRayWeaponFire','ALL_Gunship_ColliderCannonWeaponFire','ALL_Gunship_ColliderCannonExploMS','ALL_Gunship_MachineGunWeaponFire','ALL_Gunship_Weapon1ToggleMS','ALL_Gunship_Weapon2ToggleMS']:
        audio(event,'RA3_EXP_'+event)
    for event in ['ALL_FutureTank_PreFireChargeUp','ALL_FutureTank_ArmPrimaryWeapon','ALL_FutureTank_ArmSecondaryWeaponMS','ALL_FutureTank_Weapon_NeutronScramblerImpactSmall','ALL_FutureTank_Weapon_NeutronScramblerImpactBig']:
        audio(event,'RA3_EXP_'+event)
    profiles=json.loads((ROOT/'iron_tide/data/ra3_mirage_targets.json').read_text())
    for row in profiles['profiles'].values():row['multipliers']={kind:armor(row['armor'],kind) for kind in ['NEUTRON','EXPLOSIVE','AUTO_CANNON']}
    def node(e):return {'type':e.tag.split('}')[-1],'attributes':e.attrib,'children':[node(c) for c in e]}
    rules={e.get('id'):node(e) for e in weapons if e.get('id','').startswith(('AlliedFutureTank','AlliedGunshipAircraft'))}
    pack={'source':'EA CnC_Modding_Support Uprising XML, Steam Uprising1.1 media','units':units,'art':art,'sounds':{'specs':specs,'entries':entries},'warheads':{'RA3_EXPANSION':{'verses':{k:1.0 for k in ['none','flak','plate','light','medium','heavy','wood','steel','concrete','special_1','special_2']},'extra':{}}}}
    config={'objects':native,'weapons':rules,'target_profiles':profiles,'source_sha256':sources,'adapter':{'distance_scale':1.5,'cross_generation_hp_normalization':'same user-approved role mapping as Mirage; native damage-type armor multipliers'}}
    for filename,data in [('ra3_expansion.json',pack),('ra3_expansion_rules.json',config)]:
        (ROOT/'iron_tide/data'/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Exported',len(units),'units',len(rules),'weapon definitions',len(entries),'audio samples')

if __name__=='__main__':main()
