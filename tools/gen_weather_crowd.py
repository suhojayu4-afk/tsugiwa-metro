"""The other crowd for every weather picture: each weather picture keeps
its station's usual crowd (Shinjuku and Shibuya busy, the others calm);
this draws the opposite one from it, so rainy rush hours look busy and
quiet snowy evenings look quiet.

  busy stations  (shinjuku, shibuya): + {scene}_{part}_{sky}_few.png
  other stations:                      + {scene}_{part}_{sky}_many.png

The app asks for '{sky}_few' / '{sky}_many' and falls back to the plain
weather picture, which is that station's usual crowd.

Source: docs/art/gen/weather/{scene}_{part}_{sky}_raw.png (from
tools/gen_weather_scenes.py). Output: docs/art/gen/weather/{name}_raw.png and
assets/art/weather/{name}.webp. Existing pictures are skipped.

  python tools/gen_weather_crowd.py [--jobs 3] [--only tokyo_day_rain_many ...]
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import LIGHT, MODEL, OUT, OUT_RAW, ROOT, SCENES, WEATHER  # noqa: E402

BUSY = {'shinjuku', 'shibuya'}

CHANGE = {
    'many': """The change: it is a BUSY time. Many more people wait on the platform: neat queues of four to six people behind the yellow tactile line at each door position, all the way along the platform, about thirty to forty people in total, a little floor still visible between the queues.
- The new people are dressed and equipped for the SAME weather as the people already in the picture (same kind of coats, the same share of open or closed umbrellas).""",
    'few': """The change: it is a QUIET time. Only FOUR to SIX people wait on the whole platform, spread out with lots of empty floor between them; keep the nearest one or two people at the front at the same size as now.
- They are dressed and equipped for the SAME weather as now (same kind of coats, umbrellas).""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first ({desc}, {weather}). Make the SAME picture with ONE change: the NUMBER of people waiting on the platform. Keep EVERYTHING else exactly the same: identical composition and camera (do not move, zoom or crop), the same weather, sky, light and ground (wet, snowy or dry exactly as now), the same buildings, the fence, the EMPTY double track in the centre with the rails in exactly the same place, the covered platform on the right with the yellow tactile paving, the roof, pillars and overhead wires.

{change}
- Everybody stands ON the platform, behind the yellow line, never on the tracks. Sizes follow the perspective: smaller further away.

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The tracks in the centre stay EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""

WEATHER_WORDS = {
    'umbrella': 'rain is expected: dark clouds, closed umbrellas, dry ground',
    'rain': 'it is raining: wet floor, some open umbrellas',
    'snow': 'a snowy day: snow on roofs and trees, winter coats',
    'winter': 'a clear cold winter day: thick coats, bare trees',
    'snowsoon': 'snow is expected: pale snow clouds, winter coats, dry ground',
}


def job(name, src, scene, part, sky, grade):
    raw = f'{OUT_RAW}/{name}_raw.png'
    out = f'{OUT}/{name}.webp'
    if not os.path.exists(src):
        return f'NO SOURCE {name}'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=src, desc=SCENES[scene], weather=WEATHER_WORDS[sky],
                               change=CHANGE[grade])
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
        for p in glob.glob(f'{OUT}/{name}_preview.png'):
            shutil.move(p, f'{OUT_RAW}/previews/{os.path.basename(p)}')
    return f'ok {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(f'{OUT_RAW}/previews', exist_ok=True)
    todo = []
    for sky in WEATHER:
        if sky not in WEATHER_WORDS:
            continue  # e.g. 'closed': nobody there
        for scene in SCENES:
            grade = 'few' if scene in BUSY else 'many'
            for part in LIGHT:
                name = f'{scene}_{part}_{sky}_{grade}'
                if a.only and name not in a.only:
                    continue
                src = f'{OUT_RAW}/{scene}_{part}_{sky}_raw.png'
                todo.append((name, src, scene, part, sky, grade))
    with ThreadPoolExecutor(a.jobs) as pool:
        for result in pool.map(lambda t: job(*t), todo):
            print(result, flush=True)


if __name__ == '__main__':
    main()
