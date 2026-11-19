import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'my_catalog.dart';
import 'my_store.dart';

/// Stickers the user has: every sticker in the packs they own (the basic
/// pack is free), in catalog order.
List<String> ownedStickers(MyStore store) {
  final cat = store.catalog;
  if (cat == null) return const [];
  return [
    for (final pack in cat.inSlot(MySlot.sticker))
      if (store.owns(pack.id)) ...pack.stickers,
  ];
}

/// Stickers stuck on stations of the route map (one per station): after a
/// trip the user can mark where they got on and off.
class StickerMarks extends ChangeNotifier {
  StickerMarks({this.prefix = 'stickers'});

  final String prefix;
  final Map<String, String> _marks = {};
  bool _loaded = false;

  /// Station id → sticker name.
  Map<String, String> get marks => Map.unmodifiable(_marks);
  String? at(String stationId) => _marks[stationId];

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString('$prefix.marks') ?? '{}') as Map<String, dynamic>;
      _marks
        ..clear()
        ..addAll(raw.map((k, v) => MapEntry(k, v as String)));
    } catch (_) {
      _marks.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Sticks [sticker] on [stationId]; null takes it off.
  Future<void> put(String stationId, String? sticker) async {
    if (sticker == null) {
      _marks.remove(stationId);
    } else {
      _marks[stationId] = sticker;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$prefix.marks', jsonEncode(_marks));
  }
}
