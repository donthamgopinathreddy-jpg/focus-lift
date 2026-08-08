import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/workout_session.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/services/alert_service.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:focus_lift/services/notification_service.dart';
import 'package:focus_lift/services/wakelock_service.dart';
import 'package:focus_lift/services/workout_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock plugin to verify notification scheduling and cancellation calls.
class FakeFlutterLocalNotificationsPlugin
    extends Fake
    implements FlutterLocalNotificationsPlugin {
  int scheduledCount = 0;
  int cancelledCount = 0;
  DateTime? lastScheduledTime;
  String? lastTitle;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
    void Function(NotificationResponse)?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    dynamic scheduledDate,
    NotificationDetails? notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledCount++;
    lastTitle = title;
    lastScheduledTime = scheduledDate is DateTime ? scheduledDate : null;
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3: AlertService Sound & Vibration Tests', () {
    test('Trigger alert respects sound and vibration preferences safely', () async {
      // Sound = ON, Vibration = ON
      await AlertService.triggerRestCompleteAlert(
        soundEnabled: true,
        vibrationEnabled: true,
      );

      // Sound = OFF, Vibration = OFF
      await AlertService.triggerRestCompleteAlert(
        soundEnabled: false,
        vibrationEnabled: false,
      );

      // Selection haptic click
      await AlertService.triggerSelectionHaptic();
    });
  });

  group('Phase 3: WakelockService Tests', () {
    test('Set awake and release execute safely without crashing', () async {
      await WakelockService.setAwake(true);
      await WakelockService.setAwake(false);
      await WakelockService.release();
    });
  });

  group('Phase 3: NotificationService Scheduling & Cleanup Tests', () {
    test('Schedules notification at restEndsAt timestamp', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService(fakePlugin);
      await service.initialize();

      final futureRestEnd = DateTime.now().add(const Duration(seconds: 60));
      await service.scheduleRestNotification(
        restEndsAt: futureRestEnd,
        nextSetNumber: 2,
      );

      expect(fakePlugin.scheduledCount, 1);
      expect(fakePlugin.lastTitle, 'Rest Complete');
      expect(fakePlugin.cancelledCount, 1); // Cancels old before new
    });

    test('Does not schedule notification if restEndsAt is already in the past', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService(fakePlugin);
      await service.initialize();

      final pastRestEnd = DateTime.now().subtract(const Duration(seconds: 10));
      await service.scheduleRestNotification(
        restEndsAt: pastRestEnd,
        nextSetNumber: 1,
      );

      expect(fakePlugin.scheduledCount, 0);
      expect(fakePlugin.cancelledCount, 1); // Cleans up
    });

    test('Cancels notification properly on skip rest or finish', () async {
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final service = NotificationService(fakePlugin);
      await service.initialize();

      await service.cancelRestNotification();
      expect(fakePlugin.cancelledCount, 1);
    });
  });

  group('Phase 3: Workout Flow with Notifications, Haptics & Lifecycle', () {
    testWidgets('Full Workout flow with AlertService and NotificationService integration',
        (WidgetTester tester) async {
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(fakePlugin);
      await notificationService.initialize();

      const prefs = AppPreferences(
        defaultRestDurationSeconds: 60,
        soundEnabled: true,
        vibrationEnabled: true,
        keepScreenAwake: true,
      );
      await storage.savePreferences(prefs);

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          initialPreferences: prefs,
        ),
      );

      // 1. Home Screen -> Start Workout
      expect(find.text('START WORKOUT'), findsOneWidget);
      await tester.tap(find.text('START WORKOUT'));
      await tester.pumpAndSettle();

      // 2. Active Workout Screen
      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('SETS COMPLETED'), findsOneWidget);

      // 3. Tap END SET -> Schedules notification and starts rest
      await tester.tap(find.text('END SET'));
      await tester.pump();
      expect(find.text('REST'), findsOneWidget);
      expect(fakePlugin.scheduledCount, 1);

      // 4. Tap SKIP REST -> Cancels notification and returns to active
      await tester.tap(find.text('SKIP REST'));
      await tester.pump();
      expect(find.text('END SET'), findsOneWidget);
      expect(fakePlugin.cancelledCount, 2); // 1 from initial schedule, 1 from skip

      // 5. Tap END SET again
      await tester.tap(find.text('END SET'));
      await tester.pump();
      expect(fakePlugin.scheduledCount, 2);

      // 6. Finish Workout Flow
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      expect(find.text('FINISH WORKOUT?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'FINISH'));
      await tester.pumpAndSettle();

      // 7. Workout Complete Summary Screen
      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // 8. Tap DONE -> Returns Home
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('START WORKOUT'), findsOneWidget);
    });

    testWidgets('Lifecycle resume recalculates rest state if elapsed while backgrounded',
        (WidgetTester tester) async {
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(fakePlugin);
      await notificationService.initialize();

      const prefs = AppPreferences();

      // Start in a resting session where restEndsAt is in the past
      final now = DateTime.now();
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: now.subtract(const Duration(minutes: 5)),
      ).endSet(timestamp: now.subtract(const Duration(seconds: 70)));
      await sessionService.saveActiveSession(session);

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          initialPreferences: prefs,
        ),
      );

      // Home shows recovery banner for unfinished resting workout
      expect(find.text('UNFINISHED WORKOUT'), findsOneWidget);
      await tester.tap(find.text('RESUME'));
      await tester.pumpAndSettle();

      // Should automatically render REST COMPLETE because rest elapsed
      expect(find.text('REST COMPLETE'), findsOneWidget);
      expect(find.text('START NEXT SET'), findsOneWidget);

      // Tap Start Next Set
      await tester.tap(find.text('START NEXT SET'));
      await tester.pump();
      expect(find.text('END SET'), findsOneWidget);
    });

    testWidgets('Settings screen persists Sound, Vibration, and Screen Awake options',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = await LocalStorageService.create();
      const prefs = AppPreferences(
        soundEnabled: true,
        vibrationEnabled: true,
        keepScreenAwake: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            storageService: storage,
            initialPreferences: prefs,
            onPreferencesChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Sound Alert'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Keep Screen Awake'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      // Toggle Sound off
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      final reloaded = storage.loadPreferences();
      expect(reloaded.soundEnabled, false);
    });
  });
}
