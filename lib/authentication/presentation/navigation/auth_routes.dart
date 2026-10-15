import 'package:autth_injustice_app/authentication/presentation/navigation/check_email_args.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/password_reset_args.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/check_email_page.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/initial_page.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/login_page.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/register_page.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/reset_password_page.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/splash_page.dart';
import 'package:autth_injustice_app/core/navigation/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthRouteNames {
  static const splash = 'splash';
  static const initial = 'initial';
  static const onboardingPreview = 'onboarding-preview';
  static const login = 'login';
  static const register = 'register';
  static const checkEmail = 'check-email';
  static const resetPassword = 'reset-password';
}

class AuthPaths {
  static const splash = '/';
  static const initial = '/initial';
  static const onboardingPreview = '/onboarding-preview';
  static const login = '/login';
  static const register = '/register';
  static const checkEmail = '/check-email';
  static const resetPassword = '/reset-password';

  static String loginFor(String returnTo) {
    return Uri(
      path: login,
      queryParameters: {'returnTo': returnTo},
    ).toString();
  }
}

final List<RouteBase> rootAuthRoutes = [
  GoRoute(
    path: AuthPaths.onboardingPreview,
    name: AuthRouteNames.onboardingPreview,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      child: InitialPage(preview: true, onCompleted: () => context.pop()),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  ),
  GoRoute(
    path: AuthPaths.splash,
    name: AuthRouteNames.splash,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: SplashPage()),
  ),
  GoRoute(
    path: AuthPaths.initial,
    name: AuthRouteNames.initial,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: InitialPage()),
  ),
  GoRoute(
    path: AuthPaths.register,
    name: AuthRouteNames.register,
    pageBuilder: (context, state) => slidePage(
      key: state.pageKey,
      child: const RegisterPage(),
    ),
  ),
  GoRoute(
    path: AuthPaths.checkEmail,
    name: AuthRouteNames.checkEmail,
    redirect: (context, state) {
      return state.extra is CheckEmailArgs ? null : AuthPaths.login;
    },
    pageBuilder: (context, state) {
      final args = state.extra as CheckEmailArgs;

      return slidePage(
        key: state.pageKey,
        child: CheckEmailPage(args: args),
      );
    },
  ),
  GoRoute(
    path: AuthPaths.resetPassword,
    name: AuthRouteNames.resetPassword,
    redirect: (context, state) {
      return state.extra is PasswordResetArgs ? null : AuthPaths.login;
    },
    pageBuilder: (context, state) {
      final args = state.extra as PasswordResetArgs;

      return slidePage(
        key: state.pageKey,
        child: ResetPasswordPage(args: args),
      );
    },
  ),
];

final loginRoute = GoRoute(
  path: AuthPaths.login,
  name: AuthRouteNames.login,
  pageBuilder: (context, state) => NoTransitionPage(
    key: state.pageKey,
    child: LoginPage(
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
);
