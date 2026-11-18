import 'dart:math' as math;

import 'models/city.dart';

/// Getting home without trains: rough taxi fare and walking time between two
/// stations, worked out offline from their positions.

/// Roads are longer than a straight line: about 1.25× in Tokyo.
const _roadFactor = 1.25;

/// Road distance between two stations, metres (straight line × 1.25).
double roadMetres(CityData city, String fromId, String toId) {
  final a = city.station(fromId), b = city.station(toId);
  const r = 6371000.0;
  final p1 = a.lat * math.pi / 180, p2 = b.lat * math.pi / 180;
  final dp = (b.lat - a.lat) * math.pi / 180, dl = (b.lng - a.lng) * math.pi / 180;
  final h = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(h)) * _roadFactor;
}

/// Tokyo 23-ward taxi fare (2026 tariff): ¥500 for the first 1,096 m, then
/// ¥100 every 255 m; 22:00–5:00 is 20% more. Rounded up to ¥100 — an
/// estimate (waiting in traffic and tolls are not counted).
int taxiFareYen(double metres, {bool lateNight = false}) {
  var fare = 500 + (math.max(0, metres - 1096) / 255).ceil() * 100;
  if (lateNight) fare = (fare * 1.2).round();
  return (fare / 100).ceil() * 100;
}

/// Late-night taxi rates apply from 22:00 to 5:00 (Japan time).
bool isLateNight(DateTime jst) => jst.hour >= 22 || jst.hour < 5;

/// Walking time at 80 m a minute.
int walkMinutes(double metres) => (metres / 80).ceil();

/// Walking is worth showing up to an hour.
const maxWalkMinutes = 60;
