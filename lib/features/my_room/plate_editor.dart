import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/my_store.dart';
import '../../l10n/app_localizations.dart';
import 'station_plate.dart';

/// Bottom sheet to name the station shown on the train's destination LED:
/// the name and its reading (the LED shows them in turn).
class PlateEditor extends StatefulWidget {
  const PlateEditor({super.key, required this.fallbackName});

  final String fallbackName;

  @override
  State<PlateEditor> createState() => _PlateEditorState();
}

class _PlateEditorState extends State<PlateEditor> {
  final _store = Services.my;
  late final _name = TextEditingController(text: _store.plate.name);
  late final _kana = TextEditingController(text: _store.plate.kana);

  @override
  void dispose() {
    _name.dispose();
    _kana.dispose();
    super.dispose();
  }

  PlateText get _draft => PlateText(
    name: PlateText.cut(_name.text, PlateText.maxName),
    kana: PlateText.cut(_kana.text, PlateText.maxKana),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = _draft;
    final colors = _store.plateStyle.colors;
    final name = d.name.isEmpty ? widget.fallbackName : d.name;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PixelText(t.plateTitle, size: 24),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: PixelColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    LedSign(text: name, colors: colors, width: 250),
                    if (d.kana.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      LedSign(text: d.kana, colors: colors, width: 250, page: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              PixelText(t.plateHint, size: 12, color: PixelColors.muted),
              const SizedBox(height: 12),
              _Field(
                controller: _name,
                label: t.plateName,
                hint: widget.fallbackName,
                max: PlateText.maxName,
                onChanged: _redraw,
              ),
              _Field(
                controller: _kana,
                label: t.plateKana,
                hint: t.plateKanaHint,
                max: PlateText.maxKana,
                onChanged: _redraw,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await _store.setPlate(_draft);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E9447),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: PixelText(t.plateSave, size: 18, color: PixelColors.card),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _redraw(String _) => setState(() {});
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.max,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int max;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      // Japanese input: only cut once the kana → kanji conversion is done.
      maxLength: max,
      maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: PixelColors.background,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    ),
  );
}
