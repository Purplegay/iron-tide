"""Compare the three installed campaign map exports to extracted retail MAP/TMP.
Usage: python tools/audit_three_campaign_maps.py S01_DIR ALL02_DIR S07_DIR OUT_JSON
"""
from collections import Counter
from functools import cache
from hashlib import sha256
import json
from pathlib import Path
import struct
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / 'ra2pipe'))
from native_maps import fill_clear_cells, ini, iso_records, unpack


def audit(source, file, mid, origin):
    data = json.loads((root / f'data/maps/{mid}.json').read_text(encoding='utf8'))
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf8'))
    entry = next(e for e in manifest if e['archive'].lower().split('.')[0] in (file.split('.')[0], mid[3:]))
    raw = (source / file).read_bytes()
    retail = ini(raw.decode('cp1252'))
    size = list(map(int, retail['Map']['Size'].split(',')))
    width, height = size[2:]
    lx, ly, lw, lh = local = list(map(int, retail['Map']['LocalSize'].split(',')))
    # SOV01 uses the union export instead of cropping permanently to the opening.
    cx, cy, cw, ch = data['local_size'] if mid == 'yr_sov01' else local
    origin_x, origin_y = origin
    def crop(x, y): return 2*cx <= x-y+width-1 < 2*(cx+cw) and 2*cy <= x+y-width-1 < 2*(cy+ch)
    def export(x, y): return origin_y-y, x-origin_x
    def retail_xy(u, v): return origin_x+v, origin_y-u
    expected = {export(x,y):(0 if tile in (65535,0xffffffff) else tile,sub,z)
                for x,y,tile,sub,z,_ in fill_clear_cells(iso_records(unpack(retail['IsoMapPack5'],'lzo')),width,height) if crop(x,y)}
    actual = {(u,v):((tile,sub,z),kind,ramp) for u,v,kind,z,tile,sub,ramp in data['cells']}
    @cache
    def tmp(tile, sub):
        path = source / entry['tiles'][tile]['name']
        b=path.read_bytes()
        off=struct.unpack_from('<I',b,16+sub*4)[0]
        if not off or off+43>len(b): raise ValueError((path,sub,off))
        return tuple(b[off+41:off+43]),path.stem
    overlap=actual.keys() & expected.keys()
    mismatch=[(p,expected[p],actual[p][0]) for p in sorted(overlap) if expected[p]!=actual[p][0]]
    tmp_mismatch=[]
    slopes=Counter()
    for p,((tile,sub,z),kind,ramp) in actual.items():
        kr,name=tmp(tile,sub)
        if kr!=(kind,ramp):tmp_mismatch.append((p,kr,(kind,ramp)))
        if ramp: slopes[f'{name}:{ramp}']+=1
    names=list(ini((source/'rulesmd.ini').read_text(encoding='cp1252'))['OverlayTypes'].values())
    ov=unpack(retail['OverlayPack'],'lcw'); levels=unpack(retail['OverlayDataPack'],'lcw')
    bridges=[]; fences=[]; resources=[]
    for u,v in expected:
        x,y=retail_xy(u,v); n=x+y*512; code=ov[n]
        if code>=len(names):continue
        name=names[code].split(';')[0].strip()
        if name.startswith(('BRIDGE','RAILBRDG','LOBRDG')): bridges.append([u,v,name,levels[n]])
        if name in ('CAFNCP','CAFNCB','CAFNCW','GAWALL','NAWALL','GAFWLL','GAFWLL2','YAWALL'):fences.append([u,v,name,levels[n]])
        if name.startswith(('TIB','GEM')) and name[-2:].isdigit():resources.append([u,v,'gems' if name.startswith('GEM') else 'ore',levels[n]+1])
    structures=[r.split(',') for r in retail['Structures'].values()]
    sites=[]
    for source_id, raw_structure in retail['Structures'].items():
        owner, kind, hp, x, y, facing, tag, *_=raw_structure.split(',')
        u,v=export(int(x),int(y))
        if (u,v) not in expected: continue
        sites.append([source_id,owner,kind,int(hp),u,v,int(facing),tag])
    huts=[r[:7] for r in structures if r[1]=='CABHUT']
    mission_bridge=[r[:7] for r in structures if r[0]=='BridgeHouse' or mid=='yr_sov01' and r[1] in ('CASANF04','CASANF09','CASANF10','CASANF11','CASANF12','CASANF13','CASANF14')]
    report=dict(map=mid,sha=sha256(raw).hexdigest(),hash_matches=data['sha256']==sha256(raw).hexdigest(),retail_size=size,
        retail_boundary=local,export_boundary=data['local_size'],origin=origin,actual_cells=len(actual),expected_cells=len(expected),
        duplicate_cells=len(data['cells'])-len(actual),missing_cells=sorted(expected.keys()-actual.keys()),extra_cells=sorted(actual.keys()-expected.keys()),
        tile_height_differences=mismatch,tmp_differences=tmp_mismatch,slope_count=sum(slopes.values()),slopes=slopes,
        bridge_count=len(bridges),bridge_match=sorted(bridges)==sorted(data['bridges']),
        resource_count=len(resources),resource_match=sorted(resources)==sorted(data['resources']),
        bridge_huts=huts,inside_huts=sum(export(int(r[3]),int(r[4])) in expected for r in huts),
        data_huts=sum(r[0]=='CABHUT' for r in data['structures']),mission_bridge=mission_bridge,fences=fences,retail_sites=sites)
    if mid=='yr_sov01':
        field=json.loads((root/'data/time_shift_field.json').read_text())
        listed=sorted([int(u),int(v),name,frame] for name,u,v,frame in field['overlay'] if name in ('CAFNCP','GAWALL') and (int(u),int(v)) in expected)
        report['fence_rows_match']=listed==sorted(r for r in fences if r[2] in ('CAFNCP','GAWALL'))
        report['alcatraz_fence']=[r for r in fences if 117<=r[0]<=123 and 27<=r[1]<=33]
    elif mid=='yr_all02umd':
        overlay_path=root/'data/maps/hollywood_wall_overlays.json'
        report['fence_rows_match']=overlay_path.exists() and json.loads(overlay_path.read_text())==sorted(fences)
    elif mid=='yr_sov07':
        field=json.loads((root/'data/head_games_sites.json').read_text(encoding='utf8'))
        listed=sorted([int(u),int(v),name,frame] for name,u,v,frame in field['overlaySites'])
        report['fence_rows_match']=listed==sorted(fences)
    return report


def main(args):
    s1,a2,s7,out=map(Path,args)
    rows=[audit(s1,'sov01.map','yr_sov01',(10,190)),audit(a2,'all02umd.map.map','yr_all02umd',(12,206)),audit(s7,'sov07.map','yr_sov07',(11,201))]
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    for r in rows:
        print(r['map'], 'cells',r['actual_cells'], 'missing/extra/tile/TMP',*[len(r[k]) for k in ('missing_cells','extra_cells','tile_height_differences','tmp_differences')],
              'slopes',r['slope_count'],'bridges',r['bridge_count'],r['bridge_match'],'huts',r['inside_huts'],r['data_huts'],'ore',r['resource_count'],r['resource_match'],'walls',Counter(x[2] for x in r['fences']))
    print('Fence tables:',[r['fence_rows_match'] for r in rows], 'Alcatraz:',len(rows[0]['alcatraz_fence']))
    return int(any(not all(r[k] for k in ('hash_matches','bridge_match','resource_match','fence_rows_match'))
                   or r['inside_huts']!=r['data_huts'] or any(r[k] for k in ('duplicate_cells','missing_cells','extra_cells','tile_height_differences','tmp_differences')) for r in rows))


if __name__=='__main__': sys.exit(main(sys.argv[1:]))
