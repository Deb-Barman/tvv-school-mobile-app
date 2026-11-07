import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'state/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(TvvApp(services: AppServices.create()));
}
