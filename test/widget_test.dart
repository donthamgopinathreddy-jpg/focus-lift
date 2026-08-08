import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/allowed_workout_apps.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/workout_session.dart';
import 'package:focus_lift/models/workout_state.dart';
import 'package:focus_lift/screens/focus/allowed_apps_screen.dart';
import 'package:focus_lift/screens/home/home_screen.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/screens/summary/workout_summary_screen.dart';
import 'package:focus_lift/screens/workout/workout_screen.dart';
import 'package:focus_lift/services/alert_service.dart';
import 'package:focus_lift/services/focus_control/app_info.dart';
import 'package:focus_lift/services/focus_control/focus_authorization_status.dart';
import 'package:focus_lift/services/focus_control/focus_control_result.dart';
import 'package:focus_lift/services/focus_control/focus_control_service.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:focus_lift/services/notification_service.dart';
import 'package:focus_lift/services/wakelock_service.dart';
import 'package:focus_lift/services/workout_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel mockChannel;
  late int startFocusWorkoutCalls;
  late int stopFocusCalls;
  late int restoreAccessCalls;
  late int launchMusicCalls;
  late int launchPhoneCalls;

  setUp(() {
    startFocusWorkoutCalls = 0;
    stopFocusCalls = 0;
    restoreAccessCalls = 0;
    launchMusicCalls = 0;
    launchPhoneCalls = 0;

    mockChannel = const MethodChannel(FocusControlService.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mockChannel, (MethodCall call) async {
      switch (call.method) {
        case 'getAuthorizationStatus':
          return 'authorized';
        case 'requestAuthorization':
          return true;
        case 'launchMusicApp':
          launchMusicCalls++;
          return true;
        case 'launchPhoneApp':
          launchPhoneCalls++;
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

  group('Redesign: AllowedWorkoutApps & Preferences Models', () {
    test('AllowedWorkoutApps defaults and serialization', () {
      const defaultApps = AllowedWorkoutApps();
      expect(defaultApps.callsAllowed, isTrue);
      expect(defaultApps.musicAllowed, isTrue);
      expect(defaultApps.messagesAllowed, isFalse);
      expect(defaultApps.cameraAllowed, isFalse);

      final map = defaultApps.toMap();
      final fromMap = AllowedWorkoutApps.fromMap(map);
      expect(fromMap.callsAllowed, isTrue);
      expect(fromMap.musicAllowed, isTrue);
      expect(fromMap.messagesAllowed, isFalse);

      final custom = defaultApps.copyWith(
        musicAllowed: true,
        selectedMusicPackage: 'com.spotify.music',
        selectedMusicAppName: 'Spotify',
        messagesAllowed: true,
      );
      expect(custom.selectedMusicPackage, 'com.spotify.music');
      expect(custom.selectedMusicAppName, 'Spotify');
      expect(custom.messagesAllowed, isTrue);
    });

    test('AppPreferences stores AllowedWorkoutApps', () {
      const prefs = AppPreferences(
        defaultRestDurationSeconds: 90,
        allowedApps: AllowedWorkoutApps(
          messagesAllowed: true,
          cameraAllowed: true,
        ),
      );

      expect(prefs.defaultRestDurationSeconds, 90);
      expect(prefs.allowedApps.messagesAllowed, isTrue);
      expect(prefs.allowedApps.cameraAllowed, isTrue);
    });
  });

  group('Redesign: Home Screen UI & Allowlist Structure', () {
    testWidgets('Home renders simplified UI with rest options and dominant CTA', (tester) async {
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

      // Verify minimal Header Brand
      expect(find.text('FOCUS LIFT'), findsOneWidget);
      expect(find.text('TRAIN WITHOUT DISTRACTIONS'), findsOneWidget);

      // Verify Rest options
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('90s'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);
      expect(find.text('Custom Rest'), findsOneWidget);

      // Verify Allowed During Workout section
      expect(find.text('ALLOWED DURING WORKOUT'), findsOneWidget);
      expect(find.text('Music Playback'), findsOneWidget);
      expect(find.text('Phone & Calls'), findsOneWidget);
      expect(find.text('Manage Allowed Apps'), findsOneWidget);

      // Verify Dominant START FOCUS WORKOUT CTA
      expect(find.text('START FOCUS WORKOUT'), findsOneWidget);

      // Verify OLD CLUTTER IS COMPLETELY ABSENT
      expect(find.text('FOCUS MODE'), findsNothing);
      expect(find.text('BALANCED MODE'), findsNothing);
      expect(find.text('CUSTOM MODE'), findsNothing);
      expect(find.text('Configure Distractions'), findsNothing);
    });

    testWidgets('Selecting rest options updates state and persistence', (tester) async {
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

      // Tap 90s rest
      await tester.tap(find.text('90s'));
      await tester.pumpAndSettle();

      final reloaded = storage.loadPreferences();
      expect(reloaded.defaultRestDurationSeconds, 90);
    });
  });

  group('Redesign: AllowedAppsScreen & Local Persistence', () {
    testWidgets('AllowedAppsScreen loads music apps and toggles optional permissions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final focusService = await FocusControlService.create();
      AllowedWorkoutApps currentAllowed = const AllowedWorkoutApps();

      await tester.pumpWidget(
        MaterialApp(
          home: AllowedAppsScreen(
            storageService: storage,
            focusService: focusService,
            initialAllowed: currentAllowed,
            onAllowedChanged: (updated) {
              currentAllowed = updated;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ALLOWED DURING WORKOUT'), findsOneWidget);
      expect(find.text('Phone & Calls'), findsOneWidget);
      expect(find.text('ALWAYS ON'), findsOneWidget);
      expect(find.text('Music Playback'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('YouTube Music'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);

      // Select Spotify as preferred music app
      await tester.tap(find.text('Spotify'));
      await tester.pumpAndSettle();

      expect(currentAllowed.selectedMusicPackage, 'com.spotify.music');
      expect(currentAllowed.selectedMusicAppName, 'Spotify');
    });
  });

  group('Redesign: Workout Screen with Quick Access & Fail-Safe Cleanup', () {
    testWidgets('WorkoutScreen starts focus session and offers quick access to Music & Calls', (tester) async {
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
            preferences: const AppPreferences(
              allowedApps: AllowedWorkoutApps(
                musicAllowed: true,
                callsAllowed: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(startFocusWorkoutCalls, 1);

      // Verify Active Workout layout
      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.text('CALL'), findsOneWidget);

      // Tap Quick Access MUSIC
      await tester.tap(find.text('MUSIC'));
      await tester.pump();
      expect(launchMusicCalls, 1);

      // Tap Quick Access CALL
      await tester.tap(find.text('CALL'));
      await tester.pump();
      expect(launchPhoneCalls, 1);

      // Tap END SET -> Enters Rest
      await tester.tap(find.text('END SET'));
      await tester.pump();

      expect(find.text('REST'), findsOneWidget);
      expect(find.text('SKIP REST'), findsOneWidget);
      expect(find.text('MUSIC'), findsOneWidget);
      expect(find.text('CALL'), findsOneWidget);

      // Tap SKIP REST -> Returns to Workout Active
      await tester.tap(find.text('SKIP REST'));
      await tester.pump();

      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('END SET'), findsOneWidget);
    });

    testWidgets('Finishing workout cleans up focus and displays minimal Summary', (tester) async {
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

      // Tap Finish
      await tester.tap(find.text('Finish Workout'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();

      expect(stopFocusCalls, greaterThanOrEqualTo(1));
      expect(restoreAccessCalls, greaterThanOrEqualTo(1));

      // Summary screen renders cleanly
      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(find.text('WORKOUT TIME'), findsOneWidget);
      expect(find.text('SETS COMPLETED'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      // Verify no fake scores or ads
      expect(find.text('Focus Score'), findsNothing);
      expect(find.text('Distraction Attempts'), findsNothing);
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

      expect(stopFocusCalls, 1);
      expect(restoreAccessCalls, 1);
      expect(find.text('UNFINISHED WORKOUT'), findsNothing);
      expect(sessionService.loadActiveSession(), isNull);
    });
  });

  group('Redesign: Settings Screen UI', () {
    testWidgets('Settings screen provides minimal toggles, allowed apps link, and privacy text', (tester) async {
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

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Default Rest Timer'), findsOneWidget);
      expect(find.text('Sound Alert'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Keep Screen Awake'), findsOneWidget);
      expect(find.text('Allowed Apps'), findsOneWidget);
      expect(find.text('Focus Lift stores workout settings and preferences on this device. No account is required.'), findsOneWidget);
    });
  });
}
