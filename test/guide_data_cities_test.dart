import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';

/// Every city's guide files read (a Tottori tip with months as numbers once
/// stopped the whole guide, and the 路線図 with it).
void main() {
  for (final dir in Directory('assets/cities').listSync().whereType<Directory>()) {
    final id = dir.path.split(Platform.pathSeparator).last.split('/').last;
    test('$id guide data reads', () {
      Object? read(String f) {
        final file = File('${dir.path}/$f');
        return file.existsSync() ? jsonDecode(file.readAsStringSync()) : null;
      }

      final g = GuideData.fromJson(
        exits: read('exits.json') as Map<String, dynamic>?,
        courses: read('courses.json') as List<dynamic>?,
        tips: read('tips.json') as Map<String, dynamic>?,
        pool: read('attendant_tips.json') as List<dynamic>?,
      );
      if (File('${dir.path}/attendant_tips.json').existsSync()) expect(g.pool, isNotEmpty);
    });
  }
}
