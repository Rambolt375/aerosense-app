import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider holding the loaded [SharedPreferences] instance.
/// Overridden in `main.dart` before `runApp` to avoid theme flashing.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Provider holding the initial [ThemeMode] loaded before `runApp`.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Notifier managing user-selected [ThemeMode] and persisting it via [SharedPreferences].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String prefKey = 'theme_mode';

  @override
  ThemeMode build() {
    final initial = ref.watch(initialThemeModeProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final saved = prefs.getString(prefKey);
      if (saved != null) {
        return parse(saved);
      }
    }
    return initial;
  }

  /// Sets the active theme mode and persists it to SharedPreferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs =
        ref.read(sharedPreferencesProvider) ??
        await SharedPreferences.getInstance();
    await prefs.setString(prefKey, mode.name);
  }

  /// Parses string into [ThemeMode].
  static ThemeMode parse(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

/// Dynamic theme mode provider.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
