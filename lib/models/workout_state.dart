/// The active phase of a workout session.
enum WorkoutState {
  active,
  resting,
  restComplete;

  String get label {
    switch (this) {
      case WorkoutState.active:
        return 'ACTIVE';
      case WorkoutState.resting:
        return 'RESTING';
      case WorkoutState.restComplete:
        return 'REST COMPLETE';
    }
  }
}
