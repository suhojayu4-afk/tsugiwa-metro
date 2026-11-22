"""The country diesel railcar (kidosha) for Tottori's platform, head-on, by
GPT image generation in the frame of the standard train
(docs/art/gen/train_front_raw.png), three variations. Cut out afterwards
with tools/train_cutout.py.

  python tools/tottori/gen_diesel.py   ->  docs/art/gen/tottori/diesel/c{1,2,3}_raw.png
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace(os.sep, '/')
OUT = f'{ROOT}/docs/art/gen/tottori/diesel'

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it). Do not write or change any other files. Reply with the saved path only.

Look at this first:
- {ref} : a commuter train seen HEAD-ON on pure magenta. Copy EXACTLY its camera angle, image size, the train's position and size in the frame, its pixel-art style and its evening rim light. Also keep the SAME LAYOUT OF PARTS: a dark amber dot-matrix destination display band across the top of the windshield, the bright pure green stripe running straight across the face at the same height, the two round headlights at the same height and the same left/right positions just below the stripe, the skirt at the bottom.

What to draw instead: an ORIGINAL Japanese rural DIESEL RAILCAR (a one-car "kidosha" of a quiet country line), seen head-on, NOT any real train model.
- NO pantograph and NO overhead-wire equipment on the roof: instead a low air-conditioner box and a small black exhaust pipe sticking up at one side of the roof.
- Body: cream-white with a slightly worn, friendly look; a flat, upright face.
- Front: two front windows with a narrow gangway door (with its own small window) in the middle between them, the destination display band along the top.
- The stripe across the face must be one single bright pure green (#33CC33) band, and the ONLY green anywhere on the train.
- Headlights: two round lamps just below the stripe, as in the reference; small marker lights near the top corners.
- Below: a sturdy dark grey skirt with a snow plough shape, a coupler in the middle.
- Same detailed 16-bit era pixel art style, crisp square pixels, warm evening rim light.
- Background: one flat solid pure magenta colour (#FF00FF) everywhere around the train - no ground, no rails, no sky, no platform, no shadows on the background.
- ABSOLUTELY NO text, letters, numbers, logos or company marks anywhere.
Variation {n} of 3: {var}
"""
VARS = {1: 'rounded roof corners, slightly larger windows',
        2: 'squarer, boxier classic face with a visible rain gutter line',
        3: 'modern-ish face with dark window surrounds framing both windows and the door'}


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
