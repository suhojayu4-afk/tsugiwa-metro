import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/models/station.dart';
import '../../l10n/app_localizations.dart';
import '../common/station_name.dart';
import 'platform_texts.dart';

/// Bottom sheet listing every station, searchable in ja / kana / ko / en.
Future<String?> pickStation(BuildContext context, CityData city) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: PixelColors.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _StationPicker(city: city)),
  );
}

class _StationPicker extends StatefulWidget {
  const _StationPicker({required this.city});
  final CityData city;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  List<Station> get _stations {
    // Line order, without duplicates for transfer stations.
    final seen = <String>{};
    final list = <Station>[
      for (final line in widget.city.lines)
        for (final id in line.stations)
          if (seen.add(id)) widget.city.station(id),
    ];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    // Exact name / reading first, then names that start with it, then the rest.
    int rank(Station s) {
      final names = [...s.name.values.values.map((n) => n.toLowerCase()), s.kana, s.id.split('.').last];
      if (names.contains(q)) return 0;
      if (names.any((n) => n.startsWith(q))) return 1;
      return 2;
    }

    final hits = list.where((s) => s.searchKey.contains(q)).toList();
    final order = {for (var i = 0; i < hits.length; i++) hits[i]: i};
    return hits..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : order[a]!.compareTo(order[b]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final stations = _stations;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: PixelBox(
            color: PixelColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            child: TextField(
              style: pixelStyle(size: 18),
              cursorColor: PixelColors.ink,
              decoration: InputDecoration(
                hintText: t.searchHint,
                hintStyle: pixelStyle(size: 15, color: PixelColors.muted),
                prefixIcon: Icon(Icons.search, color: PixelColors.ink),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (stations.isEmpty)
          // Nothing matches: say so, with a way on.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 40, color: PixelColors.muted),
                  const SizedBox(height: 10),
                  PixelText(
                    searchNoMatch.of(lang),
                    key: const ValueKey('searchNoMatch'),
                    size: 18,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  PixelText(searchNoMatchHint.of(lang), size: 14, color: PixelColors.muted, align: TextAlign.center),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: stations.length,
              itemBuilder: (context, i) {
                final s = stations[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, s.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: PixelColors.soft, width: pu),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: StationName(station: s, size: 22)),
                        for (final lineId in s.lines)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: PixelSquare(color: widget.city.line(lineId).color, size: 15),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
