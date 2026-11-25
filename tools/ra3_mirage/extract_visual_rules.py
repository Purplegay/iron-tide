import argparse, json, hashlib
from pathlib import Path
from xml.etree import ElementTree as ET
p=argparse.ArgumentParser();p.add_argument('--sdk',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
ns={'s':'uri:ea.com:eala:asset','x':'http://www.w3.org/2001/XMLSchema'};sources={}
def read(rel):
 b=(a.sdk/rel).read_bytes();sources[rel]=hashlib.sha256(b).hexdigest();return ET.fromstring(b)
unit=read('SAGEXML/Allied/Units/AlliedAntiVehicleVehicleTech3.xml').find('s:GameObject',ns)
weapons=read('SAGEXML/GlobalData/Weapon.xml')
weapon=weapons.find("s:WeaponTemplate[@id='AlliedAntiVehicleVehicleTech3PrismCannon']",ns)
elite=weapons.find("s:WeaponTemplate[@id='AlliedAntiVehicleVehicleTech3PrismCannon_Veteran']",ns)
sec=lambda v:float(v.rstrip('s'))
life=sec(weapon.find('.//s:ActivateLaserNugget',ns).get('Lifetime'))
assert life==sec(elite.find('.//s:ActivateLaserNugget',ns).get('Lifetime'))
laser=unit.find(".//s:LaserDraw[@id='ModuleTag_LaserDraw']",ns)
schema=read('Schemas/xsd/Modules/LaserDraw.xsd')
fade=sec(laser.get('FadeOutTime',schema.find(".//x:attribute[@name='FadeOutTime']",ns).get('default')))
fade_in=sec(laser.get('FadeInTime',schema.find(".//x:attribute[@name='FadeInTime']",ns).get('default')))
node=read('SAGEXML/Allied/Props/AlliedAntiVehicleVehicleTech3CannonNode.xml')
scatter=node.find("s:GameObject[@id='AlliedAntiVehicleVehicleTech3CannonNodeBase']",ns)
def particle(name):
 e=read('SAGEXML/FXParticleSystems/'+name+'.xml').find('s:FXParticleSystemTemplate',ns)
 life=e.find('s:Lifetime',ns);delay=e.find('s:InitialDelay',ns)
 out={'lifetime_frames':[float(life.get('Low')),float(life.get('High'))], 'delay_frames':float(delay.get('Low')) if delay is not None else 0}
 colors=e.findall('s:Colors/s:Color',ns)
 out['colors']=[{'age':float(k.get('RelativeAge'))/100,'rgb':[float(k.find('s:Color',ns).get(c)) for c in ['r','g','b']]} for k in colors]
 alphas=e.findall('s:Alphas/s:Alpha',ns)
 out['alpha']=[{'age':float(k.get('RelativeAge'))/100,'value':float(k.get('Low'))} for k in alphas]
 return out
data={'source':'EA RA3 Mod SDK v3', 'primary_lifetime':life,'scatter_lifetime':sec(scatter.find('.//s:LaserScatterUpdate',ns).get('LaserLifetime')),'beam_fade_in':fade_in,'beam_fade_out':fade,'primary_width':float(laser.get('LaserWidth')),'scatter_width':float(scatter.find('.//s:LaserDraw',ns).get('LaserWidth')),'owner_disguise_opacity':float(unit.find('.//s:SpecialDisguiseUpdate',ns).get('OpacityTarget')),'particles':{name:particle(name) for name in ['AlliedPrismHitFlash','AlliedPrismHitFIre','AlliedPrismFireFlash','AlliedPrismFireFlash_Vet','Primage_Disguise']},'adapter':{'particle_frames_per_second':30,'model_crossfade_seconds':0.7,'model_crossfade_note':'SAGE transition time is not exposed by SDK; presentation interpolation only'},'source_sha256':sources}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8');print('SDK visual rules exported:',life,data['scatter_lifetime'],fade)
