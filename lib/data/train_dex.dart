import 'dart:ui' show Color;

import '../core/localized_text.dart';
import 'achievements.dart' show RareSightings;
import 'models/city.dart';
import 'models/rail_line.dart';
import 'my_store.dart';

/// 車両図鑑: every ride "collects" the kind of train of the lines ridden.
///
/// The kinds are ORIGINAL designs for this app (pictures in
/// assets/art/train_dex/, drawn by tools/gen_train_dex_gpt.py): inspired by
/// the general shapes of Japanese trains, but no real model, series name or
/// company livery is used.
enum DexRarity { common, rare, legendary }

class TrainType {
  const TrainType({
    required this.id,
    required this.name,
    required this.flavor,
    required this.rarity,
    required this.color,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText flavor;
  final DexRarity rarity;

  /// The colour the picture is painted in (card background tint).
  final Color color;

  String get art => 'assets/art/train_dex/$id.png';

  /// The rare yellow inspection train is found at the platform, not by riding.
  bool get bySighting => id == yellowTypeId;
}

const yellowTypeId = 'yellow';

const trainTypes = <TrainType>[
  TrainType(
    id: 'jr_commuter',
    name: LocalizedText({'ja': 'みどりの通勤電車', 'ko': '초록 통근전차', 'en': 'Green Commuter'}),
    flavor: LocalizedText({
      'ja': '朝も夜も、まちの人をはこぶ働きもの。ドアがたくさんで、すぐ乗れてすぐ降りられる。',
      'ko': '아침에도 밤에도 동네 사람들을 실어 나르는 일꾼. 문이 많아서 금방 타고 금방 내려요.',
      'en': 'A hard worker carrying the town morning and night. Lots of doors: quick on, quick off.',
    }),
    rarity: DexRarity.common,
    color: Color(0xFF7FC342),
  ),
  TrainType(
    id: 'jr_rapid',
    name: LocalizedText({'ja': 'ふたかい建て快速', 'ko': '2층 쾌속열차', 'en': 'Double-Deck Rapid'}),
    flavor: LocalizedText({
      'ja': '遠くの街までびゅんと走る快速。2階の席からは、線路の先までよく見える。',
      'ko': '먼 도시까지 쌩 달리는 쾌속. 2층 자리에서는 선로 끝까지 잘 보여요.',
      'en': 'A rapid train for faraway towns. From the upper deck you can see far down the line.',
    }),
    rarity: DexRarity.common,
    color: Color(0xFFF68B1E),
  ),
  TrainType(
    id: 'jr_regional',
    name: LocalizedText({'ja': 'やまなみ近郊電車', 'ko': '산자락 근교전차', 'en': 'Hillside Local'}),
    flavor: LocalizedText({
      'ja': '田んぼと山のあいだを、のんびり2〜4両で行く。窓をあければ風のにおい。',
      'ko': '논과 산 사이를 2~4량으로 느긋하게 달려요. 창문을 열면 바람 냄새.',
      'en': 'Two to four cars ambling between rice fields and hills. Open a window and smell the wind.',
    }),
    rarity: DexRarity.common,
    color: Color(0xFF3CA0D8),
  ),
  TrainType(
    id: 'local_diesel',
    name: LocalizedText({'ja': 'のんびり気動車', 'ko': '느긋한 디젤카', 'en': 'Easygoing Railcar'}),
    flavor: LocalizedText({
      'ja': '架線のない線をエンジンでごとごと走る1両の車。ちいさな駅にも、ちゃんと止まる。',
      'ko': '전선이 없는 선로를 엔진으로 덜컹덜컹 달리는 1량짜리. 작은 역에도 꼭 서요.',
      'en': 'One car rumbling along unwired lines on its own engine. It stops at every tiny station.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFFD8552E),
  ),
  TrainType(
    id: 'subway',
    name: LocalizedText({'ja': 'ちかてつ号', 'ko': '지하철호', 'en': 'Subway Runner'}),
    flavor: LocalizedText({
      'ja': 'まちの下をくぐって、あっというまに次の駅へ。トンネルの明かりが窓に流れる。',
      'ko': '도시 아래를 지나 눈 깜짝할 새 다음 역으로. 터널 불빛이 창밖으로 흘러가요.',
      'en': 'Under the city and on to the next station in a blink, tunnel lights streaming past.',
    }),
    rarity: DexRarity.common,
    color: Color(0xFF009BBF),
  ),
  TrainType(
    id: 'subway_classic',
    name: LocalizedText({'ja': 'ちかてつオレンジ号', 'ko': '지하철 오렌지호', 'en': 'Orange Subway Classic'}),
    flavor: LocalizedText({
      'ja': 'まるいおでこのレトロな地下鉄。電気は屋根じゃなく、線路の横からもらっている。',
      'ko': '동그란 이마의 레트로 지하철. 전기는 지붕이 아니라 선로 옆에서 받아요.',
      'en': 'A round-faced retro subway. It takes power from a rail beside the track, not from above.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFFFF9500),
  ),
  TrainType(
    id: 'mini_subway',
    name: LocalizedText({'ja': 'ちびっこリニア地下鉄', 'ko': '꼬마 리니어 지하철', 'en': 'Mini Linear Subway'}),
    flavor: LocalizedText({
      'ja': 'せまいトンネル用の、ひくくて小さな地下鉄。床下の板で、すーっと進む。',
      'ko': '좁은 터널용 낮고 작은 지하철. 바닥 아래 판으로 스윽 나아가요.',
      'en': 'Small and low for narrow tunnels, gliding on a flat motor plate under the floor.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFFCE045B),
  ),
  TrainType(
    id: 'private_commuter',
    name: LocalizedText({'ja': 'ぎんいろ私鉄電車', 'ko': '은빛 사철전차', 'en': 'Silver Suburban'}),
    flavor: LocalizedText({
      'ja': 'まちから郊外へ、毎日行ったり来たり。帯の色で、どの会社かわかるかな？',
      'ko': '도시에서 교외로 매일 왔다 갔다. 띠 색깔로 어느 회사인지 알 수 있을까?',
      'en': 'Back and forth between city and suburbs every day. Can you tell the company by its band?',
    }),
    rarity: DexRarity.common,
    color: Color(0xFF2E5FA8),
  ),
  TrainType(
    id: 'airport_express',
    name: LocalizedText({'ja': 'そらいろ空港特急', 'ko': '하늘빛 공항특급', 'en': 'Sky Airport Express'}),
    flavor: LocalizedText({
      'ja': 'とがった鼻で空港までまっしぐら。スーツケース置き場もちゃんとある。',
      'ko': '뾰족한 코로 공항까지 곧장. 캐리어 두는 곳도 있어요.',
      'en': 'A pointed nose racing to the airport, with a proper spot for your suitcase.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFF22356B),
  ),
  TrainType(
    id: 'resort_liner',
    name: LocalizedText({'ja': 'うみかぜリゾート号', 'ko': '바닷바람 리조트호', 'en': 'Sea Breeze Resort'}),
    flavor: LocalizedText({
      'ja': '海ぞいを行く観光電車。大きな窓のむこうに、きらきらの水平線。',
      'ko': '바닷가를 달리는 관광열차. 커다란 창 너머로 반짝이는 수평선.',
      'en': 'A holiday train along the coast. Through its huge windows, a sparkling horizon.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFF3A9BD5),
  ),
  TrainType(
    id: 'monorail',
    name: LocalizedText({'ja': 'ひとすじモノレール', 'ko': '한 줄기 모노레일', 'en': 'Beam Monorail'}),
    flavor: LocalizedText({
      'ja': '1本のレールにまたがって、空中をすいすい。まちを見おろす特等席。',
      'ko': '한 줄 레일에 올라타 공중을 쓱쓱. 도시를 내려다보는 특등석.',
      'en': 'Straddling a single beam high above the streets: the best seat to look down on town.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFFF08300),
  ),
  TrainType(
    id: 'hanging_monorail',
    name: LocalizedText({'ja': 'ぶらさがりモノレール', 'ko': '매달린 모노레일', 'en': 'Hanging Monorail'}),
    flavor: LocalizedText({
      'ja': 'レールにぶらさがって空をゆく。足の下には、なにもない！',
      'ko': '레일에 매달려 하늘을 가요. 발밑에는 아무것도 없어!',
      'en': 'It hangs from its rail and sails through the sky. Nothing under your feet!',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFF23AC38),
  ),
  TrainType(
    id: 'agt',
    name: LocalizedText({'ja': 'ゴムタイヤ新交通', 'ko': '고무바퀴 신교통', 'en': 'Rubber-Tyre Shuttle'}),
    flavor: LocalizedText({
      'ja': '運転士さんがいない、コンピューターの電車。いちばん前の席は、みんなのあこがれ。',
      'ko': '기관사가 없는 컴퓨터 전차. 맨 앞자리는 모두의 로망.',
      'en': 'A computer-driven car with no driver, so everyone wants the very front seat.',
    }),
    rarity: DexRarity.common,
    color: Color(0xFF1662B8),
  ),
  TrainType(
    id: 'tram',
    name: LocalizedText({'ja': 'ちんちん路面電車', 'ko': '땡땡 노면전차', 'en': 'Ding-Ding Tram'}),
    flavor: LocalizedText({
      'ja': '道路といっしょに、家の軒先をのんびり走る。ちんちん、とベルが鳴る。',
      'ko': '도로와 함께 집 처마 끝을 느긋하게 달려요. 땡땡 하고 벨이 울려요.',
      'en': 'Trundling along the street past front doors. Ding-ding goes the bell.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFFEE86A7),
  ),
  TrainType(
    id: 'retro_local',
    name: LocalizedText({'ja': 'レトロなまち電車', 'ko': '레트로 시골전차', 'en': 'Retro Country Train'}),
    flavor: LocalizedText({
      'ja': 'むかしながらの小さな鉄道で、今日もがんばる。木の床がぎしっと鳴る。',
      'ko': '옛날 그대로의 작은 철도에서 오늘도 힘내요. 나무 바닥이 삐걱 울려요.',
      'en': 'Still working hard on a little old railway. The wooden floor creaks as you step in.',
    }),
    rarity: DexRarity.rare,
    color: Color(0xFF1F7A6E),
  ),
  TrainType(
    id: 'mountain',
    name: LocalizedText({'ja': 'スイッチバック山電車', 'ko': '스위치백 산악전차', 'en': 'Switchback Mountain Car'}),
    flavor: LocalizedText({
      'ja': 'きゅうな坂を、行ったり戻ったりしながら山の上へ。窓の外はあじさいと谷。',
      'ko': '가파른 언덕을 왔다 갔다 하며 산 위로. 창밖은 수국과 골짜기.',
      'en': 'Zigzagging back and forth up a steep mountain, past hydrangeas and deep valleys.',
    }),
    rarity: DexRarity.legendary,
    color: Color(0xFFC4282C),
  ),
  TrainType(
    id: yellowTypeId,
    name: LocalizedText({'ja': 'しあわせの黄色い電車', 'ko': '행운의 노란 전철', 'en': 'Lucky Yellow Train'}),
    flavor: LocalizedText({
      'ja': '線路や架線を点検してまわる、めったに会えない黄色い電車。のりばで見かけたら、いいことあるかも。',
      'ko': '선로와 전선을 점검하며 다니는, 좀처럼 만날 수 없는 노란 전철. 승강장에서 보면 좋은 일이 생길지도.',
      'en': 'A rarely seen yellow train that checks the rails and wires. Spot it at the platform for luck.',
    }),
    rarity: DexRarity.legendary,
    color: Color(0xFFF5C400),
  ),
];

final Map<String, TrainType> _typeById = {for (final t in trainTypes) t.id: t};

TrainType trainType(String id) => _typeById[id]!;

/// Lines whose train is not the default kind for their company.
const _lineType = <String, String>{
  // JR medium distance (double-deck green cars).
  'tokyo.tokaido': 'jr_rapid',
  'tokyo.utsunomiya': 'jr_rapid',
  'tokyo.takasaki': 'jr_rapid',
  'tokyo.yokosuka_sobu': 'jr_rapid',
  'tokyo.joban_rapid': 'jr_rapid',
  'tokyo.joban': 'jr_rapid',
  'tokyo.shonan_shinjuku': 'jr_rapid',
  'tokyo.tokaido_shizuoka': 'jr_rapid',
  'tokyo.ito': 'jr_rapid',
  // JR country electric lines.
  'tokyo.chuo_main': 'jr_regional',
  'tokyo.gotemba': 'jr_regional',
  'tokyo.minobu': 'jr_regional',
  'tokyo.ryomo': 'jr_regional',
  'tokyo.mito': 'jr_regional',
  'tokyo.joetsu': 'jr_regional',
  'tokyo.shinetsu': 'jr_regional',
  'tokyo.agatsuma': 'jr_regional',
  'tokyo.jr_nikko': 'jr_regional',
  'tokyo.sotobo': 'jr_regional',
  'tokyo.uchibo': 'jr_regional',
  'tokyo.togane': 'jr_regional',
  'tokyo.sobu_main': 'jr_regional',
  'tokyo.narita': 'jr_regional',
  'tokyo.narita_abiko': 'jr_regional',
  'tokyo.narita_choshi': 'jr_regional',
  'tokyo.kashima': 'jr_regional',
  // Lines without overhead wires.
  'tokyo.hachiko': 'local_diesel',
  'tokyo.kururi': 'local_diesel',
  'tokyo.suigun': 'local_diesel',
  'tokyo.koumi': 'local_diesel',
  'tokyo.karasuyama': 'local_diesel',
  'tokyo.kominato': 'local_diesel',
  'tokyo.isumi': 'local_diesel',
  'tokyo.hitachinaka': 'local_diesel',
  'tokyo.mooka': 'local_diesel',
  'tokyo.kanto_joso': 'local_diesel',
  'tokyo.kanto_ryugasaki': 'local_diesel',
  'tokyo.kashima_rinkai': 'local_diesel',
  'tokyo.watarase': 'local_diesel',
  // Subways.
  'tokyo.ginza': 'subway_classic',
  'tokyo.marunouchi': 'subway_classic',
  'tokyo.marunouchi_branch': 'subway_classic',
  'tokyo.toei_oedo': 'mini_subway',
  'tokyo.toei_oedo_branch': 'mini_subway',
  'tokyo.yokohama_green': 'mini_subway',
  'tokyo.saitama_railway': 'subway',
  'tokyo.toyo_rapid': 'subway',
  'tokyo.rinkai': 'subway',
  // Express, resort, mountain.
  'tokyo.skyliner': 'airport_express',
  'tokyo.access_express': 'airport_express',
  'tokyo.narita_express': 'airport_express',
  'tokyo.izukyu': 'resort_liner',
  'tokyo.fujikyu': 'resort_liner',
  'tokyo.hakone_tozan': 'mountain',
  // Monorails and people movers.
  'tokyo.tokyo_monorail': 'monorail',
  'tokyo.tama_monorail': 'monorail',
  'tokyo.disney_resort_line': 'monorail',
  'tokyo.chiba_monorail_1': 'hanging_monorail',
  'tokyo.chiba_monorail_2': 'hanging_monorail',
  'tokyo.shonan_monorail': 'hanging_monorail',
  'tokyo.yurikamome': 'agt',
  'tokyo.nippori_toneri': 'agt',
  'tokyo.new_shuttle': 'agt',
  'tokyo.seaside_line': 'agt',
  'tokyo.yamaman': 'agt',
  'tokyo.seibu_yamaguchi': 'agt',
  // Streetcars and little old railways.
  'tokyo.toden_arakawa': 'tram',
  'tokyo.tokyu_setagaya': 'tram',
  'tokyo.enoden': 'tram',
  'tokyo.ryutetsu': 'retro_local',
  'tokyo.choshi_dentetsu': 'retro_local',
  'tokyo.jomo': 'retro_local',
  'tokyo.joshin': 'retro_local',
  'tokyo.chichibu': 'retro_local',
  'tokyo.gakunan': 'retro_local',
  'tokyo.izuhakone_daiyuzan': 'retro_local',
  'tokyo.izuhakone_sunzu': 'retro_local',
  'tokyo.shinano': 'retro_local',
};

/// The kind of train that runs on [line]: listed above, otherwise by company
/// (JR → commuter, subway operators → subway, others → private commuter).
TrainType trainTypeOfLine(RailLine line) {
  final id =
      _lineType[line.id] ??
      switch (line.group) {
        'jr' => 'jr_commuter',
        'metro' || 'toei' || 'yokohama' => 'subway',
        _ => 'private_commuter',
      };
  return trainType(id);
}

/// The lines of [city] each kind runs on, in the city's line order.
Map<String, List<RailLine>> linesByType(CityData city) {
  final out = {for (final t in trainTypes) t.id: <RailLine>[]};
  for (final l in city.lines) {
    out[trainTypeOfLine(l).id]!.add(l);
  }
  return out;
}

/// Kinds collected so far: type id → day first ridden (yyyy-mm-dd, '' for
/// the yellow train, which is spotted rather than ridden).
Map<String, String> collected(MyStore store, CityData city, {bool? yellow}) =>
    collectedFromTrips(store.trips, city, yellow: yellow ?? RareSightings.yellow);

Map<String, String> collectedFromTrips(List<TripLog> trips, CityData city, {bool yellow = false}) {
  final byId = {for (final l in city.lines) l.id: l};
  final out = <String, String>{};
  for (final t in trips) {
    for (final id in t.lines) {
      final line = byId[id];
      if (line == null) continue;
      final type = trainTypeOfLine(line).id;
      final first = out[type];
      if (first == null || t.day.compareTo(first) < 0) out[type] = t.day;
    }
  }
  if (yellow) out[yellowTypeId] = '';
  return out;
}
