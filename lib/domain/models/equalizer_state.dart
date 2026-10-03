class EqualizerState {
  final bool isEnabled;
  final String preset;
  final List<double> bandGains; // 5 bands in dB: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
  final double bassBoost; // 0.0 to 1.0 (Sub-bass / Loudness boost)
  final double virtualizer; // 0.0 to 1.0 (Spatial soundstage)

  const EqualizerState({
    this.isEnabled = false,
    this.preset = 'Flat',
    this.bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
  });

  EqualizerState copyWith({
    bool? isEnabled,
    String? preset,
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      preset: preset ?? this.preset,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
    );
  }
}

class EqualizerPresets {
  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [6.5, 4.0, 0.0, 0.5, 1.0],
    'Vocal': [-2.0, 1.0, 4.5, 3.5, 1.5],
    'Rock': [4.5, 2.0, -1.0, 2.5, 4.5],
    'Pop': [2.0, 1.0, 3.0, 1.5, 3.5],
    'Electronic': [6.0, 3.5, -1.0, 2.5, 5.0],
    'Hip-Hop': [7.0, 4.5, 0.5, 1.5, 3.0],
    'Jazz': [3.0, 1.5, -1.0, 2.0, 3.0],
    'Classical': [4.0, 2.0, -0.5, 2.0, 3.5],
    'Acoustic': [3.0, 2.0, 1.5, 3.0, 2.5],
  };

  static const List<String> bandFrequencies = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];

  static const List<String> bandLabels = [
    'Sub Bass',
    'Bass',
    'Midrange',
    'Treble',
    'Air',
  ];
}
