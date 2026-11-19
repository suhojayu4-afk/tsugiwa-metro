"""Art for the side-view train on the trip screen
(lib/features/trip/widgets/side_train_view.dart), drawn by GPT image
generation (codex exec), in the style of the station pictures.

  far_{part}     sky + distant skyline, a full picture that tiles sideways
  mid_{part}     nearer buildings and trees on flat magenta (keyed out)
  tunnel         subway tunnel wall that tiles sideways
  train          a leading car (cab on the right) above a middle car, on magenta
  mast           one overhead-wire mast with its arm, on magenta
  platform       open-air platform canopy, pillars and benches, on magenta
  platform_ug    underground platform wall, a full picture

Raw pictures go to docs/art/gen/side_train/{name}_raw.png; existing ones are
skipped, so the script can be re-run after a stop. mid_evening and mid_night
are redrawn from mid_day, so they are made after it.
Then run tools/cut_side_train.py to make assets/art/side_*.png.

  python tools/gen_side_train_gpt.py [--jobs 3] [--only far_day ...]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
RAW = f'{ROOT}/docs/art/gen/side_train'
MODEL = 'gpt-6.2-sol'

HEAD = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

"""

STYLE = """Look at these first: {ROOT}/docs/art/gen/stations/shinjuku_evening_raw.png and {ROOT}/docs/art/gen/stations/tokyo_day_raw.png (Tokyo station platforms in a detailed 16-bit era pixel art style: crisp square pixels, almost no black outlines, hue-shifted shading, skyscrapers with many small lit windows, soft pixel clouds, round leafy trees). Use EXACTLY that style, the same pixel size and the same palette feel."""

SIDE = """It is a background layer for a SIDE-SCROLLING game: a FLAT SIDE VIEW, looking straight at the scenery from a train window. NO perspective, NO vanishing point, NO road or rails going into the distance; every building is seen straight from the front."""

TILE = """It must TILE HORIZONTALLY without a seam: the picture is repeated side by side endlessly, so the LEFT edge must continue exactly into the RIGHT edge (same sky colours at the same heights at both edges, and no building cut by the left or right edge)."""

RULES = """- Landscape 1536x1024.
- ABSOLUTELY NO text, letters, numbers, logos or signboards with writing."""

SKY = {
    'day': 'a bright clear DAYTIME sky: blue at the top fading to pale blue near the horizon, a few soft white pixel clouds; windows reflect the sky (no lit windows)',
    'evening': 'a SUNSET sky exactly like the Shinjuku evening picture: purple at the top, then pink and orange clouds, glowing golden near the horizon; a low setting sun in the middle of the picture (not near the edges); many windows already lit warm yellow, buildings lit pink-orange on one side',
    'night': 'a deep navy NIGHT sky with small twinkling stars and a crescent moon (in the middle, not near the edges); the buildings are dark blue-purple silhouettes with MANY warm lit windows, red aviation lights blinking on the tallest towers, a soft city glow along the horizon',
}

FAR = HEAD + STYLE + """

Draw a DISTANT TOKYO CITY SKYLINE PANORAMA. """ + SIDE + """
- Sky: {sky}.
- The sky fills the top 60 percent of the picture. The skyline fills the bottom 40 percent: a dense, varied row of far-away skyscrapers, office towers, a few distinctive towers (a red-and-white lattice radio tower, a tower with a rounded top), mid-rise blocks; the tallest only reach up to 45 percent of the picture height from the bottom. The buildings are a bit hazy and bluish from distance (aerial perspective), but still detailed with rows of tiny windows.
- The buildings stand on the very bottom edge of the picture: no ground, no trees, no streets, no rails, no people, no vehicles.
- """ + TILE + """
""" + RULES

MID_DAY = HEAD + STYLE + """

Draw the NEAR SCENERY seen from a commuter train passing a Tokyo neighbourhood. """ + SIDE + """
- Plain flat solid MAGENTA background (#FF00FF) everywhere above and between the buildings: NO sky, no clouds, no distant skyline (those are a separate layer).
- One continuous row along the bottom edge: 3-6 storey apartment blocks with balconies and laundry, small shops with awnings, a few older houses with dark tiled roofs, round leafy trees and tall cedars between them, utility poles with wires, a small shrine gate (torii), air-conditioner units, water tanks on roofs. Varied heights; the tallest building reaches only 45 percent of the picture height from the bottom; many are lower.
- Along the very bottom edge, a continuous strip (about 6 percent of the height) of green hedges and bushes in front of everything, all the way across.
- DAYTIME lighting, windows reflect a blue sky.
- Leave a little magenta gap between some buildings so the sky behind shows through.
- """ + TILE + """ At BOTH the left and right edges there is only the low hedge strip and a tree (no building touching the edge).
- Crisp edges against the magenta: no glow, no anti-aliased fringe, no shadow on the magenta.
""" + RULES

MID_LATER = HEAD + """Look at {ROOT}/docs/art/gen/side_train/mid_day_raw.png first (the near scenery of a side-scrolling game, on a flat MAGENTA background) and at {ROOT}/docs/art/gen/stations/shinjuku_{part}_raw.png (the wanted {part} lighting).

Make the SAME picture with ONE change: it is {light}. Keep EVERYTHING else exactly the same: identical composition, the same buildings, trees, poles and hedges in exactly the same places and sizes, the same flat side view, and the same plain flat solid MAGENTA background (#FF00FF) everywhere around them (do NOT paint a sky; the magenta stays pure #FF00FF).
- Crisp edges against the magenta: no glow or halo spilling onto the magenta.
""" + RULES

LIGHT = {
    'evening': 'SUNSET evening: the buildings lit warm pink-orange from the low sun on one side and purple in the shade, about half of the windows lit warm yellow, shop awnings glowing',
    'night': 'NIGHT: the buildings dark blue-purple, MANY windows lit warm yellow, some balconies and shop fronts lit, a few street lamps glowing, trees dark blue-green',
}

TUNNEL = HEAD + STYLE + """

Draw the WALL OF A TOKYO SUBWAY TUNNEL, seen from the window of a passing train. """ + SIDE + """
- The picture is filled with the tunnel wall facing the camera: dark grey concrete segment rings with vertical joints at regular intervals, bolt pockets, damp stains; along the upper part, bundles of black and dark red cables held on steel hangers, a thicker pipe; small caged wall lamps at intervals casting a warm pool of light on the concrete; a small green emergency exit lamp (just a green glowing box with a white running-man pictogram, no text); a little signal lamp. The top of the picture fades into the dark curved ceiling, the bottom into the dark track bed (no rails visible).
- Dim, moody underground lighting: mostly dark blue-grey, with the warm lamp light.
- """ + TILE + """
""" + RULES

TRAIN = HEAD + STYLE + """

Draw TWO cars of a Tokyo Metro commuter train for a SIDE-SCROLLING game, seen EXACTLY from the side (flat, no perspective), on a plain flat solid MAGENTA background (#FF00FF) everywhere around them.
- TOP: the LEADING car, driver's cab at the RIGHT end (a gently sloped front with a large front window and a headlight), facing right. BOTTOM: a MIDDLE car of the same train, both ends flat with a gangway connection, so many middle cars can be coupled in a row.
- Both cars the SAME length, height and scale, each about 90 percent of the picture width, one above the other with magenta space between them.
- Brushed SILVER stainless-steel body with subtle hue-shifted shading, four pairs of sliding doors with small windows, wide passenger windows between them (dark blue-grey glass with sky reflections, a few seated passengers' silhouettes), a roof with air-conditioner units and a pantograph on the middle car, grey bogies with wheels under the body.
- ONE line-colour band runs along the whole body just below the windows, and a thinner one above the windows: paint BOTH bands in pure bright GREEN (#00FF00), flat, so they can be recoloured. No other green anywhere.
- Crisp square pixels, chunky pixel art (the car about 140 big pixels long), no anti-aliased blur at the edges, no shadow or rails under the cars.
""" + RULES

MAST = HEAD + STYLE + """

Draw ONE overhead-wire MAST of a Japanese railway (a catenary pole) for a SIDE-SCROLLING game, seen exactly from the side, on a plain flat solid MAGENTA background (#FF00FF) everywhere around it.
- A tall grey steel H-beam or lattice pole standing straight up, about 85 percent of the picture height, its foot on the bottom edge, in the middle of the picture; near the top a horizontal cantilever arm reaching to the RIGHT with brown porcelain insulators and a short hanger dropping down to where the contact wire would be (the wires themselves are NOT drawn).
- Hue-shifted shading, crisp square pixels, chunky pixel art, no anti-aliased blur at the edges, nothing else in the picture.
""" + RULES

PLATFORM = HEAD + STYLE + """

Draw the far side of an OPEN-AIR Tokyo station PLATFORM, seen from a train stopped at it, for a SIDE-SCROLLING game. """ + SIDE + """
- Plain flat solid MAGENTA background (#FF00FF) for the sky and everywhere above the canopy roof and in the gaps (the city behind is a separate layer).
- A long flat canopy roof across the whole width at the top (about 15 percent of the height, its underside with a row of white fluorescent lights), held by slim cream-painted steel pillars at regular intervals; under it, on the platform: a row of benches, a drinks vending machine (no writing), a rubbish bin, a hanging station-name board left completely BLANK (white with a coloured band, no text), a low back fence/wall, a few potted plants. The platform floor is a flat grey strip along the bottom edge (about 8 percent of the height).
- No people. Daytime lighting.
- """ + TILE + """
""" + RULES

PLATFORM_UG = HEAD + STYLE + """

Draw the far wall of an UNDERGROUND Tokyo subway station PLATFORM, seen from a train stopped at it, for a SIDE-SCROLLING game. """ + SIDE + """
- The whole picture: a clean cream-white tiled wall with a horizontal coloured band, square pillars at regular intervals clad in tiles, a bright ceiling with long fluorescent light strips along the top, framed posters on the wall showing only pictures (landscapes, a can of drink, abstract shapes; NO writing), a bench and a vending machine against the wall, a station-name board left completely BLANK (white with a coloured band, no text). The platform floor is a flat grey strip along the bottom edge (about 8 percent of the height).
- No people. Bright, clean artificial light.
- """ + TILE + """
""" + RULES


def prompts():
    p = {}
    for part, sky in SKY.items():
        p[f'far_{part}'] = FAR.format(sky=sky, ROOT=ROOT, out='{out}')
    p['mid_day'] = MID_DAY.format(ROOT=ROOT, out='{out}')
    for part, light in LIGHT.items():
        p[f'mid_{part}'] = MID_LATER.format(ROOT=ROOT, part=part, light=light, out='{out}')
    p['tunnel'] = TUNNEL.format(ROOT=ROOT, out='{out}')
    p['train'] = TRAIN.format(ROOT=ROOT, out='{out}')
    p['mast'] = MAST.format(ROOT=ROOT, out='{out}')
    p['platform'] = PLATFORM.format(ROOT=ROOT, out='{out}')
    p['platform_ug'] = PLATFORM_UG.format(ROOT=ROOT, out='{out}')
    return p


def job(name, prompt):
    raw = f'{RAW}/{name}_raw.png'
    if not os.path.exists(raw):
        prompt = prompt.format(out=raw)
        open(f'{RAW}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                            '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                           shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    return f'{"ok" if os.path.exists(raw) else "FAILED"} {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    all_p = prompts()
    names = [n for n in all_p if not a.only or n in a.only]
    # mid_evening / mid_night are redrawn from mid_day, so they go last.
    later = [n for n in names if n in ('mid_evening', 'mid_night')]
    first = [n for n in names if n not in later]
    for batch in (first, later):
        with ThreadPoolExecutor(a.jobs) as pool:
            for line in pool.map(lambda n: job(n, all_p[n]), batch):
                print(line, flush=True)


if __name__ == '__main__':
    main()
