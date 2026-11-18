import '../../core/localized_text.dart';

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.kana,
    required this.lat,
    required this.lng,
    required this.lines,
    required this.undergroundLines,
    required this.transfers,
    this.mapX,
    this.mapY,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    final geo = json['geo'] as Map<String, dynamic>;
    final map = json['map'] as Map<String, dynamic>?;
    return Station(
      id: json['id'] as String,
      name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      kana: json['kana'] as String? ?? '',
      lat: (geo['lat'] as num).toDouble(),
      lng: (geo['lng'] as num).toDouble(),
      lines: List<String>.from(json['lines'] as List),
      undergroundLines: Set<String>.from(json['underground'] as List? ?? const []),
      transfers: [
        for (final t in json['transfers'] as List? ?? const [])
          StationTransfer.fromJson(t as Map<String, dynamic>),
      ],
      mapX: (map?['x'] as num?)?.toDouble(),
      mapY: (map?['y'] as num?)?.toDouble(),
    );
  }

  final String id;
  final LocalizedText name;
  final String kana;
  final double lat;
  final double lng;
  final List<String> lines;
  final Set<String> undergroundLines;
  final List<StationTransfer> transfers;

  /// Position on the hand-drawn route map grid (filled in by the route map step).
  final double? mapX;
  final double? mapY;

  bool isUndergroundOn(String lineId) => undergroundLines.contains(lineId);

  /// Minutes needed to walk between two lines inside this station.
  int transferWalkMin(String fromLine, String toLine) {
    for (final t in transfers) {
      if (t.lines.contains(fromLine) && t.lines.contains(toLine)) {
        return t.walkMin;
      }
    }
    return 5;
  }

  /// Text that matches a search query in any language.
  String get searchKey => [...name.values.values, kana, id.split('.').last].join(' ').toLowerCase();
}

class StationTransfer {
  const StationTransfer({required this.lines, required this.walkMin});

  factory StationTransfer.fromJson(Map<String, dynamic> json) =>
      StationTransfer(lines: Set<String>.from(json['lines'] as List), walkMin: json['walkMin'] as int);

  final Set<String> lines;
  final int walkMin;
}
