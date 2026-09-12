import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;
  final double textScale;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final bool destructive;

  const SettingsOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.scale,
    required this.textScale,
    this.onTap,
    this.trailing,
    this.showChevron = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? context.colors.error.withValues(alpha: 0.92)
        : context.onTertiary;

    return Semantics(
      button: onTap != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12 * scale),
          splashColor: context.secondary.withValues(alpha: 0.08),
          highlightColor: context.secondary.withValues(alpha: 0.035),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 52 * scale),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4 * scale),
              child: Row(
                children: [
                  SizedBox(
                    width: 43 * scale,
                    child: Icon(
                      icon,
                      size: 25 * scale,
                      color: foreground,
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: foreground,
                        fontSize: 14 * textScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                  if (trailing == null && showChevron)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 23 * scale,
                      color: context.onTertiary.withValues(alpha: 0.82),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsLanguageBadge extends StatelessWidget {
  final String languageCode;
  final double scale;
  final double textScale;

  const SettingsLanguageBadge({
    super.key,
    required this.languageCode,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Container(
        key: ValueKey(languageCode),
        constraints: BoxConstraints(minWidth: 70 * scale),
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 7 * scale,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: context.secondary
                  .withValues(alpha: context.isDarkMode ? 0.3 : 0.12)),
        ),
        child: Text(
          languageCode.toUpperCase(),
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(
            color: context.onTertiary,
            fontSize: 11 * textScale,
          ),
        ),
      ),
    );
  }
}

class SettingsValueBadge extends StatelessWidget {
  final String value;
  final double scale;
  final double textScale;

  const SettingsValueBadge({
    super.key,
    required this.value,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(value),
        constraints: BoxConstraints(minWidth: 70 * scale),
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 7 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: context.secondary.withValues(
              alpha: context.isDarkMode ? 0.30 : 0.12,
            ),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(
            color: context.onTertiary,
            fontSize: 10.5 * textScale,
          ),
        ),
      ),
    );
  }
}
