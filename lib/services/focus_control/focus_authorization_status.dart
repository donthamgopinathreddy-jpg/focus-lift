/// Represents the authorization state of the device's Focus Control capability.
enum FocusAuthorizationStatus {
  /// The user has not yet been prompted for permission.
  notDetermined,

  /// Focus Control is authorized and active on this device.
  authorized,

  /// The user denied the requested permission or settings access.
  denied,

  /// Permission is restricted by system policy or parental restrictions.
  restricted,

  /// Focus Control is unsupported on this platform or OS version.
  unsupported;

  /// User-facing descriptive label.
  String get label {
    switch (this) {
      case FocusAuthorizationStatus.authorized:
        return 'Active';
      case FocusAuthorizationStatus.denied:
        return 'Disabled';
      case FocusAuthorizationStatus.restricted:
        return 'Restricted';
      case FocusAuthorizationStatus.notDetermined:
        return 'Not Configured';
      case FocusAuthorizationStatus.unsupported:
        return 'Not Supported';
    }
  }

  /// User-friendly explanation of the status.
  String get description {
    switch (this) {
      case FocusAuthorizationStatus.authorized:
        return 'Focus Lift can help reduce distractions during your workout.';
      case FocusAuthorizationStatus.denied:
        return 'Focus control access is disabled in system settings.';
      case FocusAuthorizationStatus.restricted:
        return 'Focus control is restricted on this device.';
      case FocusAuthorizationStatus.notDetermined:
        return 'Focus control has not been set up yet.';
      case FocusAuthorizationStatus.unsupported:
        return 'Focus control is unavailable on this device.';
    }
  }
}
