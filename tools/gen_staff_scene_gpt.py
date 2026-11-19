"""Station attendant scene drawn whole by GPT (trial: Tokyo, day): the same
station picture with only the attendant added, six moments of his walk —
far down the platform edge, nearer, on the yellow line, 指差確認 towards the
arriving train, then walking back (seen from behind), far again.

Each frame is redrawn from the station's original picture; afterwards
tools/cut_staff_scene.py keeps only what changed (the attendant and his
shadow) so the background never flickers.

  docs/art/gen/staff_scene/{scene}_{part}_{n}_raw.png

  python tools/gen_staff_scene_gpt.py [--scene tokyo] [--part day] [--jobs 3]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import MODEL, ROOT  # noqa: E402

RAW = f'{ROOT}/docs/art/gen/staff_scene'

# Where he is (in the 1536x1024 picture) and what he does, frame by frame.
FRAMES = [
    'far away down the platform, standing on the narrow strip between the platform edge and the yellow tactile '
    'line, about 300 px left of the picture centre line of the platform roof pillars, very small (about 70 px tall), '
    'walking TOWARDS the viewer (three-quarter front view)',
    'half way up the platform on the same strip between the edge and the yellow line, about 150 px tall, walking '
    'TOWARDS the viewer (three-quarter front view), mid stride',
    'near the viewer, standing ON the yellow tactile line close to the platform edge, about 260 px tall, standing '
    'still and upright facing the track on his left, gloved hands at his sides',
    'at the same place and size as standing on the yellow line, doing 指差確認: his right arm stretched out '
    'straight, index finger pointing along the track towards the far end where trains arrive, looking the same way, '
    'mouth open as if calling out',
    'starting to walk back: a little further away on the same strip, about 200 px tall, seen from BEHIND '
    '(three-quarter back view), walking away from the viewer down the platform',
    'far away again on the strip between the edge and the yellow line, about 110 px tall, seen from BEHIND, walking '
    'away',
]

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at these first: {src} (the station picture) and {ROOT}/docs/art/gen/events/staff_raw.png, {ROOT}/docs/art/gen/events/staff_toward_raw.png, {ROOT}/docs/art/gen/events/staff_away_raw.png (the station attendant: navy uniform with gold buttons, navy cap with a gold band, white gloves, black shoes).

Make the SAME station picture with ONE change: add that ONE station attendant on the platform. Keep EVERYTHING else exactly the same, pixel for pixel as far as possible: identical composition and camera (do not move, zoom or crop), the same sky, light, buildings, fence, the EMPTY double track in the centre (no train), the platform, roof, pillars, wires and every waiting person in the same place.

The attendant: {what}. His size follows the perspective of the platform, his feet on the platform floor, with a small soft shadow under his feet. He never stands in front of or on top of a waiting person.

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The tracks in the centre stay EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or signboards added.
"""


def source(scene, part):
    if scene == 'standard':
        return f'{ROOT}/docs/art/gen/' + {'day': 'bg_day_raw.png', 'evening': 'bg_evening2_raw.png',
                                          'night': 'bg_night_raw.png'}[part]
    return f'{ROOT}/docs/art/gen/stations/{scene}_{part}_raw.png'


def job(args):
    scene, part, n = args
    out = f'{RAW}/{scene}_{part}_{n}_raw.png'
    if os.path.exists(out):
        return f'have {out}'
    prompt = PROMPT.format(out=out, src=source(scene, part), ROOT=ROOT, what=FRAMES[n])
    open(f'{RAW}/prompt_{scene}_{part}_{n}.txt', 'w', encoding='utf8').write(prompt)
    for _ in range(2):
        subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                       shell=sys.platform == 'win32')
        if os.path.exists(out):
            return f'ok {out}'
    return f'FAILED {out}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--scene', default='tokyo')
    ap.add_argument('--part', default='day')
    ap.add_argument('--jobs', type=int, default=3)
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    with ThreadPoolExecutor(a.jobs) as pool:
        for line in pool.map(job, [(a.scene, a.part, n) for n in range(len(FRAMES))]):
            print(line, flush=True)


if __name__ == '__main__':
    main()
