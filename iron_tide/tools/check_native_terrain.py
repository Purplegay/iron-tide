"""Scan height breaks for repeated screen-vertical texture samples."""
import argparse
import json
from PIL import Image


def inspect_terrain(row, image):
    size = row['side']
    pixels, remainder = divmod(image.width, size)
    if remainder or image.height != image.width or pixels < 8:
        raise ValueError('Invalid terrain texture dimensions')
    levels = {(u, v): z for u, v, _, z, *_ in row['cells']}
    risks = set()
    for (u, v), z in levels.items():
        if any(abs(z - levels.get(neighbor, z)) >= 2 for neighbor in ((u+1,v),(u-1,v),(u,v+1),(u,v-1))):
            risks.update((u+i,v+j) for i in (-1,0,1) for j in (-1,0,1))
    protected = set()
    if row['id'] == 'yr_all02umd':
        protected = {(u,v) for u in range(54,65) for v in range(143,152)}
    data = image.convert('RGB').load()
    shift = max(1, pixels // 6)
    samples = (pixels-shift)**2
    failures = []
    review = []
    for u,v in sorted((risks | protected) & levels.keys()):
        hits = 0
        for y in range(v*pixels, (v+1)*pixels-shift):
            for x in range(u*pixels+shift, (u+1)*pixels):
                color = data[x,y]
                if color == data[x-shift,y+shift] and color != data[x-shift,y]:
                    hits += 1
        if hits >= samples * 0.8:
            (failures if (u,v) in protected else review).append((u,v,hits))
    print(f"{row['id']} scanned {len((risks | protected) & levels.keys())} cells; samples/cell {samples}; review {review}; regression {failures}")
    if failures:
        raise ValueError('Repeated vertical texture at verified south bridge approach')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('map_json')
    parser.add_argument('texture')
    args = parser.parse_args()
    with open(args.map_json, encoding='utf8') as source, Image.open(args.texture) as image:
        inspect_terrain(json.load(source), image)
