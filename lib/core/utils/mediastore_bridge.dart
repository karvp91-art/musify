import 'dart:io';
import 'package:flutter/services.dart';

/// Parsed metadata result from Android MediaStore.
/// MediaStore uses the OS-level media scanner which is more robust
/// than manual ID3 binary parsing for non-standard / exotic files.
class MediaStoreMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final int? trackNumber;

  const MediaStoreMetadata({
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.trackNumber,
  });

  bool get hasUsefulData =>
      (title != null && title!.isNotEmpty) ||
      (artist != null && artist!.isNotEmpty);
}

/// Queries Android's MediaStore via a platform channel for audio file metadata.
/// Returns null on non-Android platforms or when the file is not indexed.
class MediaStoreBridge {
  static const _channel = MethodChannel('com.musify/mediastore');

  /// Queries MediaStore for metadata of the given file path.
  /// Returns null if the platform is not Android, or the file is not in MediaStore.
  static Future<MediaStoreMetadata?> getMetadata(String filePath) async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getMetadata', {
        'filePath': filePath,
      });

      if (result == null || result.isEmpty) return null;

      return MediaStoreMetadata(
        title: result['title'] as String?,
        artist: result['artist'] as String?,
        album: result['album'] as String?,
        durationMs: result['durationMs'] != null
            ? (result['durationMs'] as num).toInt()
            : null,
        trackNumber: result['track'] != null
            ? (result['track'] as num).toInt()
            : null,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
