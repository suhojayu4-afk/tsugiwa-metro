"""Pack the frames of test/tools/render_tottori.dart into GIFs
(docs/captures/tottori/gif/<case>.gif).

  python tools/tottori/make_gifs.py
"""
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GIF = os.path.join(ROOT, 'docs', 'captures', 'tottori', 'gif')

for d in sorted(glob.glob(os.path.join(GIF, '*'))):
    if not os.path.isdir(d):
        continue
    files = sorted(glob.glob(os.path.join(d, '*.png')))
    if not files:
        continue
    frames = [Image.open(f).convert('RGB') for f in files]
    frames = [f.resize((f.width // 2 * 3 // 2, f.height // 2 * 3 // 2), Image.NEAREST) for f in frames]
    pal = [f.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    durs = [80] * len(pal)
    durs[40] = 600            # the train at rest after pulling in
    durs[-1] = 900
    out = d + '.gif'
    pal[0].save(out, save_all=True, append_images=pal[1:], duration=durs, loop=0, optimize=True)
    for f in files:
        os.remove(f)
    os.rmdir(d)
    print(os.path.basename(out), len(pal), 'frames', round(os.path.getsize(out) / 1e6, 1), 'MB')
