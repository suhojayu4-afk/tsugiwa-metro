/// Live operation info (next train, delays). The MVP has no live data, so it
/// uses [TimetableOnlyProvider] and screens fall back to "約N分おき".
///
/// Licensing note (checked 2026-11-17, ODPT catalogue):
/// - Tokyo Metro data (Ginza Line) is under the 公共交通オープンデータ基本ライセンス,
///   which allows commercial apps (check the dataset's specific conditions and
///   ODPT's commercial-use registration before release).
/// - JR East data (Yamanote Line) is under the Challenge *limited* licence —
///   contest only, NOT for a commercial app. Yamanote stays estimate-only unless
///   data is licensed another way.
abstract class RealtimeProvider {
  /// Minutes until the next train leaves [stationId] on [lineId] in the given
  /// direction, or null when this provider does not know.
  Future<int?> nextTrainMinutes({required String stationId, required String lineId, required bool forward});

  /// Current delay on a line in minutes, or null when unknown.
  Future<int?> delayMinutes(String lineId);

  /// Whether this provider has real live data (shown as リアルタイム vs 予想 in the UI).
  bool get isLive;
}

class TimetableOnlyProvider implements RealtimeProvider {
  const TimetableOnlyProvider();

  @override
  Future<int?> nextTrainMinutes({
    required String stationId,
    required String lineId,
    required bool forward,
  }) async => null;

  @override
  Future<int?> delayMinutes(String lineId) async => null;

  @override
  bool get isLive => false;
}
