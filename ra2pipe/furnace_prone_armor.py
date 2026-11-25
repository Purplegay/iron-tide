"""Bake the Furnace prone harness in the original ConSequence frame coordinates."""
from pathlib import Path
from math import cos, sin, tau
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1] / "iron_tide"
source = Image.open(PROJECT / "assets/ra2/shp/E2.png").convert("RGBA")
width, height = 76, 96
scale = 2
sheet = Image.new("RGBA", (width * scale * 12, height * scale * 8))
for pose, first in enumerate((86, 212)):  # Eight facings, six crawl or recoil frames each.
    for facing in range(8):
        angle = -tau * facing / 8
        front = (sin(angle), -cos(angle))
        right = (-front[1], front[0])
        for phase in range(6):
            index = first + facing * 6 + phase
            x, y = index % 12 * width, index // 12 * height
            frame = source.crop((x, y, x + width, y + height))
            # Warm uniform/skin pixels locate the moving torso without following the black rifle.
            warm = [(u,v) for v in range(height) for u in range(width)
                    if (lambda c: c[3] and c[0] > 85 and c[0] > c[1]+24 and c[1] >= c[2])(frame.getpixel((u,v)))]
            if not warm:
                raise ValueError(f"No torso socket in frame {index}")
            cx = sum(u for u,v in warm)/len(warm) - 2*front[0]
            cy = sum(v for u,v in warm)/len(warm) - front[1] - 1
            layer = Image.new("RGBA", (width*scale,height*scale))
            draw = ImageDraw.Draw(layer)
            def point(f,s,z=0):
                return (round(scale*(cx+front[0]*f+right[0]*s)),
                        round(scale*(cy+(front[1]*f+right[1]*s)*0.64-z)))
            def plate(points, fill, edge):
                vertices=[point(*pt) for pt in points]
                draw.polygon(vertices,fill=fill)
                draw.line(vertices+[vertices[0]],fill=edge,width=2)
            # Overlapping lacquered lamellae, tapered toward the belt.
            for f,w in [(-6,2.9),(-3.7,4),(0,4.8),(3.2,5.1)]:
                plate([(f+1.6,-w,2),(f+2.2,0,3.7),(f+1.6,w,2),(f-1.4,w-.6,1),(f-2.5,0,1.5),(f-1.4,-w+.6,1)],"#853b32","#42262a")
                draw.line([point(f+1,-w+.6,2.3),point(f+1.8,0,3.8),point(f+1,w-.6,2.3)],fill="#e5ae59",width=2)
            # A ridged dorsal crest and two gold cheek guards leave the native muzzle clear.
            for f in [-3,.4,3.6]:
                plate([(f-1,0,3),(f-1.8,0,6),(f+1.5,0,3.4)],"#ffe19a","#9c592e")
            for side in sorted((-1,1),key=lambda n:n*right[1]):
                plate([(5,-0.1+side*3.5,3),(6.7,side*5,2.6),(3.8,side*6.4,1.8),(1.2,side*4.8,2)],"#b77637","#583327")
            slot=pose*48+facing*6+phase
            sheet.paste(layer,(slot%12*width*scale,slot//12*height*scale))
sheet.save(PROJECT / "assets/cosmetics/heroes/furnace_prone_armor.png",optimize=True)
