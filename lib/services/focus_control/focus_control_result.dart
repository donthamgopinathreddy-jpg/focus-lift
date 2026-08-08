import 'focus_authorization_status.dart';

/// The result returned when initiating or modifying a Focus session.
class FocusControlResult {
  /// Whether the focus session was successfully initiated.
  final bool success;

  /// The current authorization status of the device.
  final FocusAuthorizationStatus status;

  /// Human-readable explanation or error message.
  final String? message;

  const FocusControlResult({
    required this.success,
    required this.status,
    this.message,
  });

  /// Factory for a successful focus activation.
  factory FocusControlResult.active() {
    return const FocusControlResult(
      success: true,
      status: FocusAuthorizationStatus.authorized,
      message: 'Focus session active.',
    );
  }

  /// Factory for a reduced or skipped focus activation.
  factory FocusControlResult.reduced({
    required FocusAuthorizationStatus status,
    String? message,
  }) {
    return FocusControlResult(
      success: false,
      status: status,
      message: message ?? 'Workout running with standard timer.',
    );
  }
}
