"""Pack PixelLab ambient-animation frames into one sprite sheet for the app.

The scene is animated as two 192x192 halves (PixelLab's frame limit is 256).
This joins them back together, cleans them up and stacks the frames:

  python tools/anim_pack.py STATIC.webp LEFT_PREFIX RIGHT_PREFIX OUT.webp [--frames 8]

  STATIC.webp   the still scene (384x192), e.g. assets/art/scene_evening.webp
  LEFT_PREFIX   frames LEFT_PREFIX_00.png ... (frame 0 = the input)
  OUT.webp      384 x (192*frames) sheet, frame i at y = 192*i (.webp: lossless)

Clean-up, so it does not look "generated":
  - motion is kept only inside --left-box / --right-box
  - every frame uses the still scene's own palette (no colour drift)
  - pixels that barely changed, and lone specks, are reset to the still scene
"""
import argparse

from PIL import Image, ImageChops, ImageFilter
from art_io import save_art  # noqa: E402  (lossless WebP)

W, H, HALF = 384, 192, 192


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("static")
    ap.add_argument("left")
    ap.add_argument("right")
    ap.add_argument("out")
    ap.add_argument("--frames", type=int, default=8)
    ap.add_argument("--threshold", type=int, default=28, help="min change to keep a pixel")
    ap.add_argument("--left-box", default="0,0,192,192",
                    help="x0,y0,x1,y1 inside the left half where motion is kept")
    ap.add_argument("--right-box", default="0,0,192,192",
                    help="x0,y0,x1,y1 inside the right half where motion is kept")
    a = ap.parse_args()

    still = Image.open(a.static).convert("RGB")
    assert still.size == (W, H), still.size
    palette = still.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)

    sheet = Image.new("RGB", (W, H * a.frames))
    changed_total = 0
    for i in range(a.frames):
        frame = still.copy()
        boxes = (tuple(map(int, a.left_box.split(","))), tuple(map(int, a.right_box.split(","))))
        for (prefix, x0), box in zip(((a.left, 0), (a.right, HALF)), boxes):
            try:
                part = Image.open(f"{prefix}_{i:02d}.png").convert("RGB")
            except FileNotFoundError:
                continue  # that half stays still
            if part.size != (HALF, H):
                part = part.resize((HALF, H), Image.Resampling.NEAREST)
            part = part.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")
            base = still.crop((x0, 0, x0 + HALF, H))
            diff = ImageChops.difference(part, base).convert("L")
            mask = diff.point(lambda v: 255 if v >= a.threshold else 0)
            # Only keep motion inside the box (e.g. lit windows, not a
            # whole-picture lighting pulse that would show a seam).
            keep = Image.new("L", (HALF, H), 0)
            keep.paste(255, box)
            mask = ImageChops.multiply(mask, keep)
            # Drop lone flickering specks; keep real shapes (people, windows).
            mask = mask.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.MaxFilter(3))
            mask = ImageChops.multiply(mask, diff.point(lambda v: 255 if v >= a.threshold // 2 else 0))
            changed_total += sum(1 for v in mask.get_flattened_data() if v)
            frame.paste(part, (x0, 0), mask)
        sheet.paste(frame, (0, H * i))
    save_art(sheet, a.out, optimize=True)
    print(f"{a.out}: {a.frames} frames, {changed_total / a.frames:.0f} changed px per frame")


if __name__ == "__main__":
    main()
