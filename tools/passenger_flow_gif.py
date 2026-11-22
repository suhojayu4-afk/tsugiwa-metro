"""Turns the frames of test/tools/render_passenger_flow.dart into review
pictures: per case a GIF (8 frames a second) and contact sheets (one frame
every half second, time in the corner), then removes the frames.

  python tools/passenger_flow_gif.py [--keep]
"""
import glob
import os
import shutil
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FPS = 8


def sheet(frames, path, cols=4, every=4, cell=384, per=24):
    picks = list(range(0, len(frames), every))
    for n in range(0, len(picks), per):
        part = picks[n:n + per]
        first = Image.open(frames[0])
        h = cell * first.height // first.width
        rows = (len(part) + cols - 1) // cols
        out = Image.new('RGB', (cols * cell, rows * h), (20, 20, 28))
        d = ImageDraw.Draw(out)
        for k, i in enumerate(part):
            im = Image.open(frames[i]).convert('RGB').resize((cell, h), Image.Resampling.NEAREST)
            x, y = (k % cols) * cell, (k // cols) * h
            out.paste(im, (x, y))
            d.rectangle((x, y, x + 40, y + 11), fill=(0, 0, 0))
            d.text((x + 2, y), f'{i / FPS:5.1f}s', fill=(255, 255, 0))
        out.save(f'{path}_sheet{n // per + 1}.png')


def main():
    keep = '--keep' in sys.argv
    for base in ('passenger_flow', 'underground'):
        for d in sorted(glob.glob(os.path.join(ROOT, 'docs', 'captures', base, '*', ''))):
            frames = sorted(glob.glob(os.path.join(d, '[0-9][0-9][0-9].png')))
            if not frames:
                continue
            name = d.rstrip('\\/')
            ims = [Image.open(f).convert('RGB') for f in frames]
            pal = ims[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
            gif = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in ims]
            gif[0].save(f'{name}.gif', save_all=True, append_images=gif[1:], duration=1000 // FPS, loop=0)
            sheet(frames, name)
            # Stills at full size: queueing, walking in, the next train near.
            for sec in (1, 16, 24.5):
                shutil.copy(frames[int(sec * FPS)], f'{name}_{sec}s.png')
            print(os.path.basename(name), len(frames), 'frames')
            if not keep:
                shutil.rmtree(d)


if __name__ == '__main__':
    main()
