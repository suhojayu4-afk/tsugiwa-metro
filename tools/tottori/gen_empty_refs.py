"""Empty-platform versions of the Tottori platform pictures (GPT, from the
same original drawings), for tools/make_decor_masks.py: what differs from
the empty platform is a person, who then stands in front of the MY
decorations. Not app assets.

  python tools/tottori/gen_empty_refs.py [--jobs 3]
  ->  docs/art/gen/tottori/empty/{name}.webp  (name = the app picture's name)
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace(os.sep, '/')
GEN = f'{ROOT}/docs/art/gen/tottori'
OUT = f'{GEN}/empty'

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first (a railway station platform picture). Make the SAME picture with ONE change: there are NO PEOPLE at all - remove every person from the platform and show the empty floor, wall, bench and pillars behind where they stood. Keep EVERYTHING else exactly the same: identical camera (do not move, zoom or crop), the same scenery, track, platform, roof, pillars, lights, colours and pixel art style.
- Landscape 1536x1024, crisp square pixels.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""


def sources():
    out = {}
    for p in ('day', 'evening', 'night'):
        out[f'rural_{p}'] = f'{GEN}/rural_{p}_raw.png'
        for n in ('tottori', 'yonago', 'sakaiminato', 'koiyamagata'):
            out[f'{n}_{p}'] = f'{GEN}/stations/{n}_{p}_raw.png'
    return out


def job(name, src):
    raw = f'{OUT}/{name}_raw.png'
    out = f'{OUT}/{name}.webp'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=src)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', 'gpt-6.2-sol', '-c', 'model_reasoning_effort=low', '-s',
                            'workspace-write', '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                           shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    if not os.path.exists(raw):
        return f'FAILED {name}'
    if not os.path.exists(out):
        subprocess.run([sys.executable, f'{ROOT}/tools/pixelize.py', raw, out, '--width', '384', '--aspect', '2.0',
                        '--colors', '64'], stdout=subprocess.DEVNULL, check=True)
    return f'ok {name}'


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    with ThreadPoolExecutor(a.jobs) as pool:
        for r in pool.map(lambda kv: job(*kv), sources().items()):
            print(r, flush=True)
