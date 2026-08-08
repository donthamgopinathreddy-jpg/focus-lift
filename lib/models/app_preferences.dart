import 'allowed_workout_apps.dart';

/// Holds user preferences stored locally on the device.
class AppPreferences {
  const AppPreferences({
    this.defaultRestDurationSeconds = 60,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.keepScreenAwake = true,
    this.allowedApps = const AllowedWorkoutApps(),
  });

  final int defaultRestDurationSeconds;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool keepScreenAwake;
  final AllowedWorkoutApps allowedApps;

  AppPreferences copyWith({
    int? defaultRestDurationSeconds,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? keepScreenAwake,
    AllowedWorkoutApps? allowedApps,
  }) {
    return AppPreferences(
      defaultRestDurationSeconds:
          defaultRestDurationSeconds ?? this.defaultRestDurationSeconds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      allowedApps: allowedApps ?? this.allowedApps,
    );
  }
}
