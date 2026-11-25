"""Export missing native unit modules from EA Uprising; no runtime/media edits."""
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
XML = ROOT / 'refs/ea-modding-support/Uprising/Xml'
NS = {'s': 'uri:ea.com:eala:asset'}


def main():
    sources = {}
    def read(name):
        path = XML / name
        sources[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        return ET.parse(path).getroot()
    def record(node):
        return dict(type=node.tag.split('}')[-1], attrs=node.attrib, children=[record(c) for c in node])
    def identified(root, name):
        return next(n for n in root if n.get('id') == name)
    weapons = read('GlobalData/Weapon.xml')
    ep_weapons = read('EP1/GlobalData/Weapon_EP1.xml')
    nodes = read('Allied/Props/AlliedAntiVehicleVehicleTech3CannonNode.xml')
    scatter = []
    for name in ['Regular', 'Veteran1', 'Veteran2']:
        node = identified(nodes, 'AlliedAntiVehicleVehicleTech3CannonNode' + name)
        update = node.find('.//s:WeaponScatterEffectUpdate', NS)
        weapon = identified(weapons, update.get('WeaponTemplate'))
        damage = weapon.find('.//s:DamageNugget', NS)
        scatter.append(dict(node=node.get('id'), weapon=weapon.get('id'), count=int(update.find('s:ScatterSettings', NS).get('ScatterAmount')),
                            range=float(weapon.get('AttackRange')), damage=float(damage.get('Damage')),
                            kind=damage.get('DamageType'), delay=float(damage.get('DelayTimeSeconds').rstrip('s')), raw=record(weapon)))
    gunship = read('EP1/Allied/Units/AlliedGunshipAircraft.xml')
    unit = gunship.find('s:GameObject', NS)
    mounts = {}
    for turret in unit.findall('.//s:WeaponSlotTurret', NS):
        name = ['front', 'side', 'rear'][int(turret.get('ID')) - 1]
        template = identified(ep_weapons, turret.find('s:Weapon', NS).get('Template'))
        mounts[name] = dict(turret=record(turret), weapon=record(template))
    projectile = read('EP1/Allied/Props/AlliedGunshipAircraftWeaponProjectile.xml').find('.//s:BezierProjectile', NS)
    dying = read('EP1/Allied/Props/AlliedGunshipAircraft_Dying.xml').find('s:GameObject', NS)
    armor_nodes = {n.get('id'): n for n in read('GlobalData/Armor.xml') if n.get('id')}
    for name in ['EP1/Allied/Units/AlliedFutureTank.xml', 'EP1/Allied/Units/AlliedGunshipAircraft.xml']:
        armor_nodes.update({n.get('id'): n for n in read(name) if n.tag.endswith('ArmorTemplate')})
    def armor(name):
        row = armor_nodes[name]
        field = row.find("s:Armor[@Damage='CANNON']", NS)
        if field is not None: return float(field.get('Percent').rstrip('%')) / 100
        return armor(row.get('inheritFrom')) if row.get('inheritFrom') else float(row.get('Default', '100').rstrip('%')) / 100
    profiles = json.loads((ROOT / 'iron_tide/data/ra3_expansion_rules.json').read_text())['target_profiles']['profiles']
    cannon = {key: armor(value['armor']) for key, value in profiles.items()}
    for key, name in [('R3MIRAGE', 'AlliedAntiVehicleVehicleTech3Armor'), ('R3FUTURE', 'AlliedFutureTankArmor'), ('R3HARBINGER', 'AlliedGunshipAircraftArmor')]:
        cannon[key] = armor(name)
    result = dict(scatter=scatter, mounts=mounts, shell=projectile.attrib, dying=record(dying),
                  crash_weapon=record(identified(weapons, 'BomberAircraftDeathWeapon')),
                  shell_warhead=record(identified(ep_weapons, 'AlliedGunshipAircraftWeaponWarhead')),
                  cannon_armor=cannon, source_sha256=sources,
                  adapter=dict(distance_scale=1.5, scatter_policy='Unique targets per emitted chain; no backtracking. Native internal candidate arbitration unverified.',
                               shell_curve='Cubic path with source indents, muzzle direction, fixed native-step travel; terrain flat.',
                               crash_gravity=180.0, impulse_decay_seconds=0.25))
    path = ROOT / 'iron_tide/data/ra3_completion_rules.json'
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Exported', path, len(sources), 'source files')


if __name__ == '__main__':
    main()
