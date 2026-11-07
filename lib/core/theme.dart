import 'package:flutter/material.dart';

/// Semantic colors for Safe, Medium, and Danger tiers per DESIGN.md.
///
/// Status is sacred: Green / Amber / Red mean Safe / Medium / Danger and nothing else.
/// Never show tier by color alone (always pair with icon + text).
@immutable
class TierColors extends ThemeExtension<TierColors> {
  const TierColors({
    required this.safe,
    required this.safeContainer,
    required this.medium,
    required this.mediumContainer,
    required this.danger,
    required this.dangerContainer,
  });

  /// Light theme tier colors per DESIGN.md §2.
  static const light = TierColors(
    safe: Color(0xFF12704E),
    safeContainer: Color(0xFFE3F5EC),
    medium: Color(0xFF9A6200),
    mediumContainer: Color(0xFFFFF3D6),
    danger: Color(0xFFC62833),
    dangerContainer: Color(0xFFFDE7E9),
  );

  /// Dark theme tier colors per DESIGN.md §2.
  static const dark = TierColors(
    safe: Color(0xFF3CC98E),
    safeContainer: Color(0xFF123528),
    medium: Color(0xFFF2B544),
    mediumContainer: Color(0xFF3A2C0E),
    danger: Color(0xFFFF6B77),
    dangerContainer: Color(0xFF4A1C21),
  );

  final Color safe;
  final Color safeContainer;
  final Color medium;
  final Color mediumContainer;
  final Color danger;
  final Color dangerContainer;

  @override
  TierColors copyWith({
    Color? safe,
    Color? safeContainer,
    Color? medium,
    Color? mediumContainer,
    Color? danger,
    Color? dangerContainer,
  }) {
    return TierColors(
      safe: safe ?? this.safe,
      safeContainer: safeContainer ?? this.safeContainer,
      medium: medium ?? this.medium,
      mediumContainer: mediumContainer ?? this.mediumContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
    );
  }

  @override
  TierColors lerp(ThemeExtension<TierColors>? other, double t) {
    if (other is! TierColors) return this;
    return TierColors(
      safe: Color.lerp(safe, other.safe, t)!,
      safeContainer: Color.lerp(safeContainer, other.safeContainer, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      mediumContainer: Color.lerp(mediumContainer, other.mediumContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
    );
  }
}

/// Extra theme tokens from DESIGN.md not present in standard M3 ColorScheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.surfaceAlt, required this.textTertiary});

  /// Light theme additional tokens per DESIGN.md §2.
  static const light = AppColors(
    surfaceAlt: Color(0xFFEDF1F5),
    textTertiary: Color(0xFF5E6D7C),
  );

  /// Dark theme additional tokens per DESIGN.md §2.
  static const dark = AppColors(
    surfaceAlt: Color(0xFF1A2836),
    textTertiary: Color(0xFF6F8296),
  );

  /// Inputs, chips, chart plot area background.
  final Color surfaceAlt;

  /// Hints, axis labels.
  final Color textTertiary;

  @override
  AppColors copyWith({Color? surfaceAlt, Color? textTertiary}) {
    return AppColors(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

/// AeroSense theme definitions (Light and Dark) following DESIGN.md.
class AeroSenseTheme {
  AeroSenseTheme._();

  static const String fontFamily = 'Inter';

  // --- Light Palette Tokens ---
  static const Color _lightBackground = Color(0xFFF6F8FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightOutline = Color(0xFFD5DDE5);
  static const Color _lightTextPrimary = Color(0xFF0F1B2A);
  static const Color _lightTextSecondary = Color(0xFF4F5F6F);
  static const Color _lightPrimary = Color(0xFF1D5FA7);
  static const Color _lightOnPrimary = Color(0xFFFFFFFF);
  static const Color _lightPrimaryContainer = Color(0xFFE4EEF9);

  // --- Dark Palette Tokens ---
  static const Color _darkBackground = Color(0xFF0B131B);
  static const Color _darkSurface = Color(0xFF121D28);
  static const Color _darkOutline = Color(0xFF283849);
  static const Color _darkTextPrimary = Color(0xFFE8EEF4);
  static const Color _darkTextSecondary = Color(0xFF9DB0C2);
  static const Color _darkPrimary = Color(0xFF6FA8E8);
  static const Color _darkOnPrimary = Color(0xFF0B131B);
  static const Color _darkPrimaryContainer = Color(0xFF1B3350);

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _lightPrimary,
    onPrimary: _lightOnPrimary,
    primaryContainer: _lightPrimaryContainer,
    onPrimaryContainer: _lightTextPrimary,
    surface: _lightSurface,
    onSurface: _lightTextPrimary,
    onSurfaceVariant: _lightTextSecondary,
    outline: _lightOutline,
    outlineVariant: _lightOutline,
    error: Color(0xFFC62833),
    onError: Colors.white,
    secondary: _lightPrimary,
    onSecondary: _lightOnPrimary,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _darkPrimary,
    onPrimary: _darkOnPrimary,
    primaryContainer: _darkPrimaryContainer,
    onPrimaryContainer: _darkTextPrimary,
    surface: _darkSurface,
    onSurface: _darkTextPrimary,
    onSurfaceVariant: _darkTextSecondary,
    outline: _darkOutline,
    outlineVariant: _darkOutline,
    error: Color(0xFFFF6B77),
    onError: Color(0xFF0B131B),
    secondary: _darkPrimary,
    onSecondary: _darkOnPrimary,
  );

  static TextTheme _buildTextTheme(Color textPrimary, Color textSecondary) {
    return TextTheme(
      // metricValue: 44 / 48, w600, tabular figures
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 44,
        height: 48 / 44,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // metricUnit: 16 / 24, w500
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      // titleLarge: 22 / 28, w600
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // titleMedium: 16 / 24, w600
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      // body: 14 / 20, w400
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      // label: 12 / 16, w500
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      // caption: 11 / 14, w400
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
    );
  }

  /// Builds the light ThemeData.
  static ThemeData get light {
    final textTheme = _buildTextTheme(_lightTextPrimary, _lightTextSecondary);
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: _lightBackground,
      textTheme: textTheme,
      cardTheme: const CardThemeData(
        elevation: 0,
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _lightOutline, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _lightOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _lightOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _lightPrimary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
          minimumSize: const Size(48, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: _lightTextPrimary,
          side: const BorderSide(color: _lightOutline, width: 1),
          minimumSize: const Size(48, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      extensions: const [TierColors.light, AppColors.light],
    );
  }

  /// Builds the dark ThemeData.
  static ThemeData get dark {
    final textTheme = _buildTextTheme(_darkTextPrimary, _darkTextSecondary);
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: _darkBackground,
      textTheme: textTheme,
      cardTheme: const CardThemeData(
        elevation: 0,
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _darkOutline, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _darkOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _darkOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _darkPrimary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          minimumSize: const Size(48, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: _darkTextPrimary,
          side: const BorderSide(color: _darkOutline, width: 1),
          minimumSize: const Size(48, 44),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      extensions: const [TierColors.dark, AppColors.dark],
    );
  }
}

/// Convenience extensions on [BuildContext] to access design tokens.
extension ThemeExtensions on BuildContext {
  TierColors get tierColors =>
      Theme.of(this).extension<TierColors>() ?? TierColors.light;
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
