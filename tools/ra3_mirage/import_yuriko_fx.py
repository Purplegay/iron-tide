"""Decode the retail EP1 v7 particle records. Input is extract_uprising + convert_uprising_media output."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "iron_tide/assets/ra3/yuriko/powers"


def node(tag, attrs=None, children=()):
    return dict(tag=tag, attrs=attrs or {}, children=list(children))


def decode(name, raw, references):
    def integer(offset):
        return struct.unpack_from("<I", raw, offset)[0]

    def number(offset):
        return struct.unpack_from("<f", raw, offset)[0]

    def interval(tag, offset):
        return node(tag, {"Low": number(offset+4), "High": number(offset+8)})

    def vector(tag, offset):
        return node(tag, children=[interval(axis, offset+i*12) for i, axis in enumerate("xyz")])

    attrs = {"id": name, "SystemLifetime": integer(32)}
    for offset, key in [(16, "ParticleTexture"), (20, "Drawable")]:
        if integer(offset):
            attrs[key] = references[integer(offset)-1].split(":")[1]
    attrs["BlendMode"]=integer(8)
    children = [interval(tag, offset) for tag, offset in
                [("Lifetime",56),("Size",68),("BurstDelay",92),("BurstCount",104)] if integer(offset)]
    colors = integer(132)
    if colors:
        keys = []
        for i in range(integer(colors+4)):
            pos = integer(colors+8)+20*i
            keys.append(node("Color", {"RelativeAge": number(pos)*100}, [
                node("Color",dict(zip("rgb",struct.unpack_from("<3f",raw,pos+8))))]))
        if integer(colors+12):
            keys.append(interval("ColorScale",colors+12))
        children.append(node("Colors",children=keys))
    alphas = integer(128)
    if alphas:
        keys = []
        for i in range(integer(alphas)):
            pos = integer(alphas+4)+20*i
            item = interval("Alpha",pos)
            item["attrs"]["RelativeAge"] = 100*number(pos+12)
            keys.append(item)
        children.append(node("Alphas",children=keys))
    physics = integer(140)
    if physics:
        children.append(node("Physics", children=[node("Default", children=[interval("VelocityDamping",physics+8)])]))
    draw = integer(144)
    kind = {0x85fe07df:"Gpu",0xcb25505b:"RenderObject",0x51dae8c4:"LightSource",
            0x6f3323a5:"Trail",0xbed78e9d:"Default"}[integer(draw)]
    options = {}
    if kind == "Gpu":
        length, offset = struct.unpack_from("<II",raw,draw+4)
        options = {"Shader":raw[offset:offset+length].rstrip(b"\0").decode(),
                   "FramesPerRow":integer(draw+12),"TotalFrames":integer(draw+16),
                   "SpeedMultiplier":number(draw+32),"MiscValues":list(struct.unpack_from("<4f",raw,draw+40))}
        detail=integer(draw+28)
        if detail: options["DetailTexture"]=references[detail-1].split(":")[1]
    elif kind=="LightSource":
        options["MaximumIntensityRadiusRatio"]=number(draw+4)
    elif kind=="Trail":
        options["TrailLife"]=integer(draw+4)
    children.append(node("Draw",children=[node(kind,options)]))
    vol = integer(148)
    kind = {0x5c8a6f16:"Cylinder",0x0da35f9c:"Line",0xedf83b69:"Sphere",0xd32fc96b:"Point"}[integer(vol)]
    volume = node(kind)
    if kind in ("Sphere","Cylinder"):
        volume["attrs"]["Radius"] = number(vol+8)
    for tag, offset in {"Line":[("StartPoint",8),("EndPoint",20)],"Cylinder":[("Offset",20)]}.get(kind,[]):
        volume["children"].append(node(tag,dict(zip("xyz",struct.unpack_from("<3f",raw,vol+offset)))))
    children.append(node("Volume",children=[volume]))
    vel = integer(152)
    if vel:
        if integer(vel)==0xe7528102:
            motion=node("Ortho",children=[vector("Position",vel+4)])
        else:
            assert integer(vel)==0xcf2fd6df
            motion=node("Outward",children=[interval("Speed",vel+4)])
        children.append(node("Velocity",children=[motion]))
    update = integer(164)
    if integer(update)==0xaedea298:
        fields = ["SizeRate","SizeRateDamping","AngleZ","AngularRateZ","AngularDamping"]
        module = node("Default",children=[interval(tag,update+8+i*12) for i,tag in enumerate(fields) if integer(update+8+i*12)])
    else:
        assert integer(update)==0x0dfb6e4a
        fields = ["AngleX","AngularRateX","AngleY","AngularRateY","AngleZ","AngularRateZ","AngularDamping"]
        module=node("RenderObject",{"Rotation":{2:"ROTATE_AROUND_VELOCITY",3:"ROTATE_IN_WORLD_SPACE"}.get(integer(update+4),"")})
        module["children"] += [interval(tag,update+8+i*12) for i,tag in enumerate(fields) if integer(update+8+i*12)]
        module["children"] += [vector(tag,update+92+i*36) for i,tag in enumerate(["StartSize","SizeRate","SizeDamping"])]
    children.append(node("Update",children=[module]))
    return node("FXParticleSystemTemplate",attrs,children)


def retail_hero_records(actors):
    """Check EP1 store slots, model contracts, weapon payloads and guard formations from the installation."""
    manifest=json.loads((actors/"extraction.json").read_text(encoding="utf-8"))
    index={}
    for path in actors.glob("*-manifest-index.json"):
        for row in json.loads(path.read_text(encoding="utf-8")):
            index[row["type"],row["instance"]]=row["name"]
    instances={name:key[1] for key,name in index.items()}
    records={row["name"]:row for row in manifest["assets"]}
    binaries={item["asset"]:item for item in manifest["files"] if item["part"]=="bin"}
    def read(asset):
        record=binaries[asset]
        data=(actors/record["file"]).read_bytes()
        assert hashlib.sha256(data).hexdigest()==record["sha256"]
        return data
    def refs(asset):
        return [index[tuple(pair)] for pair in records[asset]["references"]]
    store="PlayerTechStoreTemplate:PlayerTechStore_Yuriko"
    slots=[name.split("Purchase_PlayerTech_Yuriko_")[1] for name in refs(store)]
    tree=json.loads((ROOT/"iron_tide/data/yuriko.json").read_text(encoding="utf-8"))["tree"]
    assert slots==[row["id"] for row in tree]
    actors_out={}
    for tier in (1,2,3):
        name=f"GameObject:JapanYurikoTech{tier}"
        data=read(name)
        linked=refs(name)
        model="JAPANYURIKOTECH1_SKN" if tier==1 else "JUCOMMANDOTECH1_NOPICK_SKN"
        assert "W3DContainer:"+model in linked
        short=[(60,0),(45,45),(45,-45)]
        wide=short+[(30,60),(30,-60)]
        formations=[short,wide,[(80,45),(80,-45)]+wide]
        for points in formations:
            assert b"".join(struct.pack("<3f",x,y,0) for x,y in points) in data
        states_file=("model" if tier==1 else "school")+"_states.json"
        states=json.loads((ROOT/"iron_tide/assets/ra3/yuriko"/states_file).read_text(encoding="utf-8"))
        clips={row["clip"] for row in states.values()}
        clips.update(option["clip"] for row in states.values() for option in row.get("variants",[]))
        found=[]
        for clip in sorted(clips):
            key="W3DAnimation:"+clip
            if key in linked or struct.pack("<I",instances[key]) in data:
                found.append(clip)
        missing=clips-set(found)
        assert missing==({2:{"JUCOMMANDOTECH1_SPCC"},3:{"JUCOMMANDOTECH1_SPCB1","JUCOMMANDOTECH1_SPCB2","JUCOMMANDOTECH1_SPCB3"}}.get(tier,set()))
        actors_out[name]=dict(model=model,clips=found,sha256=binaries[name]["sha256"],
            fx=sorted(set(ref for ref in linked if ref.startswith(("FXList:","ShaderOverride:","FXParticleSystemTemplate:")))),
            weapons=sorted(set(ref for ref in linked if ref.startswith("WeaponTemplate:"))))
    fields={"WeaponTemplate:JapanCommandoTech1PsyonicCrush_EP1":{"health_fraction":(2688,.04)},
            "WeaponTemplate:JapanCommandoTech1PsyonicBlast_EP1":{"damage":(3280,500),"radius":(3256,125),"delay":(3312,.4),"shock_radius":(2884,200)},
            "WeaponTemplate:FlingableProp_Vehicle_DeathWeapon":{"damage":(3028,400),"radius":(3004,25)}}
    weapons={}
    for name,checks in fields.items():
        data=read(name)
        for offset,expected in checks.values():
            assert abs(struct.unpack_from("<f",data,offset)[0]-expected)<1e-6
        weapons[name]=dict(sha256=binaries[name]["sha256"],fields=checks)
    marker=[name.split(":")[1] for name in refs("GameObject:YurikoLureMarker") if name.startswith("FXParticleSystemTemplate:")]
    return dict(actors=actors_out,store=slots,formations=formations,lure=marker,weapons=weapons)


def effect_nuggets(raw, refs):
    count,table=struct.unpack_from("<II",raw,16)
    sequence=[]
    for i in range(count):
        ptr=struct.unpack_from("<I",raw,table+4*i)[0]
        kind=struct.unpack_from("<I",raw,ptr)[0]
        if kind not in (0x2ccc1572,0x1e08c8fb):continue
        ref=struct.unpack_from("<I",raw,ptr+44)[0]
        sequence.append(refs[ref-1])
    return sequence


def related_media(links, cursors):
    sources={}
    def export(folder, names):
        report=json.loads((folder/"converted/conversion.json").read_text(encoding="utf-8"))
        records={r["asset"]:r for r in report["records"] if r["file"].endswith(".png")}
        for name in names:
            record=records["Texture:"+name]
            image=(folder/record["file"]).read_bytes()
            assert hashlib.sha256(image).hexdigest()==record["sha256"]
            (OUT/(name+".png")).write_bytes(image)
    def catalog(folder):
        index=json.loads((folder/"extraction.json").read_text(encoding="utf-8"))
        ids={(r["type"],r["instance"]):r["name"] for r in index["assets"]}
        for r in index["files"]:
            if r["part"] in ("bin","cdata"):
                assert hashlib.sha256((folder/r["file"]).read_bytes()).hexdigest()==r["sha256"]
                sources[r["asset"]+"."+r["part"]]=r["sha256"]
        return {r["name"]:[ids[tuple(ref)] for ref in r["references"]] for r in index["assets"]}
    deps=catalog(links)
    mesh="W3DMesh:FXPSYONICENDGEO"
    assert any("FXPSYONICENDGEO" in ref for ref in deps["FXParticleSystemTemplate:JapanPsyonicDraw"])
    material=json.loads((links/"converted/meshes/W3DMesh_FXPSYONICENDGEO.json").read_text())["material"]
    tex=[material["constants"][k]["asset"] for k in ("Texture_0","Texture_1")]
    assert material["shader"]=="FXLightning.fx" and all(t in deps[mesh] for t in tex)
    export(links,[t.split(":")[1] for t in tex])
    deps=catalog(cursors)
    reticles={}
    for name in ("Target_Yuriko_Lure","Target_Yuriko_Slam1","Target_Yuriko_Slam2"):
        assert deps["RadiusCursor:"+name]==["Texture:"+name]
        raw=(cursors/"raw"/("RadiusCursor_"+name+".bin")).read_bytes()
        assert struct.unpack_from("<I",raw,20)[0]==3
        minimum,maximum,hz=struct.unpack_from("<3f",raw,24)
        reticles[name]=dict(minimum=minimum,maximum=maximum,hz=hz)
    export(cursors,reticles)
    return dict(link_material=material,cursors=reticles,sources=sources)


def main(root, actors, links, cursors):
    extraction=json.loads((root/"extraction.json").read_text(encoding="utf-8"))
    ids={(r["type"],r["instance"]):r["name"] for r in extraction["assets"]}
    raw={r["asset"]:r for r in extraction["files"] if r["part"]=="bin"}
    effects,particles,hashes,nuggets={},{},{},{}
    OUT.mkdir(exist_ok=True,parents=True)
    for row in extraction["assets"]:
        asset=row["name"]
        kind,name=asset.split(":",1)
        if kind not in ("FXList","FXParticleSystemTemplate"): continue
        record=raw[asset]
        data=(root/record["file"]).read_bytes()
        assert hashlib.sha256(data).hexdigest()==record["sha256"]
        hashes[asset]=record["sha256"]
        refs=[ids[tuple(ref)] for ref in row["references"]]
        if kind=="FXList":
            nuggets[name]=effect_nuggets(data,refs)
            effects[name]=[r.split(":")[1] for r in nuggets[name] if r.startswith("FXParticleSystemTemplate:")]
            assert effects[name]==[r.split(":")[1] for r in refs if r.startswith("FXParticleSystemTemplate:")],name
        else:
            particles[name]=decode(name,data,refs)
    for path in (root/"converted/meshes").glob("*.json"):
        source=json.loads(path.read_text(encoding="utf-8"))
        attr=source["attributes"]
        material=source["material"]
        def coords(rows):
            return [v for x,y,z in rows for v in (x,z,-y)]
        mesh=dict(vertices=coords(attr["p0"]),normals=coords(attr["n0"]),uv=sum(attr["t0"],[]),
                  indices=source["indices"],material=material,colors=attr.get("c0",[]),
                  uv2=sum(attr.get("t1",attr["t0"]),[]),textures={k:v["asset"].split(":")[1]+".png"
                    for k,v in material["constants"].items() if isinstance(v,dict) and "asset" in v})
        name=path.stem.split("_",1)[1].split(".")[0].lower()
        (OUT/(name+".json")).write_text(json.dumps(mesh,separators=(",",":")))
    for path in (root/"converted/textures").glob("*.png"):
        shutil.copyfile(path,OUT/path.name.removeprefix("Texture_"))
    (OUT/"effects.json").write_text(json.dumps(dict(game=extraction["game"],manifests=extraction["manifest_sha256"],
        sources=hashes,media=related_media(links,cursors),nuggets=nuggets,hero=retail_hero_records(actors),effects=effects,particles=particles),separators=(",",":")))
    print(f"{len(effects)} FX lists, {len(particles)} decoded particle templates")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extraction",type=Path)
    parser.add_argument("actors",type=Path)
    parser.add_argument("links",type=Path)
    parser.add_argument("cursors",type=Path)
    args=parser.parse_args()
    main(args.extraction,args.actors,args.links,args.cursors)
