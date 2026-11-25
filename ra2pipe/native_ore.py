"""Export resource overlays, spawner locations and map-specific YR rules alongside the terrain."""
import hashlib
import json
from pathlib import Path
from native_maps import ini, unpack


def export_ore(raw, row, rules, output):
    assert hashlib.sha256(raw).hexdigest() == row['sha256']
    cfg = ini(raw.decode('cp1252'))
    waypoint, u, v = row['starts'][0]
    square = int(cfg['Waypoints'][str(waypoint)])
    min_x = square % 1000 - int(v)
    max_y = square // 1000 + int(u)
    overlays = unpack(cfg['OverlayPack'], 'lcw')
    density = unpack(cfg['OverlayDataPack'], 'lcw')
    names = list(rules['OverlayTypes'].values())
    variants = []
    for u, v, kind, stages in row['resources']:
        i = (v + min_x) + (max_y - u) * 512
        name = names[overlays[i]].strip()
        assert density[i] + 1 == stages and 1 <= stages <= 12
        assert name.startswith('GEM' if kind == 'gems' else 'TIB'), name
        variants.append(int(name[-2:]))
    cells = {(x[0], x[1]) for x in row['cells']}
    drills = []
    for key, name in (cfg['Terrain'].items() if 'Terrain' in cfg else []):
        if name not in rules or not rules[name].getboolean('SpawnsTiberium', fallback=False):
            continue
        u, v = max_y - int(key)//1000, int(key)%1000 - min_x
        if (u, v) in cells:
            drills.append([u, v, name, rules[name].getfloat('AnimationProbability')])
    flags = cfg['SpecialFlags']
    ore = rules['Riparius']
    assert ore.getint('Growth') == ore.getint('Spread')
    assert len({drill[3] for drill in drills}) <= 1
    result = dict(variants=variants, drills=drills, grows=flags.getboolean('TiberiumGrows', fallback=True),
                  spreads=flags.getboolean('TiberiumSpreads', fallback=True), growth_frames=ore.getint('Growth'),
                  spread_frames=ore.getint('Spread'), growth_chance=ore.getfloat('GrowthPercentage'),
                  spread_chance=ore.getfloat('SpreadPercentage'), near_scan=int(rules['General']['TiberiumShortScan'].split(';')[0]),
                  far_scan=rules['General'].getint('TiberiumLongScan'))
    output.mkdir(parents=True, exist_ok=True)
    (output / (row['id']+'.json')).write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
