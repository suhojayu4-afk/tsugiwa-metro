"""Download the PixelLab landmark candidates listed in
docs/art/gen/<city>/jobs.txt ("name job_id" per line) into
docs/art/gen/<city>/lm_<name>/c<N>.png, with a contact sheet (sheet.png,
3x, numbered) to pick from.

  python -X utf8 tools/<city>/get_candidates.py [name ...]
"""
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import conf  # noqa: E402

GEN = os.path.join(ROOT, 'docs', 'art', 'gen', conf.CITY)
URL = 'https://api.pixellab.ai/mcp/images/%s/download?index=%d'


def get(name, job, n=16):
    d = os.path.join(GEN, 'lm_' + name)
    os.makedirs(d, exist_ok=True)
    ims = []
    for i in range(n):
        p = os.path.join(d, f'c{i}.png')
        if not os.path.exists(p):
            try:
                with urllib.request.urlopen(URL % (job, i), timeout=60) as r:
                    open(p, 'wb').write(r.read())
            except Exception as e:
                print(name, i, e)
                break
        ims.append(Image.open(p).convert('RGBA'))
    k, cell = 3, 64 * 3 + 8
    sheet = Image.new('RGBA', (cell * 4, cell * ((len(ims) + 3) // 4)), (236, 236, 228, 255))
    dr = ImageDraw.Draw(sheet)
    for i, im in enumerate(ims):
        x, y = (i % 4) * cell, (i // 4) * cell
        sheet.alpha_composite(im.resize((im.width * k, im.height * k), Image.NEAREST), (x + 4, y + 4))
        dr.text((x + 6, y + 4), str(i), fill=(200, 0, 0, 255))
    sheet.save(os.path.join(d, 'sheet.png'))
    print(name, len(ims))


jobs = [l.split() for l in open(os.path.join(GEN, 'jobs.txt'), encoding='utf8') if l.strip()]
for name, job in jobs:
    if len(sys.argv) < 2 or name in sys.argv[1:]:
        get(name, job)
