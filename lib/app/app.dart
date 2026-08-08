import 'package:flutter/material.dart';
import '../models/app_preferences.dart';
import '../screens/home/home_screen.dart';
import '../screens/workout/workout_screen.dart';
import '../services/focus_control/focus_control_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/workout_session_service.dart';
import 'theme.dart';

class FocusLiftApp extends StatelessWidget {
  final LocalStorageService storageService;
  final WorkoutSessionService sessionService;
  final NotificationService notificationService;
  final FocusControlService focusService;
  final AppPreferences initialPreferences;

  const FocusLiftApp({
    super.key,
    required this.storageService,
    required this.sessionService,
    required this.notificationService,
    required this.focusService,
    required this.initialPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final activeSession = sessionService.loadActiveSession();
    final initialHome = activeSession != null
        ? WorkoutScreen(
            initialSession: activeSession.evaluatedAt(DateTime.now()),
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            preferences: initialPreferences,
          )
        : HomeScreen(
            storageService: storageService,
            sessionService: sessionService,
            notificationService: notificationService,
            focusService: focusService,
            initialPreferences: initialPreferences,
          );

    return MaterialApp(
      title: 'Focus Lift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initialHome,
    );
  }
}
