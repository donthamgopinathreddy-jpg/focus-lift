import '../../models/focus_mode.dart';
import 'focus_authorization_status.dart';

/// The result returned when initiating or modifying a Focus session.
class FocusControlResult {
  /// Whether the focus session was successfully initiated.
  final bool success;

  /// The current authorization status of the device.
  final FocusAuthorizationStatus status;

  /// The workout focus mode applied (Focus, Balanced, Custom).
  final FocusMode mode;

  /// Human-readable explanation or error message.
  final String? message;

  const FocusControlResult({
    required this.success,
    required this.status,
    required this.mode,
    this.message,
  });

  /// Factory for a successful focus activation.
  factory FocusControlResult.active(FocusMode mode) {
    return FocusControlResult(
      success: true,
      status: FocusAuthorizationStatus.authorized,
      mode: mode,
      message: 'Focus session active.',
    );
  }

  /// Factory for a reduced or skipped focus activation.
  factory FocusControlResult.reduced({
    required FocusAuthorizationStatus status,
    required FocusMode mode,
    String? message,
  }) {
    return FocusControlResult(
      success: false,
      status: status,
      mode: mode,
      message: message ?? 'Workout running with standard timer.',
    );
  }
}
