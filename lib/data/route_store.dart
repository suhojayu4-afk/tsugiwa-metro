import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a favourite is for; decides its icon and label.
enum FavouriteKind { work, home, other }

/// A saved or recent from → to pair.
@immutable
class SavedRoute {
  const SavedRoute(this.fromId, this.toId, {this.kind = FavouriteKind.other});

  final String fromId;
  final String toId;
  final FavouriteKind kind;

  bool sameStations(String from, String to) => fromId == from && toId == to;

  Map<String, Object> toJson() => {'from': fromId, 'to': toId, 'kind': kind.name};

  static SavedRoute? fromJson(Object? j) {
    if (j is! Map) return null;
    final from = j['from'], to = j['to'];
    if (from is! String || to is! String) return null;
    final kind = FavouriteKind.values.where((k) => k.name == j['kind']).firstOrNull;
    return SavedRoute(from, to, kind: kind ?? FavouriteKind.other);
  }
}

/// Favourite and recent routes, kept on the phone (SharedPreferences).
/// Recents are added when a trip starts; at most [maxRecents], newest first.
class RouteStore extends ChangeNotifier {
  RouteStore({this.prefix = 'routes'});

  static const maxFavourites = 6;
  static const maxRecents = 5;

  final String prefix;
  final List<SavedRoute> _favourites = [];
  final List<SavedRoute> _recents = [];
  bool _loaded = false;

  List<SavedRoute> get favourites => List.unmodifiable(_favourites);
  List<SavedRoute> get recents => List.unmodifiable(_recents);
  bool get loaded => _loaded;

  String get _favKey => '$prefix.favourites';
  String get _recentKey => '$prefix.recents';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _favourites
      ..clear()
      ..addAll(_decode(prefs.getString(_favKey)));
    _recents
      ..clear()
      ..addAll(_decode(prefs.getString(_recentKey)));
    _loaded = true;
    notifyListeners();
  }

  SavedRoute? favouriteFor(String from, String to) =>
      _favourites.where((f) => f.sameStations(from, to)).firstOrNull;

  Future<void> addFavourite(SavedRoute route) async {
    _favourites.removeWhere((f) => f.sameStations(route.fromId, route.toId));
    // Only one "work" and one "home"; a new one replaces the old.
    if (route.kind != FavouriteKind.other) {
      _favourites.removeWhere((f) => f.kind == route.kind);
    }
    _favourites.add(route);
    _favourites.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    while (_favourites.length > maxFavourites) {
      _favourites.removeLast();
    }
    await _save();
  }

  Future<void> removeFavourite(String from, String to) async {
    _favourites.removeWhere((f) => f.sameStations(from, to));
    await _save();
  }

  Future<void> addRecent(String from, String to) async {
    _recents.removeWhere((r) => r.sameStations(from, to));
    _recents.insert(0, SavedRoute(from, to));
    while (_recents.length > maxRecents) {
      _recents.removeLast();
    }
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favKey, jsonEncode([for (final f in _favourites) f.toJson()]));
    await prefs.setString(_recentKey, jsonEncode([for (final r in _recents) r.toJson()]));
  }

  static List<SavedRoute> _decode(String? raw) {
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final j in list) ?SavedRoute.fromJson(j)];
    } catch (_) {
      return const [];
    }
  }
}
