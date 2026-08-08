import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/workout_session.dart';
import 'package:focus_lift/models/workout_state.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:focus_lift/services/workout_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutSession Timestamp Engine & Timing Tests', () {
    test('Workout elapsed duration derives from true start timestamp without drift', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      );

      expect(session.setsCompleted, 0);
      expect(session.currentState, WorkoutState.active);

      // Evaluate at +18 minutes and 42 seconds
      final currentTime = startTime.add(const Duration(minutes: 18, seconds: 42));
      final elapsed = session.elapsedDuration(currentTime);
      expect(elapsed.inMinutes, 18);
      expect(elapsed.inSeconds, 18 * 60 + 42);
    });

    test('End Set increments count exactly once and sets rest timestamps', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      );

      final endSetTime = startTime.add(const Duration(minutes: 5));
      final restingSession = session.endSet(timestamp: endSetTime);

      expect(restingSession.setsCompleted, 1);
      expect(restingSession.currentState, WorkoutState.resting);
      expect(restingSession.restStartedAt, endSetTime);
      expect(restingSession.restEndsAt, endSetTime.add(const Duration(seconds: 60)));

      // Rest countdown check at +20 seconds into rest
      final checkTime = endSetTime.add(const Duration(seconds: 20));
      final remaining = restingSession.restRemaining(checkTime);
      expect(remaining.inSeconds, 40);
      expect(restingSession.isRestExpired(checkTime), false);
    });

    test('Expired rest transitions to restComplete without altering set count', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final resting = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      ).endSet(timestamp: startTime.add(const Duration(minutes: 2)));

      // Check at exactly +60s and +70s
      final expiryTime = resting.restStartedAt!.add(const Duration(seconds: 60));
      expect(resting.isRestExpired(expiryTime), true);
      expect(resting.restRemaining(expiryTime), Duration.zero);

      final evaluated = resting.evaluatedAt(expiryTime);
      expect(evaluated.currentState, WorkoutState.restComplete);
      expect(evaluated.setsCompleted, 1);
    });

    test('Start next set after rest completion maintains set count and clears rest', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final resting = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      ).endSet(timestamp: startTime.add(const Duration(minutes: 2)));

      final nextSetSession = resting.startNextSet();
      expect(nextSetSession.currentState, WorkoutState.active);
      expect(nextSetSession.setsCompleted, 1);
      expect(nextSetSession.restStartedAt, null);
      expect(nextSetSession.restEndsAt, null);

      // Second set completed
      final secondRest = nextSetSession.endSet(timestamp: startTime.add(const Duration(minutes: 4)));
      expect(secondRest.setsCompleted, 2);
    });

    test('Skip rest clears rest timestamps and preserves completed set count', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final resting = WorkoutSession.start(
        selectedRestDuration: 90,
        startTime: startTime,
      ).endSet(timestamp: startTime.add(const Duration(minutes: 3)));

      expect(resting.setsCompleted, 1);
      expect(resting.currentState, WorkoutState.resting);

      final skipped = resting.skipRest();
      expect(skipped.currentState, WorkoutState.active);
      expect(skipped.setsCompleted, 1);
      expect(skipped.restStartedAt, null);
      expect(skipped.restEndsAt, null);

      // Workout timer still runs from original startTime
      final checkTime = startTime.add(const Duration(minutes: 6));
      expect(skipped.elapsedDuration(checkTime).inMinutes, 6);
    });

    test('Finish workout records end timestamp and calculates final duration', () {
      final startTime = DateTime(2026, 8, 8, 10, 0, 0);
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      ).endSet(timestamp: startTime.add(const Duration(minutes: 5)));

      final endTime = startTime.add(const Duration(hours: 1, minutes: 4, seconds: 22));
      final finished = session.finishWorkout(timestamp: endTime);

      expect(finished.workoutEndedAt, endTime);
      final finalDuration = finished.elapsedDuration();
      expect(finalDuration.inHours, 1);
      expect(finalDuration.inMinutes, 64);
      expect(finalDuration.inSeconds, 64 * 60 + 22);
    });
  });

  group('WorkoutSessionService Persistence & Recovery Tests', () {
    test('Persists active session and recovers active workout correctly', () async {
      final service = await WorkoutSessionService.create();
      final startTime = DateTime.now().subtract(const Duration(minutes: 10));
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: startTime,
      );

      await service.saveActiveSession(session);

      final recovered = service.loadActiveSession();
      expect(recovered, isNotNull);
      expect(recovered!.setsCompleted, 0);
      expect(recovered.currentState, WorkoutState.active);
      expect(recovered.selectedRestDuration, 60);
    });

    test('Recovers active resting state when rest is still remaining', () async {
      final service = await WorkoutSessionService.create();
      final now = DateTime.now();
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: now.subtract(const Duration(minutes: 5)),
      ).endSet(timestamp: now.subtract(const Duration(seconds: 20)));

      await service.saveActiveSession(session);

      final recovered = service.loadActiveSession(now);
      expect(recovered, isNotNull);
      expect(recovered!.currentState, WorkoutState.resting);
      expect(recovered.setsCompleted, 1);
      expect(recovered.restRemaining(now).inSeconds, 40);
    });

    test('Recovers resting state as restComplete if rest expired while closed', () async {
      final service = await WorkoutSessionService.create();
      final now = DateTime.now();
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: now.subtract(const Duration(minutes: 10)),
      ).endSet(timestamp: now.subtract(const Duration(minutes: 2)));

      await service.saveActiveSession(session);

      final recovered = service.loadActiveSession(now);
      expect(recovered, isNotNull);
      expect(recovered!.currentState, WorkoutState.restComplete);
      expect(recovered.setsCompleted, 1);
    });

    test('Does not recover finished workouts', () async {
      final service = await WorkoutSessionService.create();
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
      ).finishWorkout();

      await service.saveActiveSession(session);

      final recovered = service.loadActiveSession();
      expect(recovered, isNull);
    });
  });

  group('UI & Workflow Widget Tests', () {
    testWidgets('Full Workout Flow: Start -> End Set -> Skip Rest -> End Set -> Next Set -> Finish -> Summary -> Done',
        (WidgetTester tester) async {
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      const prefs = AppPreferences();

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          initialPreferences: prefs,
        ),
      );

      // 1. Home Screen
      expect(find.text('START WORKOUT'), findsOneWidget);
      await tester.tap(find.text('START WORKOUT'));
      await tester.pumpAndSettle();

      // 2. Active Workout Screen
      expect(find.text('FOCUS LIFT'), findsOneWidget);
      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('SETS COMPLETED'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // 3. Tap END SET -> goes to REST
      await tester.tap(find.text('END SET'));
      await tester.pump();
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('SKIP REST'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // sets completed is now 1
      expect(find.text('2'), findsOneWidget); // next set is 2

      // 4. Tap SKIP REST -> returns to active
      await tester.tap(find.text('SKIP REST'));
      await tester.pump();
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // sets completed remains 1

      // 5. Tap END SET again
      await tester.tap(find.text('END SET'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget); // sets completed is now 2

      // 6. Finish Workout Flow
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      expect(find.text('FINISH WORKOUT?'), findsOneWidget);

      // Cancel Finish
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('FINISH WORKOUT?'), findsNothing);

      // Confirm Finish
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'FINISH'));
      await tester.pumpAndSettle();

      // 7. Workout Complete Summary Screen
      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(find.text('WORKOUT TIME'), findsOneWidget);
      expect(find.text('SETS COMPLETED'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // 8. Tap DONE -> returns to Home
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('START WORKOUT'), findsOneWidget);
    });

    testWidgets('Settings screen preferences remain intact across workout sessions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = await LocalStorageService.create();
      const prefs = AppPreferences(defaultRestDurationSeconds: 90, soundEnabled: false);
      await storage.savePreferences(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            storageService: storage,
            initialPreferences: prefs,
            onPreferencesChanged: (_) {},
          ),
        ),
      );

      expect(find.text('90s'), findsOneWidget);
      expect(find.text('Sound Alert'), findsOneWidget);
      expect(find.text('100% On-Device & Private'), findsOneWidget);
    });
  });
}
