"""Sendai lines: the Sendai City Subway (Namboku, Tozai lines) and the JR
Senseki Line to Matsushima-Kaigan, stations in running order, with readings.

Positions come from OpenStreetMap station nodes (osm/stations.json);
English and Korean names from their name:en / name:ko, otherwise spelt from
the reading. Headways and run times are estimates, like the Tokyo data.
"""

KANA = {
    '泉中央': 'いずみちゅうおう', '八乙女': 'やおとめ', '黒松': 'くろまつ', '旭ケ丘': 'あさひがおか', '台原': 'だいのはら',
    '北仙台': 'きたせんだい', '北四番丁': 'きたよばんちょう', '勾当台公園': 'こうとうだいこうえん', '広瀬通': 'ひろせどおり',
    '仙台': 'せんだい', '五橋': 'いつつばし', '愛宕橋': 'あたごばし', '河原町': 'かわらまち', '長町一丁目': 'ながまちいっちょうめ',
    '長町': 'ながまち', '長町南': 'ながまちみなみ', '富沢': 'とみざわ',
    '八木山動物公園': 'やぎやまどうぶつこうえん', '青葉山': 'あおばやま', '川内': 'かわうち', '国際センター': 'こくさいせんたー',
    '大町西公園': 'おおまちにしこうえん', '青葉通一番町': 'あおばどおりいちばんちょう', '宮城野通': 'みやぎのどおり',
    '連坊': 'れんぼう', '薬師堂': 'やくしどう', '卸町': 'おろしまち', '六丁の目': 'ろくちょうのめ', '荒井': 'あらい',
    'あおば通': 'あおばどおり', '榴ケ岡': 'つつじがおか', '宮城野原': 'みやぎのはら', '陸前原ノ町': 'りくぜんはらのまち',
    '苦竹': 'にがたけ', '小鶴新田': 'こづるしんでん', '福田町': 'ふくだまち', '陸前高砂': 'りくぜんたかさご',
    '中野栄': 'なかのさかえ', '多賀城': 'たがじょう', '下馬': 'げば', '西塩釜': 'にししおがま', '本塩釜': 'ほんしおがま',
    '東塩釜': 'ひがししおがま', '陸前浜田': 'りくぜんはまだ', '松島海岸': 'まつしまかいがん',
}
EN_FIX = {'松島海岸': 'Matsushima-Kaigan', '仙台': 'Sendai', '八木山動物公園': 'Yagiyama Zoological Park',
          '国際センター': 'International Center', '青葉通一番町': 'Aobadori Ichibancho', '長町一丁目': 'Nagamachi 1-chome',
          '勾当台公園': 'Kotodai-koen', '大町西公園': 'Omachi Nishi-koen', '泉中央': 'Izumi-Chuo', 'あおば通': 'Aoba-dori',
          '旭ケ丘': 'Asahigaoka', '榴ケ岡': 'Tsutsujigaoka', '陸前原ノ町': 'Rikuzen-Haranomachi', '六丁の目': 'Rokuchonome',
          '宮城野通': 'Miyagino-dori', '広瀬通': 'Hirose-dori', '北四番丁': 'Kita-Yobancho', '本塩釜': 'Hon-Shiogama',
          '西塩釜': 'Nishi-Shiogama', '東塩釜': 'Higashi-Shiogama'}
KO_FIX = {'仙台': '센다이', '松島海岸': '마쓰시마카이간', '八木山動物公園': '야기야마 동물공원', '国際センター': '국제센터'}


def L(key, ja, ko, en, color, stations, kind='metro', group='metro', forward=None, reverse=None, loop=False):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse, loop=loop)


def toward(ja, ko, en):
    return {'ja': f'{ja}方面', 'ko': f'{ko} 방면', 'en': f'for {en}'}


LINES = [
    L('namboku', '南北線', '난보쿠선', 'Namboku Line', '#00923F',
      ['泉中央', '八乙女', '黒松', '旭ケ丘', '台原', '北仙台', '北四番丁', '勾当台公園', '広瀬通', '仙台', '五橋', '愛宕橋', '河原町',
       '長町一丁目', '長町', '長町南', '富沢'],
      forward=toward('富沢', '도미자와', 'Tomizawa'), reverse=toward('泉中央', '이즈미추오', 'Izumi-Chuo')),
    L('tozai', '東西線', '도자이선', 'Tozai Line', '#2CA9E1',
      ['八木山動物公園', '青葉山', '川内', '国際センター', '大町西公園', '青葉通一番町', '仙台', '宮城野通', '連坊', '薬師堂', '卸町',
       '六丁の目', '荒井'],
      forward=toward('荒井', '아라이', 'Arai'), reverse=toward('八木山動物公園', '야기야마 동물공원', 'Yagiyama Zoological Park')),
    L('senseki', 'JR仙石線', 'JR 센세키선', 'JR Senseki Line', '#3A5BA9',
      ['あおば通', '仙台', '榴ケ岡', '宮城野原', '陸前原ノ町', '苦竹', '小鶴新田', '福田町', '陸前高砂', '中野栄', '多賀城', '下馬',
       '西塩釜', '本塩釜', '東塩釜', '陸前浜田', '松島海岸'], kind='local', group='jr',
      forward=toward('松島海岸・石巻', '마쓰시마카이간·이시노마키', 'Matsushima-Kaigan / Ishinomaki'),
      reverse=toward('あおば通', '아오바도리', 'Aoba-dori')),
]

_METRO = [('06:00', '07:00', 8), ('07:00', '09:00', 4), ('09:00', '17:00', 7), ('17:00', '19:30', 5),
          ('19:30', '24:00', 10)]
HEADWAY = {'namboku': _METRO, 'tozai': _METRO,
           'senseki': [('05:30', '07:00', 20), ('07:00', '09:00', 8), ('09:00', '17:00', 15), ('17:00', '20:00', 10),
                       ('20:00', '24:00', 20)]}
FIRST_LAST = {'namboku': ('05:45', '24:00'), 'tozai': ('05:40', '24:05'), 'senseki': ('05:30', '23:45')}
