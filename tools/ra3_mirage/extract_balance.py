"""Extract Mirage numeric authority from local official SDK XML, never game archives."""
from pathlib import Path
import argparse,hashlib,json,xml.etree.ElementTree as ET
NS={'s':'uri:ea.com:eala:asset'}
UNIT='AlliedAntiVehicleVehicleTech3'
def extract(sdk):
 hashes={}
 def read(path):
  p=sdk/path;hashes[path]=hashlib.sha256(p.read_bytes()).hexdigest();return ET.parse(p).getroot()
 def rows(root):return {n.get('id'):n for n in root if n.get('id')}
 def sec(value):return float(value.rstrip('s'))
 def record(n):return {'type':n.tag.split('}')[-1],**n.attrib,'children':[record(c) for c in n]}
 unit=rows(read(f'SAGEXML/Allied/Units/{UNIT}.xml'))[UNIT]
 weapons=rows(read('SAGEXML/GlobalData/Weapon.xml'))
 move=rows(read('SAGEXML/GlobalData/Locomotor.xml'))[UNIT+'Locomotor']
 ranks=rows(read('SAGEXML/GlobalData/ExperienceLevels.xml'))
 modifiers=rows(read('SAGEXML/GlobalData/AttributeModifier.xml'))
 base=read('SAGEXML/BaseObjects/BaseVehicle.xml')
 defines=read('SAGEXML/GlobalData/GlobalDefines.xml')
 scatter=read(f'SAGEXML/Allied/Props/{UNIT}CannonNode.xml')
 armor=rows(read('SAGEXML/GlobalData/Armor.xml'))
 primary=[]
 scatter_weapons=[]
 for suffix in ['', '_Veteran1']:
  w=weapons[UNIT+'CannonNode'+suffix]
  scatter_weapons.append({'range':float(w.get('AttackRange')),'damage':float(w.find('.//s:DamageNugget',NS).get('Damage')),'damage_delay':sec(w.find('.//s:DamageNugget',NS).get('DelayTimeSeconds'))})
 for suffix in ['', '_Veteran']:
  w=weapons[UNIT+'PrismCannon'+suffix]
  primary.append({'damage':float(w.find('.//s:DamageNugget',NS).get('Damage')),'damage_delay':sec(w.find('.//s:DamageNugget',NS).get('DelayTimeSeconds')),'range':float(w.get('AttackRange')),'firing_seconds':sec(w.find('s:FiringDuration',NS).get('MinSeconds')),'reload_seconds':sec(w.find('s:ClipReloadTime',NS).get('MinSeconds'))})
 promotions=[]
 for i,name in enumerate(['Unit_Veteran','Unit_Elite','Unit_Heroic'],2):
  level=ranks[UNIT+'ExperienceLevel_'+str(i)]
  promotions.append({'experience':float(level.get('RequiredExperience')),'modifiers':{n.get('Type'):float(n.get('Value').rstrip('%'))/100 for n in modifiers[name]}})
 heal=base.find('.//s:AutoHealBehavior',NS)
 armor_id=unit.find('s:ArmorSet',NS).get('Armor')
 shroud=next(float(n.get('value')) for n in defines.iter() if n.get('name')=='STANDARD_SHROUD_CLEAR')
 return {'source':'EA RA3 SDK v3 local XML','distance_scale':1.5,'cost':int(unit.find('s:BuildCost',NS).get('Amount')) if unit.find('s:BuildCost',NS) is not None else int(unit.find('.//s:BuildCost',NS).get('Amount')),'build_seconds':float(unit.get('BuildTime')),'hp':float(unit.find('.//s:ActiveBody',NS).get('MaxHealth')),'speed':float(unit.find('s:LocomotorSet',NS).get('Speed')),'vision':float(unit.find('s:VisionInfo',NS).get('VisionRange')),'shroud':shroud,'primary':primary,'scatter':scatter_weapons,'promotions':promotions,'heal':{'amount':float(heal.get('HealingAmount')),'delay':sec(heal.get('HealingDelay')),'start_delay':sec(heal.get('StartHealingDelay'))},'locomotor':dict(move.attrib),'raw':{'unit':record(unit),'weapons':[record(w) for k,w in weapons.items() if k.startswith(UNIT)],'scatter':record(scatter),'armor':record(armor[armor_id]),'base_vehicle':record(base),'experience':[record(ranks[UNIT+'ExperienceLevel_'+str(i)]) for i in range(1,5)],'promotion_modifiers':[record(modifiers[n]) for n in ['Unit_Veteran','Unit_Elite','Unit_Heroic']]},'source_sha256':hashes}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--sdk',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 a.output.write_text(json.dumps(extract(a.sdk),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
