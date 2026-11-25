"""Bake vest and head anchors from Tanya's and Boris' native UNIT palette frames."""
import json
from pathlib import Path
from statistics import median

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1] / "iron_tide"


def anchors(frame, unit_id):
    vest = []
    face = []
    for index, (red, green, blue, alpha) in enumerate(frame.get_flattened_data()):
        if not alpha:
            continue
        point = (index % frame.width, index // frame.width)
        if red < green < blue and abs(green * 1.516 - blue) < 3 and abs(red * 1.93 - green) < 3:
            vest.append(point)
        elif red - green == 48 and green - blue == 16:
            face.append(point)
    if not vest:
        return []
    x, y = (round(median(axis)) for axis in zip(*vest))
    nearby = [(px, py) for px, py in face if abs(px - x) <= 11 and y - 14 <= py <= y]
    if not nearby:
        return [x, y, x, y - (5 if unit_id == "TANY" else 8)]
    top = min(py for _, py in nearby)
    forehead = [px for px, py in nearby if py <= top + 2]
    return [x, y, round(median(forehead)), top + 1]


def bake(unit_id):
    base = PROJECT / "assets/ra2/shp" / unit_id
    sheet = Image.open(base.with_suffix(".png")).convert("RGBA")
    metadata = json.loads(base.with_suffix(".json").read_text())
    sequences = json.loads(base.with_suffix(".seq.json").read_text())["seq"]
    end = max(s["start"] + (s["facings"] - 1) * s.get("stride", s["per"]) + s["per"]
              for s in sequences.values())
    rows = []
    for rect in metadata["rects"][:end]:
        x, y = rect["x"], rect["y"]
        rows.append(anchors(sheet.crop((x, y, x + rect["w"], y + rect["h"])), unit_id))
    path = PROJECT / "assets/cosmetics/skins" / (unit_id.lower() + "_rig_sockets.json")
    path.write_text(json.dumps(rows, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    for commando in ["TANY", "BORIS"]:
        bake(commando)
