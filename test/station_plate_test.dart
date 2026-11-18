import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/features/my_room/stamp_book_screen.dart';
import 'package:tsugiwa_metro/features/my_room/station_plate.dart';

void main() {
  test('the LED shows the name, then the reading', () {
    expect(const PlateData(name: '桜坂', kana: 'さくらざか').pages, ['桜坂', 'さくらざか']);
    expect(const PlateData(name: '桜坂').pages, ['桜坂']);
    final look = lookWithLed(const SceneLook(), const PlateData(name: '桜坂'));
    expect(look.led, ['桜坂']);
    expect(look.key, isNot(const SceneLook().key));
  });

  testWidgets('LED and stamps draw without errors, long text is squeezed', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            LedSign(text: 'ながいながいなまえ', colors: [Color(0xFFFFAA3C), Color(0xFF7CF08C)], width: 200, page: 1),
            SizedBox(
              width: 80,
              height: 80,
              child: StationStamp(name: '東京', day: '2026-11-18', color: Color(0xFF80C241)),
            ),
            SizedBox(
              width: 80,
              height: 80,
              child: StationStamp(name: '神田', day: null, color: Color(0xFF80C241)),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home widget picture: whole scene with the LED, PNG', (tester) async {
    final png = await tester.runAsync(
      () => renderMyStationPng(
        look: const SceneLook(),
        plate: const PlateData(name: 'さくら', style: PlateStyle.basic),
        part: DayPart.night,
        lineColor: const Color(0xFF80C241),
        scale: 1,
      ),
    );
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
  });
}
