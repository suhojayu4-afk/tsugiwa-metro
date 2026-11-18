import '../../data/models/city.dart';
import '../trip/route_finder.dart';

/// Airport expresses show their own name instead of 各停.
const _trainNames = {'tokyo.skyliner': 'スカイライナー', 'tokyo.access_express': 'アクセス特急', 'tokyo.narita_express': 'NEX'};

/// Longest English page that still reads on the LED (it is squeezed beyond
/// about 6 Japanese characters' width).
const _maxEnglish = 16;

/// What the train's destination LED shows for the first train of a route,
/// page by page, like a real Japanese train:
///   銀座線 to Asakusa  → 「各停 浅草」, 「for Asakusa」
///   山手線 (loop)      → 「山手線」, 「内回り」
///   スカイライナー      → 「スカイライナー」, 「成田空港」
List<String> destinationLed(CityData city, RouteLeg leg) {
  final line = city.line(leg.lineId);
  if (line.loop) {
    // Loops have no last stop: line name, then the way round.
    final way = line.directionName(leg.forward).ja;
    final shortWay = way.contains('・') ? '${way.split('・').first}方面' : way;
    return [line.name.ja.replaceFirst('都営', ''), shortWay];
  }
  final terminusId = leg.forward ? line.stations.last : line.stations.first;
  final terminus = city.station(terminusId);
  final special = _trainNames[line.id];
  if (special != null) return [special, terminus.name.ja];
  final english = 'for ${terminus.name.of('en')}';
  return ['各停 ${terminus.name.ja}', if (english.length <= _maxEnglish) english];
}
