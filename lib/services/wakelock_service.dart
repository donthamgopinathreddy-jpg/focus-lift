import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages keeping the display awake exclusively during active workout sessions.
class WakelockService {
  static Future<void> setAwake(bool shouldKeepAwake) async {
    try {
      if (shouldKeepAwake) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Graceful fallback on platforms or tests without wakelock capability
    }
  }

  static Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
