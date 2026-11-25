"""Bake installed YR maps into data consumed by Godot (Python: lzokay, Pillow).

Format references: EA FinalAlert source MapData / MissionEditorPackLib and XCC
TMP headers. No mission scripting is executed. Ground is a flat adaptation;
original heights remain in the data and impassable cliff cells remain blocked.
Run native_map_source.mjs first. Usage: native_maps.py SOURCE_DIR PROJECT_DIR
"""
import base64
import configparser
import hashlib
import json
import struct
import sys
from pathlib import Path

import lzokay
from PIL import Image


def ini(text):
    result = configparser.ConfigParser(strict=False, interpolation=None, inline_comment_prefixes=(';',))
    result.read_string('\n'.join(line for line in text.splitlines()
                                if line.lstrip().startswith('[') or ('=' in line and not line.lstrip().startswith((';', '//', ':')))))
    return result


def lcw(data, limit):
    out = bytearray()
    i = 0
    while i < len(data):
        tag = data[i]; i += 1
        if tag == 128:
            break
        if tag < 128:
            count = (tag >> 4) + 3
            origin = len(out) - (((tag & 15) << 8) | data[i]); i += 1
        elif tag < 192:
            count = tag & 63
            out.extend(data[i:i + count]); i += count
            continue
        elif tag == 254:
            count = struct.unpack_from('<H', data, i)[0]; i += 2
            out.extend(bytes([data[i]]) * count); i += 1
            continue
        else:
            count = (tag & 63) + 3
            if tag == 255:
                count = struct.unpack_from('<H', data, i)[0]; i += 2
            origin = struct.unpack_from('<H', data, i)[0]; i += 2
        if origin < 0 or origin >= len(out) or len(out) + count > limit:
            raise ValueError('Invalid LCW back reference')
        for j in range(count):
            out.append(out[origin + j])
    if len(out) != limit:
        raise ValueError(f'LCW decoded {len(out)}, expected {limit}')
    return bytes(out)


def unpack(section, codec):
    packed = base64.b64decode(''.join(v for k, v in sorted(section.items(), key=lambda p: int(p[0]))), validate=True)
    result = bytearray(); offset = 0
    while offset < len(packed):
        count, size = struct.unpack_from('<HH', packed, offset); offset += 4
        if count == size == 0:
            break
        if not count or not size or offset + count > len(packed):
            raise ValueError('Invalid packed map chunk')
        chunk = packed[offset:offset + count]; offset += count
        result.extend(lzokay.decompress(chunk, size) if codec == 'lzo' else lcw(chunk, size))
    return bytes(result)


def iso_records(packed):
    # FinalAlert CMapData::Unpack derives record count from decoded byte count,
    # not Map.Size: retail RiverRam omits clear tiles. Retail streams end in 4 zeros.
    count, tail = divmod(len(packed), 11)
    if tail not in (0, 4) or (tail and packed[-tail:] != bytes(tail)):
        raise ValueError('Invalid IsoMapPack5 record tail')
    rows = list(struct.iter_unpack('<HHIBBB', packed[:count * 11]))
    if not rows or len({r[:2] for r in rows}) != len(rows):
        raise ValueError('Empty or duplicate IsoMapPack5 cells')
    return rows


def fill_clear_cells(rows, width, height):
    # FinalAlert FIELDDATA defaults: wGround=0xffff (clear), subtile=height=0.
    # Keep existing order byte-stable for already imported map/save fingerprints.
    present = {r[:2] for r in rows}
    return rows + [(x, y, 65535, 0, 0, 0)
                   for x in range(1, width + height) for y in range(1, width + height)
                   if 0 <= x-y+width-1 < 2*width-1 and 0 <= x+y-width-1 < 2*height
                   and (x, y) not in present]


def tile(source, row, subtile, palette, pixels):
    b = (source / row['name']).read_bytes()
    nx, ny, width, height = struct.unpack_from('<IIII', b)
    assert subtile < nx * ny and width == 60 and height == 30
    offset = struct.unpack_from('<I', b, 16 + subtile * 4)[0]
    if not offset:
        raise ValueError('Missing subtile ' + row['name'])
    terrain, ramp = b[offset + 41], b[offset + 42]
    # TMP diamond rows are 4,8,...,60,56,...,0 pixels, header is 52 bytes.
    diamond = Image.new('RGBA', (60, 30))
    cursor = offset + 52
    for y in range(30):
        count = 4 * (y + 1 if y < 15 else 29 - y)
        start = (60 - count) // 2
        for x in range(count):
            index=b[cursor+x]
            diamond.putpixel((start + x, y), palette[index]+(255 if index else 0,))
        cursor += count
    # World +x is original -ry; world +y is original +rx. Match Iso camera.
    square = Image.new('RGBA', (pixels, pixels))
    for v in range(pixels):
        for u in range(pixels):
            sx = min(59, int((u + v + 1) * 30 / pixels))
            sy = min(29, max(0, int((v - u) * 15 / pixels + 14.5)))
            count = 4 * (sy + 1 if sy < 15 else 29 - sy)
            sx = max((60 - count) // 2, min((60 + count) // 2 - 1, sx)) if count else 29
            square.putpixel((u, v), diamond.getpixel((sx, sy)))
    extra=None
    if struct.unpack_from('<I',b,offset+36)[0]&1:
        tx,ty=struct.unpack_from('<ii',b,offset)
        ex,ey,ew,eh=struct.unpack_from('<iiii',b,offset+20)
        indices=b[offset+52+1800:offset+52+1800+ew*eh]
        if ew>0 and eh>0:
            assert len(indices)==ew*eh
            image=Image.frombytes('RGBA',(ew,eh),bytes(c for index in indices for c in palette[index]+(255 if index else 0,)))
            extra_y = ey - ty
            if Path(row['name']).stem.lower().startswith('ovrps'):
                # Bridge heads/pillars mix road-height and water-height subtiles.
                # Ground diamonds are flattened independently; put their extra
                # pixels on that same road plane, not the original lower plane.
                offsets = struct.unpack_from('<' + 'I' * (nx * ny), b, 16)
                road_height = max(b[o + 40] for o in offsets if o)
                extra_y += (road_height - b[offset + 40]) * (height // 2)
            extra=(ex-tx,extra_y,image)
    return terrain, ramp, square, extra


def bake(source, project):
    dest = project / 'assets/maps/yr'; dest.mkdir(parents=True, exist_ok=True)
    data_dir = project / 'data/maps'; data_dir.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((source / 'manifest.json').read_text())
    rules = ini((source / 'rulesmd.ini').read_text(encoding='cp1252'))
    art = ini((source / 'artmd.ini').read_text(encoding='cp1252'))
    # Westwood type lists use insertion order, NOT the numeric INI key.
    overlay_names = dict(enumerate(rules['OverlayTypes'].values()))
    catalog = []
    for entry in manifest:
        raw = (source / (entry['archive'] + '.map')).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == entry['sha256']
        config = ini(raw.decode('cp1252'))
        packed = unpack(config['IsoMapPack5'], 'lzo')
        map_width, map_height = map(int, config['Map']['Size'].split(',')[2:])
        records = fill_clear_cells(iso_records(packed), map_width, map_height)
        lx, ly, lw, lh = map(int, config['Map']['LocalSize'].split(','))
        # LocalSize is in the projected diamond grid, not raw rx/ry coordinates.
        def inside(x, y):
            dx = x - y + map_width - 1
            dy = x + y - map_width - 1
            return lx * 2 <= dx < (lx + lw) * 2 and ly * 2 <= dy < (ly + lh) * 2
        records = [r for r in records if inside(r[0], r[1])]
        min_x = min(r[0] for r in records); max_y = max(r[1] for r in records)
        side = max(max(r[0] for r in records) - min_x + 1, max_y - min(r[1] for r in records) + 1)
        def position(x, y): return [max_y - y, x - min_x]
        pixels = 24
        canvas = Image.new('RGB', (side * pixels, side * pixels), (7, 12, 16))
        pal = (source / entry['pal']).read_bytes()
        palette = [tuple(min(255, c * 4) for c in pal[i:i + 3]) for i in range(0, 768, 3)]
        cache = {}; cells = []; valid = set(); extras=[]
        clear=tile(source,entry['tiles'][0],0,palette,pixels)[2]
        overlays = unpack(config['OverlayPack'], 'lcw')
        levels = unpack(config['OverlayDataPack'], 'lcw')
        assert len(overlays) == len(levels) == 512 * 512
        resources = []; bridges = []
        for x, y, tid, sub, z, _ in records:
            tid = 0 if tid in (65535, 0xffffffff) else tid
            key = (tid, sub)
            if key not in cache:
                cache[key] = tile(source, entry['tiles'][tid], sub, palette, pixels)
            terrain, ramp, image, extra = cache[key]
            u, v = position(x, y)
            cells.append([u, v, terrain, z, tid, sub, ramp]); valid.add((x, y))
            canvas.paste(clear,(u*pixels,v*pixels))
            canvas.paste(image, (u * pixels, v * pixels),image)
            if extra:extras.append((u,v,extra))
            overlay = overlay_names.get(overlays[x + y * 512], '').split(';')[0].strip()
            if overlay.startswith(('TIB', 'GEM')) and overlay[-2:].isdigit():
                resources.append([u, v, 'gems' if overlay.startswith('GEM') else 'ore', int(levels[x + y * 512]) + 1])
            if overlay.startswith(('BRIDGE', 'RAILBRDG', 'LOBRDG')):
                bridges.append([u, v, overlay, int(levels[x+y*512])])
        for u,v,(ex,ey,image) in sorted(extras,key=lambda e:(e[1]-e[0],e[0]+e[1])):
            radius=4;extent=radius*2*pixels
            transformed=image.transform((extent,extent),Image.Transform.AFFINE,
                (30/pixels,30/pixels,30-ex-radius*60,
                 -15/pixels,15/pixels,15-ey),Image.Resampling.BICUBIC)
            canvas.paste(transformed,(int((u+.5-radius)*pixels),int((v+.5-radius)*pixels)),transformed)
        for u,v,name,frame in bridges:
            shape=entry.get('bridges',{}).get(name,{})
            local_frame = frame - 9 if name in ('BRIDGE2','BRIDGEB2') and 9 <= frame < 18 else frame
            image_row=next((f for f in shape.get('frames',[]) if f['index']==local_frame),None)
            if name in ('BRIDGE1','BRIDGE2','BRIDGEB1','BRIDGEB2') and not image_row:
                raise ValueError('Missing high bridge frame: '+name+':'+str(frame))
            if not image_row:continue
            image=Image.open(source/image_row['file']).convert('RGBA')
            # Flatten the isometric SHP into the same world axes as TMP ground.
            radius=4; extent=radius*2*pixels
            transformed=image.transform((extent,extent),Image.Transform.AFFINE,
                (30/pixels,30/pixels,shape['width']/2-radius*60,
                 -15/pixels,15/pixels,shape.get('anchor_y',shape['height']/2)),Image.Resampling.BICUBIC)
            canvas.paste(transformed,(int((u+.5-radius)*pixels),int((v+.5-radius)*pixels)),transformed)
        starts = []
        for key, value in config['Waypoints'].items():
            if int(key) > 7: continue
            x, y = int(value) % 1000, int(value) // 1000
            assert (x, y) in valid
            u, v = position(x, y); starts.append([int(key), u + .5, v + .5])
        structures = []; site_types={}
        for row in config['Structures'].values() if 'Structures' in config else []:
            values = row.split(','); x, y = int(values[3]), int(values[4])
            if (x, y) in valid:
                sid=values[1]; u, v = position(x, y); structures.append([sid, u + .5, v + .5])
                rule=rules[sid] if sid in rules else {}
                image=rule.get('image',sid)
                drawing=art[image] if image in art else {}
                site_types[sid]={key:rule.get(key,default) for key,default in [('strength','600'),('armor','wood'),('sight','4'),('canbeoccupied','no'),('maxnumberoccupants','0')]}
                site_types[sid]['foundation']=drawing.get('foundation','1x1')
        mid = 'yr_' + entry['archive'].split('.')[0].lower()
        canvas.save(dest / (mid + '_terrain.png'))
        pw, ph = map(int, config['Preview']['Size'].split(',')[2:])
        preview = unpack(config['PreviewPack'], 'lzo')
        assert len(preview) >= pw * ph * 3
        Image.frombytes('RGB', (pw, ph), preview[:pw * ph * 3]).save(dest / (mid + '_preview.png'))
        data = {k: entry[k] for k in ['title','archive','sha256','archive_sha256','theater']}
        if 'container' in entry:
            data['container'] = entry['container']
        data.update(id=mid, side=side, cell_size=55, cells=cells, resources=resources, starts=starts,
                    structures=structures, site_types=site_types, bridges=bridges, local_size=[lx,ly,lw,lh],
                    adaptation='Original cells and TMP ground, flat elevation; original mission triggers are not executed.')
        (data_dir / (mid + '.json')).write_text(json.dumps(data, separators=(',',':')), encoding='utf8')
        from native_ore import export_ore
        export_ore(raw, data, rules, data_dir / 'ore')
        catalog.append({k: data[k] for k in ['id','title','archive','sha256','theater','side']})
        print(mid, side, 'cells',len(cells),'ore',len(resources),'bridges',len(bridges),'structures',len(structures))
    catalog_file = data_dir / 'yr_catalog.json'
    existing = json.loads(catalog_file.read_text(encoding='utf8')) if catalog_file.exists() else []
    by_id = {row['id']: row for row in existing}
    by_id.update((row['id'], row) for row in catalog)
    catalog_file.write_text(json.dumps(list(by_id.values()), indent=2), encoding='utf8')


if __name__ == '__main__':
    bake(Path(sys.argv[1]), Path(sys.argv[2]))
