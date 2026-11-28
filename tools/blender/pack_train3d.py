"""Turns the Blender frames of tools/blender/train3d.py into pixel art and
packs them into the app's atlases:

  assets/art/train3d/train3d_base.webp    the train (one shared palette, outlined), its shadow
  assets/art/train3d/train3d_stripe.webp  the line band, white with its shading (the app tints it)
  assets/art/train3d/train3d_glass.webp   the window glass (lit after dark)
  assets/art/train3d/train3d.json         where each angle's frame is, and where its rail and nose fall

  python tools/blender/pack_train3d.py docs/art/gen/train3d/frames
"""

import json
import os
import sys

from PIL import Image, ImageFilter

SRC = sys.argv[1]
OUT = "assets/art/train3d"
# The second argument names the train: "train3d" (EMU) or "train3d_dmu".
NAME = sys.argv[2] if len(sys.argv) > 2 else "train3d"
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(os.path.join(SRC, "meta.json")))
# Frames shrink so one train pixel is one grid pixel of the view, at 6.5 a metre.
DOWN = meta["w"] / meta["ortho"] / 6.5
W, H = round(meta["w"] / DOWN), round(meta["h"] / DOWN)
keys = [f"{a}_{e}" for e in meta["pitches"] for a in meta["yaws"]]
COLS = 4
ROWS = (len(keys) + COLS - 1) // COLS
OUTLINE = (24, 26, 38, 255)
SHADOW = (10, 12, 24, 84)


def frame(name):
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    return im.resize((W, H), Image.LANCZOS)


def body_mask(im):
    return im.getchannel("A").point(lambda a: 255 if a >= 150 else 0)


# One palette for every frame, so turning never makes the colours flicker.
sample = Image.new("RGB", (W, H * 6))
for i, k in enumerate(keys[:: max(1, len(keys) // 6)][:6]):
    im = frame(f"base_{k}.png")
    flat = Image.new("RGB", im.size, (255, 0, 255))
    flat.paste(im.convert("RGB"), mask=body_mask(im))
    sample.paste(flat, (0, i * H))
palette = sample.quantize(40, method=Image.Quantize.MEDIANCUT)


def pixel_base(im):
    mask = body_mask(im)
    q = im.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    # The shadow the ground caught: one flat, soft tone.
    shadow = im.getchannel("A").point(lambda a: 255 if 20 <= a < 150 else 0)
    out.paste(Image.new("RGBA", im.size, SHADOW), mask=shadow)
    # A dark outline just outside the train.
    ring = mask.filter(ImageFilter.MaxFilter(3))  # one pixel round
    out.paste(Image.new("RGBA", im.size, OUTLINE), mask=ring)
    out.paste(q, mask=mask)
    return out


def pixel_mask(im, levels):
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    lum = im.convert("L").point(lambda v: min(255, int(round(v / 255 * (levels - 1))) * (255 // (levels - 1)) + 40))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(Image.merge("RGBA", (lum, lum, lum, a)), mask=a)
    return out


atlases = {p: Image.new("RGBA", (COLS * W, ROWS * H), (0, 0, 0, 0)) for p in ("base", "stripe", "glass")}
frames = {}
for i, k in enumerate(keys):
    x, y = (i % COLS) * W, (i // COLS) * H
    atlases["base"].paste(pixel_base(frame(f"base_{k}.png")), (x, y))
    atlases["stripe"].paste(pixel_mask(frame(f"stripe_{k}.png"), 5), (x, y))
    atlases["glass"].paste(pixel_mask(frame(f"glass_{k}.png"), 2), (x, y))
    f = meta["frames"][k]
    frames[k] = {"x": x, "y": y, **{n: [round(v / DOWN, 1) for v in f[n]] for n in ("rail", "nose", "tail")}}

for p, im in atlases.items():
    im.save(os.path.join(OUT, f"{NAME}_{p}.webp"), lossless=True, quality=100, method=6)
json.dump(
    {"w": W, "h": H, "span": meta["span"], "ortho": meta["ortho"], "yaws": meta["yaws"], "pitches": meta["pitches"], "frames": frames},
    open(os.path.join(OUT, f"{NAME}.json"), "w"),
    separators=(",", ":"),
)
for p in atlases:
    print(p, os.path.getsize(os.path.join(OUT, f"{NAME}_{p}.webp")) // 1024, "KB")
