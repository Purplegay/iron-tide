"""Build Yuriko's skinned unit head using the journal illustration as its UV atlas.

Run on the two exported GLBs. The outfit, inverse bind matrices, and animation data
come from each model. Geometry is authored in the original skeleton's bind space.
"""
import argparse
import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image


# Height on the portrait, half-width, front depth and rear depth in bind-space units.
# The last rings turn under the jaw and close inside the original neck.
PROFILE = [
    (9, 4, .04, .04), (18, 64, .48, .53), (40, 115, .83, .93),
    (75, 151, 1.11, 1.22), (122, 173, 1.31, 1.42),
    (178, 183, 1.42, 1.50), (235, 186, 1.46, 1.51),
    (274, 184, 1.46, 1.48), (301, 182, 1.46, 1.42),
    (325, 180, 1.45, 1.36), (349, 177, 1.44, 1.28),
    (370, 169, 1.42, 1.18), (388, 156, 1.39, 1.08),
    (410, 139, 1.37, .96), (432, 117, 1.35, .84),
    (451, 90, 1.29, .71), (472, 58, 1.24, .58),
    (486, 27, 1.16, .44), (490, 4, 1.06, .34),
]
CENTER = 365
SCALE = .00745
DEPTH_CENTER = -.48
HEAD_DROP = .40


def neck_drop(x, y):
    """Compress the exposed neck above the sloping collar in bind space."""
    collar_y = 20.035 - .32*x
    return HEAD_DROP * np.clip((y - collar_y - .09) / .74, 0., 1.)


def unpack(path):
    data = path.read_bytes()
    header_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + header_size])
    return doc, bytearray(data[28 + header_size:])


def pack(path, doc, binary):
    doc["buffers"][0]["byteLength"] = len(binary)
    header = json.dumps(doc, separators=(",", ":")).encode()
    header += b" " * (-len(header) % 4)
    binary.extend(bytes(-len(binary) % 4))
    chunks = struct.pack("<I4s", len(header), b"JSON") + header
    chunks += struct.pack("<I4s", len(binary), b"BIN\0") + binary
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(chunks)) + chunks)


def read_array(doc, binary, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    assert not view.get("byteStride") and not acc.get("byteOffset")
    dtype = {5126: "<f4", 5123: "<u2"}[acc["componentType"]]
    return np.frombuffer(memoryview(binary)[view["byteOffset"]:view["byteOffset"]+view["byteLength"]], dtype=dtype).reshape(acc["count"], -1)


def remove_old_head(doc, binary, head_joints):
    primitive = doc["meshes"][0]["primitives"][0]
    attrs = primitive["attributes"]
    joints = read_array(doc, binary, attrs["JOINTS_0"])
    weights = read_array(doc, binary, attrs["WEIGHTS_0"])
    triangles = read_array(doc, binary, primitive["indices"]).reshape(-1, 3)
    # The neck shares head weights with the face. Keep the entire component
    # connected to the torso, including its top ring.
    parents = list(range(len(joints)))

    def component(i):
        while i != parents[i]:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for a, b, c in triangles:
        parents[component(a)] = component(b)
        parents[component(c)] = component(b)
    dominant = joints[np.arange(len(joints)), weights.argmax(axis=1)]
    body = {component(i) for i, joint in enumerate(dominant) if joint not in head_joints}
    keep = np.array([t for t in triangles if component(t[0]) in body])
    assert 0 < len(keep) < len(triangles)
    used, remap = np.unique(keep, return_inverse=True)
    # Both outfits share the native rest neck and its oblique collar line.
    # Compress only retained collar-to-jaw vertices; the head moves as a rigid shape.
    positions = read_array(doc, binary, attrs["POSITION"])[used]
    x, y, z = positions.T
    offset = np.where(abs(z) < 1.1, neck_drop(x,y), 0.)
    assert 0 < np.count_nonzero(offset) < 35
    for key, index in [*attrs.items(), ("indices", primitive["indices"])]:
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        values = remap.reshape(-1, 1).astype("<u2") if key == "indices" else read_array(doc, binary, index)[used]
        if key == "POSITION":
            values[:,1] -= offset
        if key == "NORMAL":
            # Transform normals with the inverse transpose of the neck compression.
            band = (offset > 0) & (offset < HEAD_DROP)
            new_y = values[band,1] / (1 - HEAD_DROP/.74)
            values[band,0] += .32*HEAD_DROP/.74*new_y
            values[band,1] = new_y
            values[band] /= np.linalg.norm(values[band],axis=1,keepdims=True)
        start = view["byteOffset"]
        binary[start:start + values.nbytes] = values.tobytes()
        view["byteLength"] = values.nbytes
        acc["count"] = len(values)
        if "min" in acc:
            acc.update(min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist())
    return len(triangles) - len(keep)


class Sculpt:
    def __init__(self, school, head, tails):
        self.panel = 2 if school else 0
        self.head = head
        self.tails = tails
        self.positions = []
        self.normals = []
        self.uvs = []
        self.weights = []
        self.joints = []
        self.faces = []

    def surface(self, rows, steps, sample, flip=False):
        # Each strip has an independent UV chart and analytic smooth normals.
        start = len(self.positions)
        for row, t in enumerate(rows):
            for col in range(steps + 1):
                s = col / steps
                pos, uv, joint, weight = sample(t, s)
                pos[1] -= HEAD_DROP
                dt = sample(min(rows[-1], t + .0001), s)[0] - sample(max(rows[0], t - .0001), s)[0]
                ds = sample(t, s + .0001)[0] - sample(t, s - .0001)[0]
                normal = np.cross(ds, dt) * (-1 if flip else 1)
                length = np.linalg.norm(normal)
                if length == 0:
                    raise ValueError("Degenerate head surface normal")
                normal /= length
                self.positions.append(pos)
                self.normals.append(normal)
                self.uvs.append(((uv[0] - 104) / 528, uv[1] / 528))
                self.joints.append((self.head, joint, 0, 0))
                self.weights.append((1 - weight, weight, 0, 0))
                if row and col:
                    d = start + row * (steps + 1) + col
                    a, b, c = d - steps - 2, d - steps - 1, d - 1
                    self.faces.extend(((a,c,b),(b,c,d)) if flip else ((a,b,c),(b,d,c)))

    def cranium(self):
        rows = [r[0] for r in PROFILE]
        table = np.array(PROFILE)
        def strip(t, s, rear):
            width, front, back = [np.interp(t, table[:,0], table[:,i]) for i in (1,2,3)]
            angle = (s - .5) * math.pi + (math.pi if rear else 0)
            sin, cos = math.sin(angle), math.cos(angle)
            # The cheeks sit forward of the ears. Model the nose bridge at the centerline.
            depth = front * max(0., cos) ** .72 - back * max(0., -cos)
            depth += .185 * math.exp(-((t - 365)/25)**2 - (sin/.15)**2) * max(0.,cos)
            y = 24.63 - t * SCALE
            # Lift the underside behind the jaw to form a nape.
            y += max(0., (t-370)/120) * (1-cos) * .37
            # Bring the underside into the neck rather than ending in a thin vertical fin.
            if t > 410:
                under = ((t-410)/80)**1.5
                depth += under * .67 * (1-cos)
            pos = np.array([DEPTH_CENTER + depth, y-.13, -width * sin * SCALE])
            if rear:
                # Crown hair runs down the occiput. Keep skin and eyes off the rear UV island.
                uv = (CENTER + 133*sin, 29 + (t-9)/481 * 111 + 26*abs(sin))
            else:
                uv = (CENTER + width*sin, t)
            return pos, uv, self.head, 0.
        for rear in (False, True):
            self.surface(rows, 20, lambda t,s: strip(t,s,rear), True)

    def lock(self, side, rings, depth, sample_u, sample_v, tail_weight=0.):
        # Closed oval sections allow the tails and temple locks to keep their shape in profile.
        table = np.array(rings)
        def strip(t, s):
            center, radius, x, rdepth = [np.interp(t, table[:,0], table[:,i]) for i in (1,2,3,4)]
            angle = 2 * math.pi * s
            u = center + radius * math.sin(angle)
            pos = np.array([depth+x+rdepth*math.cos(angle),24.63-t*SCALE,-side*u*SCALE])
            uv = (CENTER + side*sample_u(t, center, radius, angle), sample_v(t, angle))
            joint = self.tails[side]
            weight = tail_weight * min(1., max(0., (t-95)/285))
            return pos, uv, joint, weight
        self.surface(table[:,0], 8, strip, side == 1)

    def neck(self):
        # Overlap the source collar. The upper ring stays inside the jaw when the head turns.
        def strip(t,s):
            a=2*math.pi*s
            cs,sn=math.cos(a),math.sin(a)
            # The source has an oblique neck opening, rising toward the nape.
            y0=21.08-.38*cs
            depth=-.68+.73*cs
            x=depth*(1-t)+(-.39+.84*cs)*t
            z=-sn*(.59+.11*t)
            y=y0*(1-t)+21.94*t
            # surface() lowers the whole head. At the base, match the compressed native neck.
            pos=np.array([x,y+HEAD_DROP-neck_drop(x,y),z])
            return pos,(372+10*sn,505+10*(1-t)+3*cs),self.head,0.
        self.surface([0,.4,.75,1],16,strip)

    def nape(self):
        table = np.array(PROFILE)
        def strip(t,s):
            a = math.radians(64+232*s)
            sn,cs = math.sin(a),math.cos(a)
            edge = math.sin(math.pi*min(1,max(0,s)))**.7
            # At the temples the cut ends beside the ear. Behind the head it
            # falls to the nape with a series of short pointed locks.
            bottom = 375+55*edge+11*math.cos(12*a)*edge
            row = 35+(bottom-35)*t
            w,front,back = [np.interp(row,table[:,0],table[:,i]) for i in (1,2,3)]
            volume=.035+.07*math.sin(math.pi*t)+.07*t*math.cos(12*a)**2
            depth=front*max(0.,cs)**.72-back*max(0.,-cs)
            y = 24.50-row*SCALE + max(0.,(row-370)/120)*(1-cs)*.37
            pos=np.array([DEPTH_CENTER+depth+volume*cs,y,-(w*SCALE+volume)*sn])
            u=245+94*s+12*t
            v=49+114*t+6*math.sin(a)
            return pos,(u,v),self.head,0.
        self.surface(np.linspace(0,1,9),36,strip,True)

    def hair(self):
        for side in (-1, 1):
            # A gathered section connects each high tie to the temple and tail.
            self.lock(side,[(71,168,7,0,.05),(87,174,25,0,.31),(108,183,37,0,.40),(133,190,36,0,.38),(157,195,26,0,.28),(175,200,4,0,.04)],
                -.70,lambda t,c,r,a: 75+22*math.sin(a),lambda t,a: 65+t*.55)
            # Three offset clumps make the twin tails fork into points. The bow sits across the tie.
            for rings, depth, factor in [
                ([(50,201,3,0,.03),(66,215,29,0,.23),(104,239,50,0,.40),(167,260,61,-.10,.50),(250,275,64,-.15,.50),(331,272,52,-.22,.41),(392,252,36,-.27,.34),(439,226,21,-.29,.22),(465,196,2,-.28,.025)],-.83,.29),
                ([(82,232,3,0,.025),(132,254,34,0,.19),(219,292,34,-.12,.22),(295,307,28,-.18,.21),(366,303,18,-.20,.18),(423,281,9,-.23,.10),(454,260,1,-.24,.02)],-.98,.34),
                ([(127,228,3,0,.02),(176,235,37,0,.26),(265,242,37,-.05,.27),(354,231,26,-.14,.24),(424,202,17,-.18,.19),(465,171,2,-.16,.02)],-.60,.24)
            ]:
                self.lock(side,rings,depth,
                    lambda t,c,r,a: 63+23*math.sin(a)+.040*(t-230),
                    lambda t,a: 55+(t-50)*.20, factor)
            # Tapered face-framing locks follow the ear and detach below the cheek.
            self.lock(side,[(131,159,3,0,.04),(190,164,14,0,.20),(255,165,17,0,.21),(318,161,16,.02,.19),(376,150,13,.08,.16),(419,142,9,.15,.11),(459,152,2,.17,.015)],
                .13,lambda t,c,r,a: 157+9*math.sin(a),lambda t,a: 115+t*.37)
            # The outer wisps curve away from the heavier clumps at the tip.
            self.lock(side,[(151,284,3,0,.02),(212,304,9,0,.07),(287,319,8,0,.08),(353,319,6,0,.07),(403,305,4,0,.045),(439,280,2,0,.025),(453,268,.6,0,.012)],
                -.87,lambda t,c,r,a: 76+8*math.sin(a),lambda t,a: 55+t*.21,.28)
            # Wine-red loops and falling ribbon ends, with thickness for side views.
            self.lock(side,[(56,202,2,0,.025),(64,196,14,0,.11),(79,187,17,.03,.13),(99,168,13,.08,.12),(117,163,5,.10,.045)],
                -.04,lambda t,c,r,a: 223+5*math.sin(a),lambda t,a: 128+(t-42)*.35)
            self.lock(side,[(91,161,3,0,.035),(114,185,11,.06,.075),(152,218,14,.09,.08),(204,232,14,.11,.07),(243,239,14,.12,.065),(255,247,2,.13,.02)],
                .15,lambda t,c,r,a: 224+5*math.sin(a),lambda t,a: 137+(t-91)*.23)


def replace_head(path, portrait):
    doc, binary = unpack(path)
    if any(m.get("name") == "YurikoUnitHead" for m in doc["meshes"]):
        raise ValueError(f"{path} already has the unit head")
    names = [doc["nodes"][node]["name"] for node in doc["skins"][0]["joints"]]
    head = names.index("pivot_560dc963")
    pony = [names.index("pivot_"+name) for name in ("f405cb41","e81831fe","f173ea9e","6cee6851","6f048ad7","b141d667")]
    removed = remove_old_head(doc,binary,{head,*pony})
    sculpt = Sculpt(path.stem == "JUCommandoTech1",head, {1:pony[1], -1:pony[4]})
    sculpt.cranium()
    sculpt.neck()
    sculpt.nape()
    sculpt.hair()
    def add(values, kind, dtype="<f4", bounds=False):
        arr = np.asarray(values,dtype=dtype)
        binary.extend(bytes(-len(binary)%4))
        view = len(doc["bufferViews"])
        doc["bufferViews"].append(dict(buffer=0,byteOffset=len(binary),byteLength=arr.nbytes))
        binary.extend(arr.tobytes())
        acc = dict(bufferView=view,count=len(arr),type=kind,componentType=5126 if dtype=="<f4" else 5123)
        if bounds:
            acc.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
        doc["accessors"].append(acc)
        return len(doc["accessors"])-1
    material = len(doc["materials"])
    texture = len(doc["textures"])
    doc["textures"].append(dict(source=len(doc["images"])))
    # Bake only this outfit's UV window. Unit rendering can load one 512px
    # texture without pulling the full story illustration into the battlefield.
    with Image.open(portrait) as source:
        if source.size != (2172,724):
            raise ValueError("Unexpected journal atlas dimensions")
        left = sculpt.panel*724 + 104
        atlas = source.crop((left,0,left+528,528)).convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
    encoded = io.BytesIO()
    atlas.save(encoded,format="PNG",optimize=True)
    payload = encoded.getvalue()
    binary.extend(bytes(-len(binary)%4))
    doc["images"].append(dict(name="UnitHead",mimeType="image/png",bufferView=len(doc["bufferViews"])))
    doc["bufferViews"].append(dict(buffer=0,byteOffset=len(binary),byteLength=len(payload)))
    binary.extend(payload)
    doc["materials"].append(dict(name="YurikoJournalHead",emissiveTexture=dict(index=texture),emissiveFactor=[.065,.065,.065],pbrMetallicRoughness=dict(
        baseColorTexture=dict(index=texture),metallicFactor=0,roughnessFactor=1)))
    primitive = dict(attributes=dict(POSITION=add(sculpt.positions,"VEC3",bounds=True),NORMAL=add(sculpt.normals,"VEC3"),
        TEXCOORD_0=add(sculpt.uvs,"VEC2"),JOINTS_0=add(sculpt.joints,"VEC4","<u2"),WEIGHTS_0=add(sculpt.weights,"VEC4")),
        indices=add(np.array(sculpt.faces).reshape(-1,1),"SCALAR","<u2"),material=material)
    mesh = len(doc["meshes"])
    doc["meshes"].append(dict(name="YurikoUnitHead",primitives=[primitive]))
    doc["scenes"][doc["scene"]]["nodes"].append(len(doc["nodes"]))
    doc["nodes"].append(dict(name="YurikoUnitHead",mesh=mesh,skin=0))
    pack(path,doc,binary)
    print(path.name, "removed",removed,"triangles; head",len(sculpt.positions),"vertices",len(sculpt.faces),"triangles")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("models",nargs="+",type=Path)
    parser.add_argument("--portrait",type=Path,help="Override the journal portrait atlas used by both outfits")
    args=parser.parse_args()
    for model in args.models:
        replace_head(model,args.portrait or model.parent/"school_days/story_portraits.png")

