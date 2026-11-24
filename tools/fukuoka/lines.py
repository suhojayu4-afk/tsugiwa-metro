"""Fukuoka lines: the Fukuoka City Subway (Kuko, Hakozaki, Nanakuma lines),
the Nishitetsu Tenjin-Omuta Line (to Futsukaichi) with the Dazaifu Line, and
the JR Kagoshima Main Line through Hakata (Kashii to Futsukaichi),
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
    # Nishitetsu
    '西鉄福岡（天神）': 'にしてつふくおか（てんじん）', '西鉄平尾': 'にしてつひらお', '高宮': 'たかみや', '大橋': 'おおはし',
    '井尻': 'いじり', '雑餉隈': 'ざっしょのくま', '春日原': 'かすがばる', '白木原': 'しらきばる', '下大利': 'しもおおり',
    '都府楼前': 'とふろうまえ', '西鉄二日市': 'にしてつふつかいち', '西鉄五条': 'にしてつごじょう', '太宰府': 'だざいふ',
    # JR Kagoshima Main Line
    '香椎': 'かしい', '千早': 'ちはや', '箱崎': 'はこざき', '吉塚': 'よしづか', '竹下': 'たけした', '笹原': 'ささばる',
    '南福岡': 'みなみふくおか', '春日': 'かすが', '大野城': 'おおのじょう', '水城': 'みずき', '都府楼南': 'とふろうみなみ',
    '二日市': 'ふつかいち',
}
EN_FIX = {'西新': 'Nishijin', '中洲川端': 'Nakasu-Kawabata', '福岡空港': 'Fukuoka Airport', '大濠公園': 'Ohorikoen',
          '馬出九大病院前': 'Maidashi Kyudai-byoin-mae', '箱崎九大前': 'Hakozaki Kyudai-mae', '箱崎宮前': 'Hakozakimiyamae',
          '千代県庁口': 'Chiyo Kencho-guchi', '福大前': 'Fukudai-mae', '薬院大通': 'Yakuin-odori', '天神南': 'Tenjin-minami',
          '櫛田神社前': 'Kushida Jinja-mae', '東比恵': 'Higashi-Hie', '博多': 'Hakata', '天神': 'Tenjin',
          '渡辺通': 'Watanabe-dori', '唐人町': 'Tojinmachi', '呉服町': 'Gofukumachi',
          '西鉄福岡（天神）': 'Nishitetsu-Fukuoka (Tenjin)', '西鉄平尾': 'Nishitetsu-Hirao', '下大利': 'Shimo-Ori',
          '西鉄二日市': 'Nishitetsu-Futsukaichi', '西鉄五条': 'Nishitetsu-Gojo', '南福岡': 'Minami-Fukuoka',
          '都府楼南': 'Tofuro-Minami', '大橋': 'Ohashi', '大野城': 'Onojo'}
KO_FIX = {'西新': '니시진', '中洲川端': '나카스카와바타', '福岡空港': '후쿠오카 공항', '博多': '하카타', '天神': '덴진',
          # the Tokyo spelling: 前 -마에, 公園 -코엔
          '大濠公園': '오호리코엔', '福大前': '후쿠다이마에', '箱崎宮前': '하코자키미야마에', '箱崎九大前': '하코자키큐다이마에',
          '馬出九大病院前': '마이다시큐다이뵤인마에', '櫛田神社前': '구시다진자마에', '千代県庁口': '지요켄초구치',
          '西鉄福岡（天神）': '니시테쓰후쿠오카(덴진)', '西鉄五条': '니시테쓰고조', '香椎': '가시이', '都府楼前': '도후로마에',
          '都府楼南': '도후로미나미'}
SID_FIX = {'西鉄福岡（天神）': 'nishitetsu-fukuoka'}


def L(key, ja, ko, en, color, stations, kind='metro', group='metro', forward=None, reverse=None, loop=False,
      operator=None):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse, loop=loop, operator=operator)


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
    L('tenjin_omuta', '西鉄天神大牟田線', '니시테쓰 덴진오무타선', 'Nishitetsu Tenjin-Omuta Line', '#1B4C9C',
      ['西鉄福岡（天神）', '薬院', '西鉄平尾', '高宮', '大橋', '井尻', '雑餉隈', '春日原', '白木原', '下大利', '都府楼前',
       '西鉄二日市'], kind='local', group='nishitetsu', operator='西日本鉄道|西鉄',
      forward=toward('西鉄二日市・大牟田', '니시테쓰후쓰카이치·오무타', 'Nishitetsu-Futsukaichi / Omuta'),
      reverse=toward('西鉄福岡（天神）', '니시테쓰후쿠오카(덴진)', 'Nishitetsu-Fukuoka (Tenjin)')),
    L('dazaifu', '西鉄太宰府線', '니시테쓰 다자이후선', 'Nishitetsu Dazaifu Line', '#7D5BA6',
      ['西鉄二日市', '西鉄五条', '太宰府'], kind='local', group='nishitetsu', operator='西日本鉄道|西鉄',
      forward=toward('太宰府', '다자이후', 'Dazaifu'),
      reverse=toward('西鉄二日市', '니시테쓰후쓰카이치', 'Nishitetsu-Futsukaichi')),
    L('kagoshima', 'JR鹿児島本線', 'JR 가고시마 본선', 'JR Kagoshima Main Line', '#EE3D49',
      ['香椎', '千早', '箱崎', '吉塚', '博多', '竹下', '笹原', '南福岡', '春日', '大野城', '水城', '都府楼南', '二日市'],
      kind='local', group='jr', operator='JR|九州旅客鉄道',
      forward=toward('二日市・久留米', '후쓰카이치·구루메', 'Futsukaichi / Kurume'),
      reverse=toward('香椎・小倉', '가시이·고쿠라', 'Kashii / Kokura')),
]

_METRO = [('05:30', '07:00', 8), ('07:00', '09:30', 4), ('09:30', '17:00', 7), ('17:00', '20:00', 5),
          ('20:00', '24:00', 8)]
HEADWAY = {l['key']: _METRO for l in LINES}
HEADWAY['tenjin_omuta'] = [('05:00', '07:00', 10), ('07:00', '09:30', 5), ('09:30', '17:00', 7),
                           ('17:00', '20:00', 6), ('20:00', '24:00', 10)]
HEADWAY['dazaifu'] = [('05:30', '07:00', 15), ('07:00', '20:00', 10), ('20:00', '24:00', 15)]
HEADWAY['kagoshima'] = [('05:00', '07:00', 12), ('07:00', '09:30', 6), ('09:30', '17:00', 8), ('17:00', '20:00', 7),
                        ('20:00', '24:00', 12)]
FIRST_LAST = {'kuko': ('05:30', '24:25'), 'hakozaki': ('05:30', '24:15'), 'nanakuma': ('05:30', '24:15'),
              'tenjin_omuta': ('05:00', '24:25'), 'dazaifu': ('05:50', '24:00'), 'kagoshima': ('05:10', '24:30')}

# Changes between stations of different names, on foot (minutes, rough, from the station maps).
WALKS = [('西鉄福岡（天神）', '天神', 3), ('西鉄福岡（天神）', '天神南', 4), ('天神', '天神南', 7)]
