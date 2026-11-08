import 'package:flutter/material.dart';

import 'app.dart';
import 'state/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No manual system-bar mode: Flutter + the Android version decide it, and Scaffold/SafeArea keep content inside the screen.
  runApp(TvvApp(services: AppServices.create()));
}
