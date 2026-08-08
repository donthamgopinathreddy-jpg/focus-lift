import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_preferences.dart';
import '../models/focus_mode.dart';

/// Service responsible for fast, 100% on-device preference storage.
class LocalStorageService {
  static const String _keyRestDuration = 'fl_default_rest_duration';
  static const String _keyFocusMode = 'fl_focus_mode';
  static const String _keySound = 'fl_sound_enabled';
  static const String _keyVibration = 'fl_vibration_enabled';
  static const String _keyKeepScreenAwake = 'fl_keep_screen_awake';
  static const String _keySelectedApps = 'fl_selected_apps';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Loads stored user preferences with safe defaults.
  AppPreferences loadPreferences() {
    final restSeconds = _prefs.getInt(_keyRestDuration) ?? 60;
    final focusModeIndex = _prefs.getInt(_keyFocusMode) ?? 0;
    final focusMode = (focusModeIndex >= 0 && focusModeIndex < FocusMode.values.length)
        ? FocusMode.values[focusModeIndex]
        : FocusMode.focus;
    final sound = _prefs.getBool(_keySound) ?? true;
    final vibration = _prefs.getBool(_keyVibration) ?? true;
    final keepAwake = _prefs.getBool(_keyKeepScreenAwake) ?? true;
    final appsList = _prefs.getStringList(_keySelectedApps) ?? <String>[];

    return AppPreferences(
      defaultRestDurationSeconds: restSeconds,
      focusMode: focusMode,
      soundEnabled: sound,
      vibrationEnabled: vibration,
      keepScreenAwake: keepAwake,
      selectedApps: appsList.toSet(),
    );
  }

  /// Saves updated preferences locally.
  Future<void> savePreferences(AppPreferences preferences) async {
    await Future.wait([
      _prefs.setInt(_keyRestDuration, preferences.defaultRestDurationSeconds),
      _prefs.setInt(_keyFocusMode, preferences.focusMode.index),
      _prefs.setBool(_keySound, preferences.soundEnabled),
      _prefs.setBool(_keyVibration, preferences.vibrationEnabled),
      _prefs.setBool(_keyKeepScreenAwake, preferences.keepScreenAwake),
      _prefs.setStringList(_keySelectedApps, preferences.selectedApps.toList()),
    ]);
  }

  /// Saves a single rest timer duration preference.
  Future<void> saveRestDuration(int seconds) async {
    await _prefs.setInt(_keyRestDuration, seconds);
  }

  /// Saves a single focus mode preference.
  Future<void> saveFocusMode(FocusMode mode) async {
    await _prefs.setInt(_keyFocusMode, mode.index);
  }
}
