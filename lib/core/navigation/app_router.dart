import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/app_shell/presentation/pages/app_shell_page.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/navigation/complementary_hours_routes.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/navigation/app_navigator_keys.dart';
import 'package:autth_injustice_app/events/presentation/navigation/event_management_routes.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:autth_injustice_app/notifications/presentation/navigation/notifications_routes.dart';
import 'package:autth_injustice_app/settings/presentation/navigation/settings_routes.dart';
import 'package:autth_injustice_app/user_management/presentation/navigation/user_management_routes.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter._();

  static int _tabIndexFor(
    String path, {
    String? loginReturnTo,
  }) {
    final effectivePath =
        path == AuthPaths.login ? loginReturnTo ?? MapPaths.map : path;

    if (effectivePath.startsWith(EventsPaths.catalog)) return 0;

    if (effectivePath.startsWith(EventManagementPaths.catalog)) return 0;

    if (effectivePath.startsWith(MapPaths.map)) return 1;

    if (effectivePath.startsWith(NotificationsPaths.notifications)) return 2;

    if (effectivePath.startsWith(ComplementaryHoursPaths.summary)) return 3;

    return 0;
  }

  static bool _requiresAuthentication(String path) {
    return path.startsWith(NotificationsPaths.notifications) ||
        path.startsWith(ComplementaryHoursPaths.summary) ||
        path.startsWith(SettingsPaths.settings) ||
        path.startsWith(EventManagementPaths.catalog) ||
        path.startsWith(UserManagementPaths.users);
  }

  static String? _safeReturnTo(String? value) {
    if (value == null || !value.startsWith('/') || value == AuthPaths.initial) {
      return null;
    }
    return value;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: AppNavigatorKeys.root,
    initialLocation: AuthPaths.splash,
    redirect: (context, state) async {
      final authorizationService = injector.get<AuthorizationService>();
      final appEntryRepository = injector.get<IAppEntryRepository>();
      final canManageEvents = authorizationService.canManageEvents;
      final path = state.uri.path;

      if (path == AuthPaths.initial) {
        final completed = await appEntryRepository.hasCompletedInitialPage();
        return completed ? MapPaths.map : null;
      }
      if (path == AuthPaths.login && authorizationService.isAuthenticated) {
        return _safeReturnTo(state.uri.queryParameters['returnTo']) ??
            MapPaths.map;
      }
      if (_requiresAuthentication(path) &&
          !authorizationService.isAuthenticated) {
        return AuthPaths.loginFor(state.uri.toString());
      }
      if (path.startsWith(NotificationsPaths.create) &&
          !authorizationService.canPublishAnnouncements) {
        return NotificationsPaths.notifications;
      }
      if (path.startsWith(UserManagementPaths.users) &&
          !authorizationService.canManageAccounts) {
        return ComplementaryHoursPaths.summary;
      }
      if (path.startsWith(EventManagementPaths.catalog) && !canManageEvents) {
        return EventsPaths.catalog;
      }
      if (path == EventsPaths.catalog && canManageEvents) {
        return EventManagementPaths.catalog;
      }
      return null;
    },
    routes: [
      ...rootAuthRoutes,
      ShellRoute(
        builder: (context, state, child) {
          final hidesNavigationBar =
              state.uri.path.startsWith(SettingsPaths.settings) ||
                  state.uri.path.startsWith(UserManagementPaths.users);
          return AppShellPage(
            currentIndex: _tabIndexFor(
              state.uri.path,
              loginReturnTo: _safeReturnTo(
                state.uri.queryParameters['returnTo'],
              ),
            ),
            currentPath: state.uri.path,
            showNavigationBar: !hidesNavigationBar,
            child: child,
          );
        },
        routes: [
          loginRoute,
          mapRoute,
          eventsRoute,
          notificationsRoute,
          complementaryHoursRoute,
          eventManagementRoute,
          settingsRoute,
          userManagementRoute,
        ],
      ),
    ],
  );
}
