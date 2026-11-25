"""Bake the nearest opaque pixel to each native vehicle frame's visible center."""
import json
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    root = Path(__file__).resolve().parents[1] / "iron_tide/assets/ra2"
    result = {}
    for meta in sorted((root / "vxl").glob("*.json")):
        data = json.loads(meta.read_bytes())
        texture = meta.with_suffix(".png")
        if not texture.is_file() or not data.get("frameW") or not data.get("frameH"):
            continue
        with Image.open(texture) as image:
            alpha = np.asarray(image.convert("RGBA"))[:, :, 3]
            w, h, facings = data["frameW"], data["frameH"], data.get("facings", 8)
            rows = []
            for i in range(facings * data.get("poses", 1)):
                x, y = 2 + (i % facings) * (w + 2), 2 + (i // facings) * (h + 2)
                ys, xs = np.nonzero(alpha[y:y+h, x:x+w] >= 20)
                if not xs.size:
                    rows.append(None)
                    continue
                # Row-major argmin retains Godot's first pixel in the event of a tie.
                dx = 2 * xs - (xs.min() + xs.max())
                dy = 2 * ys - (ys.min() + ys.max())
                n = (dx * dx + dy * dy).argmin()
                rows.append([int(xs[n]), int(ys[n])])
            result[meta.stem] = rows
    (root / "vehicle_selection_centers.json").write_text(
        json.dumps(result, separators=(",", ":")) + "\n", encoding="utf8")


if __name__ == "__main__":
    main()
