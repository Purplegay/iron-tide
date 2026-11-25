"""Bake the moving observatory rim for the RA2 Apocalypse tank at 2x resolution."""
from math import cos, sin, tau
from pathlib import Path

from PIL import Image, ImageDraw

RADIUS = 18 * 1.95
WIDTH, HEIGHT = 160, 72
FRAMES, COLUMNS = 72, 12
SCALE = 4


def frame(index, strength):
    tile = Image.new("RGBA", (WIDTH * SCALE, HEIGHT * SCALE))
    pen = ImageDraw.Draw(tile)
    angle = index * tau / FRAMES

    def point(a, factor=1.0):
        return ((WIDTH / 2 + 2 * RADIUS * factor * cos(a)) * SCALE,
                (HEIGHT / 2 + 2 * RADIUS * 0.4 * factor * sin(a)) * SCALE)

    def stroke(points, rgb, opacity, width):
        pen.line(points, fill=(*rgb, round(255 * opacity)), width=round(2 * SCALE * width))

    stroke([point(tau * i / 64) for i in range(65)], (64, 117, 224), .4 + strength * .32, 1.05)
    for i in range(24):
        a = tau * i / 24
        stroke([point(a, .96), point(a, 1.07 if i % 6 == 0 else 1.015)],
               (153, 201, 255), .66, .7)
    for arc in range(3):
        stroke([point(angle + tau * arc / 3 + i * .076, 1.065) for i in range(17)],
               (105, 227, 255), .55 + strength * .35, 1.05)
    for i in reversed(range(5)):
        x, y = point(angle - i * .065)
        r = (1.5 - .18 * i) * 2 * SCALE
        pen.ellipse((x-r, y-r, x+r, y+r), fill=(145, 230, 255, round(255 * (.95-.17*i))))
    return tile.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)


if __name__ == "__main__":
    atlas = Image.new("RGBA", (COLUMNS * WIDTH, 2 * FRAMES // COLUMNS * HEIGHT))
    for i in range(FRAMES):
        base, bright = frame(i, 0), frame(i, 1)
        base_alpha = base.getchannel("A").tobytes()
        bright_alpha = bright.getchannel("A").tobytes()
        # Source-over on the base frame gives the original brighter combat rim.
        extra = bytes(round(255 * max(0, b-a) / (255-a)) if a < 255 else 0
                      for a, b in zip(base_alpha, bright_alpha))
        bright.putalpha(Image.frombytes("L", bright.size, extra))
        for bank, tile in enumerate((base, bright)):
            atlas.paste(tile, (i % COLUMNS * WIDTH, (bank * FRAMES + i) // COLUMNS * HEIGHT))
    output = Path(__file__).resolve().parents[1] / "iron_tide/assets/cosmetics/skins/apoc_polar_orbit.png"
    atlas.save(output, optimize=True)
