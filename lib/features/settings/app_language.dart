import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language picked in 設定. null = follow the phone's language.
///
/// Only the screens inside the app follow this; home screen widgets and the
/// launcher label are drawn by the system in the phone's language.
class AppLanguage {
  static const key = 'settings.lang';
  static const choices = ['ja', 'ko', 'en'];

  /// Listened to by the app's MaterialApp (lib/app.dart).
  static final ValueNotifier<String?> override = ValueNotifier<String?>(null);

  /// Reads the saved choice. Called once before the app starts.
  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(key);
      override.value = choices.contains(saved) ? saved : null;
    } catch (_) {
      // Storage not ready: keep following the phone.
    }
  }

  static Future<void> set(String? lang) async {
    override.value = choices.contains(lang) ? lang : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (override.value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, override.value!);
      }
    } catch (_) {
      // Not saved: the choice still holds until the app closes.
    }
  }
}
