"""Railway lines of the Tottori–Yonago city: the part of each line inside
Tottori Prefecture, stations in running order, with readings.

Positions come from OpenStreetMap station nodes (tools/data/osm_tottori/
stations.json); English and Korean names from their name:en / name:ko,
otherwise spelt from the reading. Headways and run times are estimates
(rural lines: about one train an hour), like the Tokyo data.

L(key, ja, ko, en, colour, stations, kind, group, forward, reverse)
  kind  'local' | 'express' | 'private' (run speed, dwell)
  forward / reverse: (ja, ko, en) of where each direction goes
"""

KANA = {
    '東浜': 'ひがしはま', '岩美': 'いわみ', '大岩': 'おおいわ', '福部': 'ふくべ', '鳥取': 'とっとり', '湖山': 'こやま',
    '鳥取大学前': 'とっとりだいがくまえ', '末恒': 'すえつね', '宝木': 'ほうぎ', '浜村': 'はまむら', '青谷': 'あおや',
    '泊': 'とまり', '松崎': 'まつざき', '倉吉': 'くらよし', '下北条': 'しもほうじょう', '由良': 'ゆら', '浦安': 'うらやす',
    '八橋': 'やばせ', '赤碕': 'あかさき', '中山口': 'なかやまぐち', '下市': 'しもいち', '御来屋': 'みくりや', '名和': 'なわ',
    '大山口': 'だいせんぐち', '淀江': 'よどえ', '伯耆大山': 'ほうきだいせん', '東山公園': 'ひがしやまこうえん',
    '米子': 'よなご',
    '博労町': 'ばくろうまち', '富士見町': 'ふじみちょう', '後藤': 'ごとう', '三本松口': 'さんぼんまつぐち',
    '河崎口': 'かわさきぐち', '弓ヶ浜': 'ゆみがはま', '和田浜': 'わだはま', '大篠津町': 'おおしのづちょう',
    '米子空港': 'よなごくうこう', '中浜': 'なかはま', '高松町': 'たかまつちょう', '余子': 'あまりこ', '上道': 'あがりみち',
    '馬場崎町': 'ばばさきちょう', '境港': 'さかいみなと',
    '津ノ井': 'つのい', '東郡家': 'ひがしこおげ', '郡家': 'こおげ', '河原': 'かわはら', '国英': 'くにふさ',
    '鷹狩': 'たかがり', '用瀬': 'もちがせ', '因幡社': 'いなばやしろ', '智頭': 'ちづ', '土師': 'はじ', '那岐': 'なぎ',
    '八頭高校前': 'やずこうこうまえ', '因幡船岡': 'いなばふなおか', '隼': 'はやぶさ', '安部': 'あべ', '八東': 'はっとう',
    '徳丸': 'とくまる', '丹比': 'たんぴ', '若桜': 'わかさ',
    '恋山形': 'こいやまがた', '山郷': 'やまさと',
    '岸本': 'きしもと', '伯耆溝口': 'ほうきみぞぐち', '江尾': 'えび', '根雨': 'ねう', '武庫': 'むこ', '黒坂': 'くろさか',
    '上菅': 'かみすげ', '生山': 'しょうやま', '上石見': 'かみいわみ',
}

# Names the sources spell badly or leave out.
EN_FIX = {'鳥取大学前': 'Tottori-Daigakumae', '伯耆大山': 'Hoki-Daisen', '伯耆溝口': 'Hoki-Mizoguchi',
          '東山公園': 'Higashiyama-Koen', '米子空港': 'Yonago-Kuko', '因幡社': 'Inaba-Yashiro',
          '因幡船岡': 'Inaba-Funaoka', '八頭高校前': 'Yazu-Koko-mae', '恋山形': 'Koi-Yamagata',
          '大山口': 'Daisenguchi', '中山口': 'Nakayamaguchi', '三本松口': 'Sambommatsuguchi',
          '河崎口': 'Kawasakiguchi', '大篠津町': 'Oshinozucho', '馬場崎町': 'Babasakicho',
          '富士見町': 'Fujimicho', '博労町': 'Bakuromachi', '高松町': 'Takamatsucho', '東郡家': 'Higashi-Koge',
          '上石見': 'Kami-Iwami', '上菅': 'Kamisuge', '下北条': 'Shimo-Hojo', '弓ヶ浜': 'Yumigahama'}
KO_FIX = {'伯耆大山': '호키다이센', '大山口': '다이센구치', '米子空港': '요나고공항', '鳥取大学前': '돗토리다이가쿠마에',
          '東山公園': '히가시야마코엔', '恋山形': '고이야마가타', '八頭高校前': '야즈코코마에'}


def L(key, ja, ko, en, color, stations, kind='local', group='jr', forward=None, reverse=None):
    return dict(key=key, ja=ja, ko=ko, en=en, color=color, stations=stations, kind=kind, group=group,
                forward=forward, reverse=reverse)


def toward(ja, ko, en):
    return {'ja': f'{ja}方面', 'ko': f'{ko} 방면', 'en': f'for {en}'}


SANIN = ['東浜', '岩美', '大岩', '福部', '鳥取', '湖山', '鳥取大学前', '末恒', '宝木', '浜村', '青谷', '泊', '松崎', '倉吉',
         '下北条', '由良', '浦安', '八橋', '赤碕', '中山口', '下市', '御来屋', '名和', '大山口', '淀江', '伯耆大山',
         '東山公園', '米子']

LINES = [
    L('sanin', '山陰本線', '산인 본선', 'San\'in Main Line', '#1E73BE', SANIN,
      forward=toward('米子', '요나고', 'Yonago'), reverse=toward('鳥取', '돗토리', 'Tottori')),
    L('sakai', '境線', '사카이선', 'Sakai Line', '#8A5CB8',
      ['米子', '博労町', '富士見町', '後藤', '三本松口', '河崎口', '弓ヶ浜', '和田浜', '大篠津町', '米子空港', '中浜',
       '高松町', '余子', '上道', '馬場崎町', '境港'],
      forward=toward('境港', '사카이미나토', 'Sakaiminato'), reverse=toward('米子', '요나고', 'Yonago')),
    L('inbi', '因美線', '인비선', 'Inbi Line', '#E8892B',
      ['鳥取', '津ノ井', '東郡家', '郡家', '河原', '国英', '鷹狩', '用瀬', '因幡社', '智頭', '土師', '那岐'],
      forward=toward('智頭', '지즈', 'Chizu'), reverse=toward('鳥取', '돗토리', 'Tottori')),
    L('wakasa', '若桜鉄道', '와카사 철도', 'Wakasa Railway', '#2E9E5B',
      ['郡家', '八頭高校前', '因幡船岡', '隼', '安部', '八東', '徳丸', '丹比', '若桜'], kind='private', group='wakasa',
      forward=toward('若桜', '와카사', 'Wakasa'), reverse=toward('郡家', '고게', 'Koge')),
    L('chizukyu', '智頭急行', '지즈 급행', 'Chizu Express', '#D23F57', ['智頭', '恋山形', '山郷'],
      kind='private', group='chizukyu',
      forward=toward('大原', '오하라', 'Ohara'), reverse=toward('智頭', '지즈', 'Chizu')),
    L('hakubi', '伯備線', '하쿠비선', 'Hakubi Line', '#12998A',
      ['伯耆大山', '岸本', '伯耆溝口', '江尾', '武庫', '根雨', '黒坂', '上菅', '生山', '上石見'],
      forward=toward('新見', '니이미', 'Niimi'), reverse=toward('米子', '요나고', 'Yonago')),
    # Limited expresses: the part in the prefecture, main stops only.
    L('matsukaze', '特急スーパーまつかぜ', '특급 슈퍼 마쓰카제', 'Ltd. Exp. Super Matsukaze', '#C8372D',
      ['鳥取', '鳥取大学前', '浜村', '倉吉', '浦安', '米子'], kind='express',
      forward=toward('米子', '요나고', 'Yonago'), reverse=toward('鳥取', '돗토리', 'Tottori')),
    L('hakuto', '特急スーパーはくと・いなば', '특급 슈퍼 하쿠토·이나바', 'Ltd. Exp. Super Hakuto / Inaba', '#F2A500',
      ['倉吉', '鳥取', '郡家', '智頭'], kind='express',
      forward=toward('京都・岡山', '교토·오카야마', 'Kyoto / Okayama'), reverse=toward('鳥取', '돗토리', 'Tottori')),
    L('yakumo', '特急やくも', '특급 야쿠모', 'Ltd. Exp. Yakumo', '#E0607E', ['米子', '根雨', '生山'], kind='express',
      forward=toward('岡山', '오카야마', 'Okayama'), reverse=toward('米子', '요나고', 'Yonago')),
]

# Trains by time of day ('every' minutes), set from the published counts
# (JR West timetables and Tottori Prefecture's figures, autumn 2026):
# San'in Line locals about 18 a day each way Tottori–Kurayoshi and 17
# Kurayoshi–Yonago; Sakai Line 18 a day from Yonago (05:17–22:40);
# Wakasa Railway 12 a day each way (Koge 06:54–22:29, Wakasa 06:10–21:24);
# few trains on the Inbi, Chizu Express and Hakubi locals.
HEADWAY = {
    'sanin': [('05:00', '07:00', 60), ('07:00', '09:00', 40), ('09:00', '16:00', 70), ('16:00', '19:30', 45),
              ('19:30', '23:00', 70)],
    'sakai': [('05:00', '07:00', 60), ('07:00', '09:00', 35), ('09:00', '17:00', 65), ('17:00', '19:30', 45),
              ('19:30', '23:00', 70)],
    'inbi': [('05:00', '07:00', 70), ('07:00', '09:00', 50), ('09:00', '16:00', 110), ('16:00', '19:30', 60),
             ('19:30', '23:00', 100)],
    'wakasa': [('06:00', '09:00', 50), ('09:00', '16:00', 100), ('16:00', '20:00', 45), ('20:00', '23:00', 70)],
    'chizukyu': [('06:00', '22:00', 150)],
    'hakubi': [('05:00', '09:00', 80), ('09:00', '16:00', 150), ('16:00', '20:00', 100), ('20:00', '23:00', 150)],
    'matsukaze': [('06:00', '22:00', 75)],
    'hakuto': [('06:00', '21:30', 75)],
    'yakumo': [('06:00', '21:30', 60)],
}
FIRST_LAST = {'sanin': ('05:20', '22:50'), 'sakai': ('05:17', '22:40'), 'inbi': ('05:40', '22:10'),
              'wakasa': ('06:10', '22:29'), 'chizukyu': ('06:20', '21:10'), 'hakubi': ('05:40', '21:50'),
              'matsukaze': ('06:40', '21:30'), 'hakuto': ('06:30', '21:00'), 'yakumo': ('06:15', '21:20')}
