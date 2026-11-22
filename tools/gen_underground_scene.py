"""The underground (subway) version of the standard platform scene, drawn by
GPT image generation (codex exec) from the standard scene's original
high-resolution picture, then snapped to pixel art (tools/pixelize.py,
384x192, 64 colours) the same way as the weather and crowd pictures, so the
train, the door queue and the MY decorations line up.

Outputs: docs/art/gen/underground/scene_underground{tag}_raw.png (GPT) and
assets/art/scene_underground.webp (pixel art for the app; only with --use).

  python tools/gen_underground_scene.py --tag _v1          # one generation
  python tools/gen_underground_scene.py --tag _v1 --use    # make it the app's picture

Afterwards: python tools/find_vanishing.py (adds its rails' meeting point).
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
GEN = f'{ROOT}/docs/art/gen'
OUT_RAW = f'{GEN}/underground'
OUT = f'{ROOT}/assets/art/scene_underground.webp'
MODEL = 'gpt-6.2-sol'

PROMPT = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

Look at {src} first (an open-air elevated Tokyo station platform seen along the track). Redraw the SAME view as an UNDERGROUND SUBWAY station (a Tokyo Metro style station), keeping the composition and the camera EXACTLY the same (do not move, zoom, tilt or crop): this picture replaces the original in an app where a train, people and furniture are drawn on top at fixed pixel positions.

Keep IDENTICAL, in exactly the same place and at the same size and angle:
- the EMPTY railway track in the centre: both shiny steel rails, the sleepers and the track bed, running to the same vanishing point;
- the platform on the right: its edge along the track, the yellow tactile paving strip, the light grey floor tiles, and the row of square platform pillars at the same positions;
- the horizon / eye level and the vanishing point.

Change everything else into an indoor underground station:
- NO sky anywhere, no clouds, no sun, no buildings, no trees, no fence, no overhead wire masts or gantries.
- Where the sky and the city were far down the line: the dark round TUNNEL MOUTH that the track runs into, black inside with a couple of small dim tunnel lamps.
- On the left of the track (where the fence, trees and buildings were): the station's side wall across the track, covered with clean white and cream ceramic tiles with one coloured tile band, running in perspective to the tunnel mouth; a few blank framed poster panels (no text).
- Above everything: a low concrete ceiling with beams, pipes and cable trays, and long rows of bright white FLUORESCENT tube lights running in perspective towards the tunnel mouth, instead of the platform roof and the sky. A rigid overhead conductor rail may hang from the ceiling above the track.
- On the right behind the pillars (where the windows were): a tiled station wall with the same tile style, no windows to outside.
- Bright, even, slightly cool indoor lighting; the floor a little glossy with soft reflections of the lights. The rails stay clearly brighter than the track bed.
- NO people at all: the platform is empty.

- Landscape 1536x1024, the same detailed 16-bit era pixel art style as the original, crisp square pixels, almost no black outlines, hue-shifted shading.
- The track stays EMPTY: no train.
- ABSOLUTELY NO text, letters, numbers, logos or signboards.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', default='')
    ap.add_argument('--use', action='store_true', help='pixelize this one into the app picture')
    ap.add_argument('--extra', default='', help='extra lines for the prompt')
    a = ap.parse_args()
    os.makedirs(OUT_RAW, exist_ok=True)
    raw = f'{OUT_RAW}/scene_underground{a.tag}_raw.png'
    if not os.path.exists(raw):
        prompt = PROMPT.format(out=raw, src=f'{GEN}/bg_day_raw.png')
        if a.extra:
            prompt += '\n' + a.extra + '\n'
        open(f'{OUT_RAW}/prompt{a.tag}.txt', 'w', encoding='utf8').write(prompt)
        subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt.encode('utf8'),
                       cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=900, shell=sys.platform == 'win32')
    if not os.path.exists(raw):
        print('FAILED', raw)
        sys.exit(1)
    # A trial version next to the raw picture, for checking before --use.
    out = OUT if a.use else f'{OUT_RAW}/scene_underground{a.tag}.webp'
    subprocess.run([sys.executable, f'{ROOT}/tools/pixelize.py', raw, out,
                    '--width', '384', '--aspect', '2.0', '--colors', '64'], check=True)
    if a.use:
        os.remove(os.path.splitext(out)[0] + '_preview.png')
    print('ok', out)


if __name__ == '__main__':
    main()
