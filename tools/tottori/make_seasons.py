"""Seasonal decorations on the Tottori route map (assets/cities/tottori/
seasons.json, drawn by lib/features/route_map/map_seasons.dart): New Year
shrine visits, cherry blossoms, fireworks, autumn leaves on Daisen and
Mitoku, winter lights. The projection is build_map.py's flat one (55 map
units a km from the ground's north-west corner).

  python -X utf8 tools/tottori/make_seasons.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'cities', 'tottori', 'seasons.json')


def t(ja, ko, en):
    return {'ja': ja, 'ko': ko, 'en': en}


def spot(season, kind, name, lat, lng, landmark=None, count=None):
    s = {'season': season, 'kind': kind, 'name': name, 'lat': lat, 'lng': lng}
    if landmark:
        s['landmark'] = landmark
    if count:
        s['count'] = count
    return s


data = {
    'about': 'Seasonal decorations on the Tottori route map (tools/tottori/make_seasons.py). from/to are month-day '
             'in Japan; lat/lng go through the flat projection of tools/tottori/build_map.py; "landmark" = gather '
             'round that landmark picture.',
    'projection': {'center': [35.66, 133.02], 'kmLng': 90.9, 'kmLat': 111.0, 'units': 55, 'power': 1.0,
                   'far': 1000.0, 'soft': 0.0, 'origin': [0, 0]},
    'seasons': [
        {'id': 'hatsumode', 'from': '01-01', 'to': '01-07', 'name': t('初詣', '하쓰모데 (새해 참배)', 'New Year shrine visits')},
        {'id': 'sakura', 'from': '03-28', 'to': '04-15', 'name': t('お花見', '벚꽃 구경', 'Cherry blossoms')},
        {'id': 'hanabi', 'from': '07-15', 'to': '08-31', 'name': t('花火大会', '불꽃놀이', 'Fireworks festivals')},
        {'id': 'koyo', 'from': '10-15', 'to': '11-25', 'name': t('紅葉狩り', '단풍 구경', 'Autumn leaves')},
        {'id': 'illumination', 'from': '11-20', 'to': '12-25', 'name': t('イルミネーション', '일루미네이션', 'Winter illuminations')},
    ],
    'spots': [
        spot('hatsumode', 'shrine', t('白兎神社', '하쿠토 신사', 'Hakuto Shrine'), 35.5157, 134.0717, 'hakuto'),
        spot('hatsumode', 'shrine', t('宇倍神社', '우베 신사', 'Ube Shrine'), 35.4535, 134.2550),
        spot('hatsumode', 'temple', t('大山寺', '다이센지', 'Daisen-ji'), 35.3890, 133.5390),
        spot('hatsumode', 'temple', t('三佛寺', '산부쓰지', 'Sanbutsu-ji'), 35.3880, 133.9440, 'nageiredo'),
        spot('sakura', 'sakura', t('久松公園（鳥取城跡）', '히사마쓰 공원 (돗토리성 터)', 'Kyusho Park, Tottori Castle'),
             35.5105, 134.2388, 'jinpukaku', 6),
        spot('sakura', 'sakura', t('湊山公園（米子城跡）', '미나토야마 공원 (요나고성 터)', 'Minatoyama Park, Yonago Castle'),
             35.4280, 133.3230, 'yonago_castle', 5),
        spot('sakura', 'sakura', t('打吹公園', '우쓰부키 공원', 'Utsubuki Park'), 35.4275, 133.8270, 'kurayoshi', 5),
        spot('sakura', 'sakura', t('東郷湖畔', '도고 호반', 'Lake Togo shore'), 35.4870, 133.8860, 'togo', 4),
        spot('sakura', 'sakura', t('若桜鉄道沿線', '와카사 철도 연선', 'Along the Wakasa Railway'), 35.3600, 134.3200,
             count=4),
        spot('hanabi', 'hanabi', t('鳥取市民納涼花火大会', '돗토리 시민 납량 불꽃놀이', 'Tottori summer fireworks'),
             35.5180, 134.1950),
        spot('hanabi', 'hanabi', t('がいな祭 花火', '가이나 축제 불꽃놀이', 'Gaina Festival fireworks'), 35.4420, 133.3500),
        spot('hanabi', 'hanabi', t('東郷湖 水郷祭', '도고호 스이고 축제', 'Lake Togo water festival'), 35.4800, 133.8950,
             'togo'),
        spot('hanabi', 'hanabi', t('境港 みなと祭', '사카이미나토 항구 축제', 'Sakaiminato port festival'), 35.5450,
             133.2450, 'sakaiminato'),
        spot('koyo', 'momiji', t('大山', '다이센', 'Mt. Daisen'), 35.3712, 133.5463, 'daisen_big', 7),
        spot('koyo', 'momiji', t('三徳山', '미토쿠산', 'Mt. Mitoku'), 35.3880, 133.9440, 'nageiredo', 5),
        spot('koyo', 'momiji', t('芦津渓谷', '아시즈 계곡', 'Ashizu Gorge'), 35.2300, 134.3200, count=4),
        spot('koyo', 'mixed', t('とっとり花回廊', '돗토리 하나카이로', 'Tottori Flower Park'), 35.3700, 133.4200,
             'hanakairo', 4),
        spot('illumination', 'lights', t('鳥取駅前', '돗토리역 앞', 'Tottori Station square'), 35.4960, 134.2270),
        spot('illumination', 'lights', t('米子駅前', '요나고역 앞', 'Yonago Station square'), 35.4250, 133.3380),
        spot('illumination', 'lights', t('とっとり花回廊 ウィンターイルミネーション', '돗토리 하나카이로 겨울 일루미네이션',
                                         'Tottori Flower Park winter lights'), 35.3700, 133.4200, 'hanakairo', 5),
    ],
}
json.dump(data, open(OUT, 'w', encoding='utf8'), ensure_ascii=False, indent=1)
print(len(data['spots']), 'spots')
