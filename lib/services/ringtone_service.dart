import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum RingtoneType {
  ringtone(1, 'Phone Ringtone'),
  notification(2, 'Notification Sound'),
  alarm(4, 'Alarm Sound');

  final int value;
  final String label;
  const RingtoneType(this.value, this.label);
}

class RingtoneService {
  static const MethodChannel _channel = MethodChannel('com.musify/ringtone');

  /// Checks if WRITE_SETTINGS permission is granted on Android.
  static Future<bool> canWriteSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('canWriteSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Android Settings page allowing the user to grant WRITE_SETTINGS.
  static Future<bool> openWriteSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('openWriteSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Extracts real audio waveform amplitude samples from an audio file natively.
  static Future<List<double>?> extractWaveform(String inputPath, {int samples = 64}) async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<List>('extractWaveform', {
        'inputPath': inputPath,
        'samples': samples,
      });
      if (res != null) {
        return res.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Trims an audio file natively via Android MediaExtractor + MediaMuxer or frame-slicing.
  static Future<String?> trimAudio({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    int fadeInMs = 0,
    int fadeOutMs = 0,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map>('trimAudio', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startMs': startMs,
        'endMs': endMs,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
      });

      if (res != null && res['success'] == true) {
        return res['outputPath'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Sets an audio file as Phone Ringtone, Notification, or Alarm.
  static Future<Map<String, dynamic>> setRingtone({
    required String filePath,
    String? title,
    RingtoneType type = RingtoneType.ringtone,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map>('setRingtone', {
        'filePath': filePath,
        'title': title,
        'type': type.value,
      });

      if (res != null) {
        return {
          'success': res['success'] == true,
          'needPermission': res['needPermission'] == true,
          'uri': res['uri'] as String?,
        };
      }
      return {'success': false, 'needPermission': false};
    } catch (e) {
      return {'success': false, 'needPermission': false, 'error': e.toString()};
    }
  }

  /// Prepares an export output path inside device storage / application cache.
  static Future<String> getSuggestedOutputPath(String title, {String extension = 'mp3'}) async {
    final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final dir = await getApplicationDocumentsDirectory();
    final ringtoneDir = Directory('${dir.path}/Ringtones');
    if (!await ringtoneDir.exists()) {
      await ringtoneDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${ringtoneDir.path}/${cleanTitle}_ringtone_$timestamp.$extension';
  }
}
