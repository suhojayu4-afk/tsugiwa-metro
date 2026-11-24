import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter/services.dart';

import 'models/city.dart';

/// Reads city JSON files from assets. Adding a city = adding a folder + index entry.
class CityRepository {
  CityRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, CityData> _cache = {};

  Future<List<dynamic>> _optional(String path) async {
    try {
      return jsonDecode(await _bundle.loadString(path)) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _optionalMap(String path) async {
    try {
      return await compute(jsonDecode, await _bundle.loadString(path)) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  Future<List<CityEntry>> loadIndex() async {
    final json = jsonDecode(await _bundle.loadString('assets/cities/index.json')) as Map<String, dynamic>;
    return [for (final c in json['cities'] as List) CityEntry.fromJson(c as Map<String, dynamic>)];
  }

  Future<CityData> loadCity(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    // Decoded off the UI thread: 2,000+ stations.
    Future<dynamic> read(String file) async => compute(jsonDecode, await _bundle.loadString('assets/cities/$id/$file'));
    final city = CityData.fromJson(
      city: await read('city.json') as Map<String, dynamic>,
      stations: await read('stations.json') as List<dynamic>,
      lines: await read('lines.json') as List<dynamic>,
      timetables: await read('timetables.json') as Map<String, dynamic>,
      walks: await _optional('assets/cities/$id/walks.json'),
      throughs: await _optional('assets/cities/$id/through.json'),
      trains: await _optionalMap('assets/cities/$id/trains.json'),
    );
    return _cache[id] = city;
  }
}
