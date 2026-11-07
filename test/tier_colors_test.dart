import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/thresholds.dart';

void main() {
  group('DESIGN.md TierColors tokens', () {
    test('Light theme tier colors match DESIGN.md §2', () {
      const colors = TierColors.light;

      // Safe
      expect(colors.safe, const Color(0xFF12704E));
      expect(colors.safeContainer, const Color(0xFFE3F5EC));

      // Medium
      expect(colors.medium, const Color(0xFF9A6200));
      expect(colors.mediumContainer, const Color(0xFFFFF3D6));

      // Danger
      expect(colors.danger, const Color(0xFFC62833));
      expect(colors.dangerContainer, const Color(0xFFFDE7E9));
    });

    test('Dark theme tier colors match DESIGN.md §2', () {
      const colors = TierColors.dark;

      // Safe
      expect(colors.safe, const Color(0xFF3CC98E));
      expect(colors.safeContainer, const Color(0xFF123528));

      // Medium
      expect(colors.medium, const Color(0xFFF2B544));
      expect(colors.mediumContainer, const Color(0xFF3A2C0E));

      // Danger
      expect(colors.danger, const Color(0xFFFF6B77));
      expect(colors.dangerContainer, const Color(0xFF4A1C21));
    });

    test('AppColors tokens match DESIGN.md §2', () {
      expect(AppColors.light.surfaceAlt, const Color(0xFFEDF1F5));
      expect(AppColors.light.textTertiary, const Color(0xFF5E6D7C));

      expect(AppColors.dark.surfaceAlt, const Color(0xFF1A2836));
      expect(AppColors.dark.textTertiary, const Color(0xFF6F8296));
    });

    test('Threshold values match PRD §5.3 non-negotiables', () {
      expect(Thresholds.tempSafeMax, 28.0);
      expect(Thresholds.tempDangerMin, 32.0);
      expect(Thresholds.humiditySafeMax, 60.0);
      expect(Thresholds.humidityDangerMin, 75.0);
      expect(Thresholds.airQualitySafeMax, 1000.0);
      expect(Thresholds.airQualityDangerMin, 2000.0);
      expect(Thresholds.airQualityAdcMax, 4095.0);
    });
  });
}
