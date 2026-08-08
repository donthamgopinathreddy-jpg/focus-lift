/// Represents the distraction restriction mode selected for workouts.
enum FocusMode {
  focus,
  balanced,
  custom;

  String get label {
    switch (this) {
      case FocusMode.focus:
        return 'FOCUS';
      case FocusMode.balanced:
        return 'BALANCED';
      case FocusMode.custom:
        return 'CUSTOM';
    }
  }

  String get description {
    switch (this) {
      case FocusMode.focus:
        return 'Max focus: Restricts selected distracting apps. Essential calls and music remain accessible.';
      case FocusMode.balanced:
        return 'Balanced: Calls, emergency access, music, and selected communication apps remain allowed.';
      case FocusMode.custom:
        return 'Custom: Choose custom restriction rules and allowed applications.';
    }
  }
}
