import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await LocalStorageService.create();
  final preferences = storageService.loadPreferences();

  runApp(
    FocusLiftApp(
      storageService: storageService,
      initialPreferences: preferences,
    ),
  );
}
