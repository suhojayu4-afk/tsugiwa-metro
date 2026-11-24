"""Fukuoka lines: the Fukuoka City Subway (Kuko, Hakozaki, Nanakuma lines),
stations in running order, with readings.

Positions come from OpenStreetMap station nodes (osm/stations.json);
English and Korean names from their name:en / name:ko, otherwise spelt from
the reading. Headways and run times are estimates, like the Tokyo data.
"""

KANA = {
    '姪浜': 'めいのはま', '室見': 'むろみ', '藤崎': 'ふじさき', '西新': 'にしじん', '唐人町': 'とうじんまち',
    '大濠公園': 'おおほりこうえん', '赤坂': 'あかさか', '天神': 'てんじん', '中洲川端': 'なかすかわばた', '祇園': 'ぎおん',
    '博多': 'はかた', '東比恵': 'ひがしひえ', '福岡空港': 'ふくおかくうこう',
    '呉服町': 'ごふくまち', '千代県庁口': 'ちよけんちょうぐち', '馬出九大病院前': 'まいだしきゅうだいびょういんまえ',
    '箱崎宮前': 'はこざきみやまえ', '箱崎九大前': 'はこざききゅうだいまえ', '貝塚': 'かいづか',
    '橋本': 'はしもと', '次郎丸': 'じろうまる', '賀茂': 'かも', '野芥': 'のけ', '梅林': 'うめばやし', '福大前': 'ふくだいまえ',
    '七隈': 'ななくま', '金山': 'かなやま', '茶山': 'ちゃやま', '別府': 'べふ', '六本松': 'ろっぽんまつ', '桜坂': 'さくらざか',
    '薬院大通': 'やくいんおおどおり', '薬院': 'やくいん', '渡辺通': 'わたなべどおり', '天神南': 'てんじんみなみ',
    '櫛田神社前': 'くしだじんじゃまえ',
}
EN_FIX = {'西新': 'Nishijin', '中洲川端': 'Nakasu-Kawabata', '福岡空港': 'Fukuoka Airport', '大濠公園': 'Ohorikoen',
          '馬出九大病院前': 'Maidashi Kyudai-byoin-mae', '箱崎九大前': 'Hakozaki Kyudai-mae', '箱崎宮前': 'Hakozakimiyamae',
          '千代県庁口': 'Chiyo Kencho-guchi', '福大前': 'Fukudai-mae', '薬院大通': 'Yakuin-odori', '天神南': 'Tenjin-minami',
          '櫛田神社前': 'Kushida Jinja-mae', '東比恵': 'Higashi-Hie', '博多': 'Hakata', '天神': 'Tenjin',
          '渡辺通': 'Watanabe-dori', '唐人町': 'Tojinmachi', '呉服町': 'Gofukumachi'}
KO_FIX = {'西新': '니시진', '中洲川端': '나카스카와바타', '福岡空港': '후쿠오카 공항', '博多': '하카타', '天神': '덴진',
          '大濠公園': '오호리 공원'}


def L(key, ja, ko, en, color, stations, kind='metro', group='metro', forward=None, reverse=None, loop=False):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse, loop=loop)


def toward(ja, ko, en):
    return {'ja': f'{ja}方面', 'ko': f'{ko} 방면', 'en': f'for {en}'}


LINES = [
    L('kuko', '空港線', '공항선', 'Kuko Line', '#F08300',
      ['姪浜', '室見', '藤崎', '西新', '唐人町', '大濠公園', '赤坂', '天神', '中洲川端', '祇園', '博多', '東比恵', '福岡空港'],
      forward=toward('福岡空港', '후쿠오카 공항', 'Fukuoka Airport'), reverse=toward('姪浜', '메이노하마', 'Meinohama')),
    L('hakozaki', '箱崎線', '하코자키선', 'Hakozaki Line', '#0072BC',
      ['中洲川端', '呉服町', '千代県庁口', '馬出九大病院前', '箱崎宮前', '箱崎九大前', '貝塚'],
      forward=toward('貝塚', '가이즈카', 'Kaizuka'), reverse=toward('中洲川端', '나카스카와바타', 'Nakasu-Kawabata')),
    L('nanakuma', '七隈線', '나나쿠마선', 'Nanakuma Line', '#00A54F',
      ['橋本', '次郎丸', '賀茂', '野芥', '梅林', '福大前', '七隈', '金山', '茶山', '別府', '六本松', '桜坂', '薬院大通', '薬院',
       '渡辺通', '天神南', '櫛田神社前', '博多'],
      forward=toward('博多', '하카타', 'Hakata'), reverse=toward('橋本', '하시모토', 'Hashimoto')),
]

_METRO = [('05:30', '07:00', 8), ('07:00', '09:30', 4), ('09:30', '17:00', 7), ('17:00', '20:00', 5),
          ('20:00', '24:00', 8)]
HEADWAY = {l['key']: _METRO for l in LINES}
FIRST_LAST = {'kuko': ('05:30', '24:25'), 'hakozaki': ('05:30', '24:15'), 'nanakuma': ('05:30', '24:15')}
