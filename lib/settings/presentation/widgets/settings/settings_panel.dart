import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatelessWidget {
  final double scale;
  final Widget child;

  const SettingsPanel({
    super.key,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final panelColor = context.isDarkMode ? context.tertiary : context.tertiary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24 * scale),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: context.isDarkMode ? 0.12 : 0,
          ),
        ),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          24 * scale,
          16 * scale,
          24 * scale,
        ),
        child: child,
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  final String title;
  final double textScale;

  const SettingsSectionTitle({
    super.key,
    required this.title,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.headlineMedium?.copyWith(
        color: context.onTertiary,
        fontSize: 24 * textScale,
      ),
    );
  }
}
