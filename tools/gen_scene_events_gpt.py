"""Easter-egg events on the platform (lib/core/pixel/scene_events.dart),
drawn by GPT image generation (codex exec) in the station pictures' style:
sprite sheets on flat magenta, N frames in one row, same size and baseline.

  docs/art/gen/events/{id}_raw.png   (GPT)
  ->  assets/art/events/{id}.webp    (strip: frames side by side, feet on the
                                      bottom row, shrunk to the scene's pixels)
  yellow_train_raw.png -> assets/art/yellow_train/front_base_{day,evening,night}.webp,
                          front_stripe.webp (empty: the blue stripe is painted on),
                          front_rain.png / front_snow.png (copies of the usual ones)

  python tools/gen_scene_events_gpt.py [--only cat pigeon ...] [--jobs 3] [--cut-only]
"""
import argparse
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_weather_scenes import MODEL, ROOT  # noqa: E402
from art_io import save_art  # noqa: E402  (lossless WebP)

RAW = f'{ROOT}/docs/art/gen/events'
OUT = f'{ROOT}/assets/art/events'
TRAIN = f'{ROOT}/assets/art/yellow_train'

HEAD = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

"""

STYLE = (f'Look at these first: {ROOT}/docs/art/gen/stations/tokyo_day_raw.png (a Japanese station platform drawn in a soft, '
         'detailed 16-bit era pixel art style, almost no black outlines, hue-shifted shading) and '
         f'{ROOT}/docs/art/gen/people_gpt/suit_man_wait_raw.png (a sprite sheet in exactly the wanted style and layout: '
         'frames side by side in one row on flat magenta, feet on one baseline).\n\n')

SHEET_RULES = """- EXACTLY {n} frames side by side in ONE horizontal row, evenly spaced on an even grid, each frame the same size.
- The subject the SAME scale in every frame, feet on the SAME baseline, the same colours and markings in every frame; only the pose changes.
- Plain flat solid MAGENTA background (#FF00FF) everywhere, no floor, no shadow, no ground line, no other objects.
- Crisp square pixels, no anti-aliased blur at the edges, no outline glow, no magenta tint on the subject.
- Landscape 1536x1024; keep generous magenta space between frames.
- ABSOLUTELY NO text, letters, numbers, logos or frame labels.
"""

SHEETS = {
    # id: (frames, strip height in scene pixels, description)
    'cat': (8, 24, """Draw a SPRITE SHEET of ONE cute small orange-and-white tabby cat (a Japanese "chatora" stray cat, white chest and paws, orange tabby stripes on the back, long tail), seen exactly from the SIDE, facing LEFT.
- Frames 1 to 4: a relaxed walking cycle to the left (4 frames, legs moving, tail held up in a gentle curve).
- Frame 5: standing still, head turned towards the viewer.
- Frame 6: sitting down on its haunches (side view, body upright, front paws together), tail lying on the ground behind it, head towards the viewer.
- Frame 7: the same sitting pose, tail tip curled UP.
- Frame 8: the same sitting pose, eyes closed happily, tail tip swept to the other side.
"""),
    'pigeon': (6, 20, """Draw a SPRITE SHEET of ONE ordinary grey city pigeon (blue-grey body, darker wing bars, iridescent green-purple neck, pink feet), seen from the SIDE, facing LEFT.
- Frame 1: standing.
- Frame 2: pecking, head bent down to the ground.
- Frame 3: walking, one foot lifted, head bobbing forward.
- Frames 4 to 6: taking off and flying to the left: wings fully UP, wings level spread out, wings DOWN (body tilted up a little, feet tucked in).
"""),
    'staff': (8, 72, """Draw a SPRITE SHEET of ONE Japanese railway station attendant (an ORIGINAL generic uniform, not any real company's): a dark navy uniform jacket and trousers, a navy peaked cap with a plain gold band (no badge, no logo), white gloves, black shoes, short black hair, slim realistic adult proportions about 8 heads tall like the people in the first picture.
- Seen from the SIDE in a slight three-quarter view, facing LEFT.
- Frames 1 to 6: one smooth walking loop to the left (6 frames).
- Frame 7: standing still at attention, arms down.
- Frame 8: doing "shisa kanko" (point and call): standing still, the RIGHT arm stretched straight out forward to the left at shoulder height with the index finger pointing, the left hand at his side, mouth open calling out.
"""),
    'blimp': (2, 14, """Draw a SPRITE SHEET of ONE small cute airship (a blimp) seen from the SIDE, flying to the LEFT, nose on the left: a plump silver-white envelope with a single soft sky-blue band along its middle, small tail fins at the right end, a little gondola cabin underneath with tiny windows. Completely plain, no text, no logo, no advertisement.
- Frame 1 and frame 2 are identical except the small propeller at the back of the gondola (blurred in a different position).
- Make it fill most of each frame's width.
"""),
}

TRAIN_PROMPT = """Look at this first:
- {ROOT}/docs/art/gen/train_front_raw.png : a commuter train seen HEAD-ON on pure magenta. Copy EXACTLY its camera angle, image size, the train's position and size in the frame, its pixel-art style and its evening rim light. Also keep the SAME LAYOUT OF PARTS: a dark amber dot-matrix destination display band across the top of the windshield, the stripe running straight across the face at the same height, the two round headlights at the same height and the same left/right positions just below the stripe, the skirt at the bottom.

What to draw instead: an ORIGINAL Japanese track-inspection train ("doctor train"), seen head-on, NOT any real train model and NOT any real company's livery.
- Body: bright canary YELLOW all over the face and sides, with a boxy flat front with softly rounded corners.
- The stripe across the face is one single deep ROYAL BLUE (#1E4FC0) band at the same height as in the reference, the ONLY blue on the body.
- On the roof: a small low observation dome and a measuring pantograph frame, both light grey.
- A large dark tinted windshield with the destination display band along its top (dark, unlit).
- Headlights: two round lamps at the stripe's ends, same places as the reference.
- Skirt: dark grey with a yellow-and-black hazard-striped lower edge and a small coupler cover.
- Same detailed 16-bit era pixel art style, crisp square pixels, warm evening rim light.
- Background: one flat solid pure magenta colour (#FF00FF) everywhere around the train - no ground, no rails, no sky, no platform, no shadows on the background.
- ABSOLUTELY NO text, letters, numbers, logos or company marks anywhere.
"""


def is_key(c):
    r, g, b = c[:3]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def key_out(im):
    """Magenta to transparent; pink fringe on the outline pulled to the body
    colour or dropped (as tools/cut_gpt_walk.py)."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if is_key(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
            else:
                r, g, b, al = px[x, y]
                if r > g + 40 and b > g + 40:
                    px[x, y] = (min(r, (g + b) // 2), g, min(b, (r + g) // 2), al)
    for _ in range(2):
        drop = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                r, g, b, al = px[x, y]
                if al and r > g + 25 and b > g + 25 and any(
                        px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    drop.append((x, y))
        for x, y in drop:
            px[x, y] = (0, 0, 0, 0)
    return im


def runs_of(im):
    px = im.load()
    w, h = im.size
    cols = [any(px[x, y][3] for y in range(0, h, 2)) for x in range(w)]
    runs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 12:
                runs.append((start, x))
            start = None
    return runs


def cut_sheet(sid):
    n, height, _ = SHEETS[sid]
    im = key_out(Image.open(f'{RAW}/{sid}_raw.png').convert('RGBA'))
    runs = runs_of(im)
    if len(runs) != n:
        # Touching frames: fall back to an even grid.
        cw = im.width / n
        runs = [(round(i * cw), round((i + 1) * cw)) for i in range(n)]
    frames = [im.crop((l, 0, r, im.height)) for l, r in runs]
    boxes = [f.getbbox() for f in frames]
    top = min(b[1] for b in boxes)
    bottom = max(b[3] for b in boxes)
    # Each frame is centred on its head (the top of the figure), so the body
    # stays put when only an arm or the tail moves (the pointing attendant,
    # the cat sitting down); the pigeons on their middle.
    def anchor(f, b):
        if sid not in ('cat', 'staff'):
            return (b[0] + b[2]) / 2
        if sid == 'staff':
            head = f.crop((b[0], b[1], b[2], b[1] + (b[3] - b[1]) // 6)).getbbox()
            return b[0] + (head[0] + head[2]) / 2
        # The cat faces left and its tail is up: its head is the front of the
        # upper half.
        upper = f.crop((b[0], b[1], b[2], b[1] + (b[3] - b[1]) * 55 // 100)).getbbox()
        return b[0] + upper[0] + 26
    centres = [anchor(f, b) for f, b in zip(frames, boxes)]
    fw = 2 * max(max(c - b[0], b[2] - c) for c, b in zip(centres, boxes))
    # The pigeons' flying frames hang lower than their feet: every pigeon
    # frame stands on its own lowest pixel instead.
    own = sid == 'pigeon'
    if own:
        tall = max(b[3] - b[1] for b in boxes)
    k = height / (tall if own else bottom - top)
    out_w = round(fw * k) + 2
    strip = Image.new('RGBA', (out_w * n, height))
    for i, (f, b) in enumerate(zip(frames, boxes)):
        cx = centres[i]
        y0, y1 = (b[3] - tall, b[3]) if own else (top, bottom)
        part = f.crop((round(cx - fw / 2), y0, round(cx + fw / 2), y1))
        small = part.resize((round(fw * k), height), Image.Resampling.BOX)
        sp = small.load()
        for y in range(small.height):
            for x in range(small.width):
                c = sp[x, y]
                sp[x, y] = (c[0], c[1], c[2], 255) if c[3] >= 140 else (0, 0, 0, 0)
        strip.paste(small, (i * out_w + 1, 0))
    os.makedirs(OUT, exist_ok=True)
    save_art(strip, f'{OUT}/{sid}.webp')
    return f'{sid}: {strip.size} frames={n} ({len(runs_of(im))} found)'


def cut_train():
    raw = Image.open(f'{RAW}/yellow_train_raw.png').convert('RGB')
    f = 4
    sw, sh = raw.width // f, raw.height // f
    px = raw.load()
    out = Image.new('RGBA', (sw, sh))
    op = out.load()
    for y in range(sh):
        for x in range(sw):
            cs = [px[x * f + dx, y * f + dy] for dy in range(f) for dx in range(f)]
            cs = [c for c in cs if not is_key(c)]
            if len(cs) * 2 >= f * f:
                op[x, y] = tuple(sum(c[i] for c in cs) // len(cs) for i in range(3)) + (255,)
    for y in range(sh):
        for x in range(sw):
            if op[x, y][3] and sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                                   if 0 <= x + dx < sw and 0 <= y + dy < sh and op[x + dx, y + dy][3]) <= 1:
                op[x, y] = (0, 0, 0, 0)
    for y in range(sh):
        for x in range(sw):
            r, g, b, al = op[x, y]
            if al and r > g + 25 and b > g + 25:
                op[x, y] = (0, 0, 0, 0)
    out = out.crop(out.getbbox())
    # Same frame as every train front (75x96), bottom on the bottom row; the
    # roof dome and pantograph make it taller, so it is shrunk to fit and
    # stays centred (lamps then sit a little lower than the usual train's).
    k = min(75 / out.width, 96 / out.height)
    small = out.resize((round(out.width * k), round(out.height * k)), Image.Resampling.NEAREST)
    out = Image.new('RGBA', (75, 96))
    out.paste(small, ((75 - small.width) // 2, 96 - small.height))
    rgb = out.convert('RGB').quantize(colors=48, method=Image.Quantize.MEDIANCUT,
                                      dither=Image.Dither.NONE).convert('RGB')
    base = Image.new('RGBA', out.size)
    base.paste(rgb, mask=out.getchannel('A'))
    os.makedirs(TRAIN, exist_ok=True)
    # Lit by the sunset like the usual train: re-lit for the other parts (tools/train_cutout.py).
    for part, (tint, amount, gain) in {
        'evening': ((255, 255, 255), 0.0, 1.0),
        'day': ((236, 236, 236), 0.45, 1.06),
        'night': ((120, 132, 190), 0.7, 0.72),
    }.items():
        g = base.copy()
        gp = g.load()
        for y in range(g.height):
            for x in range(g.width):
                r, gg, b, al = gp[x, y]
                if not al or max(r, gg, b) > 235:
                    continue
                lum = (r * 299 + gg * 587 + b * 114) / 1000
                gp[x, y] = tuple(max(0, min(255, round(((1 - amount) * c + amount * lum * t / 255) * gain)))
                                 for c, t in zip((r, gg, b), tint)) + (al,)
        save_art(g, f'{TRAIN}/front_base_{part}.webp')
    save_art(Image.new('RGBA', (75, 96)), f'{TRAIN}/front_stripe.webp')
    for w in ('rain', 'snow'):
        shutil.copy(f'{ROOT}/assets/art/train_front_{w}.png', f'{TRAIN}/front_{w}.png')
    return f'yellow_train: {out.size}'


def generate(sid):
    raw = f'{RAW}/{sid}_raw.png'
    if os.path.exists(raw):
        return
    if sid == 'yellow_train':
        prompt = HEAD.format(out=raw) + TRAIN_PROMPT.format(ROOT=ROOT)
    else:
        n, _, what = SHEETS[sid]
        prompt = HEAD.format(out=raw) + STYLE + what + SHEET_RULES.format(n=n)
    open(f'{RAW}/prompt_{sid}.txt', 'w', encoding='utf8').write(prompt)
    for _ in range(2):
        subprocess.run(['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
                        '--skip-git-repo-check', '-'], input=prompt.encode('utf8'), cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900,
                       shell=sys.platform == 'win32')
        if os.path.exists(raw):
            break


def job(sid, cut_only=False):
    if not cut_only:
        generate(sid)
    if not os.path.exists(f'{RAW}/{sid}_raw.png'):
        return f'FAILED {sid}'
    try:
        return cut_train() if sid == 'yellow_train' else cut_sheet(sid)
    except Exception as e:  # noqa: BLE001
        return f'{sid}: cut failed: {e}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--cut-only', action='store_true')
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    todo = [s for s in [*SHEETS, 'yellow_train'] if not a.only or s in a.only]
    with ThreadPoolExecutor(a.jobs) as pool:
        for line in pool.map(lambda s: job(s, a.cut_only), todo):
            print(line, flush=True)


if __name__ == '__main__':
    main()
