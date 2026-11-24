"""Rain and snow versions of the city platform pictures
(tools/gen_city_scenes.py: Osaka, Fukuoka, Sendai, Sapporo), drawn by GPT
from each picture's own original so the place, the camera and the people
stay the same, then snapped to pixel art. Same wording as Tokyo's
(tools/gen_weather_scenes.py).

  python tools/gen_city_weather.py [--jobs 5] [--only osaka_umeda_day_rain ...]
  ->  docs/art/gen/cities/weather/{name}_{part}_{weather}_raw.png
      assets/art/weather/{name}_{part}_{weather}.webp   (384x192)
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace(os.sep, '/')
SRC = f'{ROOT}/docs/art/gen/cities'
OUT_RAW = f'{SRC}/weather'
OUT = f'{ROOT}/assets/art/weather'

SCENES = {
    'osaka_umeda': 'Umeda in Osaka: skyscrapers, a red Ferris wheel and a river',
    'osaka_castle': 'Osaka Castle above its moat, with cherry trees',
    'osaka_shinsekai': 'the Shinsekai downtown of Osaka with its lattice tower and shop street',
    'fukuoka_nakasu': 'Nakasu in Fukuoka: food stalls along a river with willow trees',
    'fukuoka_momochi': 'the Momochi seaside of Fukuoka: a beach, a glass tower and a dome',
    'sendai_aoba': 'a zelkova avenue in Sendai with festival streamers',
    'sendai_matsushima': 'Matsushima Bay: pine-covered islands and a red bridge',
    'sapporo_odori': 'Odori Park in Sapporo: fountains, a red lattice tower and a clock tower',
    'sapporo_otaru': 'the Otaru canal in winter: snowy brick warehouses and gas lamps',
}

LIGHT = {
    'day': 'daytime',
    'evening': 'evening (keep the sunset colours of the original, only dimmed by the clouds)',
    'night': 'night (keep the night lighting of the original: lit windows, platform lights)',
}

WEATHER = {
    'rain': """The change: it is RAINING, {light}.
- Only SOME of the people (about one in three) hold an OPEN umbrella above their head (clear vinyl, navy, black or beige), drawn in perspective at the right size for that person. The others stand under the platform roof without opening theirs; some of them hold a closed, wet umbrella.
- Grey overcast sky with rain clouds; everything slightly darker and cooler. The scenery on the left stays the same place, seen in the rain: wet roofs and streets, lights reflected in the wet ground and on the water.
- The platform floor and the rails look wet, with gentle reflections of the people and the lights.
- Do NOT draw falling rain streaks or drops (the app adds animated rain on top).""",
    'snow': """The change: it is a SNOWY winter day, {light}.
- A layer of fresh white snow on the roofs, the fence, the trees, the buildings' ledges, every landmark of the scenery on the left, and between the sleepers at the sides of the track. The rails themselves stay dark and clear.
- The people wear winter coats, scarves and hats; a few hold open umbrellas with a little snow on them.
- Pale grey-white snowy sky; soft, quiet light. Trees that flower or are in leaf in the original are bare or snow-covered now.
- Do NOT draw falling snowflakes (the app adds animated snow on top).""",
}

EXTRA = {
    # The snowy nights of Tokyo looked like a pale lavender day at first.
    ('snow', 'night'): """- It is still NIGHT: a DARK navy night sky with low snow clouds, as dark as the original night picture. The snow is lit only by the platform lights, the lit windows and street lamps (warm pools of light), and stays blue-grey in the shadows.""",
    # Otaru is already deep in snow.
    ('snow', 'sapporo_otaru'): """- The original already has snow: make it a HEAVIER snowfall day, with deeper, softer snow piled on the roofs, the railings and the lamps, and a whiter sky.""",
    ('rain', 'sapporo_otaru'): """- The original is snowy: now the snow is melting in the rain. Keep patches of grey, wet, slushy snow on the roofs and the ground, with wet dark stone showing through.""",
    ('snow', 'sendai_aoba'): """- The festival streamers still hang over the street, with a little snow on them; the big trees are bare with snow along their branches.""",
    ('snow', 'fukuoka_momochi'): """- Snow lies on the beach and the palm leaves, a rare sight; the sea is grey and calm.""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first ({desc}, seen from a railway platform). Make the SAME picture with ONE change. Keep EVERYTHING else exactly the same: identical composition and camera (do not move, zoom or crop), the same horizon, the same buildings and landmarks, the fence, the EMPTY track in the centre with the rails in exactly the same place, the covered platform on the right with the yellow tactile paving, the roof, pillars and overhead wires, and the SAME people in the SAME places at the SAME sizes.

{change}

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The track in the centre stays EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or readable signboards.
"""


def job(scene, part, weather):
    name = f'{scene}_{part}_{weather}'
    raw = f'{OUT_RAW}/{name}_raw.png'
    out = f'{OUT}/{name}.webp'
    if not os.path.exists(raw):
        change = '\n'.join([WEATHER[weather].format(light=LIGHT[part])] +
                           [EXTRA[k] for k in ((weather, part), (weather, scene)) if k in EXTRA])
        prompt = PROMPT.format(out=raw, src=f'{SRC}/{scene}_{part}_raw.png', desc=SCENES[scene], change=change)
        open(f'{OUT_RAW}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
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
        # pixelize leaves a 4x preview beside the picture: keep it with the raw ones.
        preview = out.replace('.webp', '_preview.png')
        if os.path.exists(preview):
            os.replace(preview, f'{OUT_RAW}/{name}_preview.png')
    return f'ok {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=5)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(OUT_RAW, exist_ok=True)
    todo = [(s, p, w) for w in WEATHER for p in LIGHT for s in SCENES if not a.only or f'{s}_{p}_{w}' in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for r in pool.map(lambda t: job(*t), todo):
            print(r, flush=True)


if __name__ == '__main__':
    main()
