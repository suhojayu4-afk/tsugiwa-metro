"""駅印帳 (station seal book) art, for lib/features/my_room/eki_in_book.dart.

  python tools/gen_eki_in_gpt.py motifs   # GPT draws 16 seal emblems (one sheet)
  python tools/gen_eki_in_gpt.py cut      # sheet -> assets/art/eki_in/motif_<name>.webp (white alpha masks)
  python tools/gen_eki_in_gpt.py paper    # washi + gold-leaf tiles (procedural, numpy)
  python tools/gen_eki_in_gpt.py font     # Yuji Boku (OFL brush font) subset to every station name
  python tools/gen_eki_in_gpt.py all

The emblems are ORIGINAL generic motifs (sakura, wave, bridge, ...) chosen per
station by keywords in its name (see EkiInMotif in the Dart file); no railway
company marks, no copies of real 駅印.
"""
import glob
import json
import os
import subprocess
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import MODEL, ROOT  # noqa: E402
from art_io import save_art  # noqa: E402  (lossless WebP)

RAW = f'{ROOT}/docs/art/gen/eki_in'
OUT = f'{ROOT}/assets/art/eki_in'

# Row by row, 4 x 4 - the order must match MOTIFS below and EkiInMotif in Dart.
MOTIFS = [
    ('sakura', 'a five-petal cherry blossom with a few small falling petals'),
    ('plum', 'a round five-petal plum blossom (ume) with a short bare branch'),
    ('wave', 'a curling ocean wave crest with spray, in the classic Japanese woodblock manner'),
    ('mountain', 'a tall snow-capped volcanic mountain with a few horizontal cloud bands'),
    ('bridge', 'an arched wooden Japanese bridge over water, side view'),
    ('pine', 'a windswept Japanese pine tree with layered cloud-like needle clusters'),
    ('ginkgo', 'two ginkgo leaves crossed'),
    ('river', 'a gently flowing river with reeds and a small boat'),
    ('pagoda', 'a five-storey temple pagoda, front view'),
    ('tower', 'a slender lattice steel broadcasting tower (generic, not a real landmark)'),
    ('train', 'the front view of a cute retro commuter train car with two round headlights, on rails'),
    ('lantern', 'a hanging paper lantern (chochin) with a little tassel'),
    ('crane', 'a flying crane bird with wide wings'),
    ('maple', 'a single maple leaf with its stem'),
    ('rice', 'three bending ears of rice'),
    ('hill', 'a hillside with stone steps climbing up between small houses and a torii-less shrine roof'),
]

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

A SHEET of 16 small emblems for hand-carved Japanese rubber seal stamps (like the motif inside a temple goshuin seal or a souvenir station stamp), arranged in an exact 4 x 4 grid, each emblem centred in its own equal square cell, with wide empty white gutters so no two emblems touch.
Style: bold, simple, carved-stamp / woodblock line art. PURE BLACK ink only on a PURE WHITE background, solid black shapes and thick confident lines (no thin hairlines, no grey, no gradients, no shading, no colour), slightly rough hand-carved edges. Each emblem fills about 75% of its cell and reads clearly when printed small (about 2 cm). No frames or circles around the emblems.
Row by row, left to right:
{items}
Square 1024x1024. ABSOLUTELY NO text, letters, kanji, numbers, logos or signatures anywhere.
"""


def motifs():
    os.makedirs(RAW, exist_ok=True)
    raw = f'{RAW}/motifs_raw.png'
    items = '\n'.join(f'{i + 1}. {d}' for i, (_, d) in enumerate(MOTIFS))
    prompt = PROMPT.format(out=raw, items=items)
    open(f'{RAW}/prompt_motifs.txt', 'w', encoding='utf8').write(prompt)
    subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                    '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900, shell=sys.platform == 'win32')
    print(raw if os.path.exists(raw) else 'FAILED')


def cut(size=192):
    os.makedirs(OUT, exist_ok=True)
    im = np.asarray(Image.open(f'{RAW}/motifs_raw.png').convert('L'), dtype=np.float32) / 255
    h, w = im.shape
    ink = np.clip((0.72 - im) / 0.5, 0, 1)  # black -> 1
    for i, (name, _) in enumerate(MOTIFS):
        r, c = divmod(i, 4)
        m = h // 60  # skip slivers of the neighbouring cells
        cell = ink[r * h // 4 + m:(r + 1) * h // 4 - m, c * w // 4 + m:(c + 1) * w // 4 - m]
        ys, xs = np.nonzero(cell > 0.5)
        if len(xs) == 0:
            print('empty', name)
            continue
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = cell[y0:y1, x0:x1]
        side = int(max(crop.shape) * 1.06)
        sq = np.zeros((side, side), np.float32)
        oy, ox = (side - crop.shape[0]) // 2, (side - crop.shape[1]) // 2
        sq[oy:oy + crop.shape[0], ox:ox + crop.shape[1]] = crop
        a = Image.fromarray((sq * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
        rgba = Image.merge('RGBA', [Image.new('L', a.size, 255)] * 3 + [a])
        save_art(rgba, f'{OUT}/motif_{name}.webp')
    print('cut', len(MOTIFS))


def _noise(n, scale, rng):
    """Smooth tileable value noise, n x n, in 0..1."""
    g = rng.random((scale, scale))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    # wrap for tiling: blend with a rolled copy
    a = np.asarray(img, np.float32) / 255
    return a


def paper(n=512):
    rng = np.random.default_rng(7)
    base = np.zeros((n, n), np.float32)
    for scale, amp in [(4, 0.5), (8, 0.25), (32, 0.15), (128, 0.10)]:
        g = rng.random((scale, scale))
        g = np.tile(g, (3, 3))
        big = Image.fromarray((g * 255).astype(np.uint8)).resize((n * 3, n * 3), Image.BICUBIC)
        base += amp * (np.asarray(big, np.float32)[n:2 * n, n:2 * n] / 255)
    base = (base - base.min()) / (base.max() - base.min())
    # Kozo fibres: long thin curved strokes, a little darker and a little lighter.
    fib = Image.new('L', (n * 3, n * 3), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(fib)
    for _ in range(260):
        x, y = rng.random() * n + n, rng.random() * n + n
        ang = rng.random() * np.pi * 2
        ln = 20 + rng.random() * 90
        pts = []
        for t in np.linspace(0, 1, 12):
            ang += (rng.random() - 0.5) * 0.35
            x += np.cos(ang) * ln / 12
            y += np.sin(ang) * ln / 12
            pts.append((x, y))
        d.line(pts, fill=int(90 + rng.random() * 120), width=1)
    fa = np.asarray(fib, np.float32) / 255
    # fold the 3x3 canvas back so fibres wrap around the tile edges
    f = np.zeros((n, n), np.float32)
    for oy in range(3):
        for ox in range(3):
            f = np.maximum(f, fa[oy * n:(oy + 1) * n, ox * n:(ox + 1) * n])
    f = np.asarray(Image.fromarray((f * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255
    # Grayscale washi: mid grey ~0.5 means "no change"; drawn with overlay-ish
    # alpha in Dart (multiply). Light paper with soft clouds and fibres.
    v = 0.93 + (base - 0.5) * 0.07 - f * 0.10
    rgb = np.stack([v * 0.985, v * 0.955, v * 0.89], -1)  # warm kinari
    save_art(Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)), f'{OUT}/washi.webp')

    # Gold leaf (kinpaku): square leaves ~ n/4 with seams, each a slightly
    # different tone, with crinkles.
    rng = np.random.default_rng(11)
    gold = np.zeros((n, n, 3), np.float32)
    leaf = n // 4
    crink = base.copy()
    for gy in range(4):
        for gx in range(4):
            t = 0.88 + rng.random() * 0.2
            ox = (gy % 2) * leaf // 2  # brick-like offset rows
            cols = (np.arange(n) - ox) % n
            mask = (cols >= gx * leaf) & (cols < (gx + 1) * leaf)
            gold[gy * leaf:(gy + 1) * leaf, mask] = [t * 0.93, t * 0.76, t * 0.36]
    gold *= (0.85 + crink[..., None] * 0.3)
    fine = rng.random((n, n)).astype(np.float32)
    fine = np.asarray(Image.fromarray((fine * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)),
                      np.float32) / 255
    gold *= (0.92 + fine[..., None] * 0.16)
    # seams: thin darker lines where the leaves overlap
    for gy in range(4):
        gold[gy * leaf:gy * leaf + 2] *= 0.82
        ox = (gy % 2) * leaf // 2
        for gx in range(4):
            x = (gx * leaf + ox) % n
            gold[gy * leaf:(gy + 1) * leaf, x:x + 2] *= 0.84
    save_art(Image.fromarray((np.clip(gold, 0, 1) * 255).astype(np.uint8)), f'{OUT}/gold_leaf.webp')
    print('paper ok')


FONT_URL = 'https://github.com/google/fonts/raw/main/ofl/yujiboku/YujiBoku-Regular.ttf'
OFL_URL = 'https://github.com/google/fonts/raw/main/ofl/yujiboku/OFL.txt'


def font():
    from fontTools import subset
    src = f'{RAW}/YujiBoku-Regular.ttf'
    os.makedirs(RAW, exist_ok=True)
    if not os.path.exists(src):
        urllib.request.urlretrieve(FONT_URL, src)
    urllib.request.urlretrieve(OFL_URL, f'{OUT}/YujiBoku-OFL.txt')
    chars = set()
    for city in glob.glob(f'{ROOT}/assets/cities/*/'):
        for f in ('stations.json', 'lines.json'):
            p = os.path.join(city, f)
            if os.path.exists(p):
                for item in json.load(open(p, encoding='utf8')):
                    chars.update(item['name'].get('ja', ''))
    # Kana (any future station), kanji numerals and the page's own words.
    chars.update(chr(c) for c in range(0x3041, 0x3097))
    chars.update(chr(c) for c in range(0x30A1, 0x30FD))
    chars.update('〇一二三四五六七八九十百元年月日令和平成乗車記念下印駅線全制覇完乗之御朱帳番目東京都')
    chars.update('（）()・ー-〜々ヶ 0123456789')
    text = ''.join(sorted(chars))
    out = f'{OUT}/yuji_boku_eki.ttf'
    subset.main([src, f'--text={text}', f'--output-file={out}', '--layout-features=vert,vrt2,palt',
                 '--no-hinting', '--desubroutinize'])
    print('font', len(chars), 'chars', os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'all'
    os.makedirs(OUT, exist_ok=True)
    if cmd in ('motifs', 'all'):
        motifs()
    if cmd in ('cut', 'all'):
        cut()
    if cmd in ('paper', 'all'):
        paper()
    if cmd in ('font', 'all'):
        font()
