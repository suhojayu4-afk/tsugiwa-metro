"""Puts the city platform pictures (tools/gen_city_scenes.py, in
assets/art/cities/scenes/) into the app:

  - assets/my/catalog.json: one MY shop scene per place, tied to its station
    (shown at that station once owned). Items already there are replaced.
  - assets/art/vanishing.json: where the rails meet in each picture.
  - assets/art/decor/vending_front/ + index.json: the people standing where
    MY platform decorations go (the pictures are the built-in platform
    redrawn, so they are compared with its empty crowd picture, like the
    seasonal scenes in tools/make_decor_masks.py). Tokyo's entries stay as
    they are.

  python -X utf8 tools/add_city_scenes.py
"""
import glob
import json
import os

import numpy as np
from PIL import Image

import find_vanishing
import make_decor_masks as m
from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENES = os.path.join(ROOT, 'assets', 'art', 'cities', 'scenes')
CATALOG = os.path.join(ROOT, 'assets', 'my', 'catalog.json')
VANISHING = os.path.join(ROOT, 'assets', 'art', 'vanishing.json')
INDEX = os.path.join(ROOT, 'assets', 'art', 'decor', 'index.json')
PARTS = ('day', 'evening', 'night')


def t(ja, ko, en):
    return {'ja': ja, 'ko': ko, 'en': en}


# key: (station id, name)
PLACES = {
    'osaka_umeda': ('osaka.osaka', t('大阪・梅田', '오사카 우메다', 'Osaka Umeda')),
    'osaka_castle': ('osaka.osakajokoen', t('大阪城', '오사카성', 'Osaka Castle')),
    'osaka_shinsekai': ('osaka.shin-imamiya', t('新世界', '신세카이', 'Shinsekai')),
    'fukuoka_nakasu': ('fukuoka.nakasu-kawabata', t('中洲', '나카스', 'Nakasu')),
    'fukuoka_momochi': ('fukuoka.nishijin', t('ももち浜', '모모치 해변', 'Momochi Seaside')),
    'sendai_aoba': ('sendai.sendai', t('仙台', '센다이', 'Sendai')),
    'sendai_matsushima': ('sendai.matsushima-kaigan', t('松島', '마쓰시마', 'Matsushima')),
    'sapporo_odori': ('sapporo.odori', t('大通公園', '오도리 공원', 'Odori Park')),
    'sapporo_otaru': ('sapporo.otaru', t('小樽運河', '오타루 운하', 'Otaru Canal')),
}


def catalog():
    items = [{'id': f'scene.{key}', 'slot': 'scene', 'name': name, 'price': 1000, 'priceYen': 250,
              'images': {p: f'assets/art/cities/scenes/{key}_{p}.webp' for p in PARTS}, 'station': station}
             for key, (station, name) in PLACES.items()]
    cat = json.load(open(CATALOG, encoding='utf8'))
    ids = {i['id'] for i in items}
    rest = [i for i in cat['items'] if i['id'] not in ids]
    last = max(k for k, i in enumerate(rest) if i['slot'] == 'scene')
    rest[last + 1:last + 1] = items
    cat['items'] = rest
    open(CATALOG, 'w', encoding='utf8', newline='\n').write(json.dumps(cat, ensure_ascii=False, indent=2) + '\n')
    print(len(items), 'scenes in the shop')


def vanishing():
    out = json.load(open(VANISHING, encoding='utf8'))
    for key in PLACES:
        for p in PARTS:
            name = f'{key}_{p}.webp'
            x, y, n = find_vanishing.find(os.path.join(SCENES, name))
            if n < 30 or not (210 <= x <= 245 and 82 <= y <= 112):
                print('unsure', name, x, y, n)  # the app's usual point for a station scene
                out.pop(name, None)
                continue
            out[name] = [x, y]
    json.dump(out, open(VANISHING, 'w'), indent=0, sort_keys=True)


def masks():
    index = json.load(open(INDEX, encoding='utf8'))
    names, shifts = set(index['masks']), dict(index['shifts'])
    for key in PLACES:
        for p in PARTS:
            name = f'{key}_{p}.webp'
            moving = os.path.join(SCENES, f'{key}_{p}_anim.webp')
            path = moving if os.path.exists(moving) else os.path.join(SCENES, name)
            img = np.asarray(Image.open(path).convert('RGB'))
            ref = np.asarray(Image.open(os.path.join(ROOT, 'assets', 'art', 'crowd',
                                                     f'standard_{p}_relaxed.webp')).convert('RGB'))
            found = []
            for f in range(img.shape[0] // m.H):
                mk, shift = m.people(img[f * m.H:(f + 1) * m.H], ref)
                found.append(mk)
            mask = np.concatenate(m.steady(found), axis=0)
            shifts[name] = int(shift)
            out_path = os.path.join(m.OUT, name)
            if mask.any():
                out = np.zeros((mask.shape[0], m.W, 4), np.uint8)
                out[..., 3] = mask * 255
                save_art(Image.fromarray(out, 'RGBA'), out_path)
                names.add(name)
            else:
                names.discard(name)
                if os.path.exists(out_path):
                    os.remove(out_path)
            print(name, len(found), 'frames, shift', shift, 'people px', int(mask.sum()), flush=True)
    index['masks'] = sorted(names)
    index['shifts'] = dict(sorted(shifts.items()))
    json.dump(index, open(INDEX, 'w', encoding='utf8'), indent=1)


if __name__ == '__main__':
    catalog()
    vanishing()
    masks()
