import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'screens/catalog/food_catalog_screen.dart';
import 'theme/fit_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const MyApp());
}

class FitTrackAiApp extends StatelessWidget {
  const FitTrackAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack AI',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.dark,
      // Replace this local profile identifier with the signed-in profile ID
      // when the authentication/profile module is connected.
      home: const FoodCatalogScreen(currentUserId: 'local-user'),
    );
  }
}

class MyApp extends FitTrackAiApp {
  const MyApp({super.key});
}
