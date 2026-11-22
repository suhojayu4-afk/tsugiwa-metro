"""More MY trains with their own shape, head-on, by GPT image generation in
the frame of the standard train (docs/art/gen/train_front_raw.png), a few
variations each. Cut out afterwards with tools/train_cutout.py and put in
the app with tools/make_trains.py.

  python tools/gen_trains.py [name ...]   ->  docs/art/gen/trains/<name>/c{n}_raw.png
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace(os.sep, '/')
OUT = f'{ROOT}/docs/art/gen/trains'

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it). Do not write or change any other files. Reply with the saved path only.

Look at this first:
- {ref} : a commuter train seen HEAD-ON on pure magenta. Copy EXACTLY its camera angle, image size, the train's position and size in the frame (same width, same height, its wheels on the same bottom line), its pixel-art style and its evening rim light. Also keep the SAME LAYOUT OF PARTS: a dark amber dot-matrix destination display band across the top of the windshield, ONE bright pure green stripe running straight across the face at the same height, the two round headlights at the same height and the same left/right positions just below the stripe, the skirt at the bottom.

What to draw instead: {what}
- The stripe across the face must be one single bright pure green (#33CC33) band, and the ONLY green anywhere on the train.
- Same detailed 16-bit era pixel art style, crisp square pixels, warm evening rim light.
- Background: one flat solid pure magenta colour (#FF00FF) everywhere around the train - no ground, no rails, no sky, no platform, no shadows on the background.
- ABSOLUTELY NO text, letters, numbers, logos or company marks anywhere.
Variation {n}: {var}
"""

TRAINS = {
    'oni': ("""an ORIGINAL fantasy "ONI" train from Japanese folklore (a friendly-fierce red ogre), seen head-on, NOT any real train and NOT any existing character.
- Body: deep crimson red lacquer with darker red shading, like a festival oni mask.
- Roof: two short curved GOLDEN HORNS standing up at the left and right roof corners, and a pantograph between them.
- Face: the windshield is one wide dark glass shaped like two fierce slanted eyes under heavy black angled brows (the brows are part of the body paint); the destination display band sits along the top of the windshield.
- Below the stripe: two round glowing yellow headlights like eyes, and between them a wide grinning mouth painted in black with two white upward FANGS.
- Skirt: dark iron grey with a yellow-and-black tiger-skin pattern (bold wavy black stripes on yellow), like an oni's loincloth, a coupler in the middle.
- Small twisted shimenawa rope with white paper zigzag strips hanging under the roof edge.""",
            {1: 'rounder, slightly cute face', 2: 'sharper, fiercer face with bigger horns', 3: 'broad square face, small horns, big fangs'}),
    'yako': ("""an ORIGINAL classic Japanese NIGHT SLEEPER express locomotive-style car ("blue train" feeling), seen head-on, NOT any real train model.
- Body: deep midnight navy blue with two thin GOLD lines; a tall, rounded, dignified classic face.
- Front: two large upright front windows with silver frames, the destination display band along the top, a small round plate holder (empty, plain silver) in the middle of the face below the stripe.
- Headlights: two round warm lamps just below the stripe, as in the reference; red tail-light lenses beside them.
- Roof: a pantograph and a row of ventilators.
- Below: a heavy dark grey skirt with a coupler and air hoses.""",
             {1: 'rounded bonnet-like face', 2: 'flat upright face with a centre gangway door'}),
    'tenbo': ("""an ORIGINAL Japanese sightseeing PANORAMA limited express, seen head-on, NOT any real train model.
- Body: pearl white with a warm vermilion red lower half; smooth streamlined nose.
- Front: one very large curved panoramic windshield reaching high up, with passengers' seats faintly visible behind it and a small driver's cab window above it under the roof; the destination display band along the top of the windshield.
- Headlights: two round lamps just below the stripe, as in the reference.
- Roof: a pantograph.
- Below: a rounded aerodynamic skirt in dark grey with a covered coupler.""",
              {1: 'tall elegant face', 2: 'lower, wider, sportier face'}),
}


def job(key):
    name, n = key
    what, vars_ = TRAINS[name]
    os.makedirs(f'{OUT}/{name}', exist_ok=True)
    raw = f'{OUT}/{name}/c{n}_raw.png'
    if os.path.exists(raw):
        return f'have {name} c{n}'
    prompt = PROMPT.format(out=raw, ref=f'{ROOT}/docs/art/gen/train_front_raw.png', what=what, n=n, var=vars_[n])
    open(f'{OUT}/{name}/prompt_c{n}.txt', 'w', encoding='utf8').write(prompt)
    for _ in range(2):
        subprocess.run(['codex', 'exec', '-m', 'gpt-6.2-sol', '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900, shell=sys.platform == 'win32')
        if os.path.exists(raw):
            return f'ok {name} c{n}'
    return f'FAILED {name} c{n}'


if __name__ == '__main__':
    names = sys.argv[1:] or list(TRAINS)
    keys = [(name, n) for name in names for n in TRAINS[name][1]]
    with ThreadPoolExecutor(4) as pool:
        for r in pool.map(job, keys):
            print(r, flush=True)
