"""Bake native SHP alpha bounds and foot anchors without changing artwork.

Run after regenerating SHP atlases. Runtime verifies frame layout before using it.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, UnidentifiedImageError


def box_rect(box):
    return [box[0], box[1], box[2]-box[0], box[3]-box[1]] if box else [0, 0, 0, 0]


def main():
    root = Path(__file__).resolve().parents[1] / 'iron_tide/assets/ra2'
    entries = {}
    for path in sorted((root / 'shp').glob('*.json')):
        if not path.with_suffix('.png').is_file():
            continue
        desc = json.loads(path.read_bytes())
        frames = desc.get('rects', [])
        if not frames or not all(isinstance(f, dict) for f in frames):
            continue
        try:
            opened = Image.open(path.with_suffix('.png'))
        except UnidentifiedImageError:
            print('Skip unreadable source, retain runtime fallback:', path.name)
            continue
        with opened as image:
            alpha = image.convert('RGBA').getchannel('A')
            rows = []
            for f in frames:
                x, y, w, h = [int(f[k]) for k in ('x', 'y', 'w', 'h')]
                frame = alpha.crop((x, y, x+w, y+h))
                rows.append([x, y, w, h, *box_rect(frame.getbbox()),
                             *box_rect(frame.point(lambda a: 255 if a >= 16 else 0).getbbox())])
            entries[path.stem] = {'size': list(image.size), 'frames': rows,
                'sha256': hashlib.sha256(path.with_suffix('.png').read_bytes()).hexdigest()}
    dest = root / 'shp_geometry.json'
    dest.write_text(json.dumps(entries, separators=(',', ':'))+'\n', encoding='utf8')
    print(len(entries), 'atlases;', dest.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
