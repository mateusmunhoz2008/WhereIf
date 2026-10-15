import 'package:autth_injustice_app/institution/domain/models/institution_theme_config.dart';
import 'package:flutter/material.dart';

// Bundled font families: no runtime download or network-dependent fallback.
abstract final class _Fonts {
  static TextStyle archivoBlack({TextStyle? textStyle}) =>
      (textStyle ?? const TextStyle()).copyWith(fontFamily: 'ArchivoBlack');
  static TextStyle inter({TextStyle? textStyle}) =>
      (textStyle ?? const TextStyle()).copyWith(fontFamily: 'Inter');
}

class AppDesign {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double hg = 48.0;

  static const double pageHorizontalPadding = 20.0;
  static const double extraPageHorizontalPadding = 27.0;

  static const double radiusMd = 20.0;
}

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;

  TextStyle? get displayLarge => text.displayLarge;
  TextStyle? get displayMedium => text.displayMedium;
  TextStyle? get displaySmall => text.displaySmall;

  TextStyle? get headlineLarge => text.headlineLarge;
  TextStyle? get headlineMedium => text.headlineMedium;
  TextStyle? get headlineSmall => text.headlineSmall;

  TextStyle? get bodyLarge => text.bodyLarge;
  TextStyle? get bodyMedium => text.bodyMedium;
  TextStyle? get bodySmall => text.bodySmall;

  TextStyle? get titleLarge => text.titleLarge;

  bool get isDarkMode => theme.brightness == Brightness.dark;
  bool get isLightMode => theme.brightness == Brightness.light;

  double get spaceSm => AppDesign.sm;
  double get spaceMd => AppDesign.md;
  double get spaceLg => AppDesign.lg;

  // Backgrounds
  Color get background => theme.scaffoldBackgroundColor;
  Color get scaffoldBackground => theme.scaffoldBackgroundColor;
  Color get surface => colors.surface;

  // Principais cores
  Color get primary => colors.primary;
  Color get secondary => colors.secondary;
  Color get tertiary => colors.tertiary;

  // Cores "on"
  Color get onPrimary => colors.onPrimary;
  Color get onSecondary => colors.onSecondary;
  Color get onSurface => colors.onSurface;
  Color get onTertiary => colors.onTertiary;

  // Bordas
  double get radiusMd => AppDesign.radiusMd;

  EdgeInsets get pagePadding => const EdgeInsets.symmetric(
        horizontal: AppDesign.pageHorizontalPadding,
      );

  EdgeInsets get extraPagePadding => const EdgeInsets.symmetric(
        horizontal: AppDesign.extraPageHorizontalPadding,
      );

  Gradient get initialPageGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary,
          colors.secondary,
        ],
      );
}

TextTheme _buildCustomTextTheme(TextTheme baseTheme) {
  return baseTheme.copyWith(
    displayLarge: _Fonts.archivoBlack(
      textStyle: baseTheme.displayLarge?.copyWith(
        fontSize: 48,
        height: 1.0,
        letterSpacing: 0,
      ),
    ),
    displayMedium: _Fonts.archivoBlack(
      textStyle: baseTheme.displayMedium?.copyWith(
        fontSize: 40,
        height: 1.05,
        letterSpacing: 0,
      ),
    ),
    displaySmall: _Fonts.archivoBlack(
      textStyle: baseTheme.displaySmall?.copyWith(
        fontSize: 32,
        height: 1.08,
        letterSpacing: 0,
      ),
    ),
    headlineLarge: _Fonts.archivoBlack(
      textStyle: baseTheme.headlineLarge?.copyWith(
        fontSize: 36,
        height: 1.05,
        letterSpacing: 0,
      ),
    ),
    headlineMedium: _Fonts.inter(
      textStyle: baseTheme.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ),
    headlineSmall: _Fonts.inter(
      textStyle: baseTheme.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    titleLarge: _Fonts.inter(
      textStyle: baseTheme.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    bodyLarge: _Fonts.inter(
      textStyle: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
    ),
    bodyMedium: _Fonts.inter(
      textStyle: baseTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    ),
    bodySmall: _Fonts.inter(
      textStyle: baseTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    ),
    labelLarge: _Fonts.inter(
      textStyle: baseTheme.labelLarge?.copyWith(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    labelMedium: _Fonts.inter(
      textStyle: baseTheme.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    labelSmall: _Fonts.inter(
      textStyle: baseTheme.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
  );
}

ThemeData buildLightTheme(InstitutionThemeConfig config) {
  final base = ThemeData.light(useMaterial3: true);
  final palette = config.light;
  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      tertiary: palette.tertiary,
      onTertiary: palette.onTertiary,
    ),
    scaffoldBackgroundColor: palette.scaffoldBackground,
    textTheme: _buildCustomTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: palette.onSurface,
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
    ),
  );
}

ThemeData buildDarkTheme(InstitutionThemeConfig config) {
  final base = ThemeData.dark(useMaterial3: true);
  final palette = config.dark;
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      tertiary: palette.tertiary,
      onTertiary: palette.onTertiary,
    ),
    scaffoldBackgroundColor: palette.scaffoldBackground,
    textTheme: _buildCustomTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: palette.onSurface,
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
    ),
  );
}
