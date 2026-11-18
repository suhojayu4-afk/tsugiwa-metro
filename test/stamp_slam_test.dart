import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/features/my_room/stamp_book_screen.dart';
import 'package:tsugiwa_metro/features/trip/widgets/stamp_slam.dart';

void main() {
  Widget app(int n, {bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: StampSlam(stamps: [for (var i = 0; i < n; i++) (name: '駅$i', color: const Color(0xFF80C241))]),
      ),
    ),
  );

  testWidgets('new stamps are pressed on one by one, at most six plus a count', (tester) async {
    await tester.pumpWidget(app(8));
    expect(find.byType(StationStamp), findsNWidgets(6));
    expect(find.text('+2'), findsOneWidget);
    // Mid-way the first stamp has landed while the last is still coming down.
    await tester.pump(const Duration(milliseconds: 500));
    final first = tester.widget<Opacity>(
      find.ancestor(of: find.byType(StationStamp).first, matching: find.byType(Opacity)).first,
    );
    final last = tester.widget<Opacity>(
      find.ancestor(of: find.byType(StationStamp).last, matching: find.byType(Opacity)).first,
    );
    expect(first.opacity, 1.0);
    expect(last.opacity, lessThan(1.0));
    await tester.pumpAndSettle();
  });

  testWidgets('with reduce motion the stamps are simply there', (tester) async {
    await tester.pumpWidget(app(2, reduceMotion: true));
    await tester.pump();
    for (final o in tester.widgetList<Opacity>(
      find.ancestor(of: find.byType(StationStamp), matching: find.byType(Opacity)),
    )) {
      expect(o.opacity, 1.0);
    }
  });
}
