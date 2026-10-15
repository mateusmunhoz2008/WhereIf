import 'dart:ui';

import 'package:flutter/material.dart';

class AppGlassSurface extends StatelessWidget {
  // Scoped to the map by AppShellPage; other tabs keep their own glass.
  static final ValueNotifier<bool> mapBlurTestEnabled =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> mapNavigationBlurTestEnabled =
      ValueNotifier<bool>(true);
  final BorderRadius borderRadius;
  final bool forceDark;
  final bool neutralTint;
  final bool blurEnabled;
  final Widget child;

  const AppGlassSurface({
    super.key,
    required this.borderRadius,
    this.forceDark = false,
    this.neutralTint = false,
    this.blurEnabled = true,
    required this.child,
  });

  static const darkColors = [
    Color.fromARGB(210, 21, 1, 39),
    Color.fromARGB(169, 0, 0, 0),
    Color.fromARGB(109, 26, 2, 47),
    Color.fromARGB(148, 0, 0, 0),
  ];

  static const lightColors = [
    Color.fromARGB(255, 247, 227, 252),
    Color(0xFFFFFFFF),
    Color.fromARGB(255, 250, 230, 255),
    Color(0xFFFFFFFF),
  ];

  static const neutralDarkColors = [
    Color.fromARGB(210, 24, 24, 24),
    Color.fromARGB(169, 0, 0, 0),
    Color.fromARGB(110, 24, 24, 24),
    Color.fromARGB(148, 0, 0, 0),
  ];

  static const neutralLightColors = [
    Color(0xFFF7F7F7),
    Color(0xFFFFFFFF),
    Color(0xFFFAFAFA),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final blurAllowed = GlassBlurScope.enabledOf(context);
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final dark = forceDark || themeDark;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.08, 0.38, 1.0],
          colors: neutralTint
              ? (dark ? neutralDarkColors : neutralLightColors)
              : (dark ? darkColors : lightColors),
        ),
        border: Border.all(
          color: themeDark
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.80),
          width: 0.2,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: blurAllowed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.06 : 0.35),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blurEnabled && blurAllowed
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 5),
                child: surface,
              )
            : surface,
      ),
    );
  }
}

class GlassBlurScope extends InheritedWidget {
  final bool enabled;

  const GlassBlurScope(
      {super.key, required this.enabled, required super.child});

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassBlurScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(GlassBlurScope oldWidget) =>
      enabled != oldWidget.enabled;
}
