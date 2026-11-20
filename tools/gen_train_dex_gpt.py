"""Card pictures for the 車両図鑑 (lib/data/train_dex.dart), drawn by GPT
image generation (codex exec) in the style of the side-view train
(docs/art/gen/side_train/train3d_a_raw.png), then cut to pixel art.

Every type is an ORIGINAL design: inspired by the general shapes of Japanese
commuter, subway, express and local trains, but no real model, series name,
logo or livery is copied (no text or emblems at all).

  python tools/gen_train_dex_gpt.py [--jobs 3] [--only jr_commuter ...]   draw
  python tools/gen_train_dex_gpt.py --cut [--only ...]                     cut

Raw pictures: docs/art/gen/train_dex/{id}_raw.png (existing ones are kept,
delete one to redraw it). Cut: assets/art/train_dex/{id}.png and a 4x
preview docs/art/gen/train_dex/{id}_preview.png.
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
RAW = f'{ROOT}/docs/art/gen/train_dex'
OUT = f'{ROOT}/assets/art/train_dex'
MODEL = 'gpt-6.2-sol'

HEAD = """Use your image generation tool to create ONE image, then save the resulting PNG file to exactly this path:
{out}
(copy it there from wherever the tool stores it, replacing any old file). Do not write or change any other files. Reply with the saved path only.

"""

STYLE = """Look at these first: {root}/docs/art/gen/side_train/train3d_a_raw.png (a commuter train car for a side-scrolling game: detailed 16-bit era pixel art, crisp square pixels, almost no black outlines, rich hue-shifted shading, seen from the side with a little depth) and {root}/docs/art/gen/stations/tokyo_day_raw.png (the same art style in a station picture). Use EXACTLY that style, pixel size and palette feel."""

CARD = """

Draw ONE single railway vehicle for a collectible card in a train encyclopedia game: {what}

- It is an ORIGINAL fantasy design made for this game: do NOT copy any real train model, series or company livery. Keep it believable and charming.
- VIEW: a side view with a little depth (camera slightly above, so a thin strip of the roof top shows), the vehicle runs perfectly straight left to right, the driver's cab / front at the RIGHT end, facing right. No horizontal perspective.
- The vehicle fills about 86 percent of the picture width, centred, with magenta space around it.
- Plain flat solid MAGENTA background (#FF00FF) everywhere around it. No ground, no rails, no sky, no shadow on the magenta (except what the description asks for, like a beam or a cable).
- Crisp edges against the magenta: no glow, no anti-aliased fringe.
- Landscape 1536x1024.
- ABSOLUTELY NO text, letters, numbers, logos, emblems or symbols anywhere on the vehicle."""

TYPES = {
    'jr_commuter': """a modern city COMMUTER electric car: brushed silver stainless-steel body with fine ribbing, four pairs of sliding doors, wide windows with black frames and a few seated passenger silhouettes, a slanted cab front with a big dark window and headlights, boxy air-conditioners on the roof, a single-arm pantograph, two bogies. A bright LEAF-GREEN band below the windows and a thin green line under the roof, the green wrapping around the cab front.""",
    'jr_rapid': """a medium-distance RAPID train car that is a DOUBLE-DECKER: a tall cream-white and silver body with two rows of windows (upper deck and lower deck, the lower deck sitting low between the bogies), doors only at the two ends, comfy seat silhouettes in the windows. ORANGE and deep GREEN parallel bands along the body (orange above, green below). The right end is a plain gangway end (it is a middle car), a short pantograph-free roof with smooth air-conditioner fairings.""",
    'jr_regional': """a small two-door REGIONAL electric car that runs through hills and farmland: a rounded friendly cab front with a big two-part windscreen and round headlights, cream-white body, a SKY-BLUE band below the windows and a thin teal line above, two pairs of doors, a pantograph, a little snow plough under the front.""",
    'local_diesel': """a single-car rural DIESEL railcar (no pantograph, no overhead wire): a short body painted warm CREAM on top and deep RED-ORANGE below, a little exhaust stack on the roof with a tiny puff of grey exhaust, a cosy rounded cab with two round headlights and a cowcatcher-like skirt, one door near each end, a few windows with a hanging-strap interior and one passenger, visible engine and radiator under the floor between two bogies.""",
    'subway': """a modern SUBWAY car: smooth aluminium body painted pale silver-white, a crisp sloping cab front with a black wraparound window, LED headlights, an emergency door outline in the middle of the front, four pairs of doors, a deep SKY-BLUE band along the body plus a thin one above the windows, a low roof (built for tunnels) with a single-arm pantograph, two bogies.""",
    'subway_classic': """a ROUND-FACED CLASSIC SUBWAY car with a retro feel: a short body painted bright warm ORANGE-YELLOW with a cream window area, a rounded old-fashioned cab with a single centred headlight and two small marker lamps, brass-coloured trim, three pairs of doors, round-cornered windows, a SHOE-TYPE third-rail collector by the bogies instead of a pantograph (no pantograph on the roof), small roof vents.""",
    'mini_subway': """a SMALL, LOW LINEAR-MOTOR SUBWAY car: noticeably compact and low (built for tiny tunnels), small wheels, a flat linear-motor plate between the wheels, a short rounded cab front with a big curved window, silver body with a bold MAGENTA-PINK band along the bottom and around the front, three pairs of doors, no pantograph on the very low roof.""",
    'private_commuter': """a suburban PRIVATE-RAILWAY commuter car: silver stainless-steel body, a sharp modern cab front with a black face and a vertical headlight strip, four pairs of doors, a ROYAL-BLUE band below the windows with a thin SKY-BLUE line above it, a single-arm pantograph, boxy roof air-conditioners, two bogies.""",
    'airport_express': """a sleek AIRPORT LIMITED EXPRESS car: a long aerodynamic pointed nose like a jet, a deep NAVY and white body with a swooshing silver-blue line, long continuous dark windows, few doors with a luggage-room window, a smooth roof fairing hiding the pantograph, skirts covering most of the bogies.""",
    'resort_liner': """a seaside RESORT TRAIN car: a big panoramic cab where the front window wraps up over the driver into the roof (passengers can look out of the front), huge side windows with seats facing the window, a white body with an OCEAN-BLUE and turquoise wave-like band, a pantograph, a cheerful holiday feel.""",
    'monorail': """a STRADDLE-BEAM MONORAIL car riding ON TOP of a thick grey concrete beam: draw the beam as a straight horizontal concrete box under the car spanning the full width of the picture edge to edge. The car body wraps down over both sides of the beam (rubber-tyred bogies hidden in skirts), a rounded bubble cab front with a big window, white body with an ORANGE band and a thin navy line, large windows.""",
    'hanging_monorail': """a SUSPENDED MONORAIL car that HANGS BELOW a steel track beam: draw a straight dark-grey steel box beam along the very top of the picture spanning the full width edge to edge, the car hanging from it on two slender hanger arms. The car has a rounded egg-like body with big panoramic windows down to the floor, white body with a fresh LIME-GREEN band, a curved cab window at the right end.""",
    'agt': """a small driverless RUBBER-TYRED AUTOMATED GUIDEWAY car (a people mover on a concrete guideway): short body, a big rounded front window with NO driver (you can see seats right at the front), rubber tyres in fender skirts, guide wheels at the sides, white body with a BRIGHT BLUE band and a light-blue gradient, wide windows, no pantograph.""",
    'tram': """a cute single-car STREETCAR / TRAM that is clearly SHORT and stubby (only about 2.5 times as long as it is tall, much shorter than a train car), drawn big so it still fills the picture width: boxy body with rounded corners, cream-white upper half and a light cherry-blossom PINK lower half (a soft light pink like #F4A6BE, never magenta or purple), a single big windscreen with a centred round headlight, a small single-arm pantograph, two low-step doors, a little brass bell on the roof by the front, small wheels hidden behind a skirt, a few small white flower-shaped dots on the pink (not text).""",
    'retro_local': """a nostalgic small-town RETRO ELECTRIC car from a country railway: riveted steel body with rounded roof ends, two-tone colours (cream top and deep BLUE-GREEN bottom), a flat three-window cab front, an old-style diamond-shaped pantograph, wooden-looking window frames, two doors, old-style bogies with leaf springs.""",
    'mountain': """a sturdy short MOUNTAIN-CLIMBING electric car that climbs steep slopes: tall body painted vivid CRIMSON RED with a cream window band and silver trim, big windows for scenic views, a diamond pantograph, sanding pipes and strong brake gear at the bogies, a small headlight, the car slightly tilted as if on a gentle uphill (the front at the right a little higher).""",
    'yellow': """a rare bright YELLOW TRACK-INSPECTION TRAIN car (a special maintenance train that checks the rails and overhead wires): vivid sunshine-yellow body with a thin dark-blue line, an observation dome on the roof with a measuring pantograph and lamps, measuring sensors and small cameras under the floor near the bogies, a pointed cab front with headlights, few windows. It looks lucky and special.""",
}


def prompt(tid):
    out = f'{RAW}/{tid}_raw.png'
    return out, (HEAD + STYLE + CARD).format(out=out, root=ROOT, what=TYPES[tid])


def draw(tid):
    out, text = prompt(tid)
    if os.path.exists(out):
        print('keep', out)
        return
    with open(f'{RAW}/prompt_{tid}.txt', 'w', encoding='utf-8') as f:
        f.write(text)
    cmd = ['codex', 'exec', '-m', MODEL, '-c', 'model_reasoning_effort=low', '-s', 'workspace-write',
           '--skip-git-repo-check', '-']
    for _ in range(2):
        try:
            subprocess.run(cmd, input=text.encode('utf8'), cwd=ROOT, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=900, shell=sys.platform == 'win32')
        except subprocess.TimeoutExpired:
            pass
        if os.path.exists(out):
            break
    print(tid, 'ok' if os.path.exists(out) else 'FAILED', flush=True)


# Width of a card picture in art pixels.
CARD_W = 192


def cut(tid):
    import numpy as np
    from PIL import Image
    sys.path.insert(0, f'{ROOT}/tools')
    from cut_side_train import despill, key_mask, palette, shrink

    a = np.asarray(Image.open(f'{RAW}/{tid}_raw.png').convert('RGB')).astype(np.float32)
    m = key_mask(a)
    # Drop specks: only rows/columns with a real run of drawing count.
    ys = np.nonzero(m.sum(1) > 6)[0]
    xs = np.nonzero(m.sum(0) > 6)[0]
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = m.shape
    k = w / CARD_W
    rgb, al = shrink(a, m, CARD_W, round(h / k))
    q = palette(despill(rgb, al), al, 48)
    ys, xs = np.nonzero(q[..., 3])
    q = q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    os.makedirs(OUT, exist_ok=True)
    im = Image.fromarray(q, 'RGBA')
    im.save(f'{OUT}/{tid}.png')
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(f'{RAW}/{tid}_preview.png')
    print(f'{tid}.png {im.size}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--cut', action='store_true')
    a = ap.parse_args()
    ids = a.only or list(TYPES)
    os.makedirs(RAW, exist_ok=True)
    if a.cut:
        for t in ids:
            if os.path.exists(f'{RAW}/{t}_raw.png'):
                cut(t)
            else:
                print('missing', t)
        return
    with ThreadPoolExecutor(a.jobs) as ex:
        list(ex.map(draw, ids))


if __name__ == '__main__':
    main()
