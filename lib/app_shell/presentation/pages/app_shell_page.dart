import 'dart:ui';

import 'package:autth_injustice_app/complementary_hours/presentation/navigation/complementary_hours_routes.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/events/presentation/navigation/event_management_routes.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:autth_injustice_app/notifications/presentation/navigation/notifications_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShellPage extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final String currentPath;
  final bool showNavigationBar;

  const AppShellPage({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.currentPath,
    this.showNavigationBar = true,
  });

  void _goToTab(BuildContext context, int index) {
    final canManageEvents =
        injector.get<AuthorizationService>().canManageEvents;
    final rootPath = switch (index) {
      0 => MapPaths.map,
      1 => canManageEvents ? EventManagementPaths.catalog : EventsPaths.catalog,
      2 => NotificationsPaths.notifications,
      3 => ComplementaryHoursPaths.summary,
      _ => MapPaths.map,
    };
    if (currentPath == rootPath) return;

    context.go(rootPath);
  }

  @override
  Widget build(BuildContext context) {
    final canManageEvents =
        injector.get<AuthorizationService>().canManageEvents;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (showNavigationBar && !keyboardOpen)
            _GlassNavigationBar(
              currentIndex: currentIndex,
              canManageEvents: canManageEvents,
              onSelected: (index) => _goToTab(context, index),
            ),
        ],
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final bool canManageEvents;
  final ValueChanged<int> onSelected;

  const _GlassNavigationBar({
    required this.currentIndex,
    required this.canManageEvents,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCompact =
        context.isVerySmallScreen || context.screenSize.width < 360;
    final horizontalPadding =
        isCompact ? 20.0 : context.extraPagePadding.horizontal / 2;

    return Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: 5,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: isCompact ? 9 : 14),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isCompact ? 332 : 460,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 20 : 25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.30 : 0.16,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: colors.secondary.withValues(
                      alpha: isDark ? 0.09 : 0.06,
                    ),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isCompact ? 20 : 25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 26,
                    sigmaY: 26,
                    tileMode: TileMode.clamp,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                colors.surface.withValues(alpha: 0.54),
                                colors.surface.withValues(alpha: 0.34),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.62),
                                colors.surface.withValues(alpha: 0.44),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(isCompact ? 20 : 25),
                      border: Border.all(
                        color: colors.onSurface.withValues(
                          alpha: isDark ? 0.17 : 0.13,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      height: isCompact ? 56 : 68,
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavItem(
                              icon: Icons.map_outlined,
                              selectedIcon: Icons.map,
                              label: context.l10n.navigationMap,
                              selected: currentIndex == 0,
                              onTap: () => onSelected(0),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: canManageEvents
                                  ? Icons.dashboard_customize_outlined
                                  : Icons.calendar_month_outlined,
                              selectedIcon: canManageEvents
                                  ? Icons.dashboard_customize_rounded
                                  : Icons.calendar_month,
                              label: context.l10n.navigationEvents,
                              selected: currentIndex == 1,
                              onTap: () => onSelected(1),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.notifications_none_outlined,
                              selectedIcon: Icons.notifications,
                              label: context.l10n.navigationNotifications,
                              selected: currentIndex == 2,
                              onTap: () => onSelected(2),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.schedule_outlined,
                              selectedIcon: Icons.access_time_filled_rounded,
                              label: context.l10n.navigationHours,
                              selected: currentIndex == 3,
                              onTap: () => onSelected(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCompact =
        context.isVerySmallScreen || context.screenSize.width < 360;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            splashColor: colors.secondary.withValues(alpha: 0.05),
            highlightColor: Colors.transparent,
            child: Center(
              child: AnimatedScale(
                scale: selected ? 1.3 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0.6,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    size: isCompact ? 25 : 27,
                    color: colors.onTertiary,
                    shadows: selected
                        ? [
                            Shadow(
                              color: colors.primary.withValues(alpha: 0.2),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
