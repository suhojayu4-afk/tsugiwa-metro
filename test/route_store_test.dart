import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/route_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('favourites and recents survive a restart', () async {
    final a = RouteStore();
    await a.load();
    await a.addFavourite(const SavedRoute('tokyo.shibuya', 'tokyo.tokyo', kind: FavouriteKind.work));
    await a.addRecent('tokyo.shinjuku', 'tokyo.ueno');

    final b = RouteStore();
    await b.load();
    expect(b.favourites.single.kind, FavouriteKind.work);
    expect(b.favouriteFor('tokyo.shibuya', 'tokyo.tokyo'), isNotNull);
    expect(b.recents.single.fromId, 'tokyo.shinjuku');
  });

  test('one work favourite at a time, recents newest first and capped', () async {
    final s = RouteStore();
    await s.load();
    await s.addFavourite(const SavedRoute('a', 'b', kind: FavouriteKind.work));
    await s.addFavourite(const SavedRoute('c', 'd', kind: FavouriteKind.work));
    expect(s.favourites.map((f) => f.fromId), ['c']);

    for (var i = 0; i < 8; i++) {
      await s.addRecent('s$i', 't$i');
    }
    await s.addRecent('s3', 't3');
    expect(s.recents, hasLength(RouteStore.maxRecents));
    expect(s.recents.first.fromId, 's3');
  });

  test('broken saved data is ignored instead of crashing', () async {
    SharedPreferences.setMockInitialValues({'routes.favourites': '{not json'});
    final s = RouteStore();
    await s.load();
    expect(s.favourites, isEmpty);
  });
}
