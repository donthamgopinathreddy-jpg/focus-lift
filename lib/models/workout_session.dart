import 'workout_state.dart';

/// Represents an active or completed workout session with timestamp-based timing.
class WorkoutSession {
  final DateTime workoutStartedAt;
  final DateTime? workoutEndedAt;
  final int setsCompleted;
  final int selectedRestDuration;
  final WorkoutState currentState;
  final DateTime? restStartedAt;
  final DateTime? restEndsAt;

  const WorkoutSession({
    required this.workoutStartedAt,
    this.workoutEndedAt,
    this.setsCompleted = 0,
    required this.selectedRestDuration,
    this.currentState = WorkoutState.active,
    this.restStartedAt,
    this.restEndsAt,
  });

  /// Factory to initialize a fresh session with 0 sets.
  factory WorkoutSession.start({
    required int selectedRestDuration,
    DateTime? startTime,
  }) {
    return WorkoutSession(
      workoutStartedAt: startTime ?? DateTime.now(),
      selectedRestDuration: selectedRestDuration,
      setsCompleted: 0,
      currentState: WorkoutState.active,
    );
  }

  /// Calculates total elapsed workout duration from the true start timestamp.
  Duration elapsedDuration([DateTime? now]) {
    final referenceTime = workoutEndedAt ?? (now ?? DateTime.now());
    final diff = referenceTime.difference(workoutStartedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Calculates remaining rest duration from the true restEndsAt timestamp.
  Duration restRemaining([DateTime? now]) {
    if (restEndsAt == null) return Duration.zero;
    final currentTime = now ?? DateTime.now();
    if (!currentTime.isBefore(restEndsAt!)) {
      return Duration.zero;
    }
    return restEndsAt!.difference(currentTime);
  }

  /// Checks if the rest countdown has elapsed past restEndsAt.
  bool isRestExpired([DateTime? now]) {
    if (restEndsAt == null) return false;
    final currentTime = now ?? DateTime.now();
    return !currentTime.isBefore(restEndsAt!);
  }

  /// Evaluates and transitions resting state if the rest timer has elapsed.
  WorkoutSession evaluatedAt([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    if (currentState == WorkoutState.resting && isRestExpired(currentTime)) {
      return copyWith(currentState: WorkoutState.restComplete);
    }
    return this;
  }

  /// Ends the current physical set and begins rest.
  WorkoutSession endSet({DateTime? timestamp}) {
    final start = timestamp ?? DateTime.now();
    final end = start.add(Duration(seconds: selectedRestDuration));
    return copyWith(
      setsCompleted: setsCompleted + 1,
      currentState: WorkoutState.resting,
      restStartedAt: start,
      restEndsAt: end,
    );
  }

  /// Skips current rest and returns to active state without modifying sets.
  WorkoutSession skipRest() {
    return WorkoutSession(
      workoutStartedAt: workoutStartedAt,
      workoutEndedAt: workoutEndedAt,
      setsCompleted: setsCompleted,
      selectedRestDuration: selectedRestDuration,
      currentState: WorkoutState.active,
      restStartedAt: null,
      restEndsAt: null,
    );
  }

  /// Starts the next set after rest completion.
  WorkoutSession startNextSet() {
    return WorkoutSession(
      workoutStartedAt: workoutStartedAt,
      workoutEndedAt: workoutEndedAt,
      setsCompleted: setsCompleted,
      selectedRestDuration: selectedRestDuration,
      currentState: WorkoutState.active,
      restStartedAt: null,
      restEndsAt: null,
    );
  }

  /// Concludes the workout and records the end timestamp.
  WorkoutSession finishWorkout({DateTime? timestamp}) {
    final endTime = timestamp ?? DateTime.now();
    return WorkoutSession(
      workoutStartedAt: workoutStartedAt,
      workoutEndedAt: endTime,
      setsCompleted: setsCompleted,
      selectedRestDuration: selectedRestDuration,
      currentState: WorkoutState.active,
      restStartedAt: null,
      restEndsAt: null,
    );
  }

  WorkoutSession copyWith({
    DateTime? workoutStartedAt,
    DateTime? workoutEndedAt,
    int? setsCompleted,
    int? selectedRestDuration,
    WorkoutState? currentState,
    DateTime? restStartedAt,
    DateTime? restEndsAt,
  }) {
    return WorkoutSession(
      workoutStartedAt: workoutStartedAt ?? this.workoutStartedAt,
      workoutEndedAt: workoutEndedAt ?? this.workoutEndedAt,
      setsCompleted: setsCompleted ?? this.setsCompleted,
      selectedRestDuration: selectedRestDuration ?? this.selectedRestDuration,
      currentState: currentState ?? this.currentState,
      restStartedAt: restStartedAt ?? this.restStartedAt,
      restEndsAt: restEndsAt ?? this.restEndsAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutStartedAt': workoutStartedAt.toIso8601String(),
      'workoutEndedAt': workoutEndedAt?.toIso8601String(),
      'setsCompleted': setsCompleted,
      'selectedRestDuration': selectedRestDuration,
      'currentState': currentState.index,
      'restStartedAt': restStartedAt?.toIso8601String(),
      'restEndsAt': restEndsAt?.toIso8601String(),
    };
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final stateIndex = json['currentState'] as int? ?? 0;
    final state = (stateIndex >= 0 && stateIndex < WorkoutState.values.length)
        ? WorkoutState.values[stateIndex]
        : WorkoutState.active;

    return WorkoutSession(
      workoutStartedAt: DateTime.parse(json['workoutStartedAt'] as String),
      workoutEndedAt: json['workoutEndedAt'] != null
          ? DateTime.parse(json['workoutEndedAt'] as String)
          : null,
      setsCompleted: json['setsCompleted'] as int? ?? 0,
      selectedRestDuration: json['selectedRestDuration'] as int? ?? 60,
      currentState: state,
      restStartedAt: json['restStartedAt'] != null
          ? DateTime.parse(json['restStartedAt'] as String)
          : null,
      restEndsAt: json['restEndsAt'] != null
          ? DateTime.parse(json['restEndsAt'] as String)
          : null,
    );
  }
}
