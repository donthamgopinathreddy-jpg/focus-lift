import 'package:flutter/material.dart';
import '../models/app_preferences.dart';
import '../screens/home/home_screen.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/workout_session_service.dart';
import 'theme.dart';

class FocusLiftApp extends StatelessWidget {
  final LocalStorageService storageService;
  final WorkoutSessionService sessionService;
  final NotificationService notificationService;
  final AppPreferences initialPreferences;

  const FocusLiftApp({
    super.key,
    required this.storageService,
    required this.sessionService,
    required this.notificationService,
    required this.initialPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Lift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(
        storageService: storageService,
        sessionService: sessionService,
        notificationService: notificationService,
        initialPreferences: initialPreferences,
      ),
    );
  }
}
