"""Tottori station scenes for the MY shop (like Tokyo's 東京 / 新宿 ...):
鳥取, 米子, 境港 and 恋山形, drawn by GPT from the country station
(docs/art/gen/tottori/rural_{part}_raw.png) so the camera, track, platform
edge and roof stay where the train, the sign and the people expect them,
then snapped to pixel art.

  python tools/tottori/gen_station_scenes.py [--jobs 3] [--only yonago_day ...]
  ->  assets/art/tottori/scenes/{name}_{part}.webp
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace(os.sep, '/')
GEN = f'{ROOT}/docs/art/gen/tottori'
OUT_RAW = f'{GEN}/stations'
OUT = f'{ROOT}/assets/art/tottori/scenes'

LIGHT = {
    'day': 'a clear day, the same bright sky and light as the original',
    'evening': 'evening, keeping the warm sunset colours of the original',
    'night': 'night, keeping the night lighting of the original: dark starry sky, warm platform lamps, lit windows',
}

SCENES = {
    'tottori': """The change: this is TOTTORI STATION, the main station of a small seaside city, {light}.
- LEFT SIDE, beyond the fence: the low-rise city of Tottori (shops, houses and a few modest 6-10 storey buildings, no skyscrapers), and above the town a forested castle hill with old grey stone castle walls (ishigaki) near its top. Far away on the horizon a pale strip of golden sand dunes and the blue Sea of Japan.
- The platform becomes a tidy modern elevated platform: the roof is a clean light-grey steel canopy at the same height and position (NOT wood: smooth light-grey steel panels and slim white steel pillars), white walls with large glass windows, a modern bench, the yellow tactile line.
- People: four or five travellers with small suitcases and shopping bags, at the original people's places and sizes.""",
    'yonago': """The change: this is YONAGO STATION, a railway junction town at the foot of a great mountain, {light}.
- LEFT SIDE, beyond the fence: a wide railway yard with several sidings and two or three parked one-car diesel railcars (cream with a coloured stripe, no pantographs), a small engine shed, then the town of Yonago, and dominating the sky behind it the big, broad, snow-capped volcano Mt. Daisen.
- NO overhead wires above the main track.
- The platform keeps an old-style canopy at the same height: cream-painted steel pillars and a dark roof, a wooden bench, a vending machine against the back wall.
- People: three or four travellers (a businessman, a mother and child, an old man), at the original people's places and sizes.""",
    'sakaiminato': """The change: this is SAKAIMINATO STATION, the little terminus at a fishing port, {light}.
- LEFT SIDE, beyond the fence (instead of fields): the harbour. Calm blue water with several colourful fishing boats moored at a concrete quay, fish crates, a small crane, a white lighthouse at the end of a breakwater, and green hills of the peninsula across the water. A few seagulls in the sky.
- The fence is a low harbour-side railing.
- The platform keeps a simple canopy at the same height (white steel pillars, a blue-grey roof), a bench, a potted plant.
- People: two or three travellers (a fisherman in boots, a tourist with a camera), at the original people's places and sizes.""",
    'koiyamagata': """The change: this is KOI-YAMAGATA, a tiny mountain station famous for being painted PINK all over, {light}.
- LEFT SIDE, beyond the fence: steep green mountains covered in tall cedar forest, a clear mountain stream with rocks below, a few wild flowers. No village, no fields.
- The fence, the platform canopy pillars and beams, the bench and the back wall are all painted soft pastel PINK; small pink heart-shaped decorations hang from the canopy (no text). The canopy keeps the same height and position.
- People: a young couple standing close together, at the original people's places and sizes.
- A sweet, cosy, romantic mood.""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first (a country railway station: scenery behind a fence on the left, the track in the centre, a covered platform on the right). Make the SAME picture with the changes below. Keep the composition exactly the same: identical camera (do not move, zoom or crop), the same horizon and vanishing point, the fence line, the EMPTY track in the centre with the rails in exactly the same place, the platform on the right with its edge in the same place, the platform roof at the same height.

{change}

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The track in the centre stays EMPTY and clear: no train, nothing standing on the rails.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""


def job(name, part):
    raw = f'{OUT_RAW}/{name}_{part}_raw.png'
    out = f'{OUT}/{name}_{part}.webp'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=f'{GEN}/rural_{part}_raw.png',
                               change=SCENES[name].format(light=LIGHT[part]))
        open(f'{OUT_RAW}/prompt_{name}_{part}.txt', 'w', encoding='utf8').write(prompt)
        for _ in range(2):
            subprocess.run(['codex', 'exec', '-m', 'gpt-6.2-sol', '-c', 'model_reasoning_effort=low', '-s',
                            'workspace-write', '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                           shell=sys.platform == 'win32')
            if os.path.exists(raw):
                break
    if not os.path.exists(raw):
        return f'FAILED {name}_{part}'
    if not os.path.exists(out):
        subprocess.run([sys.executable, f'{ROOT}/tools/pixelize.py', raw, out, '--width', '384', '--aspect', '2.0',
                        '--colors', '64'], stdout=subprocess.DEVNULL, check=True)
        os.replace(f'{OUT}/{name}_{part}_preview.png', f'{OUT_RAW}/{name}_{part}_preview.png')
    return f'ok {name}_{part}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(OUT_RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    todo = [(n, p) for n in SCENES for p in LIGHT if not a.only or f'{n}_{p}' in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for r in pool.map(lambda t: job(*t), todo):
            print(r, flush=True)


if __name__ == '__main__':
    main()
