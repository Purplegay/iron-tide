"""Export EA Uprising Q values and schema defaults; no balance numbers invented here."""
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / 'refs/ea-modding-support/Uprising'
NS = {'s': 'uri:ea.com:eala:asset', 'xs': 'http://www.w3.org/2001/XMLSchema'}
sources = {}


def read(path):
    source = EA / path
    sources[path] = hashlib.sha256(source.read_bytes()).hexdigest()
    return ET.parse(source).getroot()


def main():
    unit = read('Xml/EP1/Allied/Units/AlliedFutureTank.xml')
    beam = unit.find('.//s:BeamSpecialAbilityUpdate', NS)
    defaults = read('Schemas/Modules/BeamSpecialAbilityUpdate.xsd')
    interval = defaults.find(".//xs:attribute[@name='DamageInterval']", NS).get('default')
    weapon = read('Xml/EP1/GlobalData/Weapon_EP1.xml').find("s:WeaponTemplate[@id='AlliedFutureTankLaserSweepWeapon']", NS)
    power = read('Xml/EP1/GlobalData/SpecialPowerTemplates_EP1.xml').find("s:SpecialPowerTemplate[@id='SpecialPower_AlliedFutureTankLaserWeapon']", NS)
    read('Schemas/Modules/SpecialAbilityUpdate.xsd')
    nuggets = {}
    for node in weapon.find('s:Nuggets', NS):
        nuggets[node.tag.split('}')[-1]] = dict(node.attrib, non_infantry_scalar=float(node.find('s:DamageScalarDetails', NS).get('Scalar').rstrip('%')) / 100)
    result = {'beam': dict(beam.attrib, DamageInterval=beam.get('DamageInterval', interval)),
              'weapon': weapon.attrib, 'nuggets': nuggets, 'power': power.attrib,
              'source_sha256': sources,
              'adapter': {'distance_scale': 1.5, 'continuous_damage_hz': 15,
                          'note': "DamageInterval=0s fires each laser on the retail 15Hz logic update. audit_riot_cpu.py verifies half SweepDistance, crisscross diagonal endpoints and linear interpolation. First/last update phase and collision geometry remain adapters."}}
    (ROOT / 'iron_tide/data/ra3_riot_rules.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
