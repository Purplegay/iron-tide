"""Export retail bridge underlay and damage art; no map/save edits.

Run native_map_source.mjs first, then bridge_art.py SOURCE PROJECT OUTPUT.
The intact recomposition must equal existing terrain, except explicit repair of
previously omitted high decks with --repair-missing-high.
"""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
from native_maps import tile

PIXELS = 24
EXTENT = 192


def flatten(source, shape, frame):
    image = Image.open(source / frame['file']).convert('RGBA')
    return image.transform((EXTENT, EXTENT), Image.Transform.AFFINE,
                           (30 / PIXELS, 30 / PIXELS, shape['width'] / 2 - 240,
                            -15 / PIXELS, 15 / PIXELS, shape.get('anchor_y',shape['height'] / 2)),
                           Image.Resampling.BICUBIC)


def export(source, project, output, repair_high=False):
    output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((source / 'manifest.json').read_text())
    audit = []
    for entry in manifest:
        mid = 'yr_' + entry['archive'].split('.')[0].lower()
        map_file = project / 'data/maps' / (mid + '.json')
        row = json.loads(map_file.read_text())
        if not row['bridges']:
            continue
        assert row['sha256'] == entry['sha256']
        palette_bytes = (source / entry['pal']).read_bytes()
        palette = [tuple(min(255, c * 4) for c in palette_bytes[i:i + 3]) for i in range(0, 768, 3)]
        base = Image.new('RGB', (row['side'] * PIXELS,) * 2, (7, 12, 16))
        clear = tile(source, entry['tiles'][0], 0, palette, PIXELS)[2]
        cache = {}
        extras = []
        for u, v, _, _, tid, sub, _ in row['cells']:
            if (tid, sub) not in cache:
                cache[tid, sub] = tile(source, entry['tiles'][tid], sub, palette, PIXELS)
            _, _, image, extra = cache[tid, sub]
            base.paste(clear, (u * PIXELS, v * PIXELS))
            base.paste(image, (u * PIXELS, v * PIXELS), image)
            if extra:
                extras.append((u, v, extra))
        for u, v, (ex, ey, image) in sorted(extras, key=lambda e: (e[1] - e[0], e[0] + e[1])):
            transformed = image.transform((EXTENT, EXTENT), Image.Transform.AFFINE,
                                          (30 / PIXELS, 30 / PIXELS, 30 - ex - 240,
                                           -15 / PIXELS, 15 / PIXELS, 15 - ey), Image.Resampling.BICUBIC)
            base.paste(transformed, (int((u - 3.5) * PIXELS), int((v - 3.5) * PIXELS)), transformed)
        shapes = {}
        frames = {}
        count = sum(len(shape['frames']) for shape in entry['bridges'].values())
        atlas = Image.new('RGBA', (EXTENT * 8, EXTENT * max(4, (count + 7)//8)))
        for name, shape in entry['bridges'].items():
            for frame in shape['frames']:
                image = flatten(source, shape, frame)
                index = len(frames)
                x, y = index % 8 * EXTENT, index // 8 * EXTENT
                atlas.paste(image, (x, y))
                key = name + ':' + str(frame['index'])
                frames[key] = image
                shapes[key] = [x, y, EXTENT, EXTENT]
        for name in ('BRIDGE2','BRIDGEB2'):
            for n in range(9):
                key = f'{name}:{n}'
                if key in frames:
                    frames[f'{name}:{n+9}'] = frames[key]
                    shapes[f'{name}:{n+9}'] = shapes[key]
        intact = base.copy()
        for u, v, name, frame in row['bridges']:
            image = frames.get(name + ':' + str(frame))
            if name in ('BRIDGE1','BRIDGE2','BRIDGEB1','BRIDGEB2'):
                assert image is not None, 'Missing high bridge frame: '+name+':'+str(frame)
            if image is not None:
                intact.paste(image, (int((u - 3.5) * PIXELS), int((v - 3.5) * PIXELS)), image)
        original = Image.open(project / 'assets/maps/yr' / (mid + '_terrain.png')).convert('RGB')
        identical = original.size == intact.size and original.tobytes() == intact.tobytes()
        if not identical:
            assert repair_high and any(t[2] in ('BRIDGE1','BRIDGE2','BRIDGEB1','BRIDGEB2') for t in row['bridges']), 'Intact terrain mismatch: ' + mid
            # This repair is only permitted when the shipped map omitted all high decks.
            assert original.size == base.size and original.tobytes() == base.tobytes(), 'Unexpected existing bridge pixels: ' + mid
            intact.save(output / (mid + '_terrain.png'))
        base.save(output / (mid + '_bridge_ground.png'))
        atlas.save(output / (mid + '_bridge_atlas.png'))
        data = {'pixels': PIXELS, 'extent': EXTENT, 'frames': shapes,
                'map_sha256': hashlib.sha256(map_file.read_bytes()).hexdigest(),
                'source_sha256': entry['sha256'], 'theater': row['theater']}
        (output / (mid + '_bridges.json')).write_text(json.dumps(data, indent=2))
        audit.append({'map': mid, 'intact_pixels_identical': identical, 'repaired_missing_high': not identical, 'frames': len(frames), **data})
        print(mid, 'intact pixels identical:', identical, ';', len(frames), 'native bridge frames')
    (output / 'audit.json').write_text(json.dumps(audit, indent=2))


if __name__ == '__main__':
    export(*(Path(arg) for arg in sys.argv[1:4]), repair_high='--repair-missing-high' in sys.argv[4:])
