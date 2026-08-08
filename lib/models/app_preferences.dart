import 'focus_mode.dart';

/// Holds user preferences stored locally on the device.
class AppPreferences {
  const AppPreferences({
    this.defaultRestDurationSeconds = 60,
    this.focusMode = FocusMode.focus,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.keepScreenAwake = true,
    this.selectedApps = const <String>{},
  });

  final int defaultRestDurationSeconds;
  final FocusMode focusMode;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool keepScreenAwake;
  final Set<String> selectedApps;

  AppPreferences copyWith({
    int? defaultRestDurationSeconds,
    FocusMode? focusMode,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? keepScreenAwake,
    Set<String>? selectedApps,
  }) {
    return AppPreferences(
      defaultRestDurationSeconds:
          defaultRestDurationSeconds ?? this.defaultRestDurationSeconds,
      focusMode: focusMode ?? this.focusMode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      selectedApps: selectedApps ?? this.selectedApps,
    );
  }
}
