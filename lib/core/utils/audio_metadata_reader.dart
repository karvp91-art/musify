import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

class ParsedAudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final Uint8List? artworkBytes;

  const ParsedAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.artworkBytes,
  });
}

class AudioMetadataReader {
  /// Reads ID3v2, ID3v1 metadata and embedded album artwork (APIC) from an audio file.
  static Future<ParsedAudioMetadata?> readMetadata(File file) async {
    try {
      if (!await file.exists()) return null;

      final raf = await file.open(mode: FileMode.read);
      try {
        final length = await raf.length();
        if (length < 10) return null;

        // 1. Try reading ID3v2 header
        final header = await raf.read(10);
        if (header.length == 10 &&
            header[0] == 0x49 && // 'I'
            header[1] == 0x44 && // 'D'
            header[2] == 0x33) { // '3'
          final version = header[3]; // 3 for ID3v2.3, 4 for ID3v2.4
          final tagSize = _decodeSynchsafe(header.sublist(6, 10));

          // Read up to 8MB of ID3 frame data so embedded APIC artworks are not truncated
          final bytesToRead = tagSize < 8388608 ? tagSize : 8388608;
          final frameBytes = await raf.read(bytesToRead);

          final metadata = _parseId3v2Frames(frameBytes, version);
          if (metadata.title != null || metadata.artist != null || metadata.artworkBytes != null) {
            return metadata;
          }
        }

        // 2. Fallback: Check ID3v1 at the end of the file
        if (length >= 128) {
          await raf.setPosition(length - 128);
          final id3v1Bytes = await raf.read(128);
          if (id3v1Bytes.length == 128 &&
              id3v1Bytes[0] == 0x54 && // 'T'
              id3v1Bytes[1] == 0x41 && // 'A'
              id3v1Bytes[2] == 0x47) { // 'G'
            final title = _decodeAsciiOrLatin1(id3v1Bytes.sublist(3, 33)).trim();
            final artist = _decodeAsciiOrLatin1(id3v1Bytes.sublist(33, 63)).trim();
            final album = _decodeAsciiOrLatin1(id3v1Bytes.sublist(63, 93)).trim();

            return ParsedAudioMetadata(
              title: title.isNotEmpty ? title : null,
              artist: artist.isNotEmpty ? artist : null,
              album: album.isNotEmpty ? album : null,
            );
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {
      // Ignore reading errors on corrupt or locked files
    }

    return null;
  }

  static int _decodeSynchsafe(Uint8List bytes) {
    return ((bytes[0] & 0x7F) << 21) |
        ((bytes[1] & 0x7F) << 14) |
        ((bytes[2] & 0x7F) << 7) |
        (bytes[3] & 0x7F);
  }

  static ParsedAudioMetadata _parseId3v2Frames(Uint8List data, int version) {
    String? title;
    String? artist;
    String? album;
    Uint8List? artworkBytes;

    int? durationMs;

    int offset = 0;
    while (offset + 10 <= data.length) {
      // If frame ID starts with 0, padding reached
      if (data[offset] == 0) break;

      final frameId = String.fromCharCodes(data.sublist(offset, offset + 4));
      offset += 4;

      int frameSize;
      if (version == 4) {
        frameSize = _decodeSynchsafe(data.sublist(offset, offset + 4));
      } else {
        frameSize = (data[offset] << 24) |
            (data[offset + 1] << 16) |
            (data[offset + 2] << 8) |
            data[offset + 3];
      }
      offset += 4;

      // Skip 2 bytes flags
      offset += 2;

      if (frameSize <= 0 || offset + frameSize > data.length) {
        break;
      }

      final framePayload = data.sublist(offset, offset + frameSize);
      offset += frameSize;

      if (frameId == 'TIT2' || frameId == 'TIT1') {
        title = _decodeFrameText(framePayload);
      } else if (frameId == 'TPE1' || frameId == 'TPE2') {
        artist = _decodeFrameText(framePayload);
      } else if (frameId == 'TALB') {
        album = _decodeFrameText(framePayload);
      } else if (frameId == 'TLEN') {
        final lenStr = _decodeFrameText(framePayload);
        durationMs = int.tryParse(lenStr);
      } else if (frameId == 'APIC' || frameId == 'PIC') {
        artworkBytes = _extractApicImage(framePayload);
      }
    }

    return ParsedAudioMetadata(
      title: title?.isNotEmpty == true ? title : null,
      artist: artist?.isNotEmpty == true ? artist : null,
      album: album?.isNotEmpty == true ? album : null,
      durationMs: durationMs,
      artworkBytes: artworkBytes,
    );
  }

  /// Fast check of the first MPEG audio frame sync to read the true encoded bitrate (kbps)
  static Future<int?> readMp3Bitrate(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        final length = await raf.length();
        if (length < 128) return null;
        final bytes = await raf.read(8192);
        for (int i = 0; i + 3 < bytes.length; i++) {
          if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
            final version = (bytes[i + 1] >> 3) & 0x03;
            final layer = (bytes[i + 1] >> 1) & 0x03;
            final bitrateIdx = (bytes[i + 2] >> 4) & 0x0F;
            if (bitrateIdx > 0 && bitrateIdx < 15 && version == 3 && layer == 1) {
              const bitrates = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
              return bitrates[bitrateIdx];
            }
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return null;
  }

  /// Extracts raw JPEG / PNG binary image from APIC frame payload
  static Uint8List? _extractApicImage(Uint8List payload) {
    if (payload.length < 16) return null;

    // Search for JPEG magic number (0xFF, 0xD8)
    for (int i = 1; i + 1 < payload.length; i++) {
      if (payload[i] == 0xFF && payload[i + 1] == 0xD8) {
        return payload.sublist(i);
      }
    }

    // Search for PNG magic number (0x89, 0x50, 0x4E, 0x47)
    for (int i = 1; i + 3 < payload.length; i++) {
      if (payload[i] == 0x89 &&
          payload[i + 1] == 0x50 &&
          payload[i + 2] == 0x4E &&
          payload[i + 3] == 0x47) {
        return payload.sublist(i);
      }
    }

    return null;
  }

  static String _decodeFrameText(Uint8List payload) {
    if (payload.isEmpty) return '';
    final encoding = payload[0];
    final textBytes = payload.sublist(1);

    try {
      if (encoding == 0) {
        // ISO-8859-1 (Latin1)
        return latin1.decode(textBytes).replaceAll('\x00', '').trim();
      } else if (encoding == 1) {
        // UTF-16 with BOM
        return _decodeUtf16(textBytes);
      } else if (encoding == 2) {
        // UTF-16BE without BOM
        return _decodeUtf16BE(textBytes);
      } else if (encoding == 3) {
        // UTF-8
        return utf8.decode(textBytes, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {}

    return _decodeAsciiOrLatin1(textBytes);
  }

  static String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';
    final isLE = bytes[0] == 0xFF && bytes[1] == 0xFE;
    final isBE = bytes[0] == 0xFE && bytes[1] == 0xFF;
    final start = (isLE || isBE) ? 2 : 0;

    final buffer = StringBuffer();
    for (int i = start; i + 1 < bytes.length; i += 2) {
      final codeUnit = isBE
          ? (bytes[i] << 8) | bytes[i + 1]
          : bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit == 0) break;
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString().trim();
  }

  static String _decodeUtf16BE(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      if (codeUnit == 0) break;
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString().trim();
  }

  static String _decodeAsciiOrLatin1(Uint8List bytes) {
    try {
      return latin1.decode(bytes).replaceAll('\x00', '').trim();
    } catch (_) {
      return String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126)).trim();
    }
  }

  /// Finds cover artwork in same directory if embedded art is not present
  static Future<String?> findFolderArtwork(File audioFile) async {
    try {
      final parentDir = audioFile.parent;
      final candidates = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 'albumart.jpg', 'album.jpg', 'front.jpg'];
      for (final name in candidates) {
        final f = File(p.join(parentDir.path, name));
        if (await f.exists()) return f.path;
      }
    } catch (_) {}
    return null;
  }
}
