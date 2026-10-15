import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/widgets/app_glass_surface.dart';
import 'package:flutter/material.dart';

class CompactShellNavigationBar extends StatelessWidget {
  final int currentIndex;
  final bool canManageEvents;
  final bool whiteItems;
  final bool mapBlurDiagnostic;
  final ValueChanged<int> onSelected;

  const CompactShellNavigationBar({
    super.key,
    required this.currentIndex,
    required this.canManageEvents,
    required this.whiteItems,
    this.mapBlurDiagnostic = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final compact = context.isVerySmallScreen || context.screenSize.width < 360;
    final dark = whiteItems || theme.brightness == Brightness.dark;
    final height = compact ? 54.0 : 58.0;
    final foreground = whiteItems ? Colors.white : colors.onSurface;
    final active = whiteItems ? Colors.white : colors.secondary;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final labels = [
      context.l10n.navigationEvents,
      context.l10n.navigationMap,
      context.l10n.navigationNotifications,
      context.l10n.navigationHours,
    ];
    final icons = [
      canManageEvents
          ? Icons.dashboard_customize_outlined
          : Icons.calendar_month_outlined,
      Icons.map_outlined,
      Icons.notifications_none_rounded,
      Icons.schedule_rounded,
    ];
    final selectedIcons = [
      canManageEvents
          ? Icons.dashboard_customize_rounded
          : Icons.calendar_month_rounded,
      Icons.map_rounded,
      Icons.notifications_rounded,
      Icons.access_time_filled_rounded,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 264 : 296),
      child: ValueListenableBuilder<bool>(
        valueListenable: AppGlassSurface.mapNavigationBlurTestEnabled,
        builder: (context, navBlurEnabled, _) => AppGlassSurface(
          blurEnabled: !mapBlurDiagnostic || navBlurEnabled,
          forceDark: whiteItems,
          borderRadius: BorderRadius.circular(height / 2),
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              key: const ValueKey('shell-navigation-dock'),
              width: double.infinity,
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / 4;
                    return Stack(
                      children: [
                        AnimatedAlign(
                          alignment: Alignment(
                            -1 + currentIndex.clamp(0, 3) * 2 / 3,
                            0,
                          ),
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            key: const ValueKey('shell-navigation-indicator'),
                            width: cellWidth,
                            height: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.secondary
                                    .withValues(alpha: dark ? 0.22 : 0.12),
                                borderRadius:
                                    BorderRadius.circular((height - 6) / 2),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(
                              4,
                              (index) => Expanded(
                                    child: _DockItem(
                                      icon: icons[index],
                                      selectedIcon: selectedIcons[index],
                                      label: labels[index],
                                      selected: currentIndex == index,
                                      active: active,
                                      inactive:
                                          foreground.withValues(alpha: 0.55),
                                      iconSize: compact ? 21 : 22,
                                      duration: duration,
                                      onTap: () => onSelected(index),
                                    ),
                                  )),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color active;
  final Color inactive;
  final double iconSize;
  final Duration duration;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.active,
    required this.inactive,
    required this.iconSize,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: active.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AnimatedSlide(
                  offset: selected ? const Offset(0, -0.08) : Offset.zero,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: selected ? 1.06 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: duration,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        key: ValueKey(selected),
                        size: iconSize,
                        color: selected ? active : inactive,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: duration,
                  child: Container(
                    width: 4,
                    height: 3,
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
