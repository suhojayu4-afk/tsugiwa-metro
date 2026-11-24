"""Osaka lines: Osaka Metro, the JR Osaka Loop Line, the JR Yumesaki Line and the
first stretch of the Keihan, Nankai, Hankyu and Kintetsu lines,
stations in running order, with readings.

Positions come from OpenStreetMap station nodes (osm/stations.json);
English and Korean names from their name:en / name:ko, otherwise spelt from
the reading. Headways and run times are estimates, like the Tokyo data.

L(key, ja, ko, en, colour, stations, kind, group, forward, reverse, loop)
  kind  'metro' | 'local' (run speed, dwell)
"""

KANA = {
    # Midosuji
    '江坂': 'えさか', '東三国': 'ひがしみくに', '新大阪': 'しんおおさか', '西中島南方': 'にしなかじまみなみがた',
    '中津': 'なかつ', '梅田': 'うめだ', '淀屋橋': 'よどやばし', '本町': 'ほんまち', '心斎橋': 'しんさいばし',
    'なんば': 'なんば', '大国町': 'だいこくちょう', '動物園前': 'どうぶつえんまえ', '天王寺': 'てんのうじ',
    '昭和町': 'しょうわちょう', '西田辺': 'にしたなべ', '長居': 'ながい', 'あびこ': 'あびこ', '北花田': 'きたはなだ',
    '新金岡': 'しんかなおか', 'なかもず': 'なかもず',
    # Tanimachi
    '大日': 'だいにち', '守口': 'もりぐち', '太子橋今市': 'たいしばしいまいち', '千林大宮': 'せんばやしおおみや',
    '関目高殿': 'せきめたかどの', '野江内代': 'のえうちんだい', '都島': 'みやこじま',
    '天神橋筋六丁目': 'てんじんばしすじろくちょうめ', '中崎町': 'なかざきちょう', '東梅田': 'ひがしうめだ',
    '南森町': 'みなみもりまち', '天満橋': 'てんまばし', '谷町四丁目': 'たにまちよんちょうめ',
    '谷町六丁目': 'たにまちろくちょうめ', '谷町九丁目': 'たにまちきゅうちょうめ',
    '四天王寺前夕陽ヶ丘': 'してんのうじまえゆうひがおか', '阿倍野': 'あべの', '文の里': 'ふみのさと', '田辺': 'たなべ',
    '駒川中野': 'こまがわなかの', '平野': 'ひらの', '喜連瓜破': 'きれうりわり', '出戸': 'でと', '長原': 'ながはら',
    '八尾南': 'やおみなみ',
    # Yotsubashi
    '西梅田': 'にしうめだ', '肥後橋': 'ひごばし', '四ツ橋': 'よつばし', '花園町': 'はなぞのちょう', '岸里': 'きしのさと',
    '玉出': 'たまで', '北加賀屋': 'きたかがや', '住之江公園': 'すみのえこうえん',
    # Chuo
    '夢洲': 'ゆめしま', 'コスモスクエア': 'こすもすくえあ', '大阪港': 'おおさかこう', '朝潮橋': 'あさしおばし',
    '弁天町': 'べんてんちょう', '九条': 'くじょう', '阿波座': 'あわざ', '堺筋本町': 'さかいすじほんまち',
    '森ノ宮': 'もりのみや', '緑橋': 'みどりばし', '深江橋': 'ふかえばし', '高井田': 'たかいだ', '長田': 'ながた',
    # Sennichimae
    '野田阪神': 'のだはんしん', '玉川': 'たまがわ', '西長堀': 'にしながほり', '桜川': 'さくらがわ', '日本橋': 'にっぽんばし',
    '鶴橋': 'つるはし', '今里': 'いまざと', '新深江': 'しんふかえ', '小路': 'しょうじ', '北巽': 'きたたつみ',
    '南巽': 'みなみたつみ',
    # Sakaisuji
    '扇町': 'おうぎまち', '北浜': 'きたはま', '長堀橋': 'ながほりばし', '恵美須町': 'えびすちょう', '天下茶屋': 'てんがちゃや',
    # Nagahori Tsurumi-ryokuchi
    '大正': 'たいしょう', 'ドーム前千代崎': 'どーむまえちよざき', '西大橋': 'にしおおはし', '松屋町': 'まつやまち',
    '玉造': 'たまつくり', '大阪ビジネスパーク': 'おおさかびじねすぱーく', '京橋': 'きょうばし',
    '蒲生四丁目': 'がもうよんちょうめ', '鶴見緑地': 'つるみりょくち', '横堤': 'よこづつみ', '今福鶴見': 'いまふくつるみ',
    '門真南': 'かどまみなみ',
    # Imazatosuji
    '井高野': 'いたかの', '瑞光四丁目': 'ずいこうよんちょうめ', 'だいどう豊里': 'だいどうとよさと', '清水': 'しみず',
    '新森古市': 'しんもりふるいち', '関目成育': 'せきめせいいく', '鴫野': 'しぎの',
    # Nanko Port Town
    'トレードセンター前': 'とれーどせんたーまえ', '中ふ頭': 'なかふとう', 'ポートタウン西': 'ぽーとたうんにし',
    'ポートタウン東': 'ぽーとたうんひがし', 'フェリーターミナル': 'ふぇりーたーみなる', '南港東': 'なんこうひがし',
    '南港口': 'なんこうぐち', '平林': 'ひらばやし',
    # JR Osaka Loop / Yumesaki
    '大阪': 'おおさか', '天満': 'てんま', '桜ノ宮': 'さくらのみや', '大阪城公園': 'おおさかじょうこうえん', '桃谷': 'ももだに',
    '寺田町': 'てらだちょう', '新今宮': 'しんいまみや', '今宮': 'いまみや', '芦原橋': 'あしはらばし', '西九条': 'にしくじょう',
    '野田': 'のだ', '福島': 'ふくしま', '安治川口': 'あじかわぐち', 'ユニバーサルシティ': 'ゆにばーさるしてぃ', '桜島': 'さくらじま',
    # Nankai / Hankyu / Kintetsu
    '岸里玉出': 'きしのさとたまで', '粉浜': 'こはま', '住吉大社': 'すみよしたいしゃ',
    '大阪梅田': 'おおさかうめだ', '十三': 'じゅうそう',
    '大阪難波': 'おおさかなんば', '近鉄日本橋': 'きんてつにっぽんばし', '大阪上本町': 'おおさかうえほんまち', '布施': 'ふせ',
}

EN_FIX = {'野田阪神': 'Noda-Hanshin', 'なんば': 'Namba', 'あびこ': 'Abiko', 'なかもず': 'Nakamozu', '梅田': 'Umeda', '本町': 'Hommachi',
          '日本橋': 'Nippombashi', '天神橋筋六丁目': 'Tenjimbashisuji 6-chome', '谷町四丁目': 'Tanimachi 4-chome',
          '谷町六丁目': 'Tanimachi 6-chome', '谷町九丁目': 'Tanimachi 9-chome', '蒲生四丁目': 'Gamo 4-chome',
          '瑞光四丁目': 'Zuiko 4-chome', '四天王寺前夕陽ヶ丘': 'Shitennoji-mae Yuhigaoka',
          'ドーム前千代崎': 'Dome-mae Chiyozaki', '大阪ビジネスパーク': 'Osaka Business Park',
          'ユニバーサルシティ': 'Universal City', 'コスモスクエア': 'Cosmosquare',
          'トレードセンター前': 'Trade Center-mae', 'フェリーターミナル': 'Ferry Terminal',
          'ポートタウン西': 'Port Town-nishi', 'ポートタウン東': 'Port Town-higashi', '中ふ頭': 'Nakafuto',
          'だいどう豊里': 'Daido-Toyosato', '新大阪': 'Shin-Osaka', '西中島南方': 'Nishinakajima-Minamigata',
          '大阪港': 'Osakako', '大阪城公園': 'Osakajokoen', '新今宮': 'Shin-Imamiya', '桜ノ宮': 'Sakuranomiya',
          '森ノ宮': 'Morinomiya', '四ツ橋': 'Yotsubashi', '大阪': 'Osaka', '天王寺': 'Tennoji', '京橋': 'Kyobashi',
          '岸里玉出': 'Kishinosato-Tamade', '粉浜': 'Kohama', '住吉大社': 'Sumiyoshitaisha', '大阪梅田': 'Osaka-Umeda',
          '中津#阪急': 'Nakatsu', '十三': 'Juso', '大阪難波': 'Osaka-Namba', '近鉄日本橋': 'Kintetsu-Nippombashi',
          '大阪上本町': 'Osaka-Uehommachi', '布施': 'Fuse'}
KO_FIX = {'ユニバーサルシティ': '유니버설시티', 'コスモスクエア': '코스모스퀘어', '大阪ビジネスパーク': '오사카 비즈니스 파크',
          'トレードセンター前': '트레이드센터마에', 'フェリーターミナル': '페리 터미널', 'ドーム前千代崎': '돔마에치요자키',
          'ポートタウン西': '포트타운니시', 'ポートタウン東': '포트타운히가시', '大阪': '오사카', '新大阪': '신오사카',
          '梅田': '우메다', 'なんば': '난바', '天王寺': '덴노지', '心斎橋': '신사이바시',
          # the Tokyo spelling: 前 -마에, 公園 -코엔, N丁目 'N초메' after a space
          '動物園前': '도부쓰엔마에', '住之江公園': '스미노에코엔', '大阪城公園': '오사카조코엔',
          '谷町四丁目': '다니마치 4초메', '谷町六丁目': '다니마치 6초메', '谷町九丁目': '다니마치 9초메',
          '天神橋筋六丁目': '덴진바시스지 6초메', '蒲生四丁目': '가모 4초메', '瑞光四丁目': '즈이코 4초메',
          '四天王寺前夕陽ヶ丘': '시텐노지마에유히가오카', '岸里玉出': '기시노사토타마데', '大阪梅田': '오사카우메다',
          '中津#阪急': '나카쓰', '十三': '주소', '大阪難波': '오사카난바', '近鉄日本橋': '긴테쓰닛폰바시',
          '大阪上本町': '오사카우에혼마치', '住吉大社': '스미요시타이샤'}
# Station ids other than the English name would give (two stations of one name).
SID_FIX = {'中津#阪急': 'hankyu-nakatsu'}


def L(key, ja, ko, en, color, stations, kind='metro', group='metro', forward=None, reverse=None, loop=False,
      operator=None):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse, loop=loop, operator=operator)


def toward(ja, ko, en):
    return {'ja': f'{ja}方面', 'ko': f'{ko} 방면', 'en': f'for {en}'}


LOOP = ['大阪', '天満', '桜ノ宮', '京橋', '大阪城公園', '森ノ宮', '玉造', '鶴橋', '桃谷', '寺田町', '天王寺', '新今宮', '今宮',
        '芦原橋', '大正', '弁天町', '西九条', '野田', '福島']

LINES = [
    L('midosuji', '御堂筋線', '미도스지선', 'Midosuji Line', '#E5171F',
      ['江坂', '東三国', '新大阪', '西中島南方', '中津', '梅田', '淀屋橋', '本町', '心斎橋', 'なんば', '大国町', '動物園前',
       '天王寺', '昭和町', '西田辺', '長居', 'あびこ', '北花田', '新金岡', 'なかもず'],
      forward=toward('なかもず', '나카모즈', 'Nakamozu'), reverse=toward('江坂', '에사카', 'Esaka')),
    L('tanimachi', '谷町線', '다니마치선', 'Tanimachi Line', '#522886',
      ['大日', '守口', '太子橋今市', '千林大宮', '関目高殿', '野江内代', '都島', '天神橋筋六丁目', '中崎町', '東梅田', '南森町',
       '天満橋', '谷町四丁目', '谷町六丁目', '谷町九丁目', '四天王寺前夕陽ヶ丘', '天王寺', '阿倍野', '文の里', '田辺', '駒川中野',
       '平野', '喜連瓜破', '出戸', '長原', '八尾南'],
      forward=toward('八尾南', '야오미나미', 'Yao-Minami'), reverse=toward('大日', '다이니치', 'Dainichi')),
    L('yotsubashi', '四つ橋線', '요쓰바시선', 'Yotsubashi Line', '#0078BA',
      ['西梅田', '肥後橋', '本町', '四ツ橋', 'なんば', '大国町', '花園町', '岸里', '玉出', '北加賀屋', '住之江公園'],
      forward=toward('住之江公園', '스미노에코엔', 'Suminoekoen'), reverse=toward('西梅田', '니시우메다', 'Nishi-Umeda')),
    L('chuo', '中央線', '주오선', 'Chuo Line', '#019A66',
      ['夢洲', 'コスモスクエア', '大阪港', '朝潮橋', '弁天町', '九条', '阿波座', '本町', '堺筋本町', '谷町四丁目', '森ノ宮', '緑橋',
       '深江橋', '高井田', '長田'],
      forward=toward('長田', '나가타', 'Nagata'), reverse=toward('夢洲', '유메시마', 'Yumeshima')),
    L('sennichimae', '千日前線', '센니치마에선', 'Sennichimae Line', '#E44D93',
      ['野田阪神', '玉川', '阿波座', '西長堀', '桜川', 'なんば', '日本橋', '谷町九丁目', '鶴橋', '今里', '新深江', '小路', '北巽',
       '南巽'],
      forward=toward('南巽', '미나미타쓰미', 'Minami-Tatsumi'), reverse=toward('野田阪神', '노다한신', 'Noda-Hanshin')),
    L('sakaisuji', '堺筋線', '사카이스지선', 'Sakaisuji Line', '#814721',
      ['天神橋筋六丁目', '扇町', '南森町', '北浜', '堺筋本町', '長堀橋', '日本橋', '恵美須町', '動物園前', '天下茶屋'],
      forward=toward('天下茶屋', '덴가차야', 'Tengachaya'),
      reverse=toward('天神橋筋六丁目', '덴진바시스지 6초메', 'Tenjimbashisuji 6-chome')),
    L('nagahori', '長堀鶴見緑地線', '나가호리쓰루미료쿠치선', 'Nagahori Tsurumi-ryokuchi Line', '#A9CC51',
      ['大正', 'ドーム前千代崎', '西長堀', '西大橋', '心斎橋', '長堀橋', '松屋町', '谷町六丁目', '玉造', '森ノ宮', '大阪ビジネスパーク',
       '京橋', '蒲生四丁目', '今福鶴見', '横堤', '鶴見緑地', '門真南'],
      forward=toward('門真南', '가도마미나미', 'Kadoma-Minami'), reverse=toward('大正', '다이쇼', 'Taisho')),
    L('imazatosuji', '今里筋線', '이마자토스지선', 'Imazatosuji Line', '#EE7B1A',
      ['井高野', '瑞光四丁目', 'だいどう豊里', '太子橋今市', '清水', '新森古市', '関目成育', '蒲生四丁目', '鴫野', '緑橋', '今里'],
      forward=toward('今里', '이마자토', 'Imazato'), reverse=toward('井高野', '이타카노', 'Itakano')),
    L('nanko', 'ニュートラム 南港ポートタウン線', '뉴트램 난코 포트타운선', 'New Tram Nanko Port Town Line', '#00A3D9',
      ['コスモスクエア', 'トレードセンター前', '中ふ頭', 'ポートタウン西', 'ポートタウン東', 'フェリーターミナル', '南港東', '南港口',
       '平林', '住之江公園'],
      forward=toward('住之江公園', '스미노에코엔', 'Suminoekoen'), reverse=toward('コスモスクエア', '코스모스퀘어', 'Cosmosquare')),
    L('loop', 'JR大阪環状線', 'JR 오사카 순환선', 'JR Osaka Loop Line', '#D35400', LOOP, kind='local', group='jr',
      forward=toward('京橋・鶴橋', '교바시·쓰루하시', 'Kyobashi / Tsuruhashi'),
      reverse=toward('西九条・弁天町', '니시쿠조·벤텐초', 'Nishikujo / Bentencho'), loop=True),
    L('yumesaki', 'JRゆめ咲線', 'JR 유메사키선', 'JR Yumesaki Line', '#003C88',
      ['西九条', '安治川口', 'ユニバーサルシティ', '桜島'], kind='local', group='jr',
      forward=toward('桜島', '사쿠라지마', 'Sakurajima'), reverse=toward('西九条', '니시쿠조', 'Nishikujo')),
    # Private railways from the city's big terminals (only their first stretch, inside the map).
    L('keihan', '京阪本線', '게이한 본선', 'Keihan Main Line', '#1D2088', ['淀屋橋', '北浜', '天満橋', '京橋'],
      kind='local', group='keihan', operator='京阪',
      forward=toward('京橋・京都', '교바시·교토', 'Kyobashi / Kyoto'), reverse=toward('淀屋橋', '요도야바시', 'Yodoyabashi')),
    L('nankai', '南海本線', '난카이 본선', 'Nankai Main Line', '#0B3F8C',
      ['なんば', '新今宮', '天下茶屋', '岸里玉出', '粉浜', '住吉大社'], kind='local', group='nankai', operator='南海',
      forward=toward('住吉大社・関西空港', '스미요시타이샤·간사이 공항', 'Sumiyoshitaisha / Kansai Airport'),
      reverse=toward('なんば', '난바', 'Namba')),
    L('hankyu', '阪急線', '한큐선', 'Hankyu Line', '#7A1F2B', ['大阪梅田', '中津#阪急', '十三'], kind='local',
      group='hankyu', operator='阪急',
      forward=toward('十三（神戸・宝塚・京都）', '주소(고베·다카라즈카·교토)', 'Juso (Kobe / Takarazuka / Kyoto)'),
      reverse=toward('大阪梅田', '오사카우메다', 'Osaka-Umeda')),
    L('kintetsu', '近鉄奈良線', '긴테쓰 나라선', 'Kintetsu Nara Line', '#C22047',
      ['大阪難波', '近鉄日本橋', '大阪上本町', '鶴橋', '布施'], kind='local', group='kintetsu', operator='近畿日本鉄道|近鉄',
      forward=toward('布施・奈良', '후세·나라', 'Fuse / Nara'), reverse=toward('大阪難波', '오사카난바', 'Osaka-Namba')),
]

_METRO = [('05:00', '07:00', 6), ('07:00', '09:30', 3), ('09:30', '17:00', 5), ('17:00', '20:00', 4),
          ('20:00', '24:00', 7)]
HEADWAY = {l['key']: _METRO for l in LINES}
HEADWAY['loop'] = [('05:00', '07:00', 8), ('07:00', '09:30', 4), ('09:30', '17:00', 5), ('17:00', '20:00', 4),
                   ('20:00', '24:00', 8)]
HEADWAY['yumesaki'] = [('05:00', '07:00', 12), ('07:00', '10:00', 6), ('10:00', '22:00', 8), ('22:00', '24:00', 15)]
HEADWAY['nanko'] = [('05:00', '07:00', 8), ('07:00', '09:30', 4), ('09:30', '20:00', 6), ('20:00', '24:00', 9)]
FIRST_LAST = {l['key']: ('05:00', '24:00') for l in LINES}
FIRST_LAST['loop'] = ('04:55', '24:10')
FIRST_LAST['yumesaki'] = ('05:10', '23:50')
HEADWAY['keihan'] = [('05:00', '07:00', 8), ('07:00', '09:30', 3), ('09:30', '17:00', 5), ('17:00', '20:00', 4),
                     ('20:00', '24:00', 8)]
HEADWAY['nankai'] = HEADWAY['keihan']
HEADWAY['hankyu'] = [('05:00', '07:00', 6), ('07:00', '09:30', 3), ('09:30', '20:00', 4), ('20:00', '24:00', 6)]
HEADWAY['kintetsu'] = HEADWAY['keihan']
FIRST_LAST['keihan'] = ('05:00', '24:20')
FIRST_LAST['nankai'] = ('05:00', '24:15')
FIRST_LAST['hankyu'] = ('04:55', '24:25')
FIRST_LAST['kintetsu'] = ('05:05', '24:15')

# Changes between stations of different names, on foot (minutes, rough, from the station maps).
WALKS = [('梅田', '東梅田', 5), ('梅田', '西梅田', 5), ('東梅田', '西梅田', 6), ('大阪', '梅田', 4), ('大阪', '東梅田', 5),
         ('大阪', '西梅田', 4), ('大阪梅田', '梅田', 4), ('大阪梅田', '大阪', 6), ('大阪難波', 'なんば', 3),
         ('近鉄日本橋', '日本橋', 2), ('大阪上本町', '谷町九丁目', 3), ('新今宮', '動物園前', 3), ('天満', '扇町', 3),
         ('野田', '野田阪神', 4), ('岸里玉出', '岸里', 4)]
