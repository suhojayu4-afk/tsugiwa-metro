"""More scenery for the trip view (lib/features/trip/widgets/layered_train_view.dart):
themed sets of the two side-view layers, drawn by GPT image generation
(codex exec) in the style of the station pictures, like
tools/gen_side_train_gpt.py made the Tokyo set.

Per theme:
  {theme}_far_{part}   sky + distant scenery, a full picture that tiles sideways
  {theme}_mid_{part}   nearer scenery on flat magenta (keyed out); evening and
                       night are redrawn from the day one, so they match it

Raw pictures go to docs/art/gen/side_train/{name}_raw.png (existing ones are
skipped, so the script can be re-run after a stop). Then
tools/cut_side_train.py {name ...} makes assets/art/side_{name}.webp.

  python tools/gen_side_scenery_gpt.py [--jobs 3] [--only seaside ...]
"""
import argparse
import os
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_side_train_gpt import HEAD, LIGHT, RAW, ROOT, RULES, SIDE, SKY, STYLE, TILE, job  # noqa: E402

# Each theme: the far layer (bottom 40 percent of a 60 percent sky) and the
# near layer (a row along the bottom edge). Generic places, no real landmark.
THEMES = {
    'seaside': (
        """the OPEN SEA seen from a coastal railway: the calm sea fills the bottom 30 percent with sparkling pixel
waves and a few small fishing boats; on the horizon a far hilly coastline and two small islands, a white lighthouse
on a distant cape; the land is only a thin far band, the tallest hill reaching 40 percent of the picture height""",
        """a small COASTAL FISHING TOWN right beside the line: low wooden houses with dark tiled roofs, a fish
warehouse with a corrugated roof, wind-bent black PINE trees, drying fishing nets on poles, a stack of orange buoys,
a stone sea wall, patches of sandy dune grass, a small red shrine gate (torii); the tallest thing reaches 40 percent
of the picture height""",
    ),
    'country': (
        """the Japanese COUNTRYSIDE (satoyama): layered rolling green hills and a far blue mountain ridge, green rice
paddies stepping up the lower slopes, a few tiny farmhouses with tiled roofs and a small forest of cedar on the
hills; the highest ridge reaches 45 percent of the picture height""",
        """a farming village right beside the line: old farmhouses with big tiled and thatched roofs, a wooden barn,
a persimmon tree with orange fruit, a bamboo grove, a vegetable field with rows of greens, a small stone Jizo shrine
with a red bib, wooden utility poles with wires, a little stream with a stone bridge; the tallest thing reaches 45
percent of the picture height""",
    ),
    'mountain': (
        """a deep MOUNTAIN valley: steep forested mountains in several hazy layers, the farther ones bluer
(aerial perspective), wisps of mist in the folds, a thin white waterfall on one far slope; the highest peak reaches
55 percent of the picture height""",
        """a mountain GORGE beside the line: a dense edge of tall cedar and maple trees, mossy rocks, a clear
mountain river with white rapids along the bottom, a small wooden hot-spring inn with a tiled roof and steam rising,
a red-painted steel railing; the tallest tree reaches 50 percent of the picture height""",
    ),
    'oldtown': (
        """an OLD CASTLE TOWN: a sea of dark grey tiled roofs, a white-walled castle keep with curved roofs on a
wooded hill (a generic castle, not a real one), a five-storey wooden pagoda, temple halls among trees, distant green
hills behind; the castle reaches 45 percent of the picture height""",
        """an old merchant street beside the line: rows of two-storey wooden machiya townhouses with dark lattice
fronts and tiled roofs, white earthen storehouses (kura) with black trim, a temple gate, stone lanterns, a willow
tree by a narrow canal, paper lanterns WITHOUT writing; the tallest thing reaches 40 percent of the picture height""",
    ),
    'river': (
        """a WIDE RIVER the line runs along: the river fills the bottom 25 percent with gentle pixel ripples, a long
steel truss bridge far away crossing it, low-rise riverside town on the far bank and soft green hills behind; the
tallest thing reaches 40 percent of the picture height""",
        """a riverside EMBANKMENT beside the line: a grassy levee with a row of big cherry trees in full PINK
blossom, a few benches, a small boathouse with rowing boats, reeds along the water at the bottom, a lamp post or two;
the tallest tree reaches 45 percent of the picture height""",
    ),
    'suburb': (
        """the SUBURBS of a Japanese city: rows of distant mid-rise apartment blocks (danchi), a water tower, a
shopping mall roof, a far rail viaduct, low hills behind; the tallest block reaches 40 percent of the picture
height""",
        """a quiet SUBURBAN street beside the line: two-storey detached houses with gardens and small cars in the
drive, a small park with a slide and swings, a convenience store and vending machines WITHOUT any writing, a school
with a sports ground fence, hedges and street trees, utility poles with wires; the tallest thing reaches 40 percent
of the picture height""",
    ),
    'snow': (
        """a SNOWY northern landscape in deep winter: white snow-covered mountains and hills in hazy layers, dark
fir forests dusted with snow, a few tiny farmhouses with snow-laden roofs and thin chimney smoke; the highest peak
reaches 50 percent of the picture height""",
        """a snowed-in village beside the line: houses with steep roofs under thick snow, icicles, snow walls along
a path, birch and fir trees heavy with snow, a snow-covered small shrine, a red post box, snow piled on fences; the
tallest thing reaches 40 percent of the picture height""",
    ),
    'harbor': (
        """a busy PORT: the harbour water fills the bottom 25 percent, big red-and-white container cranes, a
ferry and a cargo ship at the quays, warehouses, a distant suspension bridge and the city's towers behind; the
tallest crane reaches 50 percent of the picture height""",
        """the waterfront beside the line: brick warehouses, stacked colourful shipping containers, a small
lighthouse at the end of a pier, bollards and coiled ropes, palm-like trees in planters, seagulls; the tallest thing
reaches 40 percent of the picture height""",
    ),
    'flower': (
        """gentle FLOWER HILLS: rolling hills striped with fields of lavender, yellow rapeseed and red poppies,
a lone big tree on a ridge, a small white farmhouse and a windmill, far blue mountains; the highest hill reaches 40
percent of the picture height""",
        """flower fields right beside the line: rows of sunflowers and cosmos, a wooden fence, beehives, a little
red barn, a farm truck, butterflies; the tallest thing (the sunflowers and the barn) reaches 35 percent of the
picture height""",
    ),
}

FAR = HEAD + STYLE + """

Draw a DISTANT PANORAMA: {what}. """ + SIDE + """
- Sky: {sky}.
- The sky fills the top 60 percent of the picture; the scenery fills the bottom 40 percent and stands on the very
bottom edge. No rails, no people, no vehicles on land.
- """ + TILE + """
""" + RULES

MID_DAY = HEAD + STYLE + """

Draw the NEAR SCENERY seen from a train passing {what}. """ + SIDE + """
- Plain flat solid MAGENTA background (#FF00FF) everywhere above and between the things: NO sky, no clouds, no
distant scenery (those are a separate layer).
- One continuous row along the bottom edge; varied heights, many lower than the tallest.
- Along the very bottom edge, a continuous strip (about 6 percent of the height) of grass and bushes in front of
everything, all the way across.
- DAYTIME lighting.
- Leave magenta gaps between some things so the sky behind shows through.
- """ + TILE + """ At BOTH the left and right edges there is only the low strip and a tree or bush.
- Crisp edges against the magenta: no glow, no anti-aliased fringe, no shadow on the magenta.
""" + RULES

MID_LATER = HEAD + """Look at {ROOT}/docs/art/gen/side_train/{theme}_mid_day_raw.png first (the near scenery of a
side-scrolling game, on a flat MAGENTA background) and at {ROOT}/docs/art/gen/stations/shinjuku_{part}_raw.png (the
wanted {part} lighting).

Make the SAME picture with ONE change: it is {light}. Keep EVERYTHING else exactly the same: identical composition,
the same things in exactly the same places and sizes, the same flat side view, and the same plain flat solid MAGENTA
background (#FF00FF) everywhere around them (do NOT paint a sky; the magenta stays pure #FF00FF).
- Crisp edges against the magenta: no glow or halo spilling onto the magenta.
""" + RULES


def prompts(themes):
    p = {}
    for t in themes:
        far, mid = THEMES[t]
        for part, sky in SKY.items():
            p[f'{t}_far_{part}'] = FAR.format(what=far, sky=sky, ROOT=ROOT, out='{out}')
        p[f'{t}_mid_day'] = MID_DAY.format(what=mid, ROOT=ROOT, out='{out}')
        for part, light in LIGHT.items():
            p[f'{t}_mid_{part}'] = MID_LATER.format(theme=t, part=part, light=light, ROOT=ROOT, out='{out}')
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*', help='themes')
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    all_p = prompts(a.only or THEMES)
    later = [n for n in all_p if n.endswith(('_mid_evening', '_mid_night'))]
    first = [n for n in all_p if n not in later]
    for batch in (first, later):
        with ThreadPoolExecutor(a.jobs) as pool:
            for line in pool.map(lambda n: job(n, all_p[n]), batch):
                print(line, flush=True)


if __name__ == '__main__':
    main()
