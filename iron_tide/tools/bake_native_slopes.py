"""Reproject retail TMP slopes onto the flat playable map, preserving cell coordinates.
Usage: python tools/bake_native_slopes.py SOURCE MAP_JSON INPUT_PNG OUTPUT_PNG
"""
import json
import struct
import sys
from functools import lru_cache
from pathlib import Path
from PIL import Image

source, map_file, input_png, output_png = map(Path, sys.argv[1:])
row = json.loads(map_file.read_text(encoding='utf8'))
theater = next(t for t in json.loads((source/'manifest.json').read_text()) if t['theater'] == row['theater'])
palette = bytes(min(255, v*4) for v in (source/theater['pal']).read_bytes())
# NW, NE, SE, SW in the original rx/ry coordinate system (ObjectPosition rampHeights).
corners = [(0,0,0,0),(0,1,1,0),(0,0,1,1),(1,0,0,1),(1,1,0,0),
           (0,0,1,0),(0,0,0,1),(1,0,0,0),(0,1,0,0),(0,1,1,1),
           (1,0,1,1),(1,1,0,1),(1,1,1,0),
           (0,1,2,1),(1,0,1,2),(2,1,0,1),(1,2,1,0),
           (0,1,0,1),(1,0,1,0),(0,1,0,1),(1,0,1,0)]

@lru_cache(None)
def sprite(tid, sub):
    data = (source/theater['tiles'][tid]['name']).read_bytes()
    offset, = struct.unpack_from('<I', data, 16+4*sub)
    assert offset
    x,y,extra_off,_,_,ex,ey,w,h,flags = struct.unpack_from('<iiIIIiiiiI', data, offset)
    image = Image.new('L',(60,30))
    cursor = offset+52
    for line in range(29):
        length = 4*min(line+1,29-line)
        image.paste(Image.frombytes('L',(length,1),data[cursor:cursor+length]),((60-length)//2,line))
        cursor += length
    parts = [(image,0,0)]
    if flags & 1:
        start = offset+extra_off
        parts.append((Image.frombytes('L',(w,h),data[start:start+w*h]),ex-x,ey-y))
    return parts, data[offset+42]

# The retail diamond and extra rectangle can both extend into adjacent cells.
# Composite in original screen space before sampling the inclined surface.
size = row['side']
surface = Image.new('L',(size*60+512,size*30+768))
def origin(u,v,z):
    return (256+30*(u+v),384+15*(size+v-u-z))
for u,v,_,z,tid,sub,ramp in sorted(row['cells'],key=lambda c:(c[1]-c[0],c[0]+c[1])):
    sx,sy = origin(u,v,z)
    parts, tmp_ramp = sprite(tid,sub)
    if ramp != tmp_ramp or not 0 <= ramp < len(corners):
        raise ValueError(f'Cell ({u},{v}), tile {tid}/{sub}: map ramp {ramp}, retail TMP ramp {tmp_ramp}')
    for part,dx,dy in parts:
        surface.paste(part,(sx+dx,sy+dy),part.point(lambda p:255 if p else 0))

result = Image.open(input_png).convert('RGB')
pixels = result.width//size
assert result.size == (size*pixels,)*2
# The old flat bake also stamped slope extras across the adjoining flat tiles.
# Resample those joins from the same elevated composite as the road surface.
road_edges = {(u+du, v+dv) for u,v,_,_,tid,_,ramp in row['cells']
              if ramp and theater['tiles'][tid]['name'].lower().startswith('prslpe')
              for du in (-1,0,1) for dv in (-1,0,1)}
# A vertical TMP face lies between two walkable elevations. Give it a
# continuous sampling interval on the flat map, including its slope join.
# In local sampling coordinates x follows +v and y follows -u.
from collections import defaultdict
vertex_levels = defaultdict(list)
cliff_edges = set()
for u,v,_,z,tid,sub,ramp in row['cells']:
    for (du,dv), height in zip(((1,0),(1,1),(0,1),(0,0)), corners[ramp]):
        vertex_levels[u+du,v+dv].append(z+height)
    if theater['tiles'][tid]['name'].lower().startswith('cliff'):
        cliff_edges.update((u+du,v+dv) for du in range(-2,3) for dv in range(-2,3))
# Alcatraz uses WClifx coastal faces as well as inland Cliff pieces.
# Ease a four-level discontinuity over the artwork's footprint. A direct
# average at the two shared vertices would stretch a single source scanline.
alcatraz = {}
if row['id'] == 'yr_sov01':
    heights = {(u,v): z for u,v,_,z,*_ in row['cells']}
    for u,v,_,z,tid,_,_ in row['cells']:
        if 106 <= u <= 140 and 20 <= v <= 46 and 'clif' in theater['tiles'][tid]['name'].lower():
            for i in range(u-2,u+3):
                for j in range(v-2,v+3):
                    alcatraz[i,j] = True
    @lru_cache(None)
    def coast_vertex(u,v):
        samples = [heights[i,j] for i in range(u-2,u+2) for j in range(v-2,v+2) if (i,j) in heights]
        return sum(samples)/len(samples)
covered = 0
for u,v,_,z,tid,sub,ramp in row['cells']:
    # ALL02UMD's south abutment is a four-level vertical face. Project the
    # retail composite in a single plane across the face; averaging cliff
    # vertices here collapses the sampler onto one scanline of pavement.
    south_bank = row['id'] == 'yr_all02umd' and 50 <= u <= 68 and 139 <= v <= 159
    if not ramp and (u,v) not in road_edges and (u,v) not in cliff_edges and not south_bank and (u,v) not in alcatraz: continue
    a,b,c,d = corners[ramp]
    if (u,v) in cliff_edges and row['id'] != 'yr_sov01':
        levels = [vertex_levels[u+du,v+dv] for du,dv in ((1,0),(1,1),(0,1),(0,0))]
        a,b,c,d = (sum(values)/len(values)-z for values in levels)
    if (u,v) in alcatraz and not ramp:
        a,b,c,d = (coast_vertex(u+du,v+dv)-z for du,dv in ((1,0),(1,1),(0,1),(0,0)))
    sx,sy = origin(u,v,z)
    patch = Image.new('P',(pixels,pixels))
    patch.putpalette(palette)
    indices = []
    for py in range(pixels):
        x = (py+.5)/pixels
        for px in range(pixels):
            y = 1-(px+.5)/pixels
            rise = (1-x)*((1-y)*a+y*d)+x*((1-y)*b+y*c)
            if south_bank:
                distance = max(54-(u+1-y), (u+1-y)-64, 143-(v+x), (v+x)-155, 0)
                weight = max(0, 1-distance/4)
                rise += weight * (4-z-rise)
            indices.append(surface.getpixel((int(sx+30*(1+x-y)),int(sy+15*(x+y-rise)))))
    patch.putdata(indices)
    result.paste(patch.convert('RGB'),(u*pixels,v*pixels),Image.frombytes('L',patch.size,bytes(255 if i else 0 for i in indices)))
    covered += 1
from check_native_terrain import inspect_terrain
inspect_terrain(row, result)
result.save(output_png)
slopes = sum(bool(cell[6]) for cell in row['cells'])
print(f'Baked {slopes} slope cells and {covered-slopes} adjoining flat cells at {pixels} pixels per cell')
