import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SampleAudioGenerator {
  /// Generates a valid 16-bit PCM Stereo WAV file with musical chords.
  static Future<File> generateSampleWav({
    required String fileName,
    required List<double> chordFrequencies,
    required double durationSeconds,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final sampleDir = Directory(p.join(docsDir.path, 'Music', 'MusifySamples'));
    if (!await sampleDir.exists()) {
      await sampleDir.create(recursive: true);
    }

    final filePath = p.join(sampleDir.path, fileName);
    final file = File(filePath);

    // Audio parameters
    const sampleRate = 44100;
    const numChannels = 2; // Stereo
    const bitsPerSample = 16;
    final numSamples = (sampleRate * durationSeconds).toInt();
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 44 + dataSize;

    final bytes = BytesBuilder();

    // 1. "RIFF" Header
    bytes.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    bytes.add(_int32ToBytes(fileSize - 8));
    bytes.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // 2. "fmt " Sub-chunk
    bytes.add([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    bytes.add(_int32ToBytes(16)); // SubChunk1Size (16 for PCM)
    bytes.add(_int16ToBytes(1)); // AudioFormat (1 = PCM)
    bytes.add(_int16ToBytes(numChannels));
    bytes.add(_int32ToBytes(sampleRate));
    bytes.add(_int32ToBytes(sampleRate * numChannels * (bitsPerSample ~/ 8))); // ByteRate
    bytes.add(_int16ToBytes(numChannels * (bitsPerSample ~/ 8))); // BlockAlign
    bytes.add(_int16ToBytes(bitsPerSample));

    // 3. "data" Sub-chunk
    bytes.add([0x64, 0x61, 0x74, 0x61]); // "data"
    bytes.add(_int32ToBytes(dataSize));

    // 4. Synthesize Musical Harmonic Audio Samples
    const maxAmplitude = 16000;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;

      // Exponential decay envelope per second for gentle chime feel
      final noteTime = t % 1.5;
      final envelope = exp(-3.0 * noteTime);

      double sampleValue = 0.0;
      for (int c = 0; c < chordFrequencies.length; c++) {
        final freq = chordFrequencies[c];
        sampleValue += sin(2.0 * pi * freq * t) * (1.0 / chordFrequencies.length);
      }

      final intSample = (sampleValue * envelope * maxAmplitude).clamp(-32768, 32767).toInt();

      // Left Channel
      bytes.add(_int16ToBytes(intSample));
      // Right Channel (slight phase delay for stereo width)
      final rightSample = (sampleValue * envelope * 0.95 * maxAmplitude).clamp(-32768, 32767).toInt();
      bytes.add(_int16ToBytes(rightSample));
    }

    await file.writeAsBytes(bytes.toBytes(), flush: true);
    return file;
  }

  static Uint8List _int16ToBytes(int value) {
    return Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);
  }

  static Uint8List _int32ToBytes(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
  }

  /// Creates 3 sample demonstration tracks
  static Future<List<File>> generateDemoSuite() async {
    final track1 = await generateSampleWav(
      fileName: 'Aura Sound - Ambient Sunrise.wav',
      chordFrequencies: [261.63, 329.63, 392.0, 523.25], // C Major
      durationSeconds: 12.0,
    );

    final track2 = await generateSampleWav(
      fileName: 'Ketsa - Velvet Chill.wav',
      chordFrequencies: [220.0, 261.63, 329.63, 440.0], // A Minor
      durationSeconds: 15.0,
    );

    final track3 = await generateSampleWav(
      fileName: 'Lofi Collective - Midnight Study.wav',
      chordFrequencies: [349.23, 440.0, 523.25, 659.25], // F Major 7
      durationSeconds: 14.0,
    );

    return [track1, track2, track3];
  }
}
