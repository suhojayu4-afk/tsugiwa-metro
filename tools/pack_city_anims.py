"""The moving versions of the city platform pictures (tools/gen_city_scenes.py):
downloads the PixelLab ambient animations (animate_image_pixminimax, one per
picture half; job ids in docs/art/gen/cities/anim/jobs.json as
{"osaka_castle_day": ["<left job>", "<right job>"], ...}) and packs each
picture with tools/anim_pack.py into
assets/art/cities/scenes/{name}_{part}_anim.webp (loaded by SceneArt.loadMoving).

Motion is kept only above the fence on the left (water, trees, lights) and
round the people on the right, like the Tottori station scenes.

  python -X utf8 tools/pack_city_anims.py [name_part ...]
"""
import json
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'cities', 'anim')
OUT = os.path.join(ROOT, 'assets', 'art', 'cities', 'scenes')
# Pictures where the animator redrew too much of the left half: a smaller box.
LEFT_BOX = {}


def main():
    jobs = json.load(open(os.path.join(RAW, 'jobs.json'), encoding='utf8'))
    for name in sys.argv[1:] or sorted(jobs):
        left, right = jobs[name]
        for side, job in (('L', left), ('R', right)):
            if not job:
                continue
            for i in range(8):
                p = os.path.join(RAW, f'{name}_{side}_{i:02d}.png')
                if os.path.exists(p) and os.path.getsize(p) > 200:
                    continue
                req = urllib.request.Request(f'https://api.pixellab.ai/mcp/images/{job}/download?index={i}',
                                             headers={'User-Agent': 'pixel-scene-packer/1.0'})
                open(p, 'wb').write(urllib.request.urlopen(req, timeout=60).read())
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'anim_pack.py'),
                        os.path.join(OUT, f'{name}.webp'), os.path.join(RAW, f'{name}_L'),
                        os.path.join(RAW, f'{name}_R'), os.path.join(OUT, f'{name}_anim.webp'),
                        '--left-box', LEFT_BOX.get(name, '0,0,192,128'), '--right-box', '96,60,192,175'],
                       check=True, cwd=os.path.join(ROOT, 'tools'))
        print('packed', name, flush=True)


if __name__ == '__main__':
    main()
