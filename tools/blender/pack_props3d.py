"""Turns the Blender renders of tools/blender/props3d.py into pixel art (as
pack_train3d.py does the train) and packs them for the app:

  assets/art/train3d/props_base.webp  every prop, outlined, with its shadow
  assets/art/train3d/props_lamp.webp  their lamps only (lit after dark)
  assets/art/train3d/props.json       each prop's place in the atlas, its ground anchor and width

  python tools/blender/pack_props3d.py docs/art/gen/train3d/props
"""

import json
import os
import sys

from PIL import Image, ImageFilter

SRC = sys.argv[1]
OUT = "assets/art/train3d"
OUTLINE = (24, 26, 38, 255)
SHADOW = (10, 12, 24, 84)
meta = json.load(open(os.path.join(SRC, "meta.json")))
DOWN = meta["pxPerM"] / 6.5  # to 6.5 pixels a metre, as the train


def frame(name, w, h):
    return Image.open(os.path.join(SRC, name)).convert("RGBA").resize((w, h), Image.LANCZOS)


def pixel_base(im):
    mask = im.getchannel("A").point(lambda a: 255 if a >= 150 else 0)
    q = im.convert("RGB").quantize(24, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow = im.getchannel("A").point(lambda a: 255 if 20 <= a < 150 else 0)
    out.paste(Image.new("RGBA", im.size, SHADOW), mask=shadow)
    out.paste(Image.new("RGBA", im.size, OUTLINE), mask=mask.filter(ImageFilter.MaxFilter(3)))
    out.paste(q, mask=mask)
    return out


def pixel_lamp(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= 100 else 0)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", im.size, (255, 255, 255, 255)), mask=a)
    return out


items = []
for name, p in meta["props"].items():
    w, h = round(p["w"] / DOWN), round(p["h"] / DOWN)
    items.append((name, w, h, p))
# Shelf packing, tallest first.
items.sort(key=lambda t: -t[2])
MAXW = 2048
x = y = shelf = 0
place = {}
for name, w, h, p in items:
    if x + w > MAXW:
        x, y, shelf = 0, y + shelf + 2, 0
    place[name] = (x, y)
    x += w + 2
    shelf = max(shelf, h)
W, H = MAXW, y + shelf
base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
lamp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
out = {"pxPerM": meta["pxPerM"] / DOWN, "props": {}}
for name, w, h, p in items:
    px, py = place[name]
    base.paste(pixel_base(frame(f"base_{name}.png", w, h)), (px, py))
    lamp.paste(pixel_lamp(frame(f"lamp_{name}.png", w, h)), (px, py))
    out["props"][name] = {
        "x": px,
        "y": py,
        "w": w,
        "h": h,
        "anchor": [round(v / DOWN, 1) for v in p["anchor"]],
        "widthM": p["width_m"],
    }
base.save(os.path.join(OUT, "props_base.webp"), lossless=True, quality=100, method=6)
lamp.save(os.path.join(OUT, "props_lamp.webp"), lossless=True, quality=100, method=6)
json.dump(out, open(os.path.join(OUT, "props.json"), "w"), separators=(",", ":"))
print("props", W, "x", H, os.path.getsize(os.path.join(OUT, "props_base.webp")) // 1024, "KB")
