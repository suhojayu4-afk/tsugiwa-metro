"""Download the PixelLab ambient animations of the Tottori station scenes
(animate_image_pixminimax, one per scene half; job ids below) into
docs/art/gen/tottori/anim_st/{name}_{part}_{L,R}_NN.png and pack each scene
with tools/anim_pack.py into assets/art/tottori/scenes/{name}_{part}_anim.webp
(loaded by SceneArt.loadMoving).

  python -X utf8 tools/tottori/pack_station_anims.py
"""
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori', 'anim_st')
OUT = os.path.join(ROOT, 'assets', 'art', 'tottori', 'scenes')
JOBS = {
    'yonago_day': ('d0b10dfe-12be-4829-8cf3-731f63308b31', '02fd86c8-0cd1-47a8-858b-67363894a6fe'),
    'yonago_evening': ('ce614efc-c86a-47c0-a002-3120cd5e653e', '9ff26094-63d1-4790-a757-9a8b0d5fd57d'),
    'yonago_night': ('41a89a40-7258-46d7-8ceb-8a066e3c4b73', '23ee6801-f5d5-4855-ab8f-69adc8b6b0c8'),
    'sakaiminato_day': ('f4c0a11d-d04c-43a1-9128-f0b807a6564a', '6285afdf-3166-4085-8314-e1db09ab8bc9'),
    'sakaiminato_evening': ('edc98631-eaf4-425a-b8eb-352c31dc89f4', 'c8857a34-792e-45aa-a35c-74431d912e09'),
    'sakaiminato_night': ('b1f18618-3e65-4ff2-b4ee-56ea725066b6', 'c880db4c-67ba-4933-ab2d-f702a8f62eef'),
    'koiyamagata_day': ('f385f40c-372a-462a-b093-b7cad44b5eba', 'f3995ee5-5a79-4826-842b-b3a052e67453'),
    'koiyamagata_evening': ('878a0c1f-4a75-4f23-b17f-95a9ed1d44aa', 'cf4c7092-4001-434b-8180-ae55abcceffa'),
    'koiyamagata_night': ('ed46a7fa-8b75-49ba-8aa0-9b5a8e8f6897', '47758011-4cf2-4d95-a017-01e30ef66c1e'),
    'tottori_day': ('6557ec41-9464-4be6-96bc-d5a1c25a4019', '01d58086-b61f-49fb-b46a-aa7eb27a95d9'),
    'tottori_evening': ('60d971e0-f186-458f-a8e2-de194e4cc988', '2ced27b3-bebb-455f-98bc-32c01ab71c41'),
    'tottori_night': ('5a56db1e-da05-4331-adf0-9448bc8cf636', '5115cca7-97e3-45e8-98cc-db7d89b4219b'),
}

for name, (left, right) in JOBS.items():
    for side, job in (('L', left), ('R', right)):
        for i in range(8):
            p = os.path.join(RAW, f'{name}_{side}_{i:02d}.png')
            if os.path.exists(p):
                continue
            req = urllib.request.Request(f'https://api.pixellab.ai/mcp/images/{job}/download?index={i}',
                                         headers={'User-Agent': 'pixel-route-map-builder/1.0'})
            open(p, 'wb').write(urllib.request.urlopen(req, timeout=60).read())
    # Motion only above the fence on the left and round the people on the right.
    # 恋山形 by day and evening: PixelLab redrew whole patches of forest, so
    # only the stream moves there.
    left = '40,95,140,130' if name in ('koiyamagata_day', 'koiyamagata_evening') else '0,0,192,128'
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'anim_pack.py'),
                    os.path.join(OUT, f'{name}.webp'), os.path.join(RAW, f'{name}_L'), os.path.join(RAW, f'{name}_R'),
                    os.path.join(OUT, f'{name}_anim.webp'), '--left-box', left, '--right-box', '96,60,192,175'],
                   check=True, cwd=os.path.join(ROOT, 'tools'))
