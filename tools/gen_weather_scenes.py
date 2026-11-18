"""Weather versions of every station scene, drawn by GPT image generation
(codex exec) from each scene's original high-resolution picture, then
snapped to pixel art (tools/pixelize.py, 384x192, 64 colours).

  weathers: umbrella (rain expected), rain (raining), snow, winter (Dec-Feb, clear: thick coats), snowsoon (winter, snow expected)
  scenes:   standard + tokyo, shinjuku, shibuya, asakusa, ginza
  parts:    day, evening, night

Outputs: docs/art/gen/weather/{scene}_{part}_{weather}_raw.png (GPT) and
assets/art/weather/{scene}_{part}_{weather}.png (pixel art for the app).
Existing pictures are skipped, so the script can be re-run after a stop.

  python tools/gen_weather_scenes.py [--jobs 3] [--only tokyo_day_rain ...]
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
GEN = f'{ROOT}/docs/art/gen'
OUT_RAW = f'{GEN}/weather'
OUT = f'{ROOT}/assets/art/weather'
MODEL = 'gpt-6.2-sol'           # owner's choice (2026-11-18)

SCENES = {
    'standard': 'a generic Tokyo station with city buildings',
    'tokyo': 'Tokyo Station with its red-brick building on the left',
    'shinjuku': 'Shinjuku with tall skyscrapers',
    'shibuya': 'Shibuya with big screens and the busy crossing',
    'asakusa': 'Asakusa with a temple, a pagoda and lanterns',
    'ginza': 'Ginza with elegant shops and a clock tower',
}
STANDARD_SRC = {'day': 'bg_day_raw.png', 'evening': 'bg_evening2_raw.png', 'night': 'bg_night_raw.png'}

LIGHT = {
    'day': 'daytime',
    'evening': 'evening (keep the sunset colours of the original, only dimmed by the clouds)',
    'night': 'night (keep the night lighting of the original: lit windows, platform lights)',
}

WEATHER = {
    'umbrella': """The change: it looks like it will RAIN SOON (50% chance), but it is NOT raining yet.
- MOST of the people hold a CLOSED, folded umbrella in one hand (a long umbrella hanging down, or a short folded one), drawn at the right size for that person. Nobody has an umbrella open.
- The sky is covered with heavy, low, dark grey rain clouds; only a little light breaks through. The whole scene is dimmer and cooler than the original, a calm "rain is coming" mood, still {light}.
- The ground is still DRY. No rain, no wet reflections, no puddles.""",
    'rain': """The change: it is RAINING, {light}.
- Only SOME of the people (about one in three) hold an OPEN umbrella above their head (clear vinyl, navy, black or beige), drawn in perspective at the right size for that person. The others stand under the platform roof without opening theirs; some of them hold a closed, wet umbrella.
- Grey overcast sky with rain clouds; everything slightly darker and cooler.
- The platform floor and the rails look wet, with gentle reflections of the people and the lights.
- Do NOT draw falling rain streaks or drops (the app adds animated rain on top).""",
    'snow': """The change: it is a SNOWY winter day in Tokyo, {light}.
- A thin layer of fresh white snow on the roofs, the fence, the trees, the buildings' ledges and between the sleepers at the sides of the track. The rails themselves stay dark and clear.
- The people wear winter coats, scarves and hats; a few hold open umbrellas with a little snow on them.
- Pale grey-white snowy sky; soft, quiet light.
- Do NOT draw falling snowflakes (the app adds animated snow on top).""",
    'winter': """The change: it is a clear, cold WINTER day in Tokyo (December to February), {light}. No snow, no rain.
- EVERY person wears thick winter clothes: puffy down jackets or long wool coats in dark navy, black, camel, grey or beige, wool scarves wrapped around the neck, some knit hats, earmuffs or gloves. They look bundled up and a little rounder than before, but stand in the SAME places at the SAME sizes.
- Deciduous trees are bare (no leaves, thin brown branches); evergreen trees and bushes stay green, a bit darker.
- Crisp, clear winter air: slightly cooler, bluer light and longer soft shadows; the sky stays the same kind of sky as the original.
- The ground is DRY: no snow, no puddles.""",
    'snowsoon': """The change: a cold WINTER day in Tokyo when it looks like it will SNOW SOON, but it is NOT snowing yet, {light}.
- The sky is covered with thick, low, pale grey-white snow clouds; the light is flat, dim and cold, a quiet "snow is coming" mood.
- EVERY person wears thick winter clothes: down jackets or long wool coats, scarves, knit hats, gloves; a few hold a CLOSED umbrella. Same places, same sizes.
- Deciduous trees are bare; evergreens stay green.
- The ground is DRY: no snow anywhere yet, no puddles.""",
    # Only drawn for night: after the last train (終電後).
    'closed': """The change: it is LATE at NIGHT, AFTER THE LAST TRAIN. The station is closed for the night.
- NOBODY is on the platform: remove every person. The platform is completely empty and quiet.
- About HALF of the platform roof lights are switched OFF (every other lamp is dark), so the platform is dimmer, with pools of light and darker gaps between them. The city behind is darker too: fewer lit windows.
- Same night sky as the original, dry ground.""",
}

# Extra notes for single pictures that came out wrong the first time.
EXTRA = {
    # The snowy nights looked like a pale lavender day.
    ('snow', 'night'): """- It is still NIGHT: a DARK navy night sky with low snow clouds, as dark as the original night picture. The snow is lit only by the platform lights, the lit windows and street lamps (warm pools of light), and stays blue-grey in the shadows.""",
    # Crowded platforms got far too many open umbrellas.
    ('rain', 'shinjuku'): """- The platform is crowded: only a FEW people (about one in six, mostly near the front) have an open umbrella; most of the crowd has none open.""",
    ('rain', 'shibuya'): """- The platform is crowded: only a FEW people (about one in six, mostly near the front) have an open umbrella; most of the crowd has none open.""",
}

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first ({desc}). Make the SAME picture with ONE change. Keep EVERYTHING else exactly the same: identical composition and camera (do not move, zoom or crop), the same horizon, the same buildings, the fence, the EMPTY double track in the centre with the rails in exactly the same place, the covered platform on the right with the yellow tactile paving, the roof, pillars and overhead wires, and the SAME people in the SAME places at the SAME sizes.

{change}

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The tracks in the centre stay EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""


def source(scene, part):
    if scene == 'standard':
        return f'{GEN}/{STANDARD_SRC[part]}'
    return f'{GEN}/stations/{scene}_{part}_raw.png'


def job(name, scene, part, weather):
    raw = f'{OUT_RAW}/{name}_raw.png'
    out = f'{OUT}/{name}.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=source(scene, part), desc=SCENES[scene],
                               change='\n'.join([WEATHER[weather].format(light=LIGHT[part])] +
                                                [EXTRA[k] for k in ((weather, part), (weather, scene)) if k in EXTRA]))
        open(f'{OUT_RAW}/prompt_{name}.txt', 'w', encoding='utf8').write(prompt)
        for attempt in range(2):
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
    return f'ok {name}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    a = ap.parse_args()
    os.makedirs(OUT_RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    todo = []
    for weather in WEATHER:
        for scene in SCENES:
            for part in LIGHT:
                name = f'{scene}_{part}_{weather}'
                if a.only and name not in a.only:
                    continue
                todo.append((name, scene, part, weather))
    with ThreadPoolExecutor(a.jobs) as pool:
        for result in pool.map(lambda t: job(*t), todo):
            print(result, flush=True)


if __name__ == '__main__':
    main()
