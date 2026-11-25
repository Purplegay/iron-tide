"""Export SDK health/PRISM armor inheritance and explicit cross-game role mappings."""
import argparse
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {'s': 'uri:ea.com:eala:asset'}
UNITS = {
    'infantry': 'AlliedAntiInfantryInfantry', 'anti_vehicle_infantry': 'AlliedAntiVehicleInfantry',
    'commando': 'AlliedCommandoTech1', 'engineer': 'AlliedEngineer', 'scout': 'AlliedScoutInfantry',
    'spy': 'AlliedInfiltrationInfantry', 'tank': 'AlliedAntiVehicleVehicleTech1',
    'mirage': 'AlliedAntiVehicleVehicleTech3', 'ifv': 'AlliedAntiAirVehicleTech1',
    'miner': 'AlliedMiner', 'artillery': 'AlliedAntiStructureVehicle', 'mcv': 'AlliedMCV',
    'destroyer': 'AlliedAntiNavyShipTech1', 'carrier': 'AlliedAntiStructureShip',
    'dolphin': 'AlliedAntiNavalScout', 'transport': 'AlliedAntiInfantryVehicle',
}
BUILDINGS = {
    'barracks': 'AlliedBarracks', 'power': 'AlliedPowerPlant', 'refinery': 'AlliedRefinery',
    'factory': 'AlliedWarFactory', 'airfield': 'AlliedAirfield', 'naval_yard': 'AlliedNavalYard',
    'construction_yard': 'AlliedConstructionYard', 'tech': 'AlliedTechStructure',
    'defense': 'AlliedBaseDefense', 'advanced_defense': 'AlliedBaseDefenseAdvanced',
    'support_superweapon': 'AlliedSuperWeapon', 'attack_superweapon': 'AlliedSuperWeaponAdvanced',
}
MAPPING = {
    'E1': 'infantry', 'GGI': 'anti_vehicle_infantry', 'ENGINEER': 'engineer', 'DOG': 'scout',
    'ADOG': 'scout', 'TANY': 'commando', 'GHOST': 'commando', 'SPY': 'spy',
    'MTNK': 'tank', 'MGTK': 'mirage', 'FV': 'ifv', 'CMIN': 'miner', 'SREF': 'artillery',
    'AMCV': 'mcv', 'DEST': 'destroyer', 'AEGIS': 'destroyer', 'CARRIER': 'carrier',
    'DLPH': 'dolphin', 'LCRF': 'transport',
    'GAPILE': 'barracks', 'GAPOWR': 'power', 'GAREFN': 'refinery', 'GAWEAP': 'factory',
    'GAAIRC': 'airfield', 'GAYARD': 'naval_yard', 'GACNST': 'construction_yard',
    'GATECH': 'tech', 'GAPILL': 'defense', 'NASAM': 'defense', 'ATESLA': 'advanced_defense',
    'GTGCAN': 'advanced_defense', 'GACSPH': 'support_superweapon', 'GAWEAT': 'attack_superweapon',
}


def extract(sdk: Path):
    hashes = {}

    def read(path):
        raw = (sdk / path).read_bytes()
        hashes[path] = hashlib.sha256(raw).hexdigest()
        return ET.fromstring(raw)

    armors = {n.get('id'): n for n in read('SAGEXML/GlobalData/Armor.xml') if n.get('id')}

    def prism(armor, seen=()):
        assert armor not in seen, armor
        row = armors[armor]
        own = row.find("s:Armor[@Damage='PRISM']", NS)
        if own is not None:
            return float(own.get('Percent')) / 100.0
        if row.get('inheritFrom'):
            return prism(row.get('inheritFrom'), seen + (armor,))
        return float(row.get('Default', '100')) / 100.0

    profiles = {}
    for folder, table in [('Units', UNITS), ('Structures', BUILDINGS)]:
        for key, name in table.items():
            path = f'SAGEXML/Allied/{folder}/{name}.xml'
            obj = read(path).find('s:GameObject', NS)
            body = obj.find('.//s:ActiveBody', NS)
            armor = obj.find('s:ArmorSet', NS).get('Armor')
            profiles[key] = {'id': name, 'hp': float(body.get('MaxHealth')),
                             'armor': armor, 'prism_multiplier': prism(armor), 'source': path}
    return {'source': 'EA RA3 SDK v3; resolved ArmorTemplate inheritance',
            'adapter': 'User-approved cross-game hit-count normalization: SDK damage * PRISM multiplier * target baseline HP / reference HP. Progression and defense remain independent. Role mappings/fallbacks are project policy, not original RA3 data.',
            'profiles': profiles, 'mapping': MAPPING,
            'fallback': {'infantry': 'infantry', 'vehicle': 'tank', 'naval': 'destroyer', 'building': 'barracks'},
            'source_sha256': hashes}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sdk', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    args.output.write_text(json.dumps(extract(args.sdk), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
