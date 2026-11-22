import 'congestion_source.dart';

/// Rough crowding estimate (予想) from the time of day and how busy each line
/// usually is. Not live: the card always says 予想. Replace or blend with
/// user reports / live feeds later (see [CongestionSource]).
class EstimateCongestionSource implements CongestionSource {
  const EstimateCongestionSource();

  /// Lines famous for packed rush hours.
  static const _veryBusy = {'tokyo.yamanote', 'tokyo.tozai', 'tokyo.hibiya', 'tokyo.chiyoda', 'tokyo.keio'};

  /// Quiet branches and reserved-seat airport trains.
  static const _light = {
    'tokyo.marunouchi_branch',
    'tokyo.toei_oedo_branch',
    'tokyo.skyliner',
    'tokyo.access_express',
    'tokyo.narita_express',
  };

  /// Level for [lineId] at [at] (Japan time).
  static CongestionLevel levelAt(String lineId, DateTime at) {
    // Country lines (Tottori–Yonago) are never packed.
    final tier = _veryBusy.contains(lineId) ? 2 : (_light.contains(lineId) || lineId.startsWith('tottori.') ? 0 : 1);
    final m = at.hour * 60 + at.minute;
    final weekend = at.weekday == DateTime.saturday || at.weekday == DateTime.sunday;
    // Base crowding by time of day: 0 relaxed … 3 packed (for a normal line).
    int base;
    if (weekend) {
      base = (m >= 11 * 60 && m < 19 * 60) ? 1 : 0;
    } else if (m >= 7 * 60 + 30 && m < 9 * 60 + 30) {
      base = 2; // morning rush
    } else if (m >= 17 * 60 + 30 && m < 19 * 60 + 30) {
      base = 2; // evening rush
    } else if ((m >= 7 * 60 && m < 7 * 60 + 30) ||
        (m >= 9 * 60 + 30 && m < 10 * 60) ||
        (m >= 19 * 60 + 30 && m < 21 * 60)) {
      base = 1; // shoulders of the rush
    } else if (m >= 10 * 60 && m < 17 * 60 + 30) {
      base = 1; // daytime
    } else {
      base = 0; // early morning, late night
    }
    final level = (base + tier - 1).clamp(0, 3);
    return CongestionLevel.values[level];
  }

  @override
  Future<CongestionReading?> segment({
    required String lineId,
    required String fromStationId,
    required String toStationId,
    required DateTime at,
  }) async => CongestionReading(level: levelAt(lineId, at), isLive: false);
}
