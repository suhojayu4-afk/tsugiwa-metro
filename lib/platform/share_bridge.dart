import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shares one picture (PNG or GIF) through the phone's share menu. Android
/// goes through the app's own "tsugiwa/share" channel (MainActivity.kt):
/// share_plus's JNI path fails in release builds there. Other platforms
/// use share_plus.
Future<void> shareFile(Uint8List bytes, {required String name, required String mime, String? text}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannel('tsugiwa/share')
        .invokeMethod<bool>('share', {'bytes': bytes, 'name': name, 'mime': mime, 'text': text});
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile.fromData(bytes, mimeType: mime, name: name)],
      fileNameOverrides: [name],
    ),
  );
}
