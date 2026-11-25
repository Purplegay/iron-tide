"""Convert installed EP1 W3D skeletons, meshes and clips. XML supplies the state labels."""
import argparse
import bisect
import json
import math
import struct
from pathlib import Path
from xml.etree import ElementTree as ET
from import_expansion import cv, mul, rotate
from import_uprising_runtime import decode_delta


def normalize(v):
    size=math.sqrt(sum(x*x for x in v))
    return [x/size for x in v]


def timecoded_frames(channel, frames):
    keys=channel["frame_and_binary_flag"]
    assert all(key<32768 for key in keys), "unexpected binary key in Yuriko animation"
    width=channel["vector_length"]
    raw=channel["values"]
    samples=[raw[i:i+width] for i in range(0,len(raw),width)]
    result=[]
    for frame in range(frames):
        left=max(0,bisect.bisect_right(keys,frame)-1)
        right=min(left+1,len(keys)-1)
        a,b=samples[left],samples[right]
        if left==right or frame==keys[left]:
            result.append(a)
            continue
        t=(frame-keys[left])/(keys[right]-keys[left])
        if channel["channel_type"]!=3:
            result.append([x+(y-x)*t for x,y in zip(a,b)])
            continue
        a,b=normalize(a),normalize(b)
        dot=sum(x*y for x,y in zip(a,b))
        if dot<0: b=[-v for v in b];dot=-dot
        angle=math.acos(min(1.,dot))
        if angle<.001:
            result.append(normalize([x+(y-x)*t for x,y in zip(a,b)]))
        else:
            l=math.sin((1-t)*angle)/math.sin(angle)
            r=math.sin(t*angle)/math.sin(angle)
            result.append([l*x+r*y for x,y in zip(a,b)])
    return result


def cq(q):
    return normalize([q[0],q[2],-q[1],q[3]])


class Buffer:
    def __init__(self):
        self.data=bytearray()
        self.views=[]
        self.accessors=[]

    def view(self,data):
        self.data.extend(bytes(-len(self.data)%4))
        self.views.append(dict(buffer=0,byteOffset=len(self.data),byteLength=len(data)))
        self.data.extend(data)
        return len(self.views)-1

    def add(self,values,form,code,bounds=False):
        components,fmt={"float":(5126,"f"),"short":(5123,"H")}[code]
        flat=[x for row in values for x in row]
        view=self.view(struct.pack("<"+str(len(flat))+fmt,*flat))
        spec=dict(bufferView=view,componentType=components,count=len(values),type=form)
        if bounds:
            spec.update(min=list(map(min,zip(*values))),max=list(map(max,zip(*values))))
        self.accessors.append(spec)
        return len(self.accessors)-1


def import_model(src,xml,dest,shield_src):
    def read(pattern):return json.loads(next(src.glob(pattern)).read_text())
    draw=ET.parse(xml).find(".//*[@id='ModuleTag_Draw']")
    skin_name=draw.find("{*}ModelConditionState/{*}Model").get("Name").upper()
    school=skin_name=="JUCOMMANDOTECH1_NOPICK_SKN"
    family="JUCOMMANDOTECH1" if school else "JAPANYURIKOTECH1"
    bones=read("hierarchies/*"+family+"_SKL.json")["bones"]
    mesh=read("meshes/W3DMesh_"+skin_name+".*.json")
    attrs=mesh["attributes"]
    buf=Buffer()
    nodes=[]
    rests=[]
    inverse_binds=[]
    for i,bone in enumerate(bones):
        t=cv(bone["translation"])
        q=cq(bone["rotation_xyzw"])
        nodes.append(dict(name="pivot_"+bone["name_hash"],translation=t,rotation=q))
        p=bone["parent"]
        if p>=0:
            nodes[p].setdefault("children",[]).append(i)
            pt,pq=rests[p]
            t=[a+b for a,b in zip(pt,rotate(pq,t))]
            q=normalize(mul(pq,q))
        rests.append((t,q))
        inv=[-q[0],-q[1],-q[2],q[3]]
        cols=[rotate(inv,v)+[0] for v in ((1,0,0),(0,1,0),(0,0,1))]
        cols.append(rotate(inv,[-v for v in t])+[1])
        inverse_binds.append(sum(cols,[]))
    positions=[]; normals=[]; joints=[]; weights=[]
    for i,ws in enumerate(attrs["w0"]):
        js=[mesh["bone_palette"][j] if w else 0 for j,w in zip(attrs["i0"][i],ws)]
        pos=[0.,0.,0.];normal=[0.,0.,0.]
        for k,(j,w) in enumerate(zip(js,ws)):
            if not w:continue
            t,q=rests[j]
            p=rotate(q,cv(attrs["p"+str(k)][i]))
            n=rotate(q,cv(attrs["n"+str(k)][i]))
            for c in range(3):
                pos[c]+=w*(p[c]+t[c])/sum(ws)
                normal[c]+=w*n[c]/sum(ws)
        positions.append(pos);normals.append(normalize(normal))
        joints.append(js);weights.append([w/sum(ws) for w in ws])
    native_min,native_max=mesh["source_bounds"][:3],mesh["source_bounds"][3:]
    expected=cv(native_min),cv(native_max)
    for j in range(3):
        actual=[min(v[j] for v in positions),max(v[j] for v in positions)]
        assert max(abs(a-b) for a,b in zip(actual,sorted(t[j] for t in expected)))<.003
    primitive=dict(attributes={
        "POSITION":buf.add(positions,"VEC3","float",True),
        "NORMAL":buf.add(normals,"VEC3","float"),
        "TEXCOORD_0":buf.add(attrs["t0"],"VEC2","float"),
        "JOINTS_0":buf.add(joints,"VEC4","short"),
        "WEIGHTS_0":buf.add(weights,"VEC4","float")},
        indices=buf.add([[i] for i in mesh["indices"]],"SCALAR","short"),material=0)
    skin=dict(joints=list(range(len(bones))),skeleton=0,inverseBindMatrices=buf.add(inverse_binds,"MAT4","float"))
    nodes.append(dict(name="YurikoBody",mesh=0,skin=0))
    states={}
    for state in draw.findall("{*}AnimationState"):
        anim=state.find("{*}Animation")
        # Variant-specific death replacements (irradiated body/skeleton) use other rigs.
        if anim is None or not anim.get("AnimationName","").upper().startswith(family+"_"):continue
        key=state.get("ConditionsYes") or state.get("StateName","default")
        states[key]=dict(clip=anim.get("AnimationName").upper(),mode=anim.get("AnimationMode"),
                         restart="RESTART_ANIM_WHEN_COMPLETE" in state.get("Flags",""),
                         blend_frames=int(anim.get("AnimationBlendTime",0)))
        options=state.findall("{*}Animation")
        if len(options)>1:
            states[key]["variants"]=[dict(clip=a.get("AnimationName").upper(),weight=int(a.get("AnimationPriority",1))) for a in options]
        if anim.get("AnimationAbsoluteTime"):
            states[key]["duration"]=float(anim.get("AnimationAbsoluteTime").rstrip("s"))
    animations=[]
    if school:
        third=ET.parse(xml.with_name("JapanYurikoTech3.xml")).find(".//*[@id='ModuleTag_Draw']")
        entrance=third.find("{*}AnimationState[@ConditionsYes='USER_7']/{*}Animation")
        states["USER_7"]=dict(clip=entrance.get("AnimationName").upper(),mode=entrance.get("AnimationMode"),restart=False,blend_frames=0)
    clips={s["clip"] for s in states.values()}
    clips.update(v["clip"] for state in states.values() for v in state.get("variants",[]))
    for name in sorted(clips):
        a=read("animations/*_"+name+".json")
        assert a["hierarchy"].endswith(family+"_SKL")
        tracks={}; count=a["frames"]
        for channel in a["channels"]:
            kind=channel["channel_type"]
            if kind==4: continue  # This skin has no visibility-driven subobjects.
            i=channel["pivot"]
            if channel["format"]=="AnimationChannelDelta":values=decode_delta(channel,count)
            else: values=timecoded_frames(channel,count)
            if kind==3:
                tracks[i,"rotation"]=[normalize(mul(nodes[i]["rotation"],cq(v))) for v in values]
            else:
                pos=tracks.setdefault((i,"translation"),[[0.,0.,0.] for _ in range(count)])
                axis=[0,2,1][kind]
                for row,v in zip(pos,values):row[axis]+=v[0]*(-1 if kind==1 else 1)
        # W3D composes the local animation delta after the pivot rest transform.
        # For example, falling translates the pelvis down its rotated local Y axis.
        for (bone,kind),samples in tracks.items():
            if kind=="translation":
                base=nodes[bone]
                for frame,delta in enumerate(samples):
                    samples[frame]=[t+d for t,d in zip(base["translation"],rotate(base["rotation"],delta))]
        time=buf.add([[f/a["fps"]] for f in range(count)],"SCALAR","float",True)
        samplers=[];channels=[]
        for (bone,kind),values in tracks.items():
            channels.append(dict(sampler=len(samplers),target=dict(node=bone,path=kind)))
            samplers.append(dict(input=time,output=buf.add(values,"VEC4" if kind=="rotation" else "VEC3","float")))
        animations.append(dict(name=name,channels=channels,samplers=samplers))
    tex=src/"textures"/("Texture_"+mesh["material"]["constants"]["Texture_0"]["asset"].split(":")[1]+".png")
    image=buf.view(tex.read_bytes())
    doc=dict(asset=dict(version="2.0",generator="IronTide Uprising importer"),scene=0,scenes=[dict(nodes=[0,len(bones)])],
             nodes=nodes,meshes=[dict(primitives=[primitive])],skins=[skin],animations=animations,
             textures=[dict(source=0)],images=[dict(name="YurikoUniform",bufferView=image,mimeType="image/png")],
             materials=[dict(name="YurikoUniform",doubleSided=not mesh["material"]["constants"]["CullingEnable"],pbrMetallicRoughness=dict(baseColorTexture=dict(index=0),metallicFactor=0.,roughnessFactor=1.))],
             accessors=buf.accessors,bufferViews=buf.views,buffers=[dict(byteLength=len(buf.data))])
    # The two retail containers use separate attachment pivots even where the mesh matches.
    shell_name="FXYURIKOSHIELDUPGRADE" if school else "FXYURIKOSHIELD"
    shell=json.loads((shield_src/"meshes"/("W3DMesh_"+shell_name+".SHIELD.json")).read_text())
    shell_bones=json.loads((shield_src/"hierarchies"/("W3DHierarchy_"+shell_name+".json")).read_text())["bones"]
    container=(shield_src.parent/"raw"/("W3DContainer_"+shell_name+".bin")).read_bytes()
    count,offset=struct.unpack_from("<II",container,8)
    assert count==1
    pivot=shell_bones[struct.unpack_from("<I",container,offset)[0]]
    assert pivot["parent"]==0
    shell_attrs=shell["attributes"]
    shell_prim=dict(attributes={
        "POSITION":buf.add([cv(p) for p in shell_attrs["p0"]],"VEC3","float",True),
        "NORMAL":buf.add([cv(n) for n in shell_attrs["n0"]],"VEC3","float"),
        "TEXCOORD_0":buf.add(shell_attrs["t0"],"VEC2","float")},
        indices=buf.add([[i] for i in shell["indices"]],"SCALAR","short"))
    doc["meshes"].append(dict(name="ShieldSurface",primitives=[shell_prim]))
    doc["scenes"][0]["nodes"].append(len(nodes))
    nodes.append(dict(name="YurikoShield",mesh=1,translation=cv(pivot["translation"]),rotation=cq(pivot["rotation_xyzw"])))
    textures={k:v["asset"].split(":")[1]+".png" for k,v in shell["material"]["constants"].items() if isinstance(v,dict) and "asset" in v}
    (dest/(shell_name+".json")).write_text(json.dumps(dict(material=shell["material"],textures=textures),separators=(",",":")))
    from shutil import copyfile
    copyfile(shield_src/"textures/Texture_FXYurikoShieldFractal.png",dest/"FXYurikoShieldFractal.png")
    doc["buffers"][0]["byteLength"]=len(buf.data)
    header=json.dumps(doc,separators=(",",":")).encode()
    header+=b" "*(-len(header)%4); buf.data.extend(bytes(-len(buf.data)%4))
    chunks=struct.pack("<I4s",len(header),b"JSON")+header+struct.pack("<I4s",len(buf.data),b"BIN\0")+buf.data
    (dest/("JUCommandoTech1.glb" if school else "JapanYurikoTech1.glb")).write_bytes(struct.pack("<4sII",b"glTF",2,12+len(chunks))+chunks)
    (dest/("school_states.json" if school else "model_states.json")).write_text(json.dumps(states,indent=2)+"\n")
    print(len(bones),"bones",len(joints),"vertices",len(mesh["indices"])//3,"triangles",len(states),"XML states",len(animations),"clips")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("converted",type=Path)
    parser.add_argument("unit_xml",type=Path)
    parser.add_argument("output",type=Path)
    parser.add_argument("shield_converted",type=Path)
    a=parser.parse_args()
    import_model(a.converted,a.unit_xml,a.output,a.shield_converted)
