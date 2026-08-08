import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/allowed_workout_apps.dart';
import 'app_info.dart';
import 'focus_authorization_status.dart';
import 'focus_control_result.dart';

/// Service responsible for Focus Control, permission checks, allowlist management, and quick access bridges.
class FocusControlService {
  static const String channelName = 'com.cotrainr.focuslift/focus_control';
  static const String _prefSelectedDistractionsKey = 'focus_lift_selected_distractions';

  final MethodChannel _channel;
  final SharedPreferences? _prefs;
  bool _isSessionActive = false;

  FocusControlService([
    MethodChannel? channel,
    SharedPreferences? prefs,
  ])  : _channel = channel ?? const MethodChannel(channelName),
        _prefs = prefs;

  static Future<FocusControlService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FocusControlService(const MethodChannel(channelName), prefs);
  }

  bool get isSessionActive => _isSessionActive;

  /// Checks the current platform authorization status for usage access / Screen Time.
  Future<FocusAuthorizationStatus> getAuthorizationStatus() async {
    try {
      final String? result = await _channel.invokeMethod<String>('getAuthorizationStatus');
      switch (result) {
        case 'authorized':
          return FocusAuthorizationStatus.authorized;
        case 'denied':
          return FocusAuthorizationStatus.denied;
        case 'restricted':
          return FocusAuthorizationStatus.restricted;
        case 'notDetermined':
          return FocusAuthorizationStatus.notDetermined;
        default:
          return FocusAuthorizationStatus.unsupported;
      }
    } catch (_) {
      return FocusAuthorizationStatus.unsupported;
    }
  }

  /// Checks if Usage Access is granted on Android / Screen Time on iOS.
  Future<bool> isUsageAccessGranted() async {
    final status = await getAuthorizationStatus();
    return status == FocusAuthorizationStatus.authorized;
  }

  /// Checks if system notifications are enabled for Focus Lift.
  Future<bool> areNotificationsEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the official system notification settings for this application.
  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  /// Opens the official Android Settings.ACTION_USAGE_ACCESS_SETTINGS screen.
  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } catch (_) {
      await requestAuthorization();
    }
  }

  /// Contextually requests focus control or usage access authorization.
  Future<bool> requestAuthorization() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('requestAuthorization');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the native system app picker (e.g., Apple's FamilyActivityPicker on iOS).
  Future<void> openAppPicker() async {
    try {
      await _channel.invokeMethod<void>('openAppPicker');
    } catch (_) {}
  }

  /// Launches the user's selected music app or standard system audio player.
  Future<bool> launchMusicApp([String? packageName]) async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>('launchMusicApp', {
        'packageName': packageName,
      });
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the standard system dialer for essential or emergency calls.
  Future<bool> launchPhoneApp() async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>('launchPhoneApp');
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the standard system camera for recording sets or taking form photos.
  Future<bool> launchCameraApp() async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>('launchCameraApp');
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Discovers installed music and audio streaming applications on the device.
  Future<List<AppInfo>> discoverInstalledMusicApps() async {
    try {
      final List<dynamic>? apps =
          await _channel.invokeListMethod<dynamic>('discoverInstalledMusicApps');
      if (apps == null) return [];

      return apps.map((item) {
        if (item is Map) {
          final pkg = item['packageName'] as String? ?? '';
          final name = item['appName'] as String? ?? pkg;
          return AppInfo(
            appName: name,
            packageName: pkg,
          );
        }
        return const AppInfo(appName: 'Unknown', packageName: '');
      }).where((app) => app.packageName.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns user-launchable applications discovered on the device.
  Future<List<AppInfo>> getLauncherApps() async {
    try {
      final List<dynamic>? apps = await _channel.invokeListMethod<dynamic>('getLauncherApps');
      if (apps == null) return [];

      final selectedPackages = await getSelectedDistractions();
      final selectedSet = selectedPackages.toSet();

      return apps.map((item) {
        if (item is Map) {
          final pkg = item['packageName'] as String? ?? '';
          final name = item['appName'] as String? ?? pkg;
          return AppInfo(
            appName: name,
            packageName: pkg,
            isSelected: selectedSet.contains(pkg),
          );
        }
        return const AppInfo(appName: 'Unknown', packageName: '');
      }).where((app) => app.packageName.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns the saved list of custom distracting/allowed package identifiers.
  Future<List<String>> getSelectedDistractions() async {
    if (_prefs != null) {
      return _prefs.getStringList(_prefSelectedDistractionsKey) ?? [];
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefSelectedDistractionsKey) ?? [];
  }

  /// Saves the user's selected packages locally on the device.
  Future<void> saveSelectedDistractions(List<String> packageNames) async {
    if (_prefs != null) {
      await _prefs.setStringList(_prefSelectedDistractionsKey, packageNames);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefSelectedDistractionsKey, packageNames);
    }

    try {
      await _channel.invokeMethod<void>('updateSelectedDistractions', {
        'packages': packageNames,
      });
    } catch (_) {}
  }

  /// Starts an active focus control session with the user's allowed workout apps.
  Future<FocusControlResult> startFocusWorkout(AllowedWorkoutApps allowed) async {
    _isSessionActive = true;
    final status = await getAuthorizationStatus();

    try {
      final bool? success = await _channel.invokeMethod<bool>('startFocusSession', {
        'allowed': allowed.toMap(),
      });

      if (success == true) {
        return FocusControlResult.active();
      } else {
        return FocusControlResult.reduced(
          status: status,
          message: 'Workout active with standard timer.',
        );
      }
    } catch (_) {
      return FocusControlResult.reduced(
        status: status,
        message: 'Workout active with standard timer.',
      );
    }
  }

  /// Stops the active focus session when workout finishes or is discarded.
  Future<void> stopFocusSession() async {
    _isSessionActive = false;
    try {
      await _channel.invokeMethod<void>('stopFocusSession');
    } catch (_) {}
  }

  /// Unconditional fail-safe method ensuring all shields/restrictions are cleared.
  Future<void> restoreNormalAccess() async {
    _isSessionActive = false;
    try {
      await _channel.invokeMethod<void>('restoreNormalAccess');
    } catch (_) {}
  }
}
