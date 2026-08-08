import 'package:flutter/services.dart';

/// Provides brief, non-intrusive sound and haptic alerts upon rest completion.
class AlertService {
  /// Triggers haptic vibration and audio chime according to user preferences.
  static Future<void> triggerRestCompleteAlert({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    if (vibrationEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {
        // Graceful fallback on devices without haptic motor
      }
    }

    if (soundEnabled) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Graceful fallback on platforms without system sound capability
      }
    }
  }

  /// Triggers a subtle haptic tap on button presses.
  static Future<void> triggerSelectionHaptic() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
