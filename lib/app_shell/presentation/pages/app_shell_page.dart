import 'package:autth_injustice_app/complementary_hours/presentation/navigation/complementary_hours_routes.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/app_shell/presentation/widgets/compact_shell_navigation_bar.dart';
import 'package:autth_injustice_app/core/widgets/app_glass_surface.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
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
      0 => canManageEvents ? EventManagementPaths.catalog : EventsPaths.catalog,
      1 => MapPaths.map,
      2 => NotificationsPaths.notifications,
      3 => ComplementaryHoursPaths.summary,
      _ => canManageEvents ? EventManagementPaths.catalog : EventsPaths.catalog,
    };
    if (currentPath == rootPath) return;

    context.go(rootPath);
  }

  @override
  Widget build(BuildContext context) {
    final canManageEvents =
        injector.get<AuthorizationService>().canManageEvents;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isMapScreen = currentPath == MapPaths.map;

    return ValueListenableBuilder<bool>(
      valueListenable: AppGlassSurface.mapBlurTestEnabled,
      builder: (context, mapBlurEnabled, _) => GlassBlurScope(
        enabled: !isMapScreen || mapBlurEnabled,
        child: Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: child),
              if (showNavigationBar && !keyboardOpen)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: CompactShellNavigationBar(
                        currentIndex: currentIndex,
                        canManageEvents: canManageEvents,
                        mapBlurDiagnostic: isMapScreen,
                        whiteItems: isMapScreen ||
                            (currentPath == AuthPaths.login &&
                                Theme.of(context).brightness ==
                                    Brightness.dark),
                        onSelected: (index) => _goToTab(context, index),
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
