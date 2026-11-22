"""Special sticker sets for MY: drawn larger and richer than the first twelve
(160 px, a gold foil rim and a glint), six to a sheet, by GPT image
generation; each sheet is cut into its stickers.

  python tools/gen_stickers_special.py [set ...]
  -> docs/art/gen/stickers/<set>_raw.png, assets/art/stickers/<name>.png
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace(os.sep, '/')
GEN = f'{ROOT}/docs/art/gen/stickers'
OUT = f'{ROOT}/assets/art/stickers'
SIZE = 160

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {ref} first (a sheet of small pixel-art stickers on magenta): keep that cute Japanese pixel-art sticker feeling, but make these PREMIUM COLLECTOR stickers: bigger, with much more pixel detail and shading, each one with a thick white die-cut sticker border and around that a thin shiny GOLD FOIL rim, and one or two small white four-point sparkles glinting on it.

Draw a sticker sheet of exactly SIX stickers in a 3 columns x 2 rows grid, each sticker centred in its own cell with clear magenta space all around it (stickers must not touch each other or the image edges). Theme: {theme}. In reading order:
{items}
- Detailed 16-bit era pixel art, crisp square pixels, rich hue-shifted shading, no blur.
- Background: one flat solid pure magenta colour (#FF00FF) everywhere between the stickers; no shadows on the background.
- Landscape 1536x1024.
- ABSOLUTELY NO text, letters, numbers, kanji or logos anywhere.
"""

SETS = {
    'ekiben': ('station lunch boxes and travel snacks (ekiben)', [
        ('ekiben', 'an open wooden station lunch box with rice, a pickled plum, grilled salmon, rolled omelette and vegetables'),
        ('tea', 'a small old-fashioned travel tea bottle with its cup-lid, steam rising'),
        ('mikan', 'three mandarin oranges in a red net bag'),
        ('dango', 'a skewer of three-colour dango (pink, white, green) on a small plate'),
        ('senbei', 'a round soy-glazed rice cracker with a square of seaweed, a bite taken out'),
        ('icecream', 'a hard station ice-cream cup with a little wooden spoon and frost on it'),
    ]),
    'matsuri': ('a Japanese summer festival with friendly folklore creatures', [
        ('oni', 'a cheerful red oni (ogre) face mask with two golden horns and small fangs'),
        ('kitsune', 'a white fox festival mask with red markings and gold details'),
        ('chochin', 'a glowing red paper lantern with a wave pattern, lit from inside'),
        ('taiko', 'a taiko drum on its stand with two drumsticks crossed above it'),
        ('hanabi', 'a firework bursting in gold, pink and blue over a tiny night sky circle'),
        ('uchiwa', 'a round paper fan with a goldfish painted on it'),
    ]),
    'sanin': ('the San-in coast of Japan (Tottori): sea, sand and mountain', [
        ('camel', 'a camel standing on a golden sand dune under a blue sky'),
        ('nashi', 'a round pale-green Japanese pear, one slice cut beside it'),
        ('kani', 'a bright red snow crab with long legs'),
        ('daisen', 'a snow-capped mountain above green fields'),
        ('lighthouse', 'a white lighthouse on a rock with waves and a seagull'),
        ('onsen', 'a wooden hot-spring bucket with a folded towel and rising steam'),
    ]),
    'tetsudo': ('things a Japanese railway fan loves', [
        ('cap', "a station master's navy cap with a gold band and a plain gold badge"),
        ('signal', 'a railway signal with three lamps, the green one glowing'),
        ('gate', 'a classic ticket gate with a ticket puncher resting on it'),
        ('lantern', "a conductor's brass hand lantern glowing warm"),
        ('crossing', 'a railway crossing warning post with two red lamps and a yellow-black bar'),
        ('whistle', 'a silver whistle on a red cord with a small white glove'),
    ]),
}


def key(c):
    r, g, b = c[:3]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def alone(cell):
    """[cell] with only its biggest piece and what lies within a few pixels
    of it (its sparkles): a neighbour's edge that strayed into the cell goes."""
    import numpy as np
    from scipy import ndimage
    a = np.asarray(cell.getchannel('A')) > 0
    lab, n = ndimage.label(a)
    if n < 2:
        return cell
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    main = lab == (int(np.argmax(sizes)) + 1)
    near = ndimage.binary_dilation(main, iterations=24)
    keep = np.zeros_like(a)
    for i in range(1, n + 1):
        piece = lab == i
        if (piece & near).any():
            keep |= piece
    out = cell.copy()
    out.putalpha(Image.fromarray((keep * 255).astype('uint8')))
    return out


def cut(name):
    theme, items = SETS[name]
    im = Image.open(f'{GEN}/{name}_raw.png').convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if key(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    cw, ch = w / 3, h / 2
    for i, (sid, _) in enumerate(items):
        cell = im.crop((round((i % 3) * cw), round((i // 3) * ch), round((i % 3 + 1) * cw), round((i // 3 + 1) * ch)))
        cell = alone(cell)
        s = cell.crop(cell.getbbox())
        k = SIZE / max(s.size)
        # Box filter down to the sticker's own pixel grid, then hard edges.
        s = s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))), Image.BOX)
        sp = s.load()
        for y in range(s.height):
            for x in range(s.width):
                c = sp[x, y]
                sp[x, y] = (c[0], c[1], c[2], 255) if c[3] >= 128 else (0, 0, 0, 0)
        s.save(f'{OUT}/{sid}.png')
        print(name, sid, s.size, flush=True)


def job(name):
    theme, items = SETS[name]
    raw = f'{GEN}/{name}_raw.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, ref=f'{GEN}/stickers_raw.png', theme=theme,
                               items='\n'.join(f'{i + 1}. {d}.' for i, (_, d) in enumerate(items)))
        open(f'{GEN}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', 'gpt-6.2-sol', '-c', 'model_reasoning_effort=low', '-s',
                            'workspace-write', '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                           shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    if not os.path.exists(raw):
        return f'FAILED {name}'
    cut(name)
    return f'ok {name}'


if __name__ == '__main__':
    names = sys.argv[1:] or list(SETS)
    with ThreadPoolExecutor(4) as pool:
        for r in pool.map(job, names):
            print(r, flush=True)
