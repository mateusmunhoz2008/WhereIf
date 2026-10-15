import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

abstract final class EventCardVisualStyle {
  static const _accents = [
    Color(0xFF8D55E8),
    Color(0xFF2CA58D),
    Color(0xFF4F7FEA),
    Color(0xFFE49B32),
    Color(0xFFE15F83),
  ];

  static Color accentAt(int index) => _accents[index % _accents.length];

  static List<Shadow> textShadows(
    BuildContext context, {
    bool prominent = false,
  }) =>
      [
        Shadow(
          color: Colors.black.withValues(
            alpha: context.isDarkMode
                ? (prominent ? 0.65 : 0.58)
                : (prominent ? 0.24 : 0.18),
          ),
          blurRadius: prominent ? 8 : 3,
          offset: Offset(0, prominent ? 2 : 1),
        ),
      ];

  static List<BoxShadow> shadows(
    BuildContext context, {
    required Color accentColor,
    double scale = 1,
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: context.isDarkMode ? 0.24 : 0.45,
        ),
        blurRadius: 15,
        offset: Offset(0, 6 * scale),
      ),
      BoxShadow(
        color: accentColor.withValues(
          alpha: context.isDarkMode ? 0.10 : 0.06,
        ),
        blurRadius: 18 * scale,
        offset: Offset(0, 7 * scale),
      ),
    ];
  }
}
