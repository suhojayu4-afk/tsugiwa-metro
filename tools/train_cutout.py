"""Cut a generated train out of its magenta background and split the stripe.

Usage:
  python tools/train_cutout.py RAW.png OUT_DIR [--factor 4] [--colors 48]

Writes to OUT_DIR:
  train_front_base.png    the train without its stripe (RGBA, pixel grid)
  train_front_stripe.png  the stripe only, as grey shading (RGBA); the app
                          multiplies it by the line colour
  train_front_preview.png base + green stripe at 4x, for checking
"""
import argparse
import colorsys
import os

from PIL import Image


def is_magenta(r, g, b):
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def is_stripe(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return 0.22 < h < 0.45 and s > 0.35 and v > 0.25


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out_dir")
    ap.add_argument("--factor", type=int, default=4, help="screen pixels per art pixel in the source")
    ap.add_argument("--colors", type=int, default=48)
    a = ap.parse_args()

    raw = Image.open(a.src).convert("RGB")
    w, h = raw.size
    sw, sh = w // a.factor, h // a.factor

    # Average each factor×factor block over its non-magenta pixels only.
    px = raw.load()
    out = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    op = out.load()
    for y in range(sh):
        for x in range(sw):
            rs = gs = bs = n = 0
            total = a.factor * a.factor
            for dy in range(a.factor):
                for dx in range(a.factor):
                    r, g, b = px[x * a.factor + dx, y * a.factor + dy]
                    if is_magenta(r, g, b):
                        continue
                    rs += r
                    gs += g
                    bs += b
                    n += 1
            if n * 2 >= total:
                op[x, y] = (rs // n, gs // n, bs // n, 255)

    # Drop isolated specks left over from the background edge.
    for y in range(sh):
        for x in range(sw):
            if op[x, y][3] == 0:
                continue
            neighbours = sum(
                1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < sw and 0 <= y + dy < sh and op[x + dx, y + dy][3]
            )
            if neighbours <= 1:
                op[x, y] = (0, 0, 0, 0)

    bbox = out.getbbox()
    out = out.crop(bbox)

    # Clean colour clusters: quantize the opaque pixels to one palette.
    rgb = out.convert("RGB").quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT,
                                      dither=Image.Dither.NONE).convert("RGB")
    alpha = out.getchannel("A")
    base = Image.new("RGBA", out.size, (0, 0, 0, 0))
    stripe = Image.new("RGBA", out.size, (0, 0, 0, 0))
    bp, sp, rp, ap_ = base.load(), stripe.load(), rgb.load(), alpha.load()

    # Stripe brightness is stored relative to its typical value, so the
    # line colour shows exactly on the main part of the stripe.
    values = []
    for y in range(out.height):
        for x in range(out.width):
            if ap_[x, y] and is_stripe(*rp[x, y]):
                values.append(max(rp[x, y]))
    ref = sorted(values)[len(values) * 3 // 4] if values else 255

    for y in range(out.height):
        for x in range(out.width):
            if not ap_[x, y]:
                continue
            r, g, b = rp[x, y]
            if is_stripe(r, g, b):
                v = min(255, round(max(r, g, b) * 255 / ref))
                sp[x, y] = (v, v, v, 255)
            else:
                bp[x, y] = (r, g, b, 255)

    os.makedirs(a.out_dir, exist_ok=True)
    base.save(os.path.join(a.out_dir, "train_front_base.png"))
    # The source is lit by the sunset; re-light it for the other scenes.
    # Lights (very bright pixels) keep their colour.
    for part, (tint, amount, gain) in {
        "evening": ((255, 255, 255), 0.0, 1.0),
        "day": ((214, 222, 236), 0.8, 1.06),
        "night": ((120, 132, 190), 0.7, 0.72),
    }.items():
        graded = base.copy()
        gp = graded.load()
        for y in range(graded.height):
            for x in range(graded.width):
                r, g, b, al = gp[x, y]
                if not al or max(r, g, b) > 235:
                    continue
                lum = (r * 299 + g * 587 + b * 114) / 1000
                gp[x, y] = tuple(
                    max(0, min(255, round(((1 - amount) * c + amount * lum * t / 255) * gain)))
                    for c, t in zip((r, g, b), tint)
                ) + (al,)
        graded.save(os.path.join(a.out_dir, f"train_front_base_{part}.png"))
    stripe.save(os.path.join(a.out_dir, "train_front_stripe.png"))

    # Yamanote green (#80C241) on the stripe, like the app does.
    tinted = Image.composite(
        Image.merge("RGBA", [
            Image.eval(stripe.getchannel(0), lambda v: v * 128 // 255),
            Image.eval(stripe.getchannel(1), lambda v: v * 194 // 255),
            Image.eval(stripe.getchannel(2), lambda v: v * 65 // 255),
            stripe.getchannel("A"),
        ]),
        base,
        stripe.getchannel("A"),
    )
    preview = Image.new("RGBA", out.size, (40, 40, 60, 255))
    preview.alpha_composite(tinted)
    preview.resize((out.width * 4, out.height * 4), Image.Resampling.NEAREST).save(
        os.path.join(a.out_dir, "train_front_preview.png"))
    print(f"train {out.width}x{out.height} (bbox {bbox} in {sw}x{sh}), stripe px {len(values)}")


if __name__ == "__main__":
    main()
