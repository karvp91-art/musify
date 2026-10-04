class EqualizerState {
  final bool isEnabled;
  final String preset;
  final List<double> bandGains; // 7 bands in dB: 60Hz, 150Hz, 400Hz, 1kHz, 2.5kHz, 6kHz, 14kHz
  final double bassBoost; // 0.0 to 1.0 (Low frequencies)
  final double virtualizer; // 0.0 to 1.0 (Spatial soundstage)
  final double loudness; // 0.0 to 1.0 (Overall volume boost)

  const EqualizerState({
    this.isEnabled = false,
    this.preset = 'Custom',
    this.bandGains = const [4.0, 2.0, 0.0, -1.0, 2.0, 3.0, 4.0],
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.loudness = 0.6,
  });

  EqualizerState copyWith({
    bool? isEnabled,
    String? preset,
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
    double? loudness,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      preset: preset ?? this.preset,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      loudness: loudness ?? this.loudness,
    );
  }
}

class EqualizerPresets {
  static const Map<String, List<double>> presets = {
    'Custom': [4.0, 2.0, 0.0, -1.0, 2.0, 3.0, 4.0],
    'Normal': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [5.0, 4.0, 2.0, 0.0, 0.0, 1.0, 1.5],
    'Vocal': [-2.0, -1.0, 2.0, 4.0, 3.5, 2.0, 1.0],
    'Rock': [4.5, 3.0, 1.5, -0.5, 1.5, 3.0, 4.5],
    'Pop': [2.0, 1.5, 1.0, 2.5, 2.0, 2.5, 3.0],
    'Electronic': [5.5, 4.0, 2.0, -0.5, 2.0, 3.5, 5.0],
    'Hip-Hop': [6.0, 4.5, 2.0, 0.5, 1.0, 2.5, 3.5],
    'Jazz': [3.0, 2.0, 1.0, 0.0, 1.5, 2.5, 3.0],
    'Classical': [4.0, 3.0, 1.5, 0.0, 1.5, 2.5, 3.5],
    'Acoustic': [3.5, 2.5, 1.5, 1.0, 2.5, 3.0, 2.5],
  };

  static const List<String> bandFrequencies = [
    '60Hz',
    '150Hz',
    '400Hz',
    '1kHz',
    '2.5kHz',
    '6kHz',
    '14kHz',
  ];

  static const List<String> bandLabels = [
    '60Hz',
    '150Hz',
    '400Hz',
    '1kHz',
    '2.5kHz',
    '6kHz',
    '14kHz',
  ];
}
