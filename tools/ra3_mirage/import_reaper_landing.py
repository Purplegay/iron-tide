"""Compile the retail JMPC_LEGS prop."""
from collections import defaultdict
from import_soviet import C, OUT, cv, read, dump

def main():
    stem = 'SUHEAVYWALKERVEHICLE_JMPC_LEGS'
    source = read(C/'meshes'/f'W3DMesh_{stem}.SCYTHE.json')
    rig = read(C/'hierarchies'/f'W3DHierarchy_{stem}.json')['bones']
    anim = read(C/'animations'/f'W3DAnimation_{stem}.json')
    attrs = source['attributes']
    assert 'w0' not in attrs  # Retail mesh is rigid per joint.
    owners = [source['bone_palette'][index[0]] for index in attrs['i0']]
    groups = defaultdict(list)
    for i in range(0, len(source['indices']), 3):
        triangle = source['indices'][i:i+3]
        assert len({owners[v] for v in triangle}) == 1
        groups[owners[triangle[0]]].extend(triangle)
    parts = []
    for bone, indices in groups.items():
        used = sorted(set(indices))
        lookup = {v:i for i,v in enumerate(used)}
        parts.append(dict(bone=bone, vertices=[x for v in used for x in cv(attrs['p0'][v])],
                          normals=[x for v in used for x in cv(attrs['n0'][v])],
                          uv=[x for v in used for x in attrs['t0'][v]], indices=[lookup[v] for v in indices]))
    tracks = []
    for c in anim['channels']:
        assert c['format'] == 'AnimationChannelTimecoded'
        n = c['vector_length']
        tracks.append(dict(bone=c['pivot'], kind=c['channel_type_name'], times=[f&0x7fff for f in c['frame_and_binary_flag']],
                           values=[c['values'][i:i+n] for i in range(0,len(c['values']),n)]))
    bones = [dict(parent=b['parent'],position=cv(b['translation']),rotation=cv(b['rotation_xyzw'][:3])+b['rotation_xyzw'][3:]) for b in rig]
    dump(OUT/'R3REAPER'/'landing_legs.json',dict(bones=bones,parts=parts,tracks=tracks,fps=anim['fps'],frames=anim['frames']))

if __name__=='__main__':
    main()
