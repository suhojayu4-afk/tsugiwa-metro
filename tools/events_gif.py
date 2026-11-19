"""GIFs of the platform easter eggs from the frames rendered by
test/tools/render_scene_events.dart (build/event_frames/<event>/NNN.png):
docs/captures/events/<event>.gif (the phone's view of the picture) and
docs/captures/events/all.gif (a short montage).

  python tools/events_gif.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAMES = os.path.join(ROOT, 'build', 'event_frames')
OUT = os.path.join(ROOT, 'docs', 'captures', 'events')

# The phone's crop of the 384x192 picture (SceneView.fit on a 390 pt phone), at 2x.
CROP = (64 * 2, 23 * 2, 356 * 2, 169 * 2)
# Frames per second each event was rendered at, and the GIF's playback speed-up.
FPS = {'cat': 8, 'pigeons': 8, 'staff': 8, 'shooting_star': 12, 'rainbow': 2, 'blimp': 2,
       'dragonflies': 10, 'yellow_train': 8}
SPEED = {'rainbow': 2.0, 'blimp': 3.0}


def load(name):
    d = os.path.join(FRAMES, name)
    return [Image.open(os.path.join(d, f)).convert('RGB').crop(CROP) for f in sorted(os.listdir(d))]


def save(frames, path, ms):
    pal = [f.quantize(colors=255, method=Image.Quantize.MEDIANCUT) for f in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=ms, loop=0, optimize=True, disposal=1)


def main():
    os.makedirs(OUT, exist_ok=True)
    montage = []
    for name, fps in FPS.items():
        if not os.path.isdir(os.path.join(FRAMES, name)):
            continue
        frames = load(name)
        ms = round(1000 / fps / SPEED.get(name, 1.0))
        save(frames, os.path.join(OUT, f'{name}.gif'), ms)
        # Montage: about 3 s of the liveliest part of each, at half size.
        step = max(1, round(fps / 6 * SPEED.get(name, 1.0)))
        pick = frames[::step]
        mid = len(pick) // 2
        part = pick[max(0, mid - 9):mid + 9] if name not in ('shooting_star',) else pick[:18]
        montage += [f.resize((f.width // 2, f.height // 2), Image.Resampling.NEAREST) for f in part]
        print(name, len(frames), 'frames', ms, 'ms')
    if montage:
        save(montage, os.path.join(OUT, 'all.gif'), 160)


if __name__ == '__main__':
    main()
