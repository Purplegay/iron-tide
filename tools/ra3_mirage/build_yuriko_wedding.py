"""Build the Same Stop bridal outfit in the native school skeleton's bind space."""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from build_yuriko_head import pack, read_array, unpack

ROOT = Path(__file__).resolve().parents[2] / "iron_tide/assets/ra3/yuriko"
OUT = ROOT / "wedding"
TAU = math.tau


def create_atlas():
    """Unwrap the illustrated fabric into rectangular charts, inset from the silhouette."""
    art = Image.open(ROOT / "school_days/cg/platform.webp").convert("RGB")
    atlas = Image.new("RGB", (1024, 1024), (238, 223, 209))

    def chart(box, rows, ivory=False):
        left, top, right, bottom = box
        patch = Image.new("RGB", (right-left, bottom-top))
        for y in range(patch.height):
            t = y / (patch.height-1) * (len(rows)-1)
            k = min(int(t), len(rows)-2)
            x1, x2, source_y = np.array(rows[k])*(1-t+k) + np.array(rows[k+1])*(t-k)
            strip = art.crop((round(x1), round(source_y), round(x2), round(source_y)+1))
            patch.paste(strip.resize((patch.width, 1), Image.Resampling.BICUBIC), (0,y))
        if ivory:
            # Retain the CG embroidery relief, keeping sampled shadows in the ivory fabric palette.
            light=np.asarray(patch.convert("L"),dtype=float)
            shade=np.clip((light-np.median(light))*.55,-29,20)
            patch=Image.fromarray(np.uint8(np.clip(np.array([233,224,213])+shade[:,:,None],0,255)))
        atlas.paste(patch, (left,top))

    chart((0,0,768,664),[(748,843,378),(720,851,408),(678,864,448),(589,880,502),
          (501,897,555),(461,918,605),(531,938,644),(638,908,681),(701,856,704)])
    chart((0,668,512,1024),[(731,842,208),(735,849,236),(726,854,266),(736,852,295),
          (744,850,336),(752,843,359),(752,844,373)], ivory=True)
    chart((773,0,1024,383),[(718,744,732),(715,747,762),(714,744,793),(712,742,830),
          (716,742,865),(722,744,894)], ivory=True)
    chart((773,388,1024,637),[(698,709,221),(689,705,248),(679,695,282),(665,682,325)], ivory=True)
    chart((520,675,765,825),[(747,824,358),(748,837,364),(747,837,371),(752,838,375)])
    chart((520,833,768,1018),[(856,879,601),(851,885,622),(837,881,642),(811,868,660)])
    atlas.save(OUT / "bridal_atlas.png",optimize=True)
    art.crop((623,0,952,329)).resize((256,256),Image.Resampling.LANCZOS).save(ROOT/"Portrait_Yuriko_Wedding.png")


CHARTS = [(2,2,765,661),(2,670,510,1021),(775,2,1021,381),(775,390,1021,635),
          (522,677,762,823),(522,835,765,1015)]


def uv(chart, u, v):
    l,t,r,b=CHARTS[chart]
    return ((l+(r-l)*u)/1024,(t+(b-t)*v)/1024)


class Mesh:
    def __init__(self):
        self.position=[]; self.normal=[]; self.uv=[]; self.joints=[]; self.weights=[]; self.faces=[]

    def surface(self,rows,steps,sample,outward=True):
        start=len(self.position)
        for i,t in enumerate(rows):
            for j in range(steps+1):
                s=j/steps
                pos,tex,skin=sample(t,s)
                dt=sample(min(rows[-1],t+.0001),s)[0]-sample(max(rows[0],t-.0001),s)[0]
                ds=sample(t,s+.0001)[0]-sample(t,s-.0001)[0]
                normal=np.cross(ds,dt)
                length=np.linalg.norm(normal)
                if length < 1e-16: raise ValueError("Degenerate garment surface")
                self.position.append(pos);self.normal.append(normal/length*(-1 if outward else 1))
                self.uv.append(tex)
                total=sum(skin.values()); bonds=list(skin.items())+[(0,0)]*(4-len(skin))
                self.joints.append([k for k,_ in bonds]);self.weights.append([w/total for _,w in bonds])
                if i and j:
                    d=start+i*(steps+1)+j
                    a,b,c=d-steps-2,d-steps-1,d-1
                    self.faces.extend([(a,c,b),(b,c,d)] if outward else [(a,b,c),(b,d,c)])

    def rings(self,profiles,steps,chart,skin,fold=0,scallop=0):
        table=np.array(profiles,float)
        def section(t,s):
            x,y,z,rx,rz=[np.interp(t,table[:,0],table[:,i]) for i in range(1,6)]
            a=TAU*s
            flute=1+fold*t*(math.cos(12*a+.38*t)+.28*math.cos(7*a-t))
            pos=np.array([x+rx*math.cos(a)*flute,y+scallop*t**5*math.cos(20*a),z-rz*math.sin(a)*flute])
            return pos,uv(chart,.5+.49*math.sin(a),t),skin(t,a)
        self.surface(table[:,0],steps,section)


def blend(a,b,t):
    return {a:1-t,b:t}


def profile(rows):
    return [(i/(len(rows)-1),*row) for i,row in enumerate(rows)]


def build_clothes():
    fabric,skin,veil=Mesh(),Mesh(),Mesh()
    # From the small neck opening down over the clavicles to the gathered waist.
    bodice=profile([(-.66,20.09,0,.72,.78),(-.61,19.74,0,.96,1.61),(-.57,19.33,0,1.17,2.26),
        (-.41,18.81,0,1.42,2.27),(-.32,18.07,0,1.67,2.11),(-.41,17.24,0,1.55,2.03),
        (-.48,16.21,0,1.30,1.79),(-.51,15.20,0,1.16,1.53),(-.52,14.62,0,1.18,1.56)])
    def torso(t,a):
        return blend(3,2,float(np.clip((t-.62)/.38,0,1)))
    fabric.rings(bodice,40,1,torso)
    skin.rings(profile([(-.64,21.55,0,.76,.70),(-.67,21.02,0,.72,.66),
        (-.65,20.30,0,.69,.64),(-.62,19.97,0,.75,.82)]),24,4,lambda t,a:blend(12,3,t))
    skirt=profile([(-.52,14.77,0,1.19,1.55),(-.54,14.25,0,1.42,1.81),(-.58,13.43,0,1.75,2.18),
        (-.64,12.45,0,2.15,2.65),(-.67,11.09,0,2.71,3.11),(-.73,9.58,0,3.32,3.72),
        (-.82,8.0,0,3.93,4.35),(-.91,6.64,0,4.40,4.88),(-.98,5.48,0,4.78,5.26),
        (-1.0,4.76,0,4.98,5.42)])
    def skirt_weights(t,a):
        # Split front and back continuously between thighs; keep the waist fixed.
        # The full hem follows the gait with reduced leg influence, retaining its bell shape.
        side=(1+math.tanh(-5*math.sin(a)))/2
        hip=float(np.clip(t*3,0,1)); legs=.73*min(1,t*1.48)**1.25
        return {2:1-hip,1:hip-legs,21:legs*side,24:legs*(1-side)}
    fabric.rings(skirt,96,0,skirt_weights,.044,.15)
    # Bias-cut lower flounce and its scalloped lace edging.
    def hem(t,a):return skirt_weights(.87+.13*t,a)
    fabric.rings(profile([(-.96,5.93,0,4.75,5.19),(-1,5.52,0,4.90,5.33),
        (-1.01,5.11,0,5.03,5.46),(-1.02,4.70,0,5.13,5.57)]),96,5,hem,.043,.19)
    fabric.rings(profile([(-.51,15.29,0,1.19,1.59),(-.51,14.96,0,1.24,1.61),
        (-.53,14.57,0,1.32,1.67)]),36,4,lambda t,a:{2:1})
    for side,upper,fore,hand,thigh,calf,foot in [(1,5,6,7,21,22,23),(-1,9,10,11,24,25,26)]:
        # Tailor the sleeve and forearm along the inclined arm of the bind pose.
        def arm(mesh,rows,chart,weights):
            table=np.array(rows)
            def sample(t,s):
                x,y,z,r=[np.interp(t,table[:,0],table[:,i]) for i in range(1,5)]
                depth=np.interp(t,table[:,0],table[:,5]) if table.shape[1]>5 else r
                a=TAU*s
                pos=np.array([x+r*math.cos(a),y+.72*depth*math.sin(a),side*(z+.70*depth*math.sin(a))])
                return pos,uv(chart,.5+.48*math.sin(a),t),weights(t)
            mesh.surface(table[:,0],20,sample,outward=(side==-1))
        arm(fabric,[(0,-.56,19.19,1.73,.58),(.12,-.57,19.03,2.19,.81),(.28,-.59,18.77,2.65,.79),
            (.56,-.61,17.98,3.40,.68),(.86,-.60,17.05,4.12,.60),(1,-.61,16.70,4.47,.62)],3,
            lambda t:blend(upper-1,upper,min(1,t*3)) if t<.8 else blend(upper,fore,(t-.8)*2.3))
        # Forearm, wrist and palm share every ring at the joint. The wrist has
        # a continuous forearm-to-hand weight ramp as the casting pose bends it.
        arm(skin,[(0,-.60,16.91,4.30,.48,.47),(.22,-.55,16.32,4.81,.52,.46),
            (.45,-.36,15.57,5.57,.43,.38),(.60,-.09,15.01,6.13,.33,.30),
            (.68,.04,14.68,6.47,.28,.24),(.74,.05,14.53,6.61,.32,.23),
            (.85,.03,14.27,6.91,.42,.24),(.94,.01,14.05,7.13,.43,.20),
            (1,.01,13.98,7.20,.34,.16)],4,
            lambda t:blend(upper,fore,min(1,.65+t*2)) if t<.2 else
                blend(fore,hand,float(np.clip((t-.57)/.22,0,1))))
        # Fingers begin inside the palm and stay on its bone. Each fingertip closes.
        for x,length,radius in [(-.27,.57,.105),(-.085,.68,.112),(.105,.63,.11),(.28,.49,.096)]:
            arm(skin,[(0,x,14.15,7.06,radius,radius),(.45,x,13.97-.25*length,7.20+.27*length,radius,radius),
                (.87,x+.025,13.99-.76*length,7.18+.72*length,.78*radius,.78*radius),
                (1,x+.04,13.98-.84*length,7.18+.77*length,.012,.012)],4,lambda t:{hand:1})
        arm(skin,[(0,.28,14.46,6.72,.16),(.40,.40,14.29,6.76,.15),
            (.82,.50,14.02,6.88,.11),(1,.51,13.96,6.92,.025)],4,lambda t:{hand:1})
        # White patterned hose and ivory Mary Janes follow the original knee and ankle pivots.
        fabric.rings(profile([(-.48,5.12,side*1.13,.73,.60),(-.55,4.35,side*1.13,.72,.58),
            (-.61,3.54,side*1.12,.63,.52),(-.66,2.02,side*1.09,.40,.38),
            (-.61,.81,side*1.08,.36,.34)]),20,2,lambda t,a:{calf:1})
        shoe_z=side*1.07
        fabric.rings(profile([(-.62,1.24,shoe_z,.43,.43),(-.39,1.02,shoe_z,.71,.50),
            (.16,.78,shoe_z,1.19,.59),(.35,.57,shoe_z,1.42,.64),(.35,.26,shoe_z,1.42,.64),
            (.33,.19,shoe_z,1.36,.58)]),28,4,lambda t,a:{foot:1})
        fabric.rings(profile([(-.61,1.52,shoe_z,.39,.41),(-.61,1.41,shoe_z,.43,.44),
            (-.62,1.30,shoe_z,.40,.41)]),20,5,lambda t,a:{foot:1})
    # A two-layer veil falls from the crown, opening around the face. The lower
    # fabric shares upper-spine motion to keep the train behind casting arms.
    for length in [5.6,8.0]:
        def veil_sheet(t,s):
            a=math.radians(70+220*s)
            width=np.interp(t,[0,.12,.35,.65,1],[.34,1.32,1.94,2.38,2.69])
            depth=np.interp(t,[0,.12,.35,.65,1],[.34,1.26,1.85,2.02,2.42])
            wave=1+.095*t*math.cos(a*13+.35*t)
            x=-1.0+depth*math.cos(a)*wave-.42*t
            y=23.89-length*t-.12*t**6*math.cos(a*20)+.85*t*abs(2*s-1)
            pos=np.array([x,y,-width*math.sin(a)*wave])
            return pos,uv(5,.5+.47*math.sin(6*a),t),blend(12,3,.52*t**1.2)
        veil.surface(np.linspace(0,1,14),58,veil_sheet)
    return fabric,skin,veil



def make_asset():
    OUT.mkdir(exist_ok=True)
    create_atlas()
    original,src=unpack(ROOT/"classic/JUCommandoTech1.glb")
    sk=original["skins"][0]
    joints=sk["joints"]
    assert joints==list(range(36))
    doc=dict(asset={"version":"2.0","generator":"Iron Tide bridal wardrobe"},scene=0,
        scenes=[{"nodes":[0,36]}],nodes=original["nodes"][:36],meshes=[],bufferViews=[],accessors=[],
        buffers=[{}],skins=[],images=[{"uri":"bridal_atlas.png"}],textures=[{"source":0}],materials=[])
    binary=bytearray()

    def view(raw):
        binary.extend(bytes(-len(binary)%4))
        index=len(doc["bufferViews"])
        doc["bufferViews"].append(dict(buffer=0,byteOffset=len(binary),byteLength=len(raw)))
        binary.extend(raw)
        return index

    def accessor(values,kind,bounds=False):
        types={"POSITION":("VEC3","<f4"),"NORMAL":("VEC3","<f4"),"TEXCOORD_0":("VEC2","<f4"),
            "WEIGHTS_0":("VEC4","<f4"),"JOINTS_0":("VEC4","<u2"),"indices":("SCALAR","<u2"),"ibm":("MAT4","<f4")}
        form,dtype=types[kind]
        arr=np.asarray(values,dtype=dtype)
        acc=dict(bufferView=view(arr.tobytes()),componentType=5123 if dtype=="<u2" else 5126,count=len(arr),type=form)
        if bounds:acc.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
        doc["accessors"].append(acc)
        return len(doc["accessors"])-1

    def primitive(arrays,faces,material):
        return dict(attributes={k:accessor(a,k,k=="POSITION") for k,a in arrays.items()},
            indices=accessor(np.array(faces).reshape(-1),"indices"),material=material)

    def material(name,color,texture=None,emission=0):
        pbr=dict(baseColorFactor=color,metallicFactor=0.,roughnessFactor=.91)
        mat=dict(name=name,pbrMetallicRoughness=pbr,doubleSided=True)
        if texture is not None:
            pbr["baseColorTexture"]={"index":texture}
            if emission:
                mat.update(emissiveTexture={"index":texture},emissiveFactor=[emission]*3)
        if color[3]<1:mat["alphaMode"]="BLEND"
        doc["materials"].append(mat)

    material("IvoryEmbroidery",[1,1,1,1],0,.08)
    material("WarmSkin",[.92,.69,.58,1])
    material("Tulle",[1,1,1,.30],0,.12)
    doc["skins"].append(dict(sk,inverseBindMatrices=accessor(read_array(original,src,sk["inverseBindMatrices"]),"ibm")))
    pieces=[]
    for i,mesh in enumerate(build_clothes()):
        assert np.isfinite(mesh.position).all() and np.allclose(np.sum(mesh.weights,axis=1),1)
        pieces.append(primitive(dict(POSITION=mesh.position,NORMAL=mesh.normal,TEXCOORD_0=mesh.uv,
            JOINTS_0=mesh.joints,WEIGHTS_0=mesh.weights),mesh.faces,i))
    doc["nodes"].append(dict(name="BridalOutfit",mesh=0,skin=0))
    doc["meshes"].append(dict(name="BridalOutfit",primitives=pieces))
    pack(OUT/"BridalOutfit.glb",doc,binary)


if __name__=="__main__":
    make_asset()

