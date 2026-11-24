"""Sapporo lines: the Sapporo City Subway (Namboku, Tozai, Toho lines), the
streetcar loop and the JR Hakodate Line to Otaru, stations in running
order, with readings.

The subway's さっぽろ and JR Sapporo are one station here (they are joined
underground); the JR station of a name the subway also has is written
'<name>#JR' (Kotoni). Positions come from OpenStreetMap station and tram
stop nodes (osm/stations.json). Headways and run times are estimates.
"""

KANA = {
    # Namboku
    '麻生': 'あさぶ', '北34条': 'きたさんじゅうよじょう', '北24条': 'きたにじゅうよじょう', '北18条': 'きたじゅうはちじょう',
    '北12条': 'きたじゅうにじょう', '札幌': 'さっぽろ', 'さっぽろ': 'さっぽろ', '大通': 'おおどおり', 'すすきの': 'すすきの',
    '中島公園': 'なかじまこうえん', '幌平橋': 'ほろひらばし', '中の島': 'なかのしま', '平岸': 'ひらぎし',
    '南平岸': 'みなみひらぎし', '澄川': 'すみかわ', '自衛隊前': 'じえいたいまえ', '真駒内': 'まこまない',
    # Tozai
    '宮の沢': 'みやのさわ', '発寒南': 'はっさむみなみ', '琴似': 'ことに', '二十四軒': 'にじゅうよんけん',
    '西28丁目': 'にしにじゅうはっちょうめ', '円山公園': 'まるやまこうえん', '西18丁目': 'にしじゅうはっちょうめ',
    '西11丁目': 'にしじゅういっちょうめ', 'バスセンター前': 'ばすせんたーまえ', '菊水': 'きくすい', '東札幌': 'ひがしさっぽろ',
    '白石': 'しろいし', '南郷7丁目': 'なんごうななちょうめ', '南郷13丁目': 'なんごうじゅうさんちょうめ',
    '南郷18丁目': 'なんごうじゅうはっちょうめ', '大谷地': 'おおやち', 'ひばりが丘': 'ひばりがおか', '新さっぽろ': 'しんさっぽろ',
    # Toho
    '栄町': 'さかえまち', '新道東': 'しんどうひがし', '元町': 'もとまち', '環状通東': 'かんじょうどおりひがし',
    '東区役所前': 'ひがしくやくしょまえ', '北13条東': 'きたじゅうさんじょうひがし', '豊水すすきの': 'ほうすいすすきの',
    '学園前': 'がくえんまえ', '豊平公園': 'とよひらこうえん', '美園': 'みその', '月寒中央': 'つきさむちゅうおう', '福住': 'ふくずみ',
    # Streetcar
    '西4丁目': 'にしよんちょうめ', '西8丁目': 'にしはっちょうめ', '中央区役所前': 'ちゅうおうくやくしょまえ',
    '西15丁目': 'にしじゅうごちょうめ', '西線6条': 'にせんろくじょう', '西線9条旭山公園通': 'にせんくじょうあさひやまこうえんどおり',
    '西線11条': 'にせんじゅういちじょう', '西線14条': 'にせんじゅうよじょう', '西線16条': 'にせんじゅうろくじょう',
    'ロープウェイ入口': 'ろーぷうぇいいりぐち', '電車事業所前': 'でんしゃじぎょうしょまえ', '中央図書館前': 'ちゅうおうとしょかんまえ',
    '石山通': 'いしやまどおり', '東屯田通': 'ひがしとんでんどおり', '幌南小学校前': 'こうなんしょうがっこうまえ',
    '山鼻19条': 'やまはなじゅうくじょう', '静修学園前': 'せいしゅうがくえんまえ', '行啓通': 'ぎょうけいどおり',
    '中島公園通': 'なかじまこうえんどおり', '山鼻9条': 'やまはなくじょう', '東本願寺前': 'ひがしほんがんじまえ',
    '資生館小学校前': 'しせいかんしょうがっこうまえ', '狸小路': 'たぬきこうじ',
    # JR Hakodate Line
    '桑園': 'そうえん', '発寒中央': 'はっさむちゅうおう', '発寒': 'はっさむ', '稲積公園': 'いなづみこうえん', '手稲': 'ていね',
    '稲穂': 'いなほ', '星置': 'ほしおき', 'ほしみ': 'ほしみ', '銭函': 'ぜにばこ', '朝里': 'あさり', '小樽築港': 'おたるちっこう',
    '南小樽': 'みなみおたる', '小樽': 'おたる',
}
EN_FIX = {'札幌': 'Sapporo', '大通': 'Odori', '小樽': 'Otaru', 'すすきの': 'Susukino', '琴似#JR': 'Kotoni (JR)',
          '北34条': 'Kita 34-jo', '北24条': 'Kita 24-jo', '北18条': 'Kita 18-jo', '北12条': 'Kita 12-jo',
          '北13条東': 'Kita 13-jo Higashi', '西28丁目': 'Nishi 28-chome', '西18丁目': 'Nishi 18-chome',
          '西11丁目': 'Nishi 11-chome', '西4丁目': 'Nishi 4-chome', '西8丁目': 'Nishi 8-chome', '西15丁目': 'Nishi 15-chome',
          '南郷7丁目': 'Nango 7-chome', '南郷13丁目': 'Nango 13-chome', '南郷18丁目': 'Nango 18-chome',
          '西線6条': 'Nishisen 6-jo', '西線9条旭山公園通': 'Nishisen 9-jo Asahiyama-koen-dori', '西線11条': 'Nishisen 11-jo',
          '西線14条': 'Nishisen 14-jo', '西線16条': 'Nishisen 16-jo', '山鼻19条': 'Yamahana 19-jo', '山鼻9条': 'Yamahana 9-jo',
          'ロープウェイ入口': 'Ropeway-iriguchi', 'バスセンター前': 'Bus Center-mae', '新さっぽろ': 'Shin-Sapporo',
          '東札幌': 'Higashi-Sapporo', '豊水すすきの': 'Hosui-Susukino', '円山公園': 'Maruyama-koen', '中島公園': 'Nakajima-koen',
          '中島公園通': 'Nakajima-koen-dori', '小樽築港': 'Otaru-Chikko', '南小樽': 'Minami-Otaru', '稲積公園': 'Inazumi-koen',
          '発寒中央': 'Hassamu-Chuo', '発寒南': 'Hassamu-Minami', '月寒中央': 'Tsukisamu-Chuo', '豊平公園': 'Toyohira-koen',
          '環状通東': 'Kanjo-dori-Higashi', '東区役所前': 'Higashi-Kuyakusho-mae', '中央区役所前': 'Chuo-Kuyakusho-mae',
          '電車事業所前': 'Densha-Jigyosho-mae', '中央図書館前': 'Chuo-Toshokan-mae', '幌南小学校前': 'Konan-Shogakko-mae',
          '資生館小学校前': 'Shiseikan-Shogakko-mae', '静修学園前': 'Seishu-Gakuen-mae', '東本願寺前': 'Higashi-Honganji-mae',
          '狸小路': 'Tanukikoji', '自衛隊前': 'Jieitai-mae'}
KO_FIX = {'札幌': '삿포로', '大通': '오도리', '小樽': '오타루', 'すすきの': '스스키노', '琴似#JR': '고토니(JR)',
          'ロープウェイ入口': '로프웨이 입구', 'バスセンター前': '버스센터마에', '新さっぽろ': '신삿포로', '狸小路': '다누키코지'}


def L(key, ja, ko, en, color, stations, kind='metro', group='metro', forward=None, reverse=None, loop=False,
      operator=None):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse, loop=loop, operator=operator)


def toward(ja, ko, en):
    return {'ja': f'{ja}方面', 'ko': f'{ko} 방면', 'en': f'for {en}'}


LINES = [
    L('namboku', '南北線', '난보쿠선', 'Namboku Line', '#008F3E',
      ['麻生', '北34条', '北24条', '北18条', '北12条', '札幌', '大通', 'すすきの', '中島公園', '幌平橋', '中の島', '平岸', '南平岸',
       '澄川', '自衛隊前', '真駒内'],
      forward=toward('真駒内', '마코마나이', 'Makomanai'), reverse=toward('麻生', '아사부', 'Asabu')),
    L('tozai', '東西線', '도자이선', 'Tozai Line', '#F39800',
      ['宮の沢', '発寒南', '琴似', '二十四軒', '西28丁目', '円山公園', '西18丁目', '西11丁目', '大通', 'バスセンター前', '菊水',
       '東札幌', '白石', '南郷7丁目', '南郷13丁目', '南郷18丁目', '大谷地', 'ひばりが丘', '新さっぽろ'],
      forward=toward('新さっぽろ', '신삿포로', 'Shin-Sapporo'), reverse=toward('宮の沢', '미야노사와', 'Miyanosawa')),
    L('toho', '東豊線', '도호선', 'Toho Line', '#0079C2',
      ['栄町', '新道東', '元町', '環状通東', '東区役所前', '北13条東', '札幌', '大通', '豊水すすきの', '学園前', '豊平公園', '美園',
       '月寒中央', '福住'],
      forward=toward('福住', '후쿠즈미', 'Fukuzumi'), reverse=toward('栄町', '사카에마치', 'Sakaemachi')),
    L('streetcar', '札幌市電', '삿포로 시덴(노면전차)', 'Sapporo Streetcar', '#7D5BA6',
      ['西4丁目', '西8丁目', '中央区役所前', '西15丁目', '西線6条', '西線9条旭山公園通', '西線11条', '西線14条', '西線16条',
       'ロープウェイ入口', '電車事業所前', '中央図書館前', '石山通', '東屯田通', '幌南小学校前', '山鼻19条', '静修学園前', '行啓通',
       '中島公園通', '山鼻9条', '東本願寺前', '資生館小学校前', 'すすきの', '狸小路'], kind='tram', group='streetcar',
      forward=toward('西線・ロープウェイ入口', '니시센·로프웨이 입구', 'Nishisen / Ropeway'),
      reverse=toward('すすきの・狸小路', '스스키노·다누키코지', 'Susukino / Tanukikoji'), loop=True),
    L('hakodate', 'JR函館本線', 'JR 하코다테 본선', 'JR Hakodate Line', '#D2493B',
      ['札幌', '桑園', '琴似#JR', '発寒中央', '発寒', '稲積公園', '手稲', '稲穂', '星置', 'ほしみ', '銭函', '朝里', '小樽築港',
       '南小樽', '小樽'], kind='local', group='jr', operator='JR|北海道旅客鉄道',
      forward=toward('小樽', '오타루', 'Otaru'), reverse=toward('札幌', '삿포로', 'Sapporo')),
]

_METRO = [('06:00', '07:00', 7), ('07:00', '09:00', 4), ('09:00', '17:00', 7), ('17:00', '19:30', 5),
          ('19:30', '24:00', 8)]
HEADWAY = {'namboku': _METRO, 'tozai': _METRO, 'toho': _METRO,
           'streetcar': [('06:20', '07:00', 10), ('07:00', '20:00', 7), ('20:00', '23:30', 10)],
           'hakodate': [('05:30', '07:00', 20), ('07:00', '09:00', 10), ('09:00', '17:00', 15), ('17:00', '20:00', 12),
                        ('20:00', '24:00', 20)]}
FIRST_LAST = {'namboku': ('06:00', '24:20'), 'tozai': ('06:00', '24:15'), 'toho': ('06:00', '24:15'),
              'streetcar': ('06:20', '23:30'), 'hakodate': ('05:50', '23:50')}
