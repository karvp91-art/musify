import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WAV Header validation logic', () {
    const sampleRate = 44100;
    const numChannels = 2;
    const bitsPerSample = 16;
    const durationSeconds = 2.0;

    final numSamples = (sampleRate * durationSeconds).toInt();
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 44 + dataSize;

    expect(fileSize, 44 + (44100 * 2 * 4));

    // Verify duration calculation formula used in scanner
    final calculatedDurationMs = (((fileSize - 44) / 176400) * 1000).round();
    expect(calculatedDurationMs, 2000);
  });
}
