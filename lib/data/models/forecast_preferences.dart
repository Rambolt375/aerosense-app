/// Data model representing the `/forecast` configuration node in RTDB.
///
/// Fields:
/// - [allowPreventive]: Cloud user opt-in for automated pre-ventilation.
///   Firmware checks this before accepting automated or manual triggers.
/// - [preventiveTrigger]: Flag written to `true` by the app to request a run.
///   Firmware resets this to `false` when finished, or immediately if declined.
class ForecastPreferences {
  const ForecastPreferences({
    this.allowPreventive = false,
    this.preventiveTrigger = false,
  });

  /// Whether automated pre-ventilation is opted into by the team in Settings.
  final bool allowPreventive;

  /// Whether a pre-ventilation trigger has been requested and is being processed/run.
  final bool preventiveTrigger;

  /// Parses defensively from RTDB snapshot value (Map or null).
  factory ForecastPreferences.fromJson(dynamic json) {
    if (json is! Map) {
      return const ForecastPreferences();
    }
    return ForecastPreferences(
      allowPreventive: json['allowPreventive'] == true,
      preventiveTrigger: json['preventiveTrigger'] == true,
    );
  }

  /// Converts to Map for test assertions or debugging.
  Map<String, dynamic> toJson() => {
    'allowPreventive': allowPreventive,
    'preventiveTrigger': preventiveTrigger,
  };

  ForecastPreferences copyWith({
    bool? allowPreventive,
    bool? preventiveTrigger,
  }) {
    return ForecastPreferences(
      allowPreventive: allowPreventive ?? this.allowPreventive,
      preventiveTrigger: preventiveTrigger ?? this.preventiveTrigger,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForecastPreferences &&
          runtimeType == other.runtimeType &&
          allowPreventive == other.allowPreventive &&
          preventiveTrigger == other.preventiveTrigger;

  @override
  int get hashCode => Object.hash(allowPreventive, preventiveTrigger);

  @override
  String toString() =>
      'ForecastPreferences(allowPreventive: $allowPreventive, preventiveTrigger: $preventiveTrigger)';
}
