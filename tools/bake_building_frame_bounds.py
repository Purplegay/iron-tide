"""Bake visible rectangles of Yuri building layers for combat fog and drawing."""
import json
from pathlib import Path

from PIL import Image


def main():
    assets = Path(__file__).resolve().parents[1] / "iron_tide/assets/ra2"
    ids = set()
    for descriptor in (assets / "bldanim").glob("*.json"):
        building = json.loads(descriptor.read_bytes())
        ids.add(building.get("image", building["id"]))
        for layer in building.get("layers", []):
            for part in (layer, layer.get("dmg", {})):
                if part.get("image"):
                    ids.add(part["image"])
    bounds = {}
    for name in sorted(ids):
        descriptor = assets / "shp" / (name + ".json")
        if not descriptor.is_file() or not descriptor.with_suffix(".png").is_file():
            continue
        frames = json.loads(descriptor.read_bytes())["rects"]
        with Image.open(descriptor.with_suffix(".png")) as sheet:
            alpha = sheet.convert("RGBA").getchannel("A")
            rows = []
            for frame in frames:
                x, y, w, h = (frame[key] for key in ("x", "y", "w", "h"))
                box = alpha.crop((x, y, x + w, y + h)).getbbox()
                rows.append([box[0], box[1], box[2]-box[0], box[3]-box[1]] if box else [0, 0, 0, 0])
            bounds[name] = rows
    dest = assets / "building_frame_bounds.json"
    dest.write_text(json.dumps(bounds, separators=(",", ":")) + "\n", encoding="utf8")


if __name__ == "__main__":
    main()
