"""Platform pictures of the places people visit most in Osaka, Fukuoka,
Sendai and Sapporo, drawn by GPT from the built-in city platform
(docs/art/gen/bg_{day,evening2,night}_raw.png) so the camera, the track, the
platform edge and the roof stay where the train, the sign and the people
expect them, then snapped to pixel art (384x192) for review.

  python tools/gen_city_scenes.py [--jobs 4] [--only osaka_umeda_day ...]
  ->  docs/art/gen/cities/{name}_{part}_raw.png   (1536x1024)
      docs/art/gen/cities/px/{name}_{part}.webp   (384x192, as the app shows it)
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace(os.sep, '/')
GEN = f'{ROOT}/docs/art/gen'
OUT_RAW = f'{GEN}/cities'
OUT = f'{GEN}/cities/px'
SRC = {'day': f'{GEN}/bg_day_raw.png', 'evening': f'{GEN}/bg_evening2_raw.png', 'night': f'{GEN}/bg_night_raw.png'}

LIGHT = {
    'day': 'a clear day, the same bright sky and light as the original',
    'evening': 'evening, keeping the warm sunset colours of the original',
    'night': 'night, keeping the night lighting of the original: a dark starry sky, warm platform lamps, many lit windows',
}

SCENES = {
    # ---- Osaka ----
    'osaka_umeda': """The change: this is the UMEDA district beside OSAKA STATION, the busiest place in western Japan, {light}.
- LEFT SIDE, beyond the fence: a dense wall of modern glass skyscrapers. The most striking one: a tall TWIN-TOWER building whose two towers are joined at the very top by a wide flat ring-shaped "floating garden" observatory with a round hole in its middle. In front of the towers, on the roof of a red shopping building, a big bright RED FERRIS WHEEL. Lower down: elevated railway viaducts and a broad river with a steel truss bridge.
- The platform stays a modern big-city elevated platform like the original.
- People: five or six commuters and shoppers, at the original people's places and sizes.""",
    'osaka_castle': """The change: this is the station beside OSAKA CASTLE PARK, {light}.
- LEFT SIDE, beyond the fence: a wide green park. Rising above the trees on a massive sloping grey stone base: the five-storey OSAKA CASTLE keep, white walls, sea-green tiled roofs with curved gables and shining GOLD ornaments and gold roof-end fish. In front of it a broad water moat with high stone walls and a white-walled corner turret; rows of round trees (cherry trees in soft pink blossom). Far behind, a cluster of glass office towers.
- The platform stays a modern elevated platform like the original.
- People: four or five visitors (a family, a tourist with a camera), at the original people's places and sizes.""",
    'osaka_shinsekai': """The change: this is the SHINSEKAI / TENNOJI downtown of Osaka, lively and retro, {light}.
- LEFT SIDE, beyond the fence: a crowded old downtown of low shop buildings with striped awnings, colourful blank signboards and strings of round paper lanterns. Standing over it: a retro steel LATTICE OBSERVATION TOWER about 100 m tall, with a wide square observation deck near the top and a slim spire, lit with coloured neon lines. Far behind it one extremely tall slim modern glass skyscraper, much taller than everything else.
- The platform stays a modern elevated platform like the original.
- People: five or six cheerful people (a cook in a white apron, friends chatting), at the original people's places and sizes.""",
    # ---- Fukuoka ----
    'fukuoka_nakasu': """The change: this is HAKATA / NAKASU in FUKUOKA, the city of food stalls by the river, {light}.
- LEFT SIDE, beyond the fence: a calm river running through the city. Along the near river bank a row of small open-air FOOD STALLS (yatai): little wooden carts with cloth half-curtains, red paper lanterns and steam rising, a few customers sitting on stools. Willow trees along the bank, arched bridges, and across the water modern mid-rise buildings with blank glowing signboards reflected in the river.
- The platform stays a modern elevated platform like the original.
- People: four or five people (office workers heading for dinner), at the original people's places and sizes.""",
    'fukuoka_momochi': """The change: this is the MOMOCHI SEASIDE of FUKUOKA, {light}.
- LEFT SIDE, beyond the fence: Hakata Bay. A sandy beach with palm trees and a small white seaside pavilion on a pier. Standing by the shore: a very tall, slim TRIANGULAR-PLAN TOWER completely covered in mirror glass that reflects the sky, with a pointed top and antenna. Beside it a huge round silver DOME STADIUM with a ribbed roof. Blue sea with a few sailing boats, low green islands on the horizon.
- The platform stays a modern elevated platform like the original.
- People: three or four people in light summer clothes, at the original people's places and sizes.""",
    # ---- Sendai ----
    'sendai_aoba': """The change: this is SENDAI, the "City of Trees", {light}.
- LEFT SIDE, beyond the fence: a wide boulevard lined with a double row of huge ZELKOVA trees whose green crowns meet overhead like a tunnel. Above the street hang long colourful TANABATA streamers: big paper balls with long flowing paper tails in pink, blue, yellow and green. Mid-rise city buildings behind. On a forested hill in the distance, the stone walls of an old castle site and a small bronze statue of a samurai on horseback wearing a crescent-moon helmet.
- The platform stays a modern elevated platform like the original.
- People: four or five people, one in a summer yukata, at the original people's places and sizes.""",
    'sendai_matsushima': """The change: this is MATSUSHIMA BAY near Sendai, one of Japan's three most beautiful views, {light}.
- LEFT SIDE, beyond the fence: a calm blue bay dotted with MANY small rocky islands, each with pale weathered cliffs and crowned with twisted green pine trees. A long RED wooden footbridge leads across the water to the nearest island. A small old wooden temple hall stands on a rock by the shore, a white sightseeing boat crosses the bay, seagulls fly.
- The fence is a low seaside railing.
- The platform keeps a simple seaside canopy at the same height.
- People: three or four sightseers, at the original people's places and sizes.""",
    # ---- Sapporo ----
    'sapporo_odori': """The change: this is ODORI PARK in SAPPORO, northern Japan, {light}.
- LEFT SIDE, beyond the fence: a long straight green park running through the city, with flower beds, fountains and lilac trees in purple bloom. At the end of the park a RED STEEL LATTICE TELEVISION TOWER (shaped like a small Eiffel tower, with a square observation deck). Near it a small old WHITE WOODEN CLOCK-TOWER building with a red roof and a square clock tower. City buildings on both sides, and behind everything a range of mountains still white with snow, a ski-jump slope on one of them.
- The platform stays a modern elevated platform like the original.
- People: four or five people in light jackets, at the original people's places and sizes.""",
    'sapporo_otaru': """The change: this is the OTARU CANAL near Sapporo, a romantic old port town in winter, {light}.
- LEFT SIDE, beyond the fence: an old stone-lined canal with dark calm water. Along its far bank a row of big old BRICK AND STONE WAREHOUSES with snow on their roofs and ivy on the walls. Along the near bank a stone walkway with old-fashioned GAS STREET LAMPS glowing warm. Deep white snow on the ground, the roofs and the railings, small snow lanterns, and snowy hills behind the town. A few snowflakes in the air.
- The fence and the platform edge have a little snow on them; the platform keeps its roof at the same height.
- People: three or four people in winter coats and scarves, at the original people's places and sizes.""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first (a city railway station: scenery behind a fence on the left, the track in the centre, a covered platform on the right). Make the SAME picture with the changes below. Keep the composition exactly the same: identical camera (do not move, zoom or crop), the same horizon and vanishing point, the fence line, the EMPTY track in the centre with the rails in exactly the same place, the overhead-wire masts, the platform on the right with its edge in the same place, the platform roof at the same height.

{change}

- Draw the scenery on the left with great care and rich detail: it is the heart of the picture and must be recognisable at once.
- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The track in the centre stays EMPTY and clear: no train, nothing standing on the rails.
- ABSOLUTELY NO text, letters, numbers, logos or readable signboards.
"""


def job(name, part):
    raw = f'{OUT_RAW}/{name}_{part}_raw.png'
    out = f'{OUT}/{name}_{part}.webp'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=SRC[part], change=SCENES[name].format(light=LIGHT[part]))
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
    return f'ok {name}_{part}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    # Day pictures first: they are the ones to judge a place by.
    todo = [(n, p) for p in LIGHT for n in SCENES if not a.only or f'{n}_{p}' in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for r in pool.map(lambda t: job(*t), todo):
            print(r, flush=True)


if __name__ == '__main__':
    main()
