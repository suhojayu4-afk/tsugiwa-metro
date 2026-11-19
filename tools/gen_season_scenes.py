"""Seasonal, limited-time station scenes for the MY駅 shop (期間限定), drawn by
GPT image generation (codex exec) from the standard station's original
high-resolution pictures, then snapped to pixel art (tools/pixelize.py,
384x192, 64 colours). The composition stays the standard one so the train,
the passengers and the vanishing point work unchanged.

  seasons: sakura (spring), hanabi (summer festival), xmas (Christmas)
  parts:   day, evening, night

Outputs: docs/art/gen/season/{season}_{part}_raw.png (GPT) and
assets/art/scenes_season/{season}_{part}.png (pixel art for the app).
Existing pictures are skipped, so the script can be re-run after a stop
(delete a picture to draw it again).

  python tools/gen_season_scenes.py [--jobs 3] [--only sakura_day ...]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
GEN = f'{ROOT}/docs/art/gen'
OUT_RAW = f'{GEN}/season'
OUT = f'{ROOT}/assets/art/scenes_season'
MODEL = 'gpt-6.2-sol'

SRC = {'day': 'bg_day_raw.png', 'evening': 'bg_evening2_raw.png', 'night': 'bg_night_raw.png'}

LIGHT = {
    'day': 'daytime, the same bright sky as the original',
    'evening': 'evening, keeping the warm sunset colours of the original',
    'night': 'night, keeping the night lighting of the original: dark navy sky, lit windows, platform lights',
}

SEASON = {
    'sakura': """The change: it is SPRING in Tokyo and the CHERRY TREES are in FULL BLOOM, {light}.
- Every tree beside the line (the green trees behind the fence on the left) becomes a big, fluffy cherry tree covered in soft pink sakura blossoms (pale pink and white, a little deeper pink in the shade). A few more cherry trees peek out between the buildings in the distance.
- Some pink petals lie scattered on the platform floor, along the fence and between the sleepers at the sides of the track; a few petals drift in the air (small, only a handful).
- The people on the platform wear light spring clothes (trench coats, cardigans, pastel colours); same people, same places, same sizes.
- A gentle, happy spring mood.""",
    'hanabi': {
        'day': """The change: it is the day of a SUMMER FESTIVAL (natsu matsuri) in Tokyo, a hot bright summer day.
- Deep blue summer sky with big white cumulus clouds; trees lush and green.
- Along the left side, beyond the fence and in front of the buildings, a festival street is being set up: rows of festival stalls (yatai) with colourful striped awnings, and strings of red and white paper lanterns (chochin) hanging across, not lit yet.
- Some of the people on the platform wear colourful YUKATA (summer kimono with obi sashes, flower and goldfish patterns) and carry round paper fans (uchiwa); the others wear light summer clothes. Same places, same sizes.
- A cheerful, lively "festival tonight" mood.""",
        'evening': """The change: it is the EVENING of a SUMMER FESTIVAL (natsu matsuri) in Tokyo, keeping the warm sunset colours of the original.
- Along the left side, beyond the fence and in front of the buildings, a festival street with rows of festival stalls (yatai) with colourful awnings, and many strings of red and white paper lanterns (chochin) hanging across, now glowing warm orange.
- Some of the people on the platform wear colourful YUKATA (summer kimono with obi sashes, flower patterns) and carry round paper fans (uchiwa); the others wear light summer clothes. Same places, same sizes.
- One or two small early fireworks bloom high in the sunset sky.
- A warm, excited "the fireworks are about to start" mood.""",
        'night': """The change: it is the NIGHT of a SUMMER FIREWORKS FESTIVAL (hanabi taikai) in Tokyo.
- The dark navy night sky above the city is filled with several BIG, bright, colourful FIREWORKS bursting (round chrysanthemum bursts in red, gold, pink, green and blue, with trailing sparks), lighting the sky and glowing on the buildings. Keep them in the sky above the city on the left and in the upper middle, not covering the track.
- Below the fence on the left, strings of glowing red paper lanterns (chochin) and festival stalls with warm lights.
- Some of the people on the platform wear colourful YUKATA and hold round paper fans (uchiwa), looking up at the fireworks; the others wear light summer clothes. Same places, same sizes.
- A magical summer night mood.""",
    },
    'xmas': """The change: it is CHRISTMAS time in Tokyo (December), {light}, with a winter illumination.
- A thin layer of fresh white snow on the roofs of the buildings, the platform roof edge, the tops of the fence and the trees. The platform floor and the track stay clear (no snow on the rails or on the platform floor).
- The trees behind the fence on the left are wrapped in thousands of tiny warm white and gold fairy lights (Tokyo winter illumination), and the buildings have a few lit decorations.
- A tall CHRISTMAS TREE stands on the left side beyond the fence, in front of the buildings (NOT on the track, NOT on the platform), decorated with coloured lights, red and gold baubles and a gold star on top.
- Garlands of green fir with red ribbons and small lights hang along the platform roof edge and around the pillars.
- The people on the platform wear warm winter coats, scarves and knit hats in red, green, navy and camel; same people, same places, same sizes.
- No falling snow. A cosy, sparkling Christmas mood.""",
}

EXTRA = {
    'xmas_day': '- In daylight the fairy lights still twinkle softly; the sky is a clear crisp winter blue.',
    'xmas_night': '- At night the illumination glows brightly: warm gold and white lights on the trees, the tree sparkling with colour.',
    # The first try had small fireworks cut off by the top edge.
    'hanabi_night': '- Make the fireworks BIG and fully inside the picture: two or three large round bursts in the open sky between the skyscrapers on the left and the platform roof, centred about a quarter of the way down from the top, none cut off by the top edge.',
    'sakura_night': '- At night the cherry blossoms are lit up from below (yozakura, light-up): glowing pale pink against the dark sky, a few paper lanterns among them.',
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first (a generic elevated Tokyo station: city buildings, trees behind a fence on the left, the track in the centre, a covered platform on the right). Make the SAME picture with ONE change. Keep EVERYTHING else exactly the same: identical composition and camera (do not move, zoom or crop), the same horizon and vanishing point, the same buildings, the fence, the EMPTY track in the centre with the rails in exactly the same place, the covered platform on the right with the yellow tactile paving, the roof, pillars and overhead wires, and the SAME people in the SAME places at the SAME sizes.

{change}

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The track in the centre stays EMPTY and clear: no train, nothing standing on the rails.
- ABSOLUTELY NO text, letters, numbers, logos or signboards (lanterns and stalls have no writing).
"""


def change(season, part):
    s = SEASON[season]
    text = s[part] if isinstance(s, dict) else s.format(light=LIGHT[part])
    extra = EXTRA.get(f'{season}_{part}')
    return text + ('\n' + extra if extra else '')


def job(season, part):
    name = f'{season}_{part}'
    raw = f'{OUT_RAW}/{name}_raw.png'
    out = f'{OUT}/{name}.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=f'{GEN}/{SRC[part]}', change=change(season, part))
        open(f'{OUT_RAW}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                            '--skip-git-repo-check', '-'], input=prompt.encode('utf8'),
                           cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=900, shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    if not os.path.exists(raw):
        return f'FAILED {name}'
    if not os.path.exists(out):
        subprocess.run([sys.executable, f'{ROOT}/tools/pixelize.py', raw, out,
                        '--width', '384', '--aspect', '2.0', '--colors', '64'],
                       stdout=subprocess.DEVNULL, check=True)
        # The 4x preview goes next to the GPT picture, not into the app's assets.
        os.replace(f'{OUT}/{name}_preview.png', f'{OUT_RAW}/{name}_preview.png')
    return f'ok {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(OUT_RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    todo = [(s, p) for s in SEASON for p in LIGHT if not a.only or f'{s}_{p}' in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for result in pool.map(lambda t: job(*t), todo):
            print(result, flush=True)


if __name__ == '__main__':
    main()
