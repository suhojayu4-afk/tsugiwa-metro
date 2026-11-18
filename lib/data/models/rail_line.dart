import 'dart:ui' show Color;

import '../../core/localized_text.dart';

class RailLine {
  const RailLine({
    required this.id,
    required this.name,
    required this.color,
    required this.loop,
    required this.dwellSec,
    required this.forwardName,
    required this.reverseName,
    required this.stations,
    required this.runSec,
    this.group = 'other',
  });

  factory RailLine.fromJson(Map<String, dynamic> json) {
    final dirs = json['directions'] as Map<String, dynamic>;
    final hex = (json['color'] as String).replaceFirst('#', '');
    final line = RailLine(
      id: json['id'] as String,
      name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      color: Color(int.parse('FF$hex', radix: 16)),
      loop: json['loop'] as bool? ?? false,
      dwellSec: json['dwellSec'] as int? ?? 30,
      forwardName: LocalizedText.fromJson(dirs['forward'] as Map<String, dynamic>),
      reverseName: LocalizedText.fromJson(dirs['reverse'] as Map<String, dynamic>),
      stations: List<String>.from(json['stations'] as List),
      runSec: List<int>.from(json['runSec'] as List),
      group: json['group'] as String? ?? 'other',
    );
    if (line.runSec.length != line.segmentCount) {
      throw FormatException(
        '${line.id}: runSec has ${line.runSec.length} values, expected ${line.segmentCount}',
      );
    }
    return line;
  }

  final String id;
  final LocalizedText name;
  final Color color;
  final bool loop;
  final int dwellSec;
  final LocalizedText forwardName;
  final LocalizedText reverseName;

  /// Railway company the line belongs to ('jr', 'metro', 'toei', 'tokyu', ...),
  /// for grouping the line chips on the route map.
  final String group;

  /// Station ids in "forward" order.
  final List<String> stations;

  /// runSec[i] = seconds from stations[i] to stations[i+1] (for a loop, the last
  /// value is from the last station back to the first).
  final List<int> runSec;

  int get segmentCount => loop ? stations.length : stations.length - 1;

  LocalizedText directionName(bool forward) => forward ? forwardName : reverseName;

  /// Seconds between two neighbouring stations, in either direction.
  int runSecBetween(String a, String b) {
    final n = stations.length;
    for (var i = 0; i < segmentCount; i++) {
      final x = stations[i];
      final y = stations[(i + 1) % n];
      if ((x == a && y == b) || (x == b && y == a)) return runSec[i];
    }
    throw ArgumentError('$a and $b are not neighbours on $id');
  }
}
