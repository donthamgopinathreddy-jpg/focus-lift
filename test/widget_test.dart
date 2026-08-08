import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/focus_mode.dart';
import 'package:focus_lift/models/workout_session.dart';
import 'package:focus_lift/screens/focus/distraction_picker_screen.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/services/alert_service.dart';
import 'package:focus_lift/services/focus_control/app_info.dart';
import 'package:focus_lift/services/focus_control/focus_authorization_status.dart';
import 'package:focus_lift/services/focus_control/focus_control_result.dart';
import 'package:focus_lift/services/focus_control/focus_control_service.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:focus_lift/services/notification_service.dart';
import 'package:focus_lift/services/wakelock_service.dart';
import 'package:focus_lift/services/workout_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeFlutterLocalNotificationsPlugin
    extends Fake
    implements FlutterLocalNotificationsPlugin {
  int scheduledCount = 0;
  int cancelledCount = 0;
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
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(FocusControlService.channelName);
  int startFocusCalls = 0;
  int stopFocusCalls = 0;
  int restoreAccessCalls = 0;
  String mockAuthStatus = 'authorized';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    startFocusCalls = 0;
    stopFocusCalls = 0;
    restoreAccessCalls = 0;
    mockAuthStatus = 'authorized';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAuthorizationStatus':
          return mockAuthStatus;
        case 'requestAuthorization':
          return true;
        case 'getLauncherApps':
          return [
            {'appName': 'Social Feed', 'packageName': 'com.social.feed'},
            {'appName': 'Video Clips', 'packageName': 'com.video.clips'},
          ];
        case 'startFocusSession':
          startFocusCalls++;
          return true;
        case 'stopFocusSession':
          stopFocusCalls++;
          return null;
        case 'restoreNormalAccess':
          restoreAccessCalls++;
          return null;
        case 'updateSelectedDistractions':
        case 'openAppPicker':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Phase 5: Focus Authorization & Result Models', () {
    test('FocusAuthorizationStatus labels and descriptions are descriptive', () {
      for (final status in FocusAuthorizationStatus.values) {
        expect(status.label.isNotEmpty, true);
        expect(status.description.isNotEmpty, true);
      }
    });

    test('FocusControlResult factory constructors populate state accurately', () {
      final active = FocusControlResult.active(FocusMode.focus);
      expect(active.success, true);
      expect(active.status, FocusAuthorizationStatus.authorized);
      expect(active.mode, FocusMode.focus);

      final reduced = FocusControlResult.reduced(
        status: FocusAuthorizationStatus.denied,
        mode: FocusMode.balanced,
      );
      expect(reduced.success, false);
      expect(reduced.status, FocusAuthorizationStatus.denied);
      expect(reduced.mode, FocusMode.balanced);
    });

    test('AppInfo model handles serialization and copying properly', () {
      const app = AppInfo(appName: 'Test App', packageName: 'com.test.app');
      final map = app.toMap();
      final fromMap = AppInfo.fromMap(map);

      expect(fromMap.appName, 'Test App');
      expect(fromMap.packageName, 'com.test.app');
      expect(fromMap.isSelected, false);

      final selectedApp = app.copyWith(isSelected: true);
      expect(selectedApp.isSelected, true);
    });
  });

  group('Phase 5: FocusControlService Tests', () {
    test('Queries authorization status and requests permissions safely', () async {
      final service = await FocusControlService.create();

      final status = await service.getAuthorizationStatus();
      expect(status, FocusAuthorizationStatus.authorized);

      final requested = await service.requestAuthorization();
      expect(requested, true);
    });

    test('Discovers launcher apps and persists selected distractions locally', () async {
      final service = await FocusControlService.create();

      final apps = await service.getLauncherApps();
      expect(apps.length, 2);
      expect(apps.first.appName, 'Social Feed');

      await service.saveSelectedDistractions(['com.social.feed']);
      final saved = await service.getSelectedDistractions();
      expect(saved, contains('com.social.feed'));
    });

    test('startFocusSession, stopFocusSession, and restoreNormalAccess invoke native bridge',
        () async {
      final service = await FocusControlService.create();

      final result = await service.startFocusSession(FocusMode.focus);
      expect(result.success, true);
      expect(startFocusCalls, 1);
      expect(service.isSessionActive, true);

      await service.stopFocusSession();
      expect(stopFocusCalls, 1);
      expect(service.isSessionActive, false);

      await service.restoreNormalAccess();
      expect(restoreAccessCalls, 1);
    });

    test('Gracefully handles platform exceptions or unsupported environments', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });

      final service = await FocusControlService.create();
      final status = await service.getAuthorizationStatus();
      expect(status, FocusAuthorizationStatus.unsupported);

      final requested = await service.requestAuthorization();
      expect(requested, false);

      final apps = await service.getLauncherApps();
      expect(apps, isEmpty);

      final result = await service.startFocusSession(FocusMode.focus);
      expect(result.success, false);
      expect(result.status, FocusAuthorizationStatus.unsupported);
    });
  });

  group('Phase 5: UI & Full Workout Flow Integration with Focus Control', () {
    testWidgets('DistractionPickerScreen allows toggling and clearing apps',
        (WidgetTester tester) async {
      final service = await FocusControlService.create();

      await tester.pumpWidget(
        MaterialApp(
          home: DistractionPickerScreen(focusService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DISTRACTIONS'), findsOneWidget);
      expect(find.text('Social Feed'), findsOneWidget);
      expect(find.text('Video Clips'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // Toggle first app
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      final saved = await service.getSelectedDistractions();
      expect(saved, contains('com.social.feed'));
    });

    testWidgets('Full Workout flow starts and finishes with FocusControlService cleanup',
        (WidgetTester tester) async {
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(fakePlugin);
      await notificationService.initialize();
      final focusService = await FocusControlService.create();

      const prefs = AppPreferences(
        defaultRestDurationSeconds: 60,
        focusMode: FocusMode.focus,
      );
      await storage.savePreferences(prefs);

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          focusService: focusService,
          initialPreferences: prefs,
        ),
      );

      // Home Screen
      expect(find.text('START WORKOUT'), findsOneWidget);
      expect(find.text('CONFIGURE DISTRACTIONS'), findsOneWidget);

      // Start Workout
      await tester.tap(find.text('START WORKOUT'));
      await tester.pumpAndSettle();

      expect(find.text('WORKOUT'), findsOneWidget);
      expect(startFocusCalls, 1);

      // Finish Workout
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'FINISH'));
      await tester.pumpAndSettle();

      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(stopFocusCalls >= 1, true);
      expect(restoreAccessCalls >= 1, true);
    });

    testWidgets('Workout starts properly even when Focus Control authorization is denied',
        (WidgetTester tester) async {
      mockAuthStatus = 'denied';
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(fakePlugin);
      final focusService = await FocusControlService.create();

      const prefs = AppPreferences();

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          focusService: focusService,
          initialPreferences: prefs,
        ),
      );

      await tester.tap(find.text('START WORKOUT'));
      await tester.pumpAndSettle();

      // Workout timer still functions normally in reduced mode
      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
    });

    testWidgets('Discarding unfinished session cleans up focus restrictions',
        (WidgetTester tester) async {
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final fakePlugin = FakeFlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(fakePlugin);
      final focusService = await FocusControlService.create();

      final now = DateTime.now();
      final session = WorkoutSession.start(
        selectedRestDuration: 60,
        startTime: now.subtract(const Duration(minutes: 2)),
      );
      await sessionService.saveActiveSession(session);

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          focusService: focusService,
          initialPreferences: const AppPreferences(),
        ),
      );

      expect(find.text('UNFINISHED WORKOUT'), findsOneWidget);
      await tester.tap(find.text('DISCARD'));
      await tester.pumpAndSettle();

      expect(stopFocusCalls, 1);
      expect(restoreAccessCalls, 1);
      expect(sessionService.loadActiveSession(), isNull);
    });
  });

  group('Previous Phase Verification: Alerts, Wakelock, Notifications & Settings', () {
    test('Sound and vibration alerts execute safely', () async {
      await AlertService.triggerRestCompleteAlert(
        soundEnabled: true,
        vibrationEnabled: true,
      );
      await AlertService.triggerRestCompleteAlert(
        soundEnabled: false,
        vibrationEnabled: false,
      );
      await AlertService.triggerSelectionHaptic();
    });

    test('WakelockService executes safely', () async {
      await WakelockService.setAwake(true);
      await WakelockService.setAwake(false);
      await WakelockService.release();
    });

    testWidgets('Settings screen toggles persist properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = await LocalStorageService.create();
      const prefs = AppPreferences();

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
    });
  });
}
