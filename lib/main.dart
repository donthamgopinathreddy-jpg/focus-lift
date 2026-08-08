import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/local_storage_service.dart';
import 'services/workout_session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await LocalStorageService.create();
  final sessionService = await WorkoutSessionService.create();
  final preferences = storageService.loadPreferences();

  runApp(
    FocusLiftApp(
      storageService: storageService,
      sessionService: sessionService,
      initialPreferences: preferences,
    ),
  );
}
