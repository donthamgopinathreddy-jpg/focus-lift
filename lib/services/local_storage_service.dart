import 'package:shared_preferences/shared_preferences.dart';
import '../models/allowed_workout_apps.dart';
import '../models/app_preferences.dart';

/// Service responsible for fast, 100% on-device preference storage.
class LocalStorageService {
  static const String _keyRestDuration = 'fl_default_rest_duration';
  static const String _keySound = 'fl_sound_enabled';
  static const String _keyVibration = 'fl_vibration_enabled';
  static const String _keyKeepScreenAwake = 'fl_keep_screen_awake';
  static const String _keyCallsAllowed = 'fl_calls_allowed';
  static const String _keyMusicAllowed = 'fl_music_allowed';
  static const String _keyMessagesAllowed = 'fl_messages_allowed';
  static const String _keyCameraAllowed = 'fl_camera_allowed';
  static const String _keyMusicPackage = 'fl_music_package';
  static const String _keyMusicAppName = 'fl_music_app_name';
  static const String _keyCustomAllowed = 'fl_custom_allowed_packages';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Loads stored user preferences with safe defaults.
  AppPreferences loadPreferences() {
    final restSeconds = _prefs.getInt(_keyRestDuration) ?? 60;
    final sound = _prefs.getBool(_keySound) ?? true;
    final vibration = _prefs.getBool(_keyVibration) ?? true;
    final keepAwake = _prefs.getBool(_keyKeepScreenAwake) ?? true;

    final callsAllowed = _prefs.getBool(_keyCallsAllowed) ?? true;
    final musicAllowed = _prefs.getBool(_keyMusicAllowed) ?? true;
    final messagesAllowed = _prefs.getBool(_keyMessagesAllowed) ?? false;
    final cameraAllowed = _prefs.getBool(_keyCameraAllowed) ?? false;
    final musicPackage = _prefs.getString(_keyMusicPackage);
    final musicAppName = _prefs.getString(_keyMusicAppName);
    final customPackages = _prefs.getStringList(_keyCustomAllowed) ?? <String>[];

    final allowedApps = AllowedWorkoutApps(
      callsAllowed: callsAllowed,
      musicAllowed: musicAllowed,
      messagesAllowed: messagesAllowed,
      cameraAllowed: cameraAllowed,
      selectedMusicPackage: musicPackage,
      selectedMusicAppName: musicAppName,
      customAllowedPackages: customPackages.toSet(),
    );

    return AppPreferences(
      defaultRestDurationSeconds: restSeconds,
      soundEnabled: sound,
      vibrationEnabled: vibration,
      keepScreenAwake: keepAwake,
      allowedApps: allowedApps,
    );
  }

  /// Saves updated preferences locally.
  Future<void> savePreferences(AppPreferences preferences) async {
    final allowed = preferences.allowedApps;
    await Future.wait([
      _prefs.setInt(_keyRestDuration, preferences.defaultRestDurationSeconds),
      _prefs.setBool(_keySound, preferences.soundEnabled),
      _prefs.setBool(_keyVibration, preferences.vibrationEnabled),
      _prefs.setBool(_keyKeepScreenAwake, preferences.keepScreenAwake),
      _prefs.setBool(_keyCallsAllowed, allowed.callsAllowed),
      _prefs.setBool(_keyMusicAllowed, allowed.musicAllowed),
      _prefs.setBool(_keyMessagesAllowed, allowed.messagesAllowed),
      _prefs.setBool(_keyCameraAllowed, allowed.cameraAllowed),
      if (allowed.selectedMusicPackage != null)
        _prefs.setString(_keyMusicPackage, allowed.selectedMusicPackage!)
      else
        _prefs.remove(_keyMusicPackage),
      if (allowed.selectedMusicAppName != null)
        _prefs.setString(_keyMusicAppName, allowed.selectedMusicAppName!)
      else
        _prefs.remove(_keyMusicAppName),
      _prefs.setStringList(_keyCustomAllowed, allowed.customAllowedPackages.toList()),
    ]);
  }

  /// Saves a single rest timer duration preference.
  Future<void> saveRestDuration(int seconds) async {
    await _prefs.setInt(_keyRestDuration, seconds);
  }

  /// Saves updated AllowedWorkoutApps configuration.
  Future<void> saveAllowedApps(AllowedWorkoutApps allowed) async {
    await Future.wait([
      _prefs.setBool(_keyCallsAllowed, allowed.callsAllowed),
      _prefs.setBool(_keyMusicAllowed, allowed.musicAllowed),
      _prefs.setBool(_keyMessagesAllowed, allowed.messagesAllowed),
      _prefs.setBool(_keyCameraAllowed, allowed.cameraAllowed),
      if (allowed.selectedMusicPackage != null)
        _prefs.setString(_keyMusicPackage, allowed.selectedMusicPackage!)
      else
        _prefs.remove(_keyMusicPackage),
      if (allowed.selectedMusicAppName != null)
        _prefs.setString(_keyMusicAppName, allowed.selectedMusicAppName!)
      else
        _prefs.remove(_keyMusicAppName),
      _prefs.setStringList(_keyCustomAllowed, allowed.customAllowedPackages.toList()),
    ]);
  }
}
