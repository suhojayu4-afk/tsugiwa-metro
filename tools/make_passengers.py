"""Passengers who get off and on at のりば (lib/core/pixel/pixel_scene.dart,
_ScenePainter._passengers): PixelLab characters (v3, 64 px, eye-level
view) with the 'walking' template (6 frames) toward the camera
(south-east, getting off) and away from it (north-west, getting on).

Each walk becomes one strip of 6 frames, cropped to the figure (the same box
for every frame) with the feet on the bottom row, so the app can size the
figure by the platform's perspective:

  assets/art/people/{id}_toward.png, {id}_away.png

  python tools/make_passengers.py
"""
import io
import json
import os
import urllib.request
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'art', 'people')
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'people')

# App id -> PixelLab character id (made 2026-11-19).
CHARACTERS = {
    'suit_man': '341c5181-524c-434b-9e75-169324c0339c',  # pro, styled on the station pictures
}
DIRS = {'toward': 'south-east', 'away': 'north-west'}


def frames(zf, direction):
    names = sorted(n for n in zf.namelist() if f'/animations/' in n and f'/{direction}/' in n and n.endswith('.png'))
    return [Image.open(io.BytesIO(zf.read(n))).convert('RGBA') for n in names]


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
            assert len(fs) == 6, (app_id, direction, len(fs))
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
            path = os.path.join(OUT, f'{app_id}_{name}.png')
            strip.save(path)
            print(path, strip.size)
    json.dumps(CHARACTERS)


if __name__ == '__main__':
    main()
