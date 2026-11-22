"""MY station decorations (assets/my/catalog.json, slots platform and roof),
drawn by GPT image generation (codex exec) in the station pictures' style:
a few objects side by side on flat magenta per picture.

  docs/art/gen/decor/{sheet}_raw.png    (GPT)
  -> docs/art/gen/decor/cut/{id}.png    (one object each, magenta keyed out,
                                         still at GPT's size)

tools/place_decor.py then shrinks them to the scene's pixels and stands
them on the platform (assets/art/decor/{id}.webp).

  python tools/gen_decor_gpt.py [--only a b ...] [--jobs 3] [--cut-only]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import MODEL, ROOT  # noqa: E402
from gen_scene_events_gpt import key_out  # noqa: E402

RAW = f'{ROOT}/docs/art/gen/decor'
CUT = f'{RAW}/cut'

HEAD = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

"""

STYLE = (f'Look at this first: {ROOT}/docs/art/gen/bg_day_raw.png (a Japanese station platform drawn in a soft, detailed '
         '16-bit era pixel art style, almost no black outlines, hue-shifted shading: shadows towards violet, lights '
         'towards warm yellow). Draw in exactly that style.\n\n')

VIEW = """How every object is seen: as if it stood on that platform's floor against the RIGHT-hand wall, between the two nearest pillars on the right, seen by the same camera. That is a three-quarter view:
- the object's FRONT (the side facing the track) is turned towards the LEFT of the image and a little towards us, and takes about two thirds of the object's width;
- its end side that faces us is seen to the RIGHT of the front, narrower;
- the camera is at chest height: we see the top surface of anything lower than a person's chest;
- all vertical edges are exactly vertical; clear daylight coming from the upper left.
"""

RULES = """- EXACTLY {n} separate object(s) side by side in ONE horizontal row, in the order given, with wide empty magenta gaps between them (they must not touch or overlap). Each object is drawn large, about the same size on the page.
- Plain flat solid MAGENTA background (#FF00FF) everywhere: no floor, no wall, no shadow on the ground, no ground line, no people.
- Crisp square pixels, clean silhouettes, no anti-aliased blur at the edges, no outline glow, no magenta or pink tint on the objects (avoid pure magenta and hot pink in the objects themselves).
- All ORIGINAL generic designs: no real brand, no real company's design, no characters from anything.
- ABSOLUTELY NO text, letters, numbers, kanji, logos, pictograms or labels anywhere (signs, screens and papers are blank or show plain colour shapes only).
- Landscape 1536x1024.
"""

# sheet: (ids in order, 'view' or 'front', description)
SHEETS = {
    'a': (['vending', 'bench', 'clock'], 'view', """Draw THREE objects of a Japanese station platform:
1. A drinks vending machine: tall box, clean white body with a sky-blue top band and base, a big lit display window showing three rows of small colourful cans and bottles, a row of tiny buttons under each row, a small coin panel on the right of the front, a dark pickup flap at the bottom. Friendly and bright.
2. A station platform bench: four joined moulded plastic seats in soft pastel blue with low backrests, on a slim grey steel frame with two legs. Seen so that the row of seats runs along the wall (its long side is the FRONT).
3. A station clock on a pole: a slim dark-green cast-iron post with a little decorative base, and on top a round clock with a white face, plain tick marks (no numerals) and two black hands, in a dark-green rim; about one and a half times as tall as a person.
"""),
    'b': (['phone_clear', 'umbrella', 'bins'], 'view', """Draw THREE objects of a Japanese station platform:
1. A retro public telephone corner: a chunky pale-green push-button payphone (generic, plain keypad squares without numbers, a black handset on its left side with a coiled cord) standing on a slim steel pedestal with a small shelf, under a small rounded clear acrylic hood. About as tall as a person's shoulders.
2. An umbrella stand: a low steel-wire rack holding six closed umbrellas of different colours (red, navy, yellow, clear vinyl, green, pink) leaning in it, handles up. About hip height.
3. A set of three station rubbish/recycling bins joined in a row: brushed-steel boxes, each with a differently coloured top panel (blue, yellow, grey) and a different opening (round hole, round hole, wide slot). No icons, no labels. About hip to waist height; the row runs along the wall (its long side is the FRONT).
"""),
    # The phone of sheet b sat under a clear hood, which took the page's
    # magenta: drawn again with a solid one.
    'h': (['phone'], 'view', """Draw ONE object of a Japanese station platform, large:
1. A retro public telephone corner: a chunky pale-green push-button payphone (generic: a plain keypad of small square buttons without numbers, a black handset hanging on its left side with a coiled black cord, a coin slot, a small coin-return flap) standing on a cream-coloured steel pedestal cabinet with a small shelf. Around the phone a small OPAQUE cream-white metal hood (a three-sided box with a sloping roof, open at the front; no glass, nothing transparent). The whole thing is about as tall as a person's shoulders.
"""),
    'c': (['soba', 'kiosk'], 'view', """Draw TWO small buildings of a Japanese station platform, each about one and a half times as tall as a person and about as wide as it is tall:
1. A tiny stand-up noodle stall (tachigui soba): a compact dark-wood booth with a tiled little roof edge, a plain indigo-blue noren curtain with NO writing (just two plain white horizontal stripes) hanging over the serving opening, a wooden counter with two steaming bowls and a chopstick jar, warm light inside, a plain red paper lantern (blank) hanging at its corner, a soft puff of steam above.
2. A small station kiosk (newsstand): a compact box shop with a red-and-white striped awning, an open front full of neat shelves of tiny colourful snack boxes, drink bottles and folded papers (no writing), a small counter, warm light inside.
"""),
    'd': (['planter', 'board', 'catbed'], 'view', """Draw THREE objects of a Japanese station platform:
1. A long wooden flower planter box on short legs, full of blooming flowers: yellow and violet pansies, red tulips, white daisies and green leaves. Knee high; the box runs along the wall (its long side is the FRONT).
2. An old station message board (dengonban): a dark-green chalkboard in a plain wooden frame standing on two wooden legs, completely blank except two or three faint smudges of wiped chalk, a narrow chalk tray with two tiny pieces of chalk and a small eraser. As tall as a person's shoulders.
3. A station cat's bed: a round woven wicker basket with a red cushion, an orange-and-white tabby cat curled up asleep in it, a tiny navy stationmaster cap with a gold band lying beside the basket, and a small blue food bowl. Low on the ground (knee high at most).
"""),
    'e': (['kadomatsu', 'tanabata', 'xmastree'], 'view', """Draw THREE seasonal decorations for a Japanese station platform:
1. A PAIR of New Year kadomatsu standing side by side with a small gap: each has three diagonally cut green bamboo stalks of different heights, pine branches, a few red berries and a white-and-red paper ornament, in a straw-wrapped base tied with rope. Waist to chest high.
2. A Tanabata bamboo branch: a tall leafy green bamboo (sasa) standing in a simple wooden stand, hung with many small colourful BLANK paper strips (tanzaku, no writing) in pink, yellow, sky blue, green and white, paper chains and a few paper stars. One and a half times as tall as a person, leaning slightly.
3. A Christmas tree in a red pot: a full green fir tree with round red and gold baubles, tiny warm lights, a gold garland and a gold star on top, two small wrapped presents at its foot. A little taller than a person.
"""),
    'f': (['pumpkin', 'koinobori', 'furinstand'], 'view', """Draw THREE seasonal decorations for a Japanese station platform:
1. An autumn pumpkin display: a hay bale with three orange pumpkins of different sizes on and around it (one carved with a simple smiling jack-o'-lantern face, softly glowing inside), a small white ghost-shaped cloth ornament, a few maple leaves and one small purple pumpkin. Knee to hip high.
2. Children's Day koinobori: a slim pole in a small weighted stand, with a golden spinning pinwheel on top and three carp streamers flying from it towards the left, one under the other: black (largest), red, and blue (smallest), each with big round eyes and scale patterns. About one and a half times as tall as a person.
3. A wind-chime stand: a simple wooden frame (two posts and two cross bars) with eight small round glass wind chimes (furin) hanging from it in two rows, each glass painted with a different simple pattern (goldfish-red dots, blue waves, morning-glory violet, green leaves) and with a long BLANK paper strip hanging below in a soft colour. Shoulder high.
"""),
    'g': (['r_lantern', 'r_furin', 'r_tsurushi', 'r_fuji'], 'front', """Draw FOUR small hanging ornaments, each seen straight from the FRONT, each hanging from a short piece of cord at its top:
1. A round red Japanese paper lantern (chochin): a plump red paper globe with fine horizontal ribs, black top and bottom rings, softly glowing warm from inside, completely BLANK (no writing).
2. A glass wind chime (furin): a small clear round glass bell with a simple painted red goldfish and blue ripple, with a long pale-blue BLANK paper strip hanging under it.
3. A tsurushi-kazari strand: one red cord with five small plump cloth ornaments one under the other (a pink plum blossom, a little white rabbit, a red ball with gold thread, a green leaf, a yellow tassel at the bottom).
4. A hanging cluster of wisteria flowers (fuji): a long tapering bunch of small violet-and-lilac blossoms with a few green leaves at the top.
Each ornament is tall and narrow; draw them all the same height.
"""),
}


def prompt_for(sheet):
    ids, view, text = SHEETS[sheet]
    return (HEAD.format(out=f'{RAW}/{sheet}_raw.png') + STYLE + text + '\n' + (VIEW if view == 'view' else '')
            + '\nRules:\n' + RULES.format(n=len(ids)))


def generate(sheet):
    raw = f'{RAW}/{sheet}_raw.png'
    if os.path.exists(raw):
        return
    for _ in range(2):
        subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt_for(sheet).encode('utf8'), cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                       shell=sys.platform == 'win32')
        if os.path.exists(raw):
            break


def column_runs(im, gap=24):
    """Column ranges holding something, split at empty gaps of [gap] columns."""
    px = im.load()
    w, h = im.size
    cols = [sum(1 for y in range(0, h, 2) if px[x, y][3]) > 1 for x in range(w)]
    runs, start, empty = [], None, 0
    for x, on in enumerate(cols + [False] * (gap + 1)):
        if on:
            if start is None:
                start = x
            empty = 0
        elif start is not None:
            empty += 1
            if empty > gap:
                if x - empty - start > 30:
                    runs.append((start, x - empty + 1))
                start, empty = None, 0
    return runs


# Sheets whose objects stand too close to find the gaps: the columns where
# to cut between them (in the raw picture as it is now).
SPLITS = {'e': [490, 1047]}


def cut(sheet):
    ids = SHEETS[sheet][0]
    im = key_out(Image.open(f'{RAW}/{sheet}_raw.png').convert('RGBA'))
    runs = column_runs(im)
    if sheet in SPLITS:
        edges = [0] + SPLITS[sheet] + [im.width]
        runs = list(zip(edges, edges[1:]))
    if len(runs) != len(ids):
        # Too many pieces (a streamer flying apart from its pole): join the
        # closest neighbours until the count fits.
        while len(runs) > len(ids):
            gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
            i = gaps.index(min(gaps))
            runs[i:i + 2] = [(runs[i][0], runs[i + 1][1])]
        if len(runs) != len(ids):
            return f'{sheet}: found {len(runs)} objects, wanted {len(ids)}'
    os.makedirs(CUT, exist_ok=True)
    out = []
    for name, (l, r) in zip(ids, runs):
        part = im.crop((l, 0, r, im.height))
        part = part.crop(part.getbbox())
        part.save(f'{CUT}/{name}.png')
        out.append(f'{name} {part.size}')
    return f'{sheet}: ' + ', '.join(out)


def job(sheet, cut_only=False):
    if not cut_only:
        generate(sheet)
    if not os.path.exists(f'{RAW}/{sheet}_raw.png'):
        return f'FAILED {sheet}'
    return cut(sheet)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--cut-only', action='store_true')
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    sheets = a.only or list(SHEETS)
    with ThreadPoolExecutor(a.jobs) as ex:
        for line in ex.map(lambda s: job(s, a.cut_only), sheets):
            print(line, flush=True)


if __name__ == '__main__':
    main()
