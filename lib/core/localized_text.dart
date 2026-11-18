/// Text in several languages, e.g. {"ja": "渋谷", "ko": "시부야", "en": "Shibuya"}.
/// Japanese is the fallback because the main audience is Japanese.
class LocalizedText {
  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(json.map((k, v) => MapEntry(k, v as String)));

  final Map<String, String> values;

  String of(String lang) => values[lang] ?? values['ja'] ?? values.values.first;

  String get ja => of('ja');
}
