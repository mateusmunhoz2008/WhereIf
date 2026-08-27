import 'dart:async';

import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/institution/presentation/widgets/institution_image.dart';

import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:autth_injustice_app/core/utils/hide_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autth_injustice_app/core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    hideKeyboard();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.28, end: 0.3).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authRepository = injector.get<IAuthRepository>();
    final authorizationService = injector.get<AuthorizationService>();
    final appEntryRepository = injector.get<IAppEntryRepository>();

    final initialization = await Future.wait([
      Future.delayed(const Duration(milliseconds: 800)),
      authRepository.initSession(),
      appEntryRepository.hasCompletedInitialPage(),
    ]);
    final hasCompletedInitialPage = initialization.last as bool;

    if (!mounted) return;
    _animController.duration = const Duration(milliseconds: 200);
    await _animController.reverse();

    if (!mounted) return;

    final destination =
        authorizationService.isAuthenticated || hasCompletedInitialPage
            ? MapRouteNames.map
            : AuthRouteNames.initial;
    context.goNamed(destination);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.colors.tertiary;

    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: RepaintBoundary(
          child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: InstitutionImage(
                resource: context.isDarkMode
                    ? context.institution.branding.logoOnDarkBackground
                    : context.institution.branding.logoOnLightBackground,
                width: screenWidth * 0.55,
                fit: BoxFit.contain,
              )),
        ),
      ),
    );
  }
}
