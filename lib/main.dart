import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aerosense_app/firebase_options.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp note: $e\n$st');
  }

  // Load SharedPreferences before runApp to avoid theme flash
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString(ThemeModeNotifier.prefKey);
  final initialMode = savedTheme != null
      ? ThemeModeNotifier.parse(savedTheme)
      : ThemeMode.system;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialThemeModeProvider.overrideWithValue(initialMode),
      ],
      child: const AeroSenseApp(),
    ),
  );
}
