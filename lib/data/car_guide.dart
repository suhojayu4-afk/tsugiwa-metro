import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/localized_text.dart';
import '../features/trip/route_finder.dart';

/// 乗換便利号車: which car/door stops nearest the stairs for a transfer or a
/// gate, from `assets/cities/<city>/cars.json`. Every spot is approximate (目安)
/// and carries the public source it was taken from.
class CarGuide {
  CarGuide(this._lines);

  factory CarGuide.fromJson(Map<String, dynamic> json) => CarGuide({
    for (final e in (json['lines'] as Map<String, dynamic>).entries)
      e.key: _LineCars.fromJson(e.value as Map<String, dynamic>),
  });

  /// An empty guide: no advice anywhere.
  static final empty = CarGuide(const {});

  static Future<CarGuide> load({String cityId = 'tokyo', AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/cities/$cityId/cars.json');
      return CarGuide.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return empty;
    }
  }

  final Map<String, _LineCars> _lines;

  bool get isEmpty => _lines.isEmpty;

  /// Train layout of [lineId] going [forward], or null when there is no data.
  CarLayout? layout(String lineId, bool forward) {
    final line = _lines[lineId];
    final dir = line?.directions[forward];
    if (line == null || dir == null) return null;
    return CarLayout(
      cars: line.cars,
      frontCar: dir.frontCar,
      door1AtFront: dir.door1AtFront,
      doorsPerCar: line.doorsPerCar,
    );
  }

  List<CarSpot> _spots(String lineId, bool forward, String stationId) =>
      _lines[lineId]?.directions[forward]?.stations[stationId] ?? const [];

  /// Best spot to get off [lineId] (going [forward]) at [stationId] to change
  /// to [toLineId]. [toForward] picks the right platform when the source tells
  /// the two directions of the next line apart.
  CarSpot? transfer(String lineId, bool forward, String stationId, String toLineId, {bool? toForward}) {
    final spots = _spots(lineId, forward, stationId).where((s) => s.to == toLineId).toList();
    if (spots.isEmpty) return null;
    return spots.firstWhere(
      (s) => toForward != null && s.toForward == toForward,
      orElse: () => spots.firstWhere((s) => s.toForward == null, orElse: () => spots.first),
    );
  }

  /// Gates at [stationId] for a train on [lineId] going [forward], main one first.
  List<CarSpot> exits(String lineId, bool forward, String stationId) =>
      _spots(lineId, forward, stationId).where((s) => s.isExit).toList();

  /// Advice for a whole route: one per change of trains (when known) and one
  /// for the final arrival (its main gate). Legs that run through without a
  /// change, and walks between stations, get none.
  List<CarAdvice> forRoute(RouteResult route) {
    final out = <CarAdvice>[];
    for (var i = 0; i < route.legs.length; i++) {
      final leg = route.legs[i];
      final at = leg.stationIds.last;
      final layout = this.layout(leg.lineId, leg.forward);
      if (layout == null) continue;
      if (i + 1 < route.legs.length) {
        final next = route.legs[i + 1];
        if (next.through || next.stationIds.first != at || next.lineId == leg.lineId) continue;
        final spot = transfer(leg.lineId, leg.forward, at, next.lineId, toForward: next.forward);
        if (spot != null) {
          out.add(CarAdvice(lineId: leg.lineId, forward: leg.forward, stationId: at, layout: layout, spot: spot));
        }
      } else {
        final gates = exits(leg.lineId, leg.forward, at);
        if (gates.isNotEmpty) {
          out.add(
            CarAdvice(lineId: leg.lineId, forward: leg.forward, stationId: at, layout: layout, spot: gates.first),
          );
        }
      }
    }
    return out;
  }
}

/// How the cars of a line are numbered when it runs in one direction.
class CarLayout {
  const CarLayout({required this.cars, required this.frontCar, required this.door1AtFront, this.doorsPerCar = 4});

  final int cars;

  /// Number of the car at the front of the train (1 or [cars]).
  final int frontCar;

  /// Door 1 is the front door of each car in this direction.
  final bool door1AtFront;
  final int doorsPerCar;

  /// Car numbers from the front of the train to the back.
  List<int> get frontToBack =>
      frontCar == 1 ? [for (var c = 1; c <= cars; c++) c] : [for (var c = cars; c >= 1; c--) c];

  /// 0-based slot of [door] counted from the front of its car.
  int doorSlot(int door) => door1AtFront ? door - 1 : doorsPerCar - door;
}

/// One spot on the platform: get off at [car] (door [door]) for [to].
class CarSpot {
  const CarSpot({required this.to, required this.car, this.door, this.toForward, this.note, required this.source});

  factory CarSpot.fromJson(Map<String, dynamic> json) => CarSpot(
    to: json['to'] as String,
    car: json['car'] as int,
    door: json['door'] as int?,
    toForward: json['toForward'] as bool?,
    note: json['note'] == null ? null : LocalizedText.fromJson(json['note'] as Map<String, dynamic>),
    source: json['source'] as String,
  );

  /// A line id, or `exit:<gate name>`.
  final String to;
  final int car;
  final int? door;
  final bool? toForward;

  /// Which stairs/escalator and gate (Japanese, from the source).
  final LocalizedText? note;
  final String source;

  bool get isExit => to.startsWith('exit:');

  /// Gate name for an exit spot ("東改札"), else null.
  String? get exitName => isExit ? to.substring(5) : null;

  /// Short form of [source] for the card ("wadattsu261.com").
  String get sourceHost => Uri.tryParse(source)?.host ?? source;
}

/// A spot picked for one point of a route.
class CarAdvice {
  const CarAdvice({
    required this.lineId,
    required this.forward,
    required this.stationId,
    required this.layout,
    required this.spot,
  });

  /// The line being ridden into [stationId].
  final String lineId;
  final bool forward;
  final String stationId;
  final CarLayout layout;
  final CarSpot spot;
}

class _LineCars {
  _LineCars({required this.cars, this.doorsPerCar = 4, required this.directions});

  factory _LineCars.fromJson(Map<String, dynamic> json) {
    final dirs = json['directions'] as Map<String, dynamic>;
    return _LineCars(
      cars: json['cars'] as int,
      doorsPerCar: json['doorsPerCar'] as int? ?? 4,
      directions: {
        for (final e in dirs.entries)
          if (e.key == 'forward' || e.key == 'reverse')
            e.key == 'forward': _DirCars.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  final int cars;

  /// Doors on each side of a car (Ginza/Marunouchi: 3).
  final int doorsPerCar;
  final Map<bool, _DirCars> directions;
}

class _DirCars {
  _DirCars({required this.frontCar, required this.door1AtFront, required this.stations});

  factory _DirCars.fromJson(Map<String, dynamic> json) => _DirCars(
    frontCar: json['frontCar'] as int,
    door1AtFront: json['door1AtFront'] as bool,
    stations: {
      for (final e in (json['stations'] as Map<String, dynamic>).entries)
        e.key: [for (final s in e.value as List) CarSpot.fromJson(s as Map<String, dynamic>)],
    },
  );

  final int frontCar;
  final bool door1AtFront;
  final Map<String, List<CarSpot>> stations;
}
