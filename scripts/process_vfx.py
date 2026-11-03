# /// script
# dependencies = ["pillow"]
# ///
"""T-053a2: make Roblox-ready copies of owner VFX/icon PNGs in assets/processed/ (originals untouched).
Usage: uv run scripts/process_vfx.py
- <name>-add.png: cropped to content (+margin), square, 512 px, opaque on black (additive: LightEmission = 1).
- <name>-alpha.png: same, alpha = luminance and colour un-premultiplied (for non-additive surfaces).
- icons: 512 px copy."""
import pathlib
from PIL import Image, ImageChops

SRC = pathlib.Path("assets/source")
OUT = pathlib.Path("assets/processed")
VFX = ["vfx-crescent-slash", "vfx-crescent-hit", "vfx-crescent-blue", "vfx-crescent-gold"]  # blue/gold: owner picks 4/3 (T-057a, D-412)
ICONS = ["icon-crescent-cut"]
SIZE = 512


def square_crop(img: Image.Image, margin: int = 16) -> Image.Image:
    lum = img.convert("L").point(lambda v: 255 if v > 8 else 0)
    l, t, r, b = lum.getbbox() or (0, 0, img.width, img.height)
    cx, cy = (l + r) / 2, (t + b) / 2
    half = max(r - l, b - t) / 2 + margin
    box = tuple(int(round(v)) for v in (cx - half, cy - half, cx + half, cy + half))
    canvas = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), (0, 0, 0))
    canvas.paste(img.crop((max(box[0], 0), max(box[1], 0), min(box[2], img.width), min(box[3], img.height))),
                 (max(-box[0], 0), max(-box[1], 0)))
    return canvas


def alpha_version(rgb: Image.Image) -> Image.Image:
    r, g, b = rgb.split()
    a = ImageChops.lighter(ImageChops.lighter(r, g), b)  # max channel as alpha keeps hue saturated
    px_rgb, px_a = rgb.load(), a.load()
    out = Image.new("RGBA", rgb.size)
    po = out.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            al = px_a[x, y]
            if al == 0:
                po[x, y] = (0, 0, 0, 0)
            else:
                cr, cg, cb = px_rgb[x, y]
                po[x, y] = (min(255, cr * 255 // al), min(255, cg * 255 // al), min(255, cb * 255 // al), al)
    return out


OUT.mkdir(parents=True, exist_ok=True)
for n in VFX:
    img = square_crop(Image.open(SRC / f"{n}.png").convert("RGB")).resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT / f"{n}-add.png", optimize=True)
    alpha_version(img).save(OUT / f"{n}-alpha.png", optimize=True)
    print(f"{n}: add + alpha {SIZE}px")
for n in ICONS:
    Image.open(SRC / f"{n}.png").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{n}.png", optimize=True)
    print(f"{n}: {SIZE}px")
