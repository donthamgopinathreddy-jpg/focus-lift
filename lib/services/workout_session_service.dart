import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_session.dart';

/// Manages local persistence and recovery for active workout sessions.
class WorkoutSessionService {
  static const String _keyActiveWorkoutSession = 'fl_active_workout_session';

  final SharedPreferences _prefs;

  WorkoutSessionService(this._prefs);

  static Future<WorkoutSessionService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkoutSessionService(prefs);
  }

  /// Persists the active workout session locally.
  Future<void> saveActiveSession(WorkoutSession session) async {
    final jsonString = jsonEncode(session.toJson());
    await _prefs.setString(_keyActiveWorkoutSession, jsonString);
  }

  /// Loads and re-evaluates any unfinished workout session against the current timestamp.
  WorkoutSession? loadActiveSession([DateTime? now]) {
    final jsonString = _prefs.getString(_keyActiveWorkoutSession);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final session = WorkoutSession.fromJson(map);

      // If the session was already finished, do not restore it as an active workout
      if (session.workoutEndedAt != null) {
        clearActiveSession();
        return null;
      }

      // Re-evaluate rest state against current time
      return session.evaluatedAt(now ?? DateTime.now());
    } catch (_) {
      clearActiveSession();
      return null;
    }
  }

  /// Removes active workout state from device storage.
  Future<void> clearActiveSession() async {
    await _prefs.remove(_keyActiveWorkoutSession);
  }
}
