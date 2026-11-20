"""Turn an AI-generated "pixel art" image into real pixel art.

Generated images only look pixelated: the blocks are uneven and edges are
blurred. This snaps the picture to a true pixel grid and limits the colours,
which removes most of the "AI look".

Usage:
  python tools/pixelize.py IN.png OUT.webp [--width 384] [--aspect 2.0] [--colors 48]

Writes OUT (.webp: lossless) at art resolution (e.g. 384x192) plus
OUT_preview.png at 4x.
"""
import argparse
import os

from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--width", type=int, default=384)
    ap.add_argument("--aspect", type=float, default=2.0, help="width / height after cropping")
    ap.add_argument("--colors", type=int, default=48)
    ap.add_argument("--yshift", type=float, default=0.0, help="crop offset, -1 (top) .. 1 (bottom)")
    a = ap.parse_args()

    img = Image.open(a.src).convert("RGB")
    w, h = img.size
    ch = min(h, round(w / a.aspect))
    top = round((h - ch) / 2 * (1 + a.yshift))
    img = img.crop((0, top, w, top + ch))

    # Each art pixel = the average of its block (box filter), not one sample,
    # so blurred block edges don't leave stray colours.
    out_w = a.width
    out_h = round(out_w / a.aspect)
    small = img.resize((out_w, out_h), Image.Resampling.BOX)

    # One shared palette for the whole picture; no dithering (clean clusters).
    small = small.quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT,
                           dither=Image.Dither.NONE).convert("RGB")
    save_art(small, a.dst)
    small.resize((out_w * 4, out_h * 4), Image.Resampling.NEAREST).save(
        os.path.splitext(a.dst)[0] + "_preview.png")
    print(f"{a.dst}: {out_w}x{out_h}, {a.colors} colours")


if __name__ == "__main__":
    main()
