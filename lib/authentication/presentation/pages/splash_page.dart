import 'dart:async';

import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/events/presentation/navigation/event_management_routes.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/institution/presentation/widgets/institution_image.dart';
import 'package:autth_injustice_app/core/utils/hide_keyboard.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:autth_injustice_app/core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.authRepository,
    this.authorizationService,
    this.entryRepository,
  });

  final IAuthRepository? authRepository;
  final AuthorizationService? authorizationService;
  final IAppEntryRepository? entryRepository;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _initializing = false;
  bool _initializationFailed = false;

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

    unawaited(_initializeApp());
  }

  Future<void> _initializeApp() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    if (_initializationFailed) {
      setState(() => _initializationFailed = false);
      _animController.forward();
    }
    try {
      final authRepository =
          widget.authRepository ?? injector.get<IAuthRepository>();
      final authorization =
          widget.authorizationService ?? injector.get<AuthorizationService>();
      final entryRepository =
          widget.entryRepository ?? injector.get<IAppEntryRepository>();
      final initialization = await Future.wait<Object?>([
        Future<void>.delayed(const Duration(milliseconds: 800)),
        authRepository.initSession(),
        _hasCompletedInitialPage(entryRepository),
      ]);
      final completed = initialization.last as bool;

      if (!mounted) return;
      _animController.duration = const Duration(milliseconds: 200);
      await _animController.reverse().orCancel;
      if (!mounted) return;
      final authenticated = authorization.isAuthenticated ||
          authRepository.currentSession != null;
      final destination = authenticated || completed
          ? (authorization.canManageEvents
              ? EventManagementRouteNames.catalog
              : EventsRouteNames.catalog)
          : AuthRouteNames.initial;
      context.goNamed(destination);
    } on TickerCanceled {
      return;
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    } finally {
      _initializing = false;
    }
  }

  Future<bool> _hasCompletedInitialPage(IAppEntryRepository repository) async {
    try {
      return await repository
          .hasCompletedInitialPage()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      return false;
    }
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
      body: _initializationFailed
          ? AppStatusView(
              key: const ValueKey('splash-initialization-error'),
              icon: Icons.error_outline_rounded,
              message: context.l10n.authUnexpectedError,
              actionLabel: context.l10n.commonRetry,
              onAction: () => unawaited(_initializeApp()),
            )
          : Center(
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
