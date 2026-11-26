"""Check imported terrain against unpacked retail theater directories (arguments)."""
import json
import struct
import sys
from collections import Counter, defaultdict
from functools import cache
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sources = defaultdict(list)
for directory in map(Path, sys.argv[1:]):
    for entry in json.loads((directory / 'manifest.json').read_text()):
        sources[entry['theater']].append((directory, entry['tiles']))

@cache
def retail(theater, tile, sub):
    for directory, tiles in sources[theater]:
        path = directory / tiles[tile]['name']
        if not path.is_file():
            continue
        data = path.read_bytes()
        nx, ny = struct.unpack_from('<II', data)
        if sub >= nx * ny:
            raise ValueError((path, sub))
        offset, = struct.unpack_from('<I', data, 16 + sub * 4)
        if not offset:
            raise ValueError((path, sub))
        return data[offset + 41:offset + 43], path.stem.lower()
    return None

errors = Counter()
print('|地图|格数|坡格|DRSLPE 坡格|高桥片|低桥片|相连桥段|维修小屋|已对照 TMP 格|差异格|')
print('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
for file in sorted((root / 'data/maps').glob('yr_*.json')):
    row = json.loads(file.read_text(encoding='utf8'))
    if 'cells' not in row:
        continue
    checked = different = slopes = streets = 0
    for u, v, kind, height, tile, sub, ramp in row['cells']:
        slopes += bool(ramp)
        ref = retail(row['theater'], tile, sub)
        if ref is None:
            errors['missing'] += 1
            continue
        checked += 1
        streets += bool(ramp and ref[1].startswith('drslpe'))
        if ref[0] != bytes((kind, ramp)):
            different += 1
            errors['mismatch'] += 1
    low = sum(t[2].startswith('LOBRDG') for t in row['bridges'])
    remaining = {(x, y) for x, y, *_ in row['bridges']}
    spans = 0
    while remaining:
        spans += 1
        stack = [remaining.pop()]
        while stack:
            x, y = stack.pop()
            for neighbor in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    stack.append(neighbor)
    huts = sum(t[0].startswith('CABHUT') for t in row['structures'])
    print(f'|{file.stem}|{len(row["cells"])}|{slopes}|{streets}|{len(row["bridges"])-low}|{low}|{spans}|{huts}|{checked}|{different}|')
print(dict(errors), file=sys.stderr)
sys.exit(bool(errors))
