"""Every railway line of the Tokyo area on the map (Yokohama - Saitama -
Narita - Takao), one entry per physical line with its all-stations
service. build_rail.py reads the stops in order from the OpenStreetMap
route relations named here (tools/data/osm/rail_routes.json).

L(key, ja, ko, en, colour, routes, ...)
  routes  OSM route relation ids; their stops are pooled and put in running
          order by position (OSM's own order is not always right)
  drop    station names to leave out
  ends    (first, last) when the running order cannot be worked out alone
  extra   (name, lat, lng) stations OSM leaves out of the route
  tracks  key in tools/data/osm/rail_tracks.json: stations along the named
          tracks, for lines OSM has no route relation for
  cut     (first, last) station names to keep (None = line end)
  pre / post   station names added before / after (shared track)
  kind    'jr' | 'jr_local' | 'jr_branch' | 'private' | 'private_branch'
          | 'subway' | 'agt' | 'tram'  (headways, underground)
  replace an existing line id to rebuild (otherwise tokyo.<key>)

Shinkansen and limited expresses are left out (the airport expresses
already on the map stay as they are).
"""


def L(key, ja, ko, en, color, routes, cut=(None, None), pre=(), post=(), kind='private', loop=False, replace=None,
      drop=(), ends=None, tracks=None, extra=()):
    return dict(extra=list(extra), tracks=tracks, ends=ends, key=key, ja=ja, ko=ko, en=en, color=color, routes=list(routes), cut=cut, pre=list(pre), drop=set(drop),
                post=list(post), kind=kind, loop=loop, replace=replace)


LINES = [
    # ---- JR East ----
    L('keihin_tohoku', '京浜東北線・根岸線', '게이힌토호쿠선·네기시선', 'Keihin-Tohoku / Negishi Line', '#00B2E5',
      [5195692], kind='jr_local'),
    L('chuo_rapid', '中央線快速', '주오선 쾌속', 'Chuo Line (Rapid)', '#F15A22', [10363876], kind='jr_local'),
    L('chuo_sobu', '中央・総武線各駅停車', '주오·소부선 각역정차', 'Chuo-Sobu Line (Local)', '#FFD400', [10312043],
      kind='jr_local'),
    L('yokosuka_sobu', '横須賀・総武快速線', '요코스카·소부 쾌속선', 'Yokosuka / Sobu Rapid Line', '#0067C0', [21262040],
      kind='jr'),
    L('tokaido', '東海道線', '도카이도선', 'Tokaido Line', '#F68B1E', [12014184], kind='jr'),
    L('utsunomiya', '宇都宮線', '우쓰노미야선', 'Utsunomiya Line', '#F68B1E', [12210362], kind='jr'),
    L('takasaki', '高崎線', '다카사키선', 'Takasaki Line', '#F68B1E', [5430810], pre=['東京'], kind='jr'),
    L('joban_rapid', '常磐線快速', '조반선 쾌속', 'Joban Line (Rapid)', '#00B261', [14330371], kind='jr'),
    L('joban_local', '常磐線各駅停車', '조반선 각역정차', 'Joban Line (Local)', '#868D8D', [10025277], kind='jr_local'),
    L('saikyo', '埼京線', '사이쿄선', 'Saikyo Line', '#00AC9A', [21361897], kind='jr_local'),
    L('kawagoe', '川越線', '가와고에선', 'Kawagoe Line', '#00AC9A', [11953294], kind='jr_branch'),
    L('keiyo', '京葉線', '게이요선', 'Keiyo Line', '#C9242F', [9474241], kind='jr_local'),
    L('musashino', '武蔵野線', '무사시노선', 'Musashino Line', '#F15A22', [1952540], kind='jr_local'),
    L('nambu', '南武線', '난부선', 'Nambu Line', '#FFD400', [1834403], kind='jr_local'),
    L('nambu_branch', '南武線（浜川崎支線）', '난부선 (하마카와사키 지선)', 'Nambu Line (Hamakawasaki branch)', '#FFD400',
      [14284531], kind='jr_branch'),
    L('yokohama', '横浜線', '요코하마선', 'Yokohama Line', '#7FC342', [18100867], kind='jr_local'),
    L('tsurumi', '鶴見線', '쓰루미선', 'Tsurumi Line', '#FFD400', [11776970], kind='jr_branch'),
    L('tsurumi_umishibaura', '鶴見線（海芝浦支線）', '쓰루미선 (우미시바우라 지선)', 'Tsurumi Line (Umi-Shibaura branch)',
      '#FFD400', [11776972], cut=('浅野', '海芝浦'), kind='jr_branch'),
    L('tsurumi_okawa', '鶴見線（大川支線）', '쓰루미선 (오카와 지선)', 'Tsurumi Line (Okawa branch)', '#FFD400',
      [11776971], cut=('安善', '大川'), kind='jr_branch'),
    L('sagami', '相模線', '사가미선', 'Sagami Line', '#009793', [1942949], kind='jr_branch'),
    L('ome', '青梅線', '오메선', 'Ome Line', '#F15A22', [11814887], kind='jr_branch'),
    L('itsukaichi', '五日市線', '이쓰카이치선', 'Itsukaichi Line', '#F15A22', [11814879], kind='jr_branch'),
    L('hachiko', '八高線', '하치코선', 'Hachiko Line', '#A8A39D', [14323630, 21268981], ends=('八王子', '高崎'),
      kind='jr_branch'),
    L('narita', '成田線', '나리타선', 'Narita Line', '#00B261', [14298709, 3139193], ends=('千葉', '成田空港'),
      drop=['久住', '滑河', '下総神崎', '大戸', '佐原', '香取', '水郷', '小見川', '笹川', '下総橘',
            '下総豊里', '椎柴', '松岸', '銚子'],
      kind='jr_branch'),
    L('narita_abiko', '成田線（我孫子支線）', '나리타선 (아비코 지선)', 'Narita Line (Abiko branch)', '#00B261', [5611753],
      kind='jr_branch'),
    L('sotobo', '外房線', '소토보선', 'Sotobo Line', '#DB2027', [1949528], kind='jr_branch'),
    L('uchibo', '内房線', '우치보선', 'Uchibo Line', '#00B2E5', [17055693, 14303807], cut=('蘇我', '安房鴨川'),
      kind='jr_branch'),

    # ---- Tokyu ----
    L('tokyu_toyoko', '東急東横線', '도큐 도요코선', 'Tokyu Toyoko Line', '#DA0442', [9288982]),
    L('tokyu_meguro', '東急目黒線', '도큐 메구로선', 'Tokyu Meguro Line', '#009CD2', [9340969], replace='tokyo.tokyu_meguro'),
    L('tokyu_denentoshi', '東急田園都市線', '도큐 덴엔토시선', 'Tokyu Den-en-toshi Line', '#20A288', [9341815]),
    L('tokyu_oimachi', '東急大井町線', '도큐 오이마치선', 'Tokyu Oimachi Line', '#F18C43', [9341647]),
    L('tokyu_ikegami', '東急池上線', '도큐 이케가미선', 'Tokyu Ikegami Line', '#EE86A7', [9342008]),
    L('tokyu_tamagawa', '東急多摩川線', '도큐 다마가와선', 'Tokyu Tamagawa Line', '#AE0378', [9343886]),
    L('tokyu_setagaya', '東急世田谷線', '도큐 세타가야선', 'Tokyu Setagaya Line', '#FCC70D', [7215410], kind='tram'),
    L('tokyu_kodomonokuni', '東急こどもの国線', '도큐 고도모노쿠니선', 'Tokyu Kodomonokuni Line', '#0068B7', [5219728],
      kind='private_branch'),
    L('tokyu_shin_yokohama', '東急新横浜線', '도큐 신요코하마선', 'Tokyu Shin-Yokohama Line', '#0071BC', [14681765],
      kind='private_branch'),

    # ---- Odakyu ----
    L('odakyu', '小田急小田原線', '오다큐 오다와라선', 'Odakyu Odawara Line', '#2288CC', [9483158, 12458961, 12458960]),
    L('odakyu_enoshima', '小田急江ノ島線', '오다큐 에노시마선', 'Odakyu Enoshima Line', '#2288CC', [14489075]),
    L('odakyu_tama', '小田急多摩線', '오다큐 다마선', 'Odakyu Tama Line', '#2288CC', [1942962], kind='private_branch'),

    # ---- Keio ----
    L('keio_sagamihara', '京王相模原線', '게이오 사가미하라선', 'Keio Sagamihara Line', '#DD0077', [11299750]),
    L('keio_takao', '京王高尾線', '게이오 다카오선', 'Keio Takao Line', '#DD0077', [14306815], kind='private_branch'),
    L('keio_inokashira', '京王井の頭線', '게이오 이노카시라선', 'Keio Inokashira Line', '#1B3B8C', [11602038]),
    L('keio_keibajo', '京王競馬場線', '게이오 경마장선', 'Keio Keibajo Line', '#DD0077', [11688125], kind='private_branch'),
    L('keio_dobutsuen', '京王動物園線', '게이오 동물원선', 'Keio Dobutsuen Line', '#DD0077', [11688292],
      kind='private_branch'),

    # ---- Seibu ----
    L('seibu_ikebukuro', '西武池袋線', '세이부 이케부쿠로선', 'Seibu Ikebukuro Line', '#F28B00', [9477760]),
    L('seibu_shinjuku', '西武新宿線', '세이부 신주쿠선', 'Seibu Shinjuku Line', '#0099CC', [9506864]),
    L('seibu_haijima', '西武拝島線', '세이부 하이지마선', 'Seibu Haijima Line', '#0099CC', [9507232], kind='private_branch'),
    L('seibu_tamako', '西武多摩湖線', '세이부 다마코선', 'Seibu Tamako Line', '#00A960', [1947331], kind='private_branch'),
    L('seibu_kokubunji', '西武国分寺線', '세이부 고쿠분지선', 'Seibu Kokubunji Line', '#00A960', [11722738],
      kind='private_branch'),
    L('seibu_seibuen', '西武園線', '세이부엔선', 'Seibu Seibuen Line', '#00A960', [5486513], kind='private_branch'),
    L('seibu_sayama', '西武狭山線', '세이부 사야마선', 'Seibu Sayama Line', '#F28B00', [11587706], kind='private_branch'),
    L('seibu_yamaguchi', '西武山口線', '세이부 야마구치선', 'Seibu Yamaguchi Line', '#00A960', [9338170], kind='agt'),
    L('seibu_toshima', '西武豊島線', '세이부 도시마선', 'Seibu Toshima Line', '#F28B00', [10961873], kind='private_branch'),
    L('seibu_yurakucho', '西武有楽町線', '세이부 유라쿠초선', 'Seibu Yurakucho Line', '#F28B00', [5486515],
      kind='private_branch'),
    L('seibu_tamagawa', '西武多摩川線', '세이부 다마가와선', 'Seibu Tamagawa Line', '#00A960', [8061897],
      kind='private_branch'),

    # ---- Tobu ----
    L('tobu_skytree', '東武スカイツリーライン', '도부 스카이트리 라인', 'Tobu Skytree Line', '#0F6CC3', [5392090],
      extra=[('北千住', 35.7497, 139.8049)]),
    L('tobu_kameido', '東武亀戸線', '도부 가메이도선', 'Tobu Kameido Line', '#0F6CC3', [5219680], kind='private_branch'),
    L('tobu_daishi', '東武大師線', '도부 다이시선', 'Tobu Daishi Line', '#0F6CC3', [5219659], kind='private_branch'),
    L('tobu_urban_park', '東武アーバンパークライン', '도부 어반 파크 라인', 'Tobu Urban Park Line', '#00A3E4',
      [14309204, 9486548, 5372771], ends=('大宮', '船橋')),
    L('tobu_tojo', '東武東上線', '도부 도조선', 'Tobu Tojo Line', '#004098', [10032017]),
    L('tobu_ogose', '東武越生線', '도부 오고세선', 'Tobu Ogose Line', '#004098', [11700879, 10443252],
      kind='private_branch'),

    # ---- Keisei group ----
    L('keisei', '京成本線', '게이세이 본선', 'Keisei Main Line', '#1E50A2', [3336658], replace='tokyo.keisei'),
    L('keisei_oshiage', '京成押上線', '게이세이 오시아게선', 'Keisei Oshiage Line', '#1E50A2', [3338455]),
    L('keisei_kanamachi', '京成金町線', '게이세이 가나마치선', 'Keisei Kanamachi Line', '#1E50A2', [1927482],
      kind='private_branch'),
    L('keisei_chiba', '京成千葉線', '게이세이 지바선', 'Keisei Chiba Line', '#1E50A2', [2060618]),
    L('keisei_chihara', '京成千原線', '게이세이 지하라선', 'Keisei Chihara Line', '#1E50A2', [2060696],
      kind='private_branch'),
    L('keisei_matsudo', '京成松戸線', '게이세이 마쓰도선', 'Keisei Matsudo Line', '#EE86A7', [11502414]),
    L('keisei_higashi_narita', '京成東成田線・芝山鉄道線', '게이세이 히가시나리타선·시바야마 철도선',
      'Keisei Higashi-Narita / Shibayama Line', '#1E50A2', [3347989, 9486564], kind='private_branch'),
    L('hokuso', '北総線', '호쿠소선', 'Hokuso Line', '#17A2C9', [3340250]),

    # ---- Keikyu ----
    L('keikyu', '京急本線', '게이큐 본선', 'Keikyu Main Line', '#E5171F', [9498719], pre=['泉岳寺'],
      replace='tokyo.keikyu'),
    L('keikyu_airport', '京急空港線', '게이큐 공항선', 'Keikyu Airport Line', '#E5171F', [3340251]),
    L('keikyu_daishi', '京急大師線', '게이큐 다이시선', 'Keikyu Daishi Line', '#E5171F', [2970698], kind='private_branch'),

    # ---- Sotetsu ----
    L('sotetsu', '相鉄本線', '소테쓰 본선', 'Sotetsu Main Line', '#004EA2', [10358687]),
    L('sotetsu_izumino', '相鉄いずみ野線', '소테쓰 이즈미노선', 'Sotetsu Izumino Line', '#004EA2', [9561172],
      cut=('二俣川', '湘南台')),
    L('sotetsu_shin_yokohama', '相鉄新横浜線', '소테쓰 신요코하마선', 'Sotetsu Shin-Yokohama Line', '#004EA2', [14681764],
      kind='private_branch'),

    # ---- other railways ----
    L('tsukuba_express', 'つくばエクスプレス', '쓰쿠바 익스프레스', 'Tsukuba Express', '#2A2F8C', [2549404]),
    L('rinkai', 'りんかい線', '린카이선', 'Rinkai Line', '#00418E', [3304256]),
    L('saitama_railway', '埼玉高速鉄道線', '사이타마 고속철도선', 'Saitama Railway Line', '#00A3D9', [7002081]),
    L('toyo_rapid', '東葉高速線', '도요 고속선', 'Toyo Rapid Railway Line', '#33B169', [9283468]),
    L('ryutetsu', '流鉄流山線', '류테쓰 나가레야마선', 'Ryutetsu Nagareyama Line', '#F08300', [1979617],
      kind='private_branch'),
    L('kanto_joso', '関東鉄道常総線', '간토 철도 조소선', 'Kanto Railway Joso Line', '#1E4D9C', [1949292], kind='private_branch'),
    L('enoden', '江ノ島電鉄線', '에노시마 전철선', 'Enoshima Electric Railway', '#005C3F', [1943301], kind='tram'),

    # ---- subways outside the 23 wards ----
    L('yokohama_blue', '横浜市営地下鉄ブルーライン', '요코하마 시영 지하철 블루라인', 'Yokohama Municipal Subway Blue Line',
      '#0070C0', [7732276], kind='subway'),
    L('yokohama_green', '横浜市営地下鉄グリーンライン', '요코하마 시영 지하철 그린라인', 'Yokohama Municipal Subway Green Line',
      '#00A73C', [7732275], kind='subway'),
    L('minatomirai', 'みなとみらい線', '미나토미라이선', 'Minatomirai Line', '#11316A', [7703632], kind='subway'),

    # ---- monorails, AGT, tram ----
    L('tokyo_monorail', '東京モノレール', '도쿄 모노레일', 'Tokyo Monorail', '#26326A', [3417174], kind='agt'),
    L('yurikamome', 'ゆりかもめ', '유리카모메', 'Yurikamome', '#1662B8', [3300716], kind='agt'),
    L('nippori_toneri', '日暮里・舎人ライナー', '닛포리·도네리 라이너', 'Nippori-Toneri Liner', '#E85298', [9253570],
      kind='agt'),
    L('toden_arakawa', '都電荒川線（東京さくらトラム）', '도덴 아라카와선 (도쿄 사쿠라 트램)', 'Toden Arakawa Line (Tokyo Sakura Tram)',
      '#EE86A7', [9254425], kind='tram'),
    L('tama_monorail', '多摩モノレール', '다마 모노레일', 'Tama Monorail', '#F08300', [3417185], kind='agt'),
    L('new_shuttle', 'ニューシャトル', '뉴셔틀', 'New Shuttle', '#10A899', [9346453], kind='agt'),
    L('seaside_line', '金沢シーサイドライン', '가나자와 시사이드라인', 'Kanazawa Seaside Line', '#00A7DB', [5503503], kind='agt'),
    L('disney_resort_line', 'ディズニーリゾートライン', '디즈니 리조트 라인', 'Disney Resort Line', '#3BB4E5', [3941253],
      kind='agt', loop=True),
    L('yamaman', '山万ユーカリが丘線', '야마만 유카리가오카선', 'Yamaman Yukarigaoka Line', '#E95295', [9603897], kind='agt'),
    L('chiba_monorail_1', '千葉都市モノレール1号線', '지바 도시 모노레일 1호선', 'Chiba Urban Monorail Line 1', '#23AC38',
      [7715379], kind='agt'),
    L('chiba_monorail_2', '千葉都市モノレール2号線', '지바 도시 모노레일 2호선', 'Chiba Urban Monorail Line 2', '#EA5413',
      [7715378], kind='agt'),
    L('shonan_monorail', '湘南モノレール', '쇼난 모노레일', 'Shonan Monorail', '#E2007F', [7715259], kind='agt'),

    # ---- all of Kanto round the map (2026-11-19) ----
    L('joban', '常磐線（取手以北）', '조반선 (도리데 이북)', 'Joban Line (north of Toride)', '#00B261', [1872548],
      cut=('取手', '磯原'), kind='jr'),
    L('chuo_main', '中央本線', '주오 본선', 'Chuo Main Line', '#6A3906', [9069258], cut=('高尾', '小淵沢'), kind='jr_branch'),
    L('tokaido_shizuoka', '東海道線（熱海〜静岡）', '도카이도선 (아타미~시즈오카)', 'Tokaido Line (Atami - Shizuoka)', '#F68B1E',
      [12015471], cut=('熱海', '静岡'), kind='jr'),
    L('gotemba', '御殿場線', '고텐바선', 'Gotemba Line', '#40A0A0', [12032382], kind='jr_branch'),
    L('ito', '伊東線', '이토선', 'Ito Line', '#F68B1E', [12014423], kind='jr_branch'),
    L('minobu', '身延線', '미노부선', 'Minobu Line', '#9B7CB6', [8888169], kind='jr_branch'),
    L('ryomo', '両毛線', '료모선', 'Ryomo Line', '#F0A030', [21708125], kind='jr_branch'),
    L('mito', '水戸線', '미토선', 'Mito Line', '#4B8C3C', [1949283], kind='jr_branch'),
    L('joetsu', '上越線', '조에쓰선', 'Joetsu Line', '#3CA0D8', [21006366], kind='jr_branch'),
    L('shinetsu', '信越本線（高崎〜横川）', '신에쓰 본선 (다카사키~요코카와)', 'Shinetsu Line (Takasaki - Yokokawa)', '#F0A030',
      [21453299], kind='jr_branch'),
    L('suigun', '水郡線', '스이군선', 'Suigun Line', '#2E8B57', [1872551], kind='jr_branch'),
    L('kashima', '鹿島線', '가시마선', 'Kashima Line', '#C8506E', [1949513], kind='jr_branch'),
    L('sobu_main', '総武本線（千葉〜銚子）', '소부 본선 (지바~조시)', 'Sobu Main Line (Chiba - Choshi)', '#FFC20D', [14303195],
      pre=['千葉'], kind='jr_branch'),
    L('narita_choshi', '成田線（成田〜銚子）', '나리타선 (나리타~조시)', 'Narita Line (Narita - Choshi)', '#00B261', [3139193],
      cut=('成田', '松岸'), kind='jr_branch'),
    L('togane', '東金線', '도가네선', 'Togane Line', '#DB2027', [5219635], kind='jr_branch'),
    L('kururi', '久留里線', '구루리선', 'Kururi Line', '#00B2B2', [14344304], kind='jr_branch'),
    L('keikyu_kurihama', '京急久里浜線', '게이큐 구리하마선', 'Keikyu Kurihama Line', '#E5171F', [9499880], kind='private_branch'),
    L('keikyu_zushi', '京急逗子線', '게이큐 즈시선', 'Keikyu Zushi Line', '#E5171F', [9499867], kind='private_branch'),
    L('hakone_tozan', '箱根登山鉄道', '하코네 등산철도', 'Hakone Tozan Railway', '#C4282C', [11072815, 3414847],
      kind='private_branch'),
    L('izuhakone_daiyuzan', '伊豆箱根鉄道大雄山線', '이즈하코네 철도 다이유잔선', 'Izuhakone Daiyuzan Line', '#2E5FA8',
      [5746641], kind='private_branch'),
    L('izuhakone_sunzu', '伊豆箱根鉄道駿豆線', '이즈하코네 철도 슨즈선', 'Izuhakone Sunzu Line', '#2E5FA8', [11986729],
      kind='private_branch'),
    L('izukyu', '伊豆急行線', '이즈큐코선', 'Izukyu Line', '#3A9BD5', [12024921], kind='private_branch'),
    L('fujikyu', '富士急行線', '후지큐코선', 'Fujikyu Line', '#2B5DAE', [1982965], kind='private_branch'),
    L('shizutetsu', '静岡鉄道静岡清水線', '시즈오카 철도 시즈오카시미즈선', 'Shizuoka Railway', '#E44B88', [10272164],
      kind='private_branch'),
    L('gakunan', '岳南電車', '가쿠난 전차', 'Gakunan Railway', '#F08300', [11730918], kind='private_branch'),
    L('seibu_chichibu', '西武秩父線', '세이부 지치부선', 'Seibu Chichibu Line', '#F28B00', [11763512, 1926312],
      kind='private_branch'),
    L('tobu_isesaki', '東武伊勢崎線', '도부 이세사키선', 'Tobu Isesaki Line', '#0F6CC3', [11703928]),
    L('tobu_nikko', '東武日光線', '도부 닛코선', 'Tobu Nikko Line', '#0F6CC3', [1872553]),
    L('tobu_utsunomiya', '東武宇都宮線', '도부 우쓰노미야선', 'Tobu Utsunomiya Line', '#0F6CC3', [1949384],
      kind='private_branch'),
    L('tobu_kiryu', '東武桐生線', '도부 기류선', 'Tobu Kiryu Line', '#0F6CC3', [1949386], kind='private_branch'),
    L('tobu_sano', '東武佐野線', '도부 사노선', 'Tobu Sano Line', '#0F6CC3', [1949291], kind='private_branch'),
    L('tobu_koizumi', '東武小泉線', '도부 고이즈미선', 'Tobu Koizumi Line', '#0F6CC3', [1949385], kind='private_branch'),
    L('jomo', '上毛電気鉄道', '조모 전기철도', 'Jomo Electric Railway', '#E4007F', [11804580], kind='private_branch'),
    L('kominato', '小湊鐵道', '고미나토 철도', 'Kominato Railway', '#C8A03C', [14706932], kind='private_branch'),
    L('isumi', 'いすみ鉄道', '이스미 철도', 'Isumi Railway', '#F0C000', [5748913], kind='private_branch'),
    L('choshi_dentetsu', '銚子電気鉄道', '조시 전기철도', 'Choshi Electric Railway', '#7A4A2A', [906154, 10006738],
      tracks='choshi', ends=('銚子', '外川'), kind='private_branch'),
    L('hitachinaka', 'ひたちなか海浜鉄道', '히타치나카 해변철도', 'Hitachinaka Seaside Railway', '#F08300', [9059060],
      kind='private_branch'),
    L('kashima_rinkai', '鹿島臨海鉄道大洗鹿島線', '가시마 임해철도 오아라이가시마선', 'Kashima Rinkai Railway', '#0091C8', [9062755],
      kind='private_branch'),
    L('kanto_ryugasaki', '関東鉄道竜ヶ崎線', '간토 철도 류가사키선', 'Kanto Railway Ryugasaki Line', '#1E4D9C', [5611693],
      kind='private_branch'),
    L('mooka', '真岡鐵道', '모오카 철도', 'Moka Railway', '#E08A2A', [1949285],
      extra=[('茂木', 36.5329, 140.1868)], kind='private_branch'),
    L('chichibu', '秩父鉄道', '지치부 철도', 'Chichibu Railway', '#2C5FAA', [], tracks='chichibu', ends=('羽生', '三峰口'), drop=['西武秩父'],
      kind='private_branch'),
    L('joshin', '上信電鉄', '조신 전철', 'Joshin Electric Railway', '#D7262C', [], tracks='joshin', pre=['高崎'],
      kind='private_branch'),
    L('watarase', 'わたらせ渓谷鐵道', '와타라세 계곡 철도', 'Watarase Keikoku Railway', '#C45A2A', [], tracks='watarase',
      pre=['桐生'], kind='private_branch'),
    L('agatsuma', '吾妻線', '아가쓰마선', 'Agatsuma Line', '#2E8B8B', [], tracks='agatsuma', pre=['渋川'], drop=['太子'],
      kind='jr_branch'),
    L('jr_nikko', 'JR日光線', 'JR 닛코선', 'JR Nikko Line', '#8E3B2F', [1872550], extra=[('日光', 36.7478, 139.6195)],
      kind='jr_branch'),
    L('tobu_kinugawa', '東武鬼怒川線', '도부 기누가와선', 'Tobu Kinugawa Line', '#0F6CC3', [5485482, 11801442],
      kind='private_branch'),
    L('karasuyama', '烏山線', '가라스야마선', 'Karasuyama Line', '#4E8C3A', [1949381], kind='jr_branch'),
    L('koumi', '小海線', '고우미선', 'Koumi Line', '#2D9C6E', [10077097], kind='jr_branch'),
    L('shinano', 'しなの鉄道線', '시나노 철도선', 'Shinano Railway', '#E0532D', [1926391, 15881702], kind='private_branch'),
    # ---- services that run on other lines' tracks (2026-11-19) ----
    L('shonan_shinjuku', '湘南新宿ライン', '쇼난신주쿠 라인', 'Shonan-Shinjuku Line', '#E21F26', [4684035], cut=('大船', '大宮'),
      kind='jr'),
    L('sotetsu_jr', '相鉄・JR直通線', '소테쓰·JR 직통선', 'Sotetsu-JR Link', '#2E3192', [10322301], cut=('新宿', '羽沢横浜国大'),
      kind='jr'),
    L('tobu_oshiage', '東武スカイツリーライン（押上〜曳舟）', '도부 스카이트리 라인 (오시아게~히키후네)', 'Tobu Skytree Line (Oshiage)',
      '#0F6CC3', [], extra=[('押上', 35.7105, 139.8135), ('曳舟', 35.7187, 139.8164)], kind='private_branch'),
]

# Through trains: (line A, station, line B, next station on B, previous station on A or None).
# A train on A arriving at the station goes on along B towards [next] without
# changing; the reverse (B coming from [next], on along A towards [previous])
# is added automatically. [previous] may be left out when the station is an
# end of A. Keys are rail_lines keys (tokyo.<key>), names Japanese.
THROUGH = [
    # Tokyo Metro / Toei with the private railways and JR
    ('fukutoshin', '渋谷', 'tokyu_toyoko', '代官山', None),
    ('fukutoshin', '和光市', 'tobu_tojo', '朝霞', None),
    ('yurakucho', '和光市', 'tobu_tojo', '朝霞', None),
    ('fukutoshin', '小竹向原', 'seibu_yurakucho', '新桜台', '千川'),
    ('yurakucho', '小竹向原', 'seibu_yurakucho', '新桜台', '千川'),
    ('seibu_yurakucho', '練馬', 'seibu_ikebukuro', '中村橋', None),
    ('hanzomon', '渋谷', 'tokyu_denentoshi', '池尻大橋', None),
    ('hanzomon', '押上', 'tobu_oshiage', '曳舟', None),
    ('tobu_oshiage', '曳舟', 'tobu_skytree', '東向島', None),
    ('hibiya', '北千住', 'tobu_skytree', '小菅', None),
    ('chiyoda', '綾瀬', 'joban_local', '亀有', '北千住'),
    ('chiyoda', '代々木上原', 'odakyu', '東北沢', None),
    ('tozai', '中野', 'chuo_sobu', '高円寺', None),
    ('tozai', '西船橋', 'toyo_rapid', '東海神', None),
    ('tozai', '西船橋', 'chuo_sobu', '船橋', None),
    ('namboku', '目黒', 'tokyu_meguro', '不動前', None),
    ('namboku', '赤羽岩淵', 'saitama_railway', '川口元郷', None),
    ('toei_mita', '目黒', 'tokyu_meguro', '不動前', None),
    ('toei_asakusa', '泉岳寺', 'keikyu', '品川', '高輪台'),
    ('toei_asakusa', '押上', 'keisei_oshiage', '京成曳舟', None),
    ('toei_shinjuku', '新宿', 'keio', '初台', None),
    # Private railways
    ('keisei_oshiage', '青砥', 'keisei', '京成高砂', None),
    ('keisei', '京成高砂', 'hokuso', '新柴又', '青砥'),
    ('keikyu_airport', '京急蒲田', 'keikyu', '梅屋敷', None),
    ('keikyu_airport', '京急蒲田', 'keikyu', '雑色', None),
    ('minatomirai', '横浜', 'tokyu_toyoko', '反町', None),
    ('tokyu_meguro', '日吉', 'tokyu_shin_yokohama', '新綱島', None),
    ('tokyu_toyoko', '日吉', 'tokyu_shin_yokohama', '新綱島', '元住吉'),
    ('tokyu_shin_yokohama', '新横浜', 'sotetsu_shin_yokohama', '羽沢横浜国大', None),
    ('sotetsu_shin_yokohama', '西谷', 'sotetsu', '鶴ヶ峰', None),
    ('keio', '調布', 'keio_sagamihara', '京王多摩川', '布田'),
    ('keio', '北野', 'keio_takao', '京王片倉', '長沼'),
    ('keisei_matsudo', '京成津田沼', 'keisei_chiba', '京成幕張本郷', None),
    ('keisei_chiba', '千葉中央', 'keisei_chihara', '千葉寺', None),
    ('odakyu', '小田原', 'hakone_tozan', '箱根板橋', None),
    # JR
    ('utsunomiya', '東京', 'tokaido', '新橋', None),
    ('takasaki', '東京', 'tokaido', '新橋', None),
    ('joban_rapid', '取手', 'joban', '藤代', None),
    ('saikyo', '大崎', 'rinkai', '大井町', None),
    ('saikyo', '大宮', 'kawagoe', '日進', None),
    ('chuo_rapid', '立川', 'ome', '西立川', '国立'),
    ('ome', '拝島', 'itsukaichi', '熊川', '昭島'),
    ('yokohama', '東神奈川', 'keihin_tohoku', '横浜', None),
    ('tokaido', '熱海', 'ito', '来宮', None),
    ('yokosuka_sobu', '千葉', 'sotobo', '本千葉', None),
    ('shonan_shinjuku', '大宮', 'utsunomiya', '土呂', None),
    ('shonan_shinjuku', '大宮', 'takasaki', '宮原', None),
    ('shonan_shinjuku', '大船', 'yokosuka_sobu', '北鎌倉', None),
    ('shonan_shinjuku', '大船', 'tokaido', '藤沢', None),
    ('sotetsu_jr', '羽沢横浜国大', 'sotetsu_shin_yokohama', '西谷', None),
]
