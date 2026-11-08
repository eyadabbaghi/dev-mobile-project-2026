import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show databaseFactoryFfiWeb;
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme/fit_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(MyApp());
}

class FitTrackAiApp extends StatelessWidget {
  final AuthService authService = AuthService();

  FitTrackAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack AI',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.dark,
      // Le module Auth devient le point d'entrée principal
      home: SplashScreen(authService: authService),
    );
  }
}

class MyApp extends FitTrackAiApp {
  MyApp({super.key});
}
