"""Audit staged YR allied campaign terrain and index the unimplemented retail script.

Run from project root: python tools/audit_allied_ends.py SOURCE_DIR STAGING_PROJECT OUTPUT_DIR
Requires the same Python dependencies as ra2pipe/native_maps.py.
"""
import hashlib
import json
import struct
import sys
from collections import Counter, defaultdict
from functools import cache
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'ra2pipe'))
from native_maps import fill_clear_cells, ini, iso_records, unpack


def check(condition, message):
    if not condition:
        raise ValueError(message)


def audit(source, project, output):
    output.mkdir(parents=True, exist_ok=True)
    maps = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    check({row['archive'] for row in maps} == {'all01umd.map', 'all07smd.map'} and len(maps) == 2,
          'Expected exactly the two retail Allied campaign maps')
    rules = ini((source / 'rulesmd.ini').read_text(encoding='cp1252'))
    overlay_names = list(rules['OverlayTypes'].values())
    summary = []
    for entry in maps:
        mid = 'yr_' + entry['archive'].split('.')[0]
        path = project / 'data/maps' / (mid + '.json')
        actual = json.loads(path.read_text(encoding='utf-8'))
        raw = (source / (entry['archive'] + '.map')).read_bytes()
        check(entry['sha256'] == hashlib.sha256(raw).hexdigest() == actual['sha256'], f'{mid}: source hash')
        retail = ini(raw.decode('cp1252'))
        dims = [int(s) for s in retail['Map']['LocalSize'].split(',')]
        lx, ly, lw, lh = dims
        w, h = map(int, retail['Map']['Size'].split(',')[2:])
        check(dims == actual['local_size'] and retail['Map']['Theater'] == actual['theater'], f'{mid}: bounds/theater')
        cells = fill_clear_cells(iso_records(unpack(retail['IsoMapPack5'], 'lzo')), w, h)
        cells = {(x, y): (0 if tid in (65535, 0xffffffff) else tid, sub, z)
                 for x, y, tid, sub, z, _ in cells
                 if 2*lx <= x-y+w-1 < 2*(lx+lw) and 2*ly <= x+y-w-1 < 2*(ly+lh)}
        origin = min(x for x, y in cells), max(y for x, y in cells)
        check(list(origin) == actual['retail_origin'], f'{mid}: cell origin')

        @cache
        def tile_bytes(tile, sub):
            name = entry['tiles'][tile]['name']
            data = (source / name).read_bytes()
            nx, ny = struct.unpack_from('<II', data)
            check(0 <= sub < nx*ny, f'{mid}: invalid subtile {name}:{sub}')
            offset = struct.unpack_from('<I', data, 16+4*sub)[0]
            check(offset > 0 and offset + 43 <= len(data), f'{mid}: invalid TMP record {name}:{sub}')
            return tuple(data[offset+41:offset+43]), name

        actual_cells = set()
        ramps = Counter()
        for u, v, kind, z, tile, sub, ramp in actual['cells']:
            xy = (origin[0]+v, origin[1]-u)
            check(xy not in actual_cells, f'{mid}: duplicate cell {xy}')
            check(cells.get(xy) == (tile, sub, z), f'{mid}: tile/sub/height at {xy}')
            (tmp_kind, tmp_ramp), name = tile_bytes(tile, sub)
            check((kind, ramp) == (tmp_kind, tmp_ramp), f'{mid}: terrain/slope at {xy}')
            if ramp:
                ramps[f'{name}:{ramp}'] += 1
            actual_cells.add(xy)
        check(actual_cells == set(cells), f'{mid}: retail and staged cell sets differ')

        waypoints = {}
        for key, value in retail['Waypoints'].items():
            y, x = divmod(int(value), 1000)
            waypoints[key] = [origin[1]-y+0.5, x-origin[0]+0.5, (x, y) in cells]
        check(waypoints == actual['waypoints'], f'{mid}: waypoints')
        home = retail['Basic']['HomeCell']
        check(waypoints[home][2] and actual['starts'] == [[int(home), *waypoints[home][:2]]], f'{mid}: HomeCell')
        catalog = project / 'data/maps/yr_catalog.json'
        if catalog.exists():
            check(all(row['id'] != mid for row in json.loads(catalog.read_text(encoding='utf-8'))),
                  f'{mid}: campaign must not leak into skirmish catalog')

        def section(name):
            return dict(retail[name]) if name in retail else {}

        overlays = unpack(retail['OverlayPack'], 'lcw')
        levels = unpack(retail['OverlayDataPack'], 'lcw')
        common_bridges = []
        bridge_overlay_counts = Counter()
        for offset, code in enumerate(overlays):
            name = overlay_names[code].strip() if code < len(overlay_names) else ''
            if not name.startswith(('BRIDGE', 'RAILBRDG', 'LOBRDG')):
                continue
            y, x = divmod(offset, 512)
            bridge_overlay_counts[f'{name}:{"inside" if (x, y) in cells else "outside"}'] += 1
            if (x, y) in cells:
                common_bridges.append([origin[1]-y, x-origin[0], name, levels[offset]])
        check(sorted(common_bridges) == sorted(actual['bridges']), f'{mid}: standard bridge overlays')
        structures = section('Structures')
        mission_bridges = []
        for key, value in structures.items():
            owner, unit, hp, x, y, _, tag, *_ = value.split(',')
            if owner.lower() == 'bridgehouse' or unit.startswith(('CABHUT', 'GGBR')):
                xy = (int(x), int(y))
                mission_bridges.append(dict(index=key, house=owner, type=unit, health_256=int(hp),
                                            xy=xy, uv=[origin[1]-xy[1], xy[0]-origin[0]],
                                            inside=xy in cells, tag=tag))

        tagged_cells = defaultdict(list)
        for cell, tag in section('CellTags').items():
            tagged_cells[tag.lower()].append(int(cell))
        trigger_tags = defaultdict(dict)
        for key, value in section('Tags').items():
            trigger_tags[value.split(',')[-1].lower()][key] = tagged_cells[key]
        triggers, events, actions = (section(name) for name in ('Triggers', 'Events', 'Actions'))
        check(triggers.keys() == events.keys() == actions.keys(), f'{mid}: trigger/events/actions identifiers')
        linked = {key: dict(trigger=record, events=events[key], actions=actions[key], tags=trigger_tags[key])
                  for key, record in triggers.items()}
        table_names = ('Basic', 'Map', 'Lighting', 'Houses', 'Structures', 'Units', 'Infantry', 'Aircraft', 'Terrain',
                       'Waypoints', 'VariableNames', 'CellTags', 'Tags', 'TeamTypes', 'TaskForces', 'ScriptTypes',
                       'AITriggerTypes', 'AITriggerTypesEnable')
        entries = {name: section(name) for name in table_names}
        sections = {}
        for name in ('Houses', 'TeamTypes', 'TaskForces', 'ScriptTypes'):
            tables = {value: section(value) for value in entries[name].values()}
            check(all(tables.values()), f'{mid}: missing definition in {name}')
            sections[name] = tables
        result = dict(id=mid, sha256=actual['sha256'], theater=actual['theater'], cells=len(cells),
                      slopes=sum(ramps.values()), height_range=[min(t[2] for t in cells.values()), max(t[2] for t in cells.values())],
                      retail_origin=origin, waypoints=len(waypoints), home=home, home_uv=waypoints[home][:2],
                      bridge_overlays=bridge_overlay_counts, mission_bridge_structures=mission_bridges,
                      triggers=len(linked), tables={name: len(rows) for name, rows in entries.items()})
        summary.append(result)
        (output / (mid + '_index.json')).write_text(json.dumps(dict(audit=result, slope_tmp=ramps, triggers=linked,
                                                              tables=entries, definitions=sections), indent=2) + '\n', encoding='utf-8')
    (output / 'audit.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    for row in summary:
        print(f"{row['id']}: {row['cells']} retail cells / {row['slopes']} slopes / {row['triggers']} script rows; zero data mismatches")


if __name__ == '__main__':
    audit(*map(Path, sys.argv[1:]))
