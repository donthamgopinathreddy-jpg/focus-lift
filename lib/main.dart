import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/focus_control/focus_control_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/workout_session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await LocalStorageService.create();
  final sessionService = await WorkoutSessionService.create();
  final notificationService = await NotificationService.create();
  final focusService = await FocusControlService.create();
  final preferences = storageService.loadPreferences();

  // Fail-safe cleanup: if no active workout is running, ensure all Focus shields/restrictions are cleared
  final activeSession = sessionService.loadActiveSession();
  if (activeSession == null) {
    await focusService.restoreNormalAccess();
  }

  runApp(
    FocusLiftApp(
      storageService: storageService,
      sessionService: sessionService,
      notificationService: notificationService,
      focusService: focusService,
      initialPreferences: preferences,
    ),
  );
}
