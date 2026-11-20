"""Passengers waiting at the train door and getting on (のりば), drawn by
GPT image generation (codex exec) in the station pictures' own style: one
sheet per passenger, seen from behind (toward the train door), on flat
magenta: frame 1 standing still in the queue, frames 2-7 a walking loop.
(The first round, {id}_away_raw.png, walk only, is the reference.)

  docs/art/gen/people_gpt/{id}_wait_raw.png  ->  tools/cut_gpt_walk.py
  ->  assets/art/people/{id}_wait.webp

  python tools/gen_passengers_gpt.py [--only coat_man ...] [--jobs 2]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import MODEL, ROOT  # noqa: E402

RAW = f'{ROOT}/docs/art/gen/people_gpt'
OUT = f'{ROOT}/assets/art/people'

PEOPLE = {
    'suit_man': 'a man in a dark navy business suit (jacket buttoned), white shirt collar, short dark brown hair, '
                'brown leather shoes, nothing in his hands',
    'office_woman': 'a woman office worker in a charcoal grey skirt suit (jacket and knee-length skirt), '
                    'shoulder-length dark brown hair, black low-heeled pumps, a small dark brown leather shoulder '
                    'bag on her right shoulder',
    'coat_man': 'a man in a long camel-coloured wool winter coat over dark trousers, a dark grey knit scarf, '
                'short black hair, black leather shoes, gloved hands, nothing in his hands',
    'coat_woman': 'a woman in a puffy navy down winter coat reaching her knees, a cream knit scarf and a grey knit '
                  'hat, dark tights, brown short boots, a small black bag on her shoulder',
    'umbrella_man': 'a man in a dark grey business suit, short black hair, black shoes, holding a long CLOSED dark '
                    'navy umbrella in his right hand, hanging down beside his leg, the same in every frame',
    'umbrella_woman': 'a woman in a beige trench coat (belted) over dark trousers, shoulder-length black hair, '
                      'black shoes, holding a short CLOSED clear vinyl umbrella in her left hand, hanging down, '
                      'the same in every frame',
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at these first: {ROOT}/docs/art/gen/stations/tokyo_day_raw.png (a station platform: the people waiting there are drawn in a soft, detailed 16-bit era pixel art style with slim, realistic adult proportions, about 8 heads tall with long legs and a small head, almost no black outlines and hue-shifted shading) and {ROOT}/docs/art/gen/people_gpt/suit_man_away_raw.png (a walk-cycle sheet in exactly the wanted style and layout).

Draw a SPRITE SHEET like that second picture, of ONE Japanese commuter: {who}. It is the SAME person as in {ROOT}/docs/art/gen/people_gpt/{pid}_away_raw.png when that file exists (same clothes, hair, colours, size).
- Seen from BEHIND, walking AWAY from the viewer and slightly to the left (a three-quarter back view: we see the back and the back of the head, facing up-left), like someone stepping onto a train at the platform.
- EXACTLY 7 frames side by side in ONE horizontal row, evenly spaced, each frame the same size. Frame 1 (the leftmost): the person STANDING STILL, waiting in line for the train door, facing the same way (feet together side by side, arms relaxed down by the sides, weight even). Frames 2 to 7: one smooth walking loop (6 frames).
- The person the SAME height and SAME scale in every frame, feet on the same baseline, the same clothes, hair, bag and colours in every frame; only the legs and arms move.
- The same size and pixel scale as the man in the second picture (that picture has 6 walking frames; this one has the standing frame first, then 6 walking frames).
- Plain flat solid MAGENTA background (#FF00FF) everywhere around the person, no floor, no shadow, no ground line, no other objects.
- Crisp square pixels, no anti-aliased blur at the edges, no outline glow.
- Landscape 1536x1024; keep generous magenta space between frames.
- ABSOLUTELY NO text, letters, numbers or frame labels.
"""


def job(pid):
    raw = f'{RAW}/{pid}_wait_raw.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, ROOT=ROOT, who=PEOPLE[pid], pid=pid)
        open(f'{RAW}/prompt_{pid}_wait.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                            '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                           shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    if not os.path.exists(raw):
        return f'FAILED {pid}'
    r = subprocess.run([sys.executable, f'{ROOT}/tools/cut_gpt_walk.py', raw, f'{OUT}/{pid}_wait.webp', '--frames', '7'],
                       capture_output=True, text=True)
    return f'{pid}: {r.stdout.strip() or r.stderr.strip()[-200:]}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=2)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    todo = [p for p in PEOPLE if not a.only or p in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for line in pool.map(job, todo):
            print(line, flush=True)


if __name__ == '__main__':
    main()
