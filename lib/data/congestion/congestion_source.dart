/// Crowding level: 1 = 余裕 (green), 2 = 普通 (yellow), 3 = 混雑 (orange), 4 = 大混雑 (red).
/// Shown with colour AND a 1–4 person-icon count so colour-blind users can read it.
enum CongestionLevel { relaxed, normal, crowded, packed }

class CongestionReading {
  const CongestionReading({required this.level, required this.isLive});
  final CongestionLevel level;

  /// false = estimate from statistics (予想), true = live data (リアルタイム).
  final bool isLive;
}

/// Where crowding data comes from. Three planned sources:
/// 1. statistics estimate (MVP), 2. user reports, 3. live feeds.
abstract class CongestionSource {
  Future<CongestionReading?> segment({
    required String lineId,
    required String fromStationId,
    required String toStationId,
    required DateTime at,
  });
}
