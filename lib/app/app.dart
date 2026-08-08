import 'package:flutter/material.dart';
import '../models/app_preferences.dart';
import '../screens/home/home_screen.dart';
import '../services/local_storage_service.dart';
import 'theme.dart';

class FocusLiftApp extends StatelessWidget {
  final LocalStorageService storageService;
  final AppPreferences initialPreferences;

  const FocusLiftApp({
    super.key,
    required this.storageService,
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
        initialPreferences: initialPreferences,
      ),
    );
  }
}
