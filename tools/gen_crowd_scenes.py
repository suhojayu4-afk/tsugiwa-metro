"""Crowd versions of every station scene, drawn by GPT image generation
(codex exec) from each scene's original picture, then snapped to pixel art.
The app picks one by the crowding estimate (EstimateCongestionSource).

  levels: relaxed, normal, crowded, packed
  scenes: standard + tokyo, shinjuku, shibuya, asakusa, ginza
  parts:  day, evening, night

Outputs: docs/art/gen/crowd/{scene}_{part}_{level}_raw.png (GPT) and
assets/art/crowd/{scene}_{part}_{level}.png. Existing pictures are skipped.

  python tools/gen_crowd_scenes.py [--jobs 3] [--only tokyo_day_packed ...]
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import LIGHT, MODEL, ROOT, SCENES, source  # noqa: E402

GEN = f'{ROOT}/docs/art/gen'
OUT_RAW = f'{GEN}/crowd'
OUT = f'{ROOT}/assets/art/crowd'

CROWD = {
    'relaxed': """The change: the platform is QUIET, {light}.
- Only TWO or THREE people wait on the whole platform, spread far apart (one near the front at the same size as in the original, one or two small ones further back). Lots of empty platform floor is visible.""",
    'normal': """The change: an ORDINARY, calm amount of people, {light}.
- About EIGHT to TWELVE people wait along the platform in small groups of one to three, with clear empty floor between the groups. The people in front are the same size as in the original.""",
    'crowded': """The change: the platform is BUSY, {light}.
- Neat queues of three to five people stand behind the yellow tactile line at each door position, all the way along the platform, about thirty people in total. Some empty floor is still visible between the queues. The people in front are the same size as in the original.""",
    'packed': """The change: RUSH HOUR, the platform is PACKED, {light}.
- The whole platform is full of commuters standing shoulder to shoulder from the front to the far end, in long dense queues; almost no floor is visible behind the yellow line. Office workers in suits, students, people looking at phones. The people in front are the same size as in the original.""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first ({desc}). Make the SAME picture with ONE change: the NUMBER of people waiting on the platform. Keep EVERYTHING else exactly the same: identical composition and camera (do not move, zoom or crop), the same sky and light, the same horizon, the same buildings, the fence, the EMPTY double track in the centre with the rails in exactly the same place, the covered platform on the right with the yellow tactile paving, the roof, pillars and overhead wires.

{change}
- Everybody stands ON the platform, behind the yellow line, never on the tracks. Sizes follow the perspective: smaller further away.
- The same everyday clothes as the people in the original.

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The tracks in the centre stay EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""


def job(name, scene, part, level):
    raw = f'{OUT_RAW}/{name}_raw.png'
    out = f'{OUT}/{name}.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=source(scene, part), desc=SCENES[scene],
                               change=CROWD[level].format(light=LIGHT[part]))
        open(f'{OUT_RAW}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', MODEL, '-s', 'workspace-write',
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
        # pixelize.py leaves a preview next to the output: keep it out of the app.
        for p in glob.glob(f'{OUT}/{name}_preview.png'):
            shutil.move(p, f'{OUT_RAW}/previews/{os.path.basename(p)}')
    return f'ok {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(f'{OUT_RAW}/previews', exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    todo = []
    # Tokyo first: it is the one shown first for review.
    for scene in ['tokyo'] + [s for s in SCENES if s != 'tokyo']:
        for part in LIGHT:
            for level in CROWD:
                name = f'{scene}_{part}_{level}'
                if a.only and name not in a.only:
                    continue
                todo.append((name, scene, part, level))
    with ThreadPoolExecutor(a.jobs) as pool:
        for result in pool.map(lambda t: job(*t), todo):
            print(result, flush=True)


if __name__ == '__main__':
    main()
