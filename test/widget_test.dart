import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/allowed_workout_apps.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/workout_session.dart';
import 'package:focus_lift/screens/focus/allowed_apps_screen.dart';
import 'package:focus_lift/screens/home/home_screen.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/screens/workout/workout_screen.dart';
import 'package:focus_lift/services/focus_control/focus_control_service.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:focus_lift/services/notification_service.dart';
import 'package:focus_lift/services/workout_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel mockChannel;
  late int startFocusWorkoutCalls;
  late int stopFocusCalls;
  late int restoreAccessCalls;
  late int launchMusicCalls;
  late int launchPhoneCalls;
  late int launchCameraCalls;

  setUp(() {
    startFocusWorkoutCalls = 0;
    stopFocusCalls = 0;
    restoreAccessCalls = 0;
    launchMusicCalls = 0;
    launchPhoneCalls = 0;
    launchCameraCalls = 0;

    mockChannel = const MethodChannel(FocusControlService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mockChannel, (MethodCall call) async {
      switch (call.method) {
        case 'getAuthorizationStatus':
          return 'authorized';
        case 'requestAuthorization':
          return true;
        case 'areNotificationsEnabled':
          return true;
        case 'openNotificationSettings':
          return null;
        case 'openUsageAccessSettings':
          return null;
        case 'launchMusicApp':
          launchMusicCalls++;
          return true;
        case 'launchPhoneApp':
          launchPhoneCalls++;
          return true;
        case 'launchCameraApp':
          launchCameraCalls++;
          return true;
        case 'discoverInstalledMusicApps':
          return [
            {'appName': 'Spotify', 'packageName': 'com.spotify.music'},
            {'appName': 'YouTube Music', 'packageName': 'com.google.android.apps.youtube.music'},
          ];
        case 'getLauncherApps':
          return [
            {'appName': 'Spotify', 'packageName': 'com.spotify.music'},
            {'appName': 'Messages', 'packageName': 'com.google.android.apps.messaging'},
          ];
        case 'startFocusSession':
          startFocusWorkoutCalls++;
          return true;
        case 'stopFocusSession':
          stopFocusCalls++;
          return null;
        case 'restoreNormalAccess':
          restoreAccessCalls++;
          return null;
        default:
          return null;
      }
    });

    const notificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall call) async {
      return null;
    });

    const wakelockChannel = MethodChannel('wakelock_plus');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, (MethodCall call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mockChannel, null);
  });

  group('Permission & Workout-Mode Upgrade: Launch Screen & Setup Flow', () {
    testWidgets('Home renders large circular LAUNCH button, rest options, and available tools', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: storage,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: preferences,
          ),
        ),
      );

      // Verify Header
      expect(find.text('FOCUS LIFT'), findsOneWidget);
      expect(find.text('TRAIN WITHOUT DISTRACTIONS'), findsOneWidget);

      // Verify Rest selector
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('90s'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Verify Large Circular LAUNCH Button
      expect(find.text('LAUNCH'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Verify Available Tools below LAUNCH
      expect(find.text('AVAILABLE DURING WORKOUT'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.text('CALLS'), findsOneWidget);
      expect(find.text('CAMERA'), findsOneWidget);
      expect(find.text('Emergency calling remains available.'), findsOneWidget);

      // Verify old concepts are absent
      expect(find.text('Focus Mode'), findsNothing);
      expect(find.text('Balanced Mode'), findsNothing);
      expect(find.text('Custom Mode'), findsNothing);
      expect(find.text('Configure Distractions'), findsNothing);
    });

    testWidgets('Selecting rest duration updates local preferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: storage,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: preferences,
          ),
        ),
      );

      await tester.tap(find.text('90s'));
      await tester.pumpAndSettle();

      final reloaded = storage.loadPreferences();
      expect(reloaded.defaultRestDurationSeconds, 90);
    });

    testWidgets('First-time LAUNCH presents setup sheet and CONTINUE activates workout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: storage,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: preferences,
          ),
        ),
      );

      // Tap LAUNCH for the first time
      await tester.tap(find.text('LAUNCH'));
      await tester.pumpAndSettle();

      // Setup sheet is presented
      expect(find.text('SET UP WORKOUT MODE'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Usage Access'), findsOneWidget);
      expect(find.text('Keep Screen Awake'), findsOneWidget);

      // Tap CONTINUE
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Workout screen active immediately
      expect(find.text('WORKOUT ACTIVE'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('QUICK ACCESS'), findsOneWidget);
      expect(sessionService.loadActiveSession(), isNotNull);
    });

    testWidgets('Subsequent LAUNCH starts workout immediately without setup sheet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      await storage.setWorkoutSetupCompleted(true);

      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: storage,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: preferences,
          ),
        ),
      );

      // Tap LAUNCH
      await tester.tap(find.text('LAUNCH'));
      await tester.pumpAndSettle();

      expect(find.text('WORKOUT ACTIVE'), findsOneWidget);
      expect(find.text('SET UP WORKOUT MODE'), findsNothing);
    });
  });

  group('Permission & Workout-Mode Upgrade: Dedicated Workout & Rest Experience', () {
    testWidgets('WorkoutScreen handles END SET, Rest Countdown, Skip Rest, and Quick Access', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final session = WorkoutSession.start(selectedRestDuration: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutScreen(
            initialSession: session,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            preferences: const AppPreferences(),
          ),
        ),
      );

      await tester.pump();
      expect(startFocusWorkoutCalls, 1);
      expect(find.text('WORKOUT ACTIVE'), findsOneWidget);
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);

      // Tap Quick Access buttons
      await tester.tap(find.text('MUSIC'));
      await tester.pump();
      expect(launchMusicCalls, 1);

      await tester.tap(find.text('CALLS'));
      await tester.pump();
      expect(launchPhoneCalls, 1);

      await tester.tap(find.text('CAMERA'));
      await tester.pump();
      expect(launchCameraCalls, 1);

      // Tap END SET -> Enters Rest
      await tester.tap(find.text('END SET'));
      await tester.pump();

      expect(find.text('REST'), findsWidgets);
      expect(find.text('SET 1 COMPLETE'), findsOneWidget);
      expect(find.text('SKIP REST'), findsOneWidget);

      // Tap SKIP REST -> Returns to Workout Active
      await tester.tap(find.text('SKIP REST'));
      await tester.pump();

      expect(find.text('WORKOUT ACTIVE'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
    });

    testWidgets('Finish workout confirms, cleans up focus, and displays minimal Summary', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final session = WorkoutSession.start(selectedRestDuration: 60);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutScreen(
            initialSession: session,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            preferences: const AppPreferences(),
          ),
        ),
      );

      await tester.pump();

      // Tap Finish Workout
      await tester.tap(find.text('Finish Workout'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'FINISH'));
      await tester.pumpAndSettle();

      expect(stopFocusCalls, greaterThanOrEqualTo(1));
      expect(restoreAccessCalls, greaterThanOrEqualTo(1));
      expect(sessionService.loadActiveSession(), isNull);

      // Summary screen
      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(find.text('WORKOUT TIME'), findsOneWidget);
      expect(find.text('SETS COMPLETED'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // Tap DONE
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
    });
  });

  group('Permission & Workout-Mode Upgrade: Active Session Recovery & Startup Routing', () {
    testWidgets('App startup with active session opens directly into WorkoutScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      // Save an active workout session in local storage
      final active = WorkoutSession.start(selectedRestDuration: 60);
      sessionService.saveActiveSession(active);

      await tester.pumpWidget(
        FocusLiftApp(
          storageService: storage,
          sessionService: sessionService,
          notificationService: notificationService,
          focusService: focusService,
          initialPreferences: preferences,
        ),
      );

      await tester.pump();

      // Bypasses Launch screen and displays WorkoutScreen directly
      expect(find.text('WORKOUT ACTIVE'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('LAUNCH'), findsNothing);
    });

    testWidgets('Discarding unfinished workout cleans up focus controls', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final sessionService = await WorkoutSessionService.create();
      final notificationService = await NotificationService.create();
      final focusService = await FocusControlService.create();
      final preferences = storage.loadPreferences();

      final active = WorkoutSession.start(selectedRestDuration: 60);
      sessionService.saveActiveSession(active);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            storageService: storage,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: preferences,
          ),
        ),
      );

      expect(find.text('UNFINISHED WORKOUT'), findsOneWidget);

      // Tap DISCARD
      await tester.tap(find.text('DISCARD'));
      await tester.pumpAndSettle();

      expect(stopFocusCalls, greaterThanOrEqualTo(1));
      expect(restoreAccessCalls, greaterThanOrEqualTo(1));
      expect(find.text('UNFINISHED WORKOUT'), findsNothing);
      expect(sessionService.loadActiveSession(), isNull);
    });
  });

  group('Permission & Workout-Mode Upgrade: Settings Screen Permissions Status', () {
    testWidgets('Settings screen displays live workout mode permission statuses', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final focusService = await FocusControlService.create();
      AppPreferences currentPrefs = storage.loadPreferences();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            storageService: storage,
            focusService: focusService,
            initialPreferences: currentPrefs,
            onPreferencesChanged: (updated) {
              currentPrefs = updated;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('WORKOUT MODE PERMISSIONS'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Usage Access'), findsOneWidget);
      expect(find.text('Default Rest Timer'), findsOneWidget);
      expect(find.text('Sound Alert'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Keep Screen Awake'), findsOneWidget);
      expect(find.text('Focus Lift stores workout settings and preferences on this device. No account is required.'), findsOneWidget);
    });
  });
}
