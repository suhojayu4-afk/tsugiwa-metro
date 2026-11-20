"""(Replaced by GPT-drawn passengers: tools/gen_passengers_gpt.py. Kept for the
PixelLab tests of 2026-11-19.)

Passengers who get off and on at のりば (lib/core/pixel/pixel_scene.dart,
_ScenePainter._passengers): PixelLab characters (v3, 64 px, eye-level
view) with the 'walking' template (6 frames) toward the camera
(south-east, getting off) and away from it (north-west, getting on).

Each walk becomes one strip of 6 frames, cropped to the figure (the same box
for every frame) with the feet on the bottom row, so the app can size the
figure by the platform's perspective:

  assets/art/people/{id}_toward.webp, {id}_away.webp

  python tools/make_passengers.py
"""
import io
import json
import os
import urllib.request
import zipfile

from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'art', 'people')
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'people')

# App id -> PixelLab character id (made 2026-11-19).
CHARACTERS = {
    'suit_man': 'a18aabf4-3a62-4176-9d68-64fd46411b54',  # pro v2 (empty hands), skeleton walk
}
DIRS = {'toward': 'south-east', 'away': 'north-west'}


def clean_edges(im):
    """Removes the light speckles on the outline (a pixel at the edge much
    brighter than the solid pixels inside next to it)."""
    px = im.load()
    w, h = im.size
    lum = lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    drop = []
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 128:
                continue
            near = [px[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < w and 0 <= y + dy < h]
            if all(n[3] >= 128 for n in near):
                continue  # inside, not on the edge
            solid = [n for n in near if n[3] >= 128]
            if not solid or lum(c) - sum(lum(n) for n in solid) / len(solid) > 45:
                drop.append((x, y))
    for x, y in drop:
        px[x, y] = (0, 0, 0, 0)
    return im


def frames(zf, direction):
    names = sorted(n for n in zf.namelist() if f'/animations/' in n and f'/{direction}/' in n and n.endswith('.png'))
    return [clean_edges(Image.open(io.BytesIO(zf.read(n))).convert('RGBA')) for n in names]


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RAW, exist_ok=True)
    for app_id, cid in CHARACTERS.items():
        raw = os.path.join(RAW, f'{app_id}.zip')
        if not os.path.exists(raw):
            req = urllib.request.Request(f'https://api.pixellab.ai/mcp/characters/{cid}/download',
                                         headers={'User-Agent': 'tsugiwa-tools'})
            open(raw, 'wb').write(urllib.request.urlopen(req).read())
        zf = zipfile.ZipFile(raw)
        for name, direction in DIRS.items():
            fs = frames(zf, direction)
            assert len(fs) >= 6, (app_id, direction, len(fs))
            fs = fs[:6] if len(fs) == 6 else [fs[round(i * len(fs) / 6)] for i in range(6)]
            # One box for all frames, so the figure does not jump.
            boxes = [f.getbbox() for f in fs]
            l = min(b[0] for b in boxes)
            t = min(b[1] for b in boxes)
            r = max(b[2] for b in boxes)
            b = max(b[3] for b in boxes)
            w, h = r - l, b - t
            strip = Image.new('RGBA', (w * len(fs), h))
            for i, f in enumerate(fs):
                strip.paste(f.crop((l, t, r, b)), (i * w, 0))
            path = os.path.join(OUT, f'{app_id}_{name}.webp')
            save_art(strip, path)
            print(path, strip.size)
    json.dumps(CHARACTERS)


if __name__ == '__main__':
    main()
