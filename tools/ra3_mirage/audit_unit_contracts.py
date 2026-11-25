"""Read-only three-unit Uprising configuration audit and XML module inventory.

Checks authored inputs consumed by runtime tests. Inventories are evidence, not
claims that every SAGE module/default has a Godot equivalent. No game extraction.
"""
import argparse
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
XML = ROOT / 'refs/ea-modding-support/Uprising/Xml'
NS = {'s': 'uri:ea.com:eala:asset'}
UNITS = {
    'R3MIRAGE': 'Allied/Units/AlliedAntiVehicleVehicleTech3.xml',
    'R3FUTURE': 'EP1/Allied/Units/AlliedFutureTank.xml',
    'R3HARBINGER': 'EP1/Allied/Units/AlliedGunshipAircraft.xml',
}


def audit():
    checks, sources, inventory = [], {}, {}

    def read(relative):
        path = XML / relative
        sources[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        return ET.parse(path).getroot()

    def check(name, actual, expected):
        checks.append(dict(name=name, passed=actual == expected, actual=actual, expected=expected))

    def load(name):
        return json.loads((ROOT / 'iron_tide/data' / name).read_text(encoding='utf-8'))

    def weapon_record(element):
        return dict(type=element.tag.split('}')[-1], attributes=element.attrib,
                    children=[weapon_record(child) for child in element])

    packs = [load('ra3_mirage.json'), load('ra3_expansion.json')]
    units = {u['id']: u for pack in packs for u in pack['units']}
    rules = load('ra3_expansion_rules.json')
    mirage = load('ra3_mirage_balance.json')
    base = read('BaseObjects/BaseVehicle.xml').find('s:GameObject', NS)
    base_object = read('BaseObjects/BaseObject.xml').find('s:GameObject', NS)
    weapons = read('EP1/GlobalData/Weapon_EP1.xml')
    for uid, relative in UNITS.items():
        root = read(relative)
        obj = root.find('s:GameObject', NS)
        data = units[uid]
        for field, expected in {
            'cost': float(obj.find('.//s:BuildCost', NS).get('Amount')),
            'build_time': float(obj.get('BuildTime')),
            'hp': float(obj.find('.//s:ActiveBody', NS).get('MaxHealth')),
            'speed': float(obj.find('s:LocomotorSet', NS).get('Speed')) * 1.5,
        }.items():
            check(uid + ' ' + field, data[field], expected)
        check(uid + ' native production seconds', data['production_seconds_native'], True)
        # Preserve every declaration and the parent order, including Remove and
        # Replace. Do not silently flatten duplicates or call this SAGE resolution.
        inventory[uid] = [dict(source=path, section=section.tag.split('}')[-1],
            modules=[dict(type=module.tag.split('}')[-1], attributes=module.attrib,
                xml=ET.tostring(module, encoding='unicode')) for module in section])
            for path, definition in [('BaseObjects/BaseObject.xml', base_object),
                ('BaseObjects/BaseVehicle.xml', base), (relative, obj)]
            for section in definition if section.tag.split('}')[-1] in
                ['Behaviors', 'Draws', 'ClientBehaviors', 'AI']]
        if uid != 'R3MIRAGE':
            passive = obj.find("s:Behaviors/s:AutoHealBehavior[@id='Upgrade_PassiveHeal']", NS)
            check(uid + ' passive heal module', rules['objects'][uid].get('passive_heal'), passive.attrib)
            check(uid + ' locomotor', rules['objects'][uid]['locomotor'], root.find('s:LocomotorTemplate', NS).attrib)
        else:
            check(uid + ' heroic heal', mirage['heal'], {
                'amount': float(base.find(".//s:AutoHealBehavior[@id='Upgrade_HeroicHeal']", NS).get('HealingAmount')),
                'delay': .5, 'start_delay': 1.0})
    for element in weapons:
        name = element.get('id', '')
        if name not in rules['weapons']:
            continue
        check(name + ' complete weapon declaration', rules['weapons'][name], weapon_record(element))
    # Normal and promoted muzzle flash deliberately share one source event.
    primary = weapons.find("s:WeaponTemplate[@id='AlliedFutureTankNeutronScrambler']", NS)
    check('Future muzzle FireFX equals FireVeteranFX', primary.get('FireFX'), primary.get('FireVeteranFX'))
    # Packed audio clips and unit icons must actually exist.
    for pack in packs:
        for sound, entry in pack.get('sounds', {}).get('entries', {}).items():
            path = entry['file'].removeprefix('res://')
            check('audio ' + sound, (ROOT / 'iron_tide' / path).is_file(), True)
        for uid, art in pack.get('art', {}).items():
            for kind in ['cameo', 'portrait']:
                if kind in art:
                    check(uid + ' ' + kind, (ROOT / 'iron_tide' / art[kind].removeprefix('res://')).is_file(), True)
    return dict(checks=checks, failed=sum(not c['passed'] for c in checks), source_sha256=sources,
        module_inventory=inventory,
        boundary='Source/config checks only; inheritance order retained, not a complete SAGE resolver. Runtime and visual evidence are separate.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(checks=len(result['checks']), failed=result['failed'])))
    for row in result['checks']:
        if not row['passed']: print(row)
    raise SystemExit(1 if result['failed'] else 0)
