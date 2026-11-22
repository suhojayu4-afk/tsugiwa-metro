"""Tottori's rare train: a little steam locomotive (the Wakasa Railway keeps
one), head-on, by GPT image generation in the frame of the standard train
(docs/art/gen/train_front_raw.png), three variations. Cut out afterwards
with tools/train_cutout.py.

  python tools/tottori/gen_sl.py   ->  docs/art/gen/tottori/sl/c{1,2,3}_raw.png
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace(os.sep, '/')
OUT = f'{ROOT}/docs/art/gen/tottori/sl'

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it). Do not write or change any other files. Reply with the saved path only.

Look at this first:
- {ref} : a commuter train seen HEAD-ON on pure magenta. Copy EXACTLY its camera angle, image size, the train's position and size in the frame, its pixel-art style and its evening rim light. Also keep the SAME LAYOUT OF PARTS: a dark amber dot-matrix destination display band across the top of the windshield, the bright pure green stripe running straight across the face at the same height, the two round headlights at the same height and the same left/right positions just below the stripe, the skirt at the bottom.

What to draw instead: an ORIGINAL small Japanese STEAM LOCOMOTIVE (a little tank engine of a country railway), seen head-on, NOT any real locomotive model, filling the same area as the reference train.
- Glossy black body with a round smokebox door in the middle (with a small round number plate WITHOUT any numbers), a tall black chimney on top with a little white steam, one big round headlight on top of the smokebox, small handrails.
- Where the reference has its destination display band, put a dark horizontal nameplate board across the upper front (plain, no text).
- A bright red buffer beam across the bottom with two buffers and a coupler, and a short snow plough / cowcatcher below it.
- Use ONE thin bright pure green (#33CC33) line along the edge of the buffer beam as the stripe, the ONLY green anywhere.
- Small round marker lamps at the lower corners.
- Same detailed 16-bit era pixel art style, crisp square pixels, warm evening rim light.
- Background: one flat solid pure magenta colour (#FF00FF) everywhere around the train - no ground, no rails, no sky, no platform, no shadows on the background.
- ABSOLUTELY NO text, letters, numbers, logos or company marks anywhere.
Variation {n} of 3: {var}
"""
VARS = {1: 'classic, with gold trim lines on the smokebox ring',
        2: 'compact and cute, a slightly larger chimney and headlight',
        3: 'with brass details and a polished silver smokebox door ring'}


def job(n):
    raw = f'{OUT}/c{n}_raw.png'
    if os.path.exists(raw):
        return f'have c{n}'
    prompt = PROMPT.format(out=raw, ref=f'{ROOT}/docs/art/gen/train_front_raw.png', n=n, var=VARS[n])
    open(f'{OUT}/prompt_c{n}.txt', 'w', encoding='utf8').write(prompt)
    for _ in range(2):
        subprocess.run(['codex', 'exec', '-m', 'gpt-6.2-sol', '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900, shell=sys.platform == 'win32')
        if os.path.exists(raw):
            return f'ok c{n}'
    return f'FAILED c{n}'


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    with ThreadPoolExecutor(3) as pool:
        for r in pool.map(job, VARS):
            print(r, flush=True)
