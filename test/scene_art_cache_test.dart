import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';

void main() {
  // Real image decoding needs real async (runAsync).
  testWidgets('SceneArt keeps only the most recently used pictures', (tester) async {
    await tester.runAsync(() => _lru());
  });
}

Future<void> _lru() async {
  final old = SceneArt.cacheLimit;
  SceneArt.cacheLimit = 3;
  final a = SceneArt.background(DayPart.day);
  final b = SceneArt.background(DayPart.evening);
  final c = SceneArt.background(DayPart.night);
  final d = SceneArt.trainStripe;

  final first = await SceneArt.load(a);
  await SceneArt.load(b);
  await SceneArt.load(c);
  expect(SceneArt.cachedCount, lessThanOrEqualTo(3));
  // Using a again makes it the newest: b is now the oldest.
  expect(identical(await SceneArt.load(a), first), isTrue);
  await SceneArt.load(d);
  expect(SceneArt.cachedCount, lessThanOrEqualTo(3));
  expect(SceneArt.isCached(a), isTrue);
  expect(SceneArt.isCached(b), isFalse);
  expect(SceneArt.isCached(c), isTrue);
  expect(SceneArt.isCached(d), isTrue);

  // A dropped picture is not disposed: whoever still holds it can draw it.
  expect(first.debugDisposed, isFalse);
  final again = await SceneArt.load(b);
  expect(again.width, SceneArt.width);
  // Now c was the oldest (order was c, a, d).
  expect(SceneArt.isCached(c), isFalse);
  expect(SceneArt.isCached(a), isTrue);
  expect(first.debugDisposed, isFalse);
  expect(first.width, SceneArt.width);
  SceneArt.cacheLimit = old;
}
