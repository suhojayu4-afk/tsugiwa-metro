"""Tottori items in the MY shop (assets/my/catalog.json): the station scenes
(鳥取 / 米子 / 境港 / 恋山形), the diesel railcar, and a reward for finishing
each local line. Items already there are replaced, so it can be run again.

  python -X utf8 tools/tottori/add_catalog.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PATH = os.path.join(ROOT, 'assets', 'my', 'catalog.json')


def t(ja, ko, en):
    return {'ja': ja, 'ko': ko, 'en': en}


def scene(key, station, name):
    return {'id': f'scene.tottori_{key}', 'slot': 'scene', 'name': name, 'price': 1000, 'priceYen': 250,
            'images': {p: f'assets/art/tottori/scenes/{key}_{p}.webp' for p in ('day', 'evening', 'night')},
            'station': f'tottori.{station}'}


ITEMS = [
    scene('tottori', 'tottori', t('鳥取', '돗토리', 'Tottori')),
    scene('yonago', 'yonago', t('米子', '요나고', 'Yonago')),
    scene('sakaiminato', 'sakaiminato', t('境港', '사카이미나토', 'Sakaiminato')),
    scene('koiyamagata', 'koi_yamagata', t('恋山形', '고이야마가타', 'Koi-Yamagata')),
    {'id': 'train.kidosha', 'slot': 'train', 'name': t('のんびり気動車', '느긋한 기동차', 'Easygoing railcar'),
     'price': 3000, 'art': 'assets/art/tottori/diesel'},
    # Finish a line, get its colour.
    {'id': 'plate.sanin', 'slot': 'plate', 'name': t('山陰ブルー', '산인 블루', 'San\'in blue'), 'price': 0,
     'unlock': 'line:tottori.sanin', 'plate': {'led': ['#5AB4FF', '#FFFFFF']}},
    {'id': 'train.sakai', 'slot': 'train', 'name': t('境線むらさき号', '사카이선 보라호', 'Sakai purple'), 'price': 0,
     'unlock': 'line:tottori.sakai', 'color': '#8A5CB8'},
    {'id': 'plate.inbi', 'slot': 'plate', 'name': t('因美オレンジ', '인비 오렌지', 'Inbi orange'), 'price': 0,
     'unlock': 'line:tottori.inbi', 'plate': {'led': ['#FFA040', '#FFE6B0']}},
    {'id': 'train.wakasa', 'slot': 'train', 'name': t('若桜みどり号', '와카사 초록호', 'Wakasa green'), 'price': 0,
     'unlock': 'line:tottori.wakasa', 'color': '#2E9E5B'},
    {'id': 'plate.koi', 'slot': 'plate', 'name': t('恋山形ピンク', '고이야마가타 핑크', 'Koi-Yamagata pink'), 'price': 0,
     'unlock': 'line:tottori.chizukyu', 'plate': {'led': ['#FF7FB8', '#FFFFFF']}},
    {'id': 'train.hakubi', 'slot': 'train', 'name': t('やまなみ号', '야마나미호', 'Yamanami'), 'price': 0,
     'unlock': 'line:tottori.hakubi', 'color': '#12998A'},
]

cat = json.load(open(PATH, encoding='utf8'))
ids = {i['id'] for i in ITEMS}
items = [i for i in cat['items'] if i['id'] not in ids]
# Next to their kind: scenes after the last scene, and so on.
for it in ITEMS:
    last = max((k for k, i in enumerate(items) if i['slot'] == it['slot']), default=len(items) - 1)
    items.insert(last + 1, it)
cat['items'] = items
json.dump(cat, open(PATH, 'w', encoding='utf8'), ensure_ascii=False, indent=2)
open(PATH, 'a', encoding='utf8').write('\n')
print(len(ITEMS), 'Tottori items;', len(items), 'in all')
