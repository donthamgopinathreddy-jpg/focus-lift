import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_lift/app/app.dart';
import 'package:focus_lift/models/app_preferences.dart';
import 'package:focus_lift/models/focus_mode.dart';
import 'package:focus_lift/screens/settings/settings_screen.dart';
import 'package:focus_lift/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppPreferences default values and copyWith test', () {
    const prefs = AppPreferences();
    expect(prefs.defaultRestDurationSeconds, 60);
    expect(prefs.focusMode, FocusMode.focus);
    expect(prefs.soundEnabled, true);
    expect(prefs.vibrationEnabled, true);
    expect(prefs.keepScreenAwake, true);

    final updated = prefs.copyWith(
      defaultRestDurationSeconds: 90,
      focusMode: FocusMode.balanced,
      soundEnabled: false,
    );
    expect(updated.defaultRestDurationSeconds, 90);
    expect(updated.focusMode, FocusMode.balanced);
    expect(updated.soundEnabled, false);
    expect(updated.vibrationEnabled, true);
  });

  test('LocalStorageService save and load test', () async {
    final storage = await LocalStorageService.create();
    final initial = storage.loadPreferences();
    expect(initial.defaultRestDurationSeconds, 60);

    await storage.saveRestDuration(120);
    await storage.saveFocusMode(FocusMode.custom);

    final reloaded = storage.loadPreferences();
    expect(reloaded.defaultRestDurationSeconds, 120);
    expect(reloaded.focusMode, FocusMode.custom);
  });

  testWidgets('HomeScreen renders core elements and handles interactions',
      (WidgetTester tester) async {
    final storage = await LocalStorageService.create();
    const prefs = AppPreferences();

    await tester.pumpWidget(
      FocusLiftApp(
        storageService: storage,
        initialPreferences: prefs,
      ),
    );

    // Verify header branding
    expect(find.text('FOCUS LIFT'), findsOneWidget);
    expect(find.text('TRAIN WITHOUT DISTRACTIONS'), findsOneWidget);

    // Verify rest timer options
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    expect(find.text('90s'), findsOneWidget);
    expect(find.text('120s'), findsOneWidget);

    // Verify focus mode options
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('BALANCED'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);

    // Verify primary CTA
    expect(find.text('START WORKOUT'), findsOneWidget);

    // Tap 90s option
    await tester.tap(find.text('90s'));
    await tester.pumpAndSettle();

    // Tap Balanced mode
    await tester.tap(find.text('BALANCED'));
    await tester.pumpAndSettle();

    // Verify Start Workout button responds
    await tester.tap(find.text('START WORKOUT'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('SettingsScreen displays all required sections and switches',
      (WidgetTester tester) async {
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

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Default Rest Timer'), findsOneWidget);
    expect(find.text('Sound Alert'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.text('Keep Screen Awake'), findsOneWidget);
    expect(find.text('100% On-Device & Private'), findsOneWidget);
    expect(find.textContaining('Cotrainr'), findsOneWidget);

    // Toggle switch
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    await tester.tap(switches.first);
    await tester.pumpAndSettle();
  });
}
