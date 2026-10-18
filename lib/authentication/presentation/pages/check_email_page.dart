import 'dart:async';

import 'package:autth_injustice_app/authentication/presentation/viewmodels/check_email/check_email_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/email_confirmation_feedback.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/auth_error_banner.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/constants/app_assets.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/check_email_args.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/password_reset_args.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/core/widgets/loading_dots.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class CheckEmailPage extends StatefulWidget {
  final CheckEmailArgs args;

  const CheckEmailPage({
    super.key,
    required this.args,
  });

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage>
    with TickerProviderStateMixin {
  static const _successFeedbackDuration = Duration(seconds: 3);

  late final CheckEmailViewModel _viewModel;
  late final AnimationController _contentController;
  late final Animation<double> _iconScale;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  Timer? _redirectTimer;
  late bool _initialLinkPrepared;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<CheckEmailViewModel>();
    _viewModel.state.reset();
    _initialLinkPrepared = widget.args.linkAlreadySent;

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _contentController.forward();
      _startEmailConfirmation();
    });
  }

  Future<void> _startEmailConfirmation() async {
    if (!_initialLinkPrepared) {
      final sent = await _viewModel.commands.resend(
        email: widget.args.email,
        flow: widget.args.flow,
      );
      if (!mounted || !sent) return;
      _initialLinkPrepared = true;
    }

    await _viewModel.commands.waitForConfirmation(
      email: widget.args.email,
      flow: widget.args.flow,
    );
    if (!mounted || !_viewModel.state.confirmed.value) return;

    _redirectTimer?.cancel();
    _redirectTimer = Timer(_successFeedbackDuration, () {
      if (!mounted) return;
      _handleConfirmedRedirect();
    });
  }

  Future<void> _resendLink() async {
    final resent = await _viewModel.commands.resend(
      email: widget.args.email,
      flow: widget.args.flow,
    );
    if (!mounted || !resent) return;
    _initialLinkPrepared = true;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.checkEmailLinkResent)),
      );

    if (!_viewModel.state.loading.value) {
      unawaited(_startEmailConfirmation());
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _viewModel.commands.cancelMonitoring();
    _contentController.dispose();
    super.dispose();
  }

  String _confirmedTitle(BuildContext context) {
    return switch (widget.args.flow) {
      EmailVerificationFlow.register => context.l10n.emailConfirmedTitle,
      EmailVerificationFlow.forgotPassword => context.l10n.emailConfirmedTitle,
      EmailVerificationFlow.changeEmail =>
        context.l10n.accountEmailChangedTitle,
    };
  }

  String _confirmedSubtitle(BuildContext context) {
    return switch (widget.args.flow) {
      EmailVerificationFlow.register => context.l10n.accountConfirmedSubtitle,
      EmailVerificationFlow.forgotPassword =>
        context.l10n.emailConfirmedSubtitle,
      EmailVerificationFlow.changeEmail =>
        context.l10n.accountEmailChangedSubtitle,
    };
  }

  void _handleConfirmedRedirect() {
    switch (widget.args.flow) {
      case EmailVerificationFlow.register:
        context.goNamed(MapRouteNames.map);
        break;

      case EmailVerificationFlow.forgotPassword:
        final actionCode = _viewModel.state.actionCode.value;
        if (actionCode == null || actionCode.isEmpty) {
          _viewModel.state
            ..setConfirmation(value: false)
            ..showError('passwordResetInvalidLink');
          break;
        }
        context.pushReplacementNamed(
          AuthRouteNames.resetPassword,
          extra: PasswordResetArgs(
            email: widget.args.email,
            actionCode: actionCode,
          ),
        );
        break;

      case EmailVerificationFlow.changeEmail:
        context.pop(true);
        break;
    }
  }

  Future<void> _handlePop() async {
    if (widget.args.flow == EmailVerificationFlow.register &&
        !_viewModel.state.confirmed.value) {
      await _viewModel.commands.cancelRegistration(
        email: widget.args.email,
        flow: widget.args.flow,
      );
    }
    await _contentController.reverse();
    if (mounted) context.pop(false);
  }

  Widget _buildWaitingEmailContent(BuildContext context) {
    final isCompact = context.isVerySmallScreen;
    return Column(
      key: const ValueKey('waiting-email'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _iconScale,
          child: Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: context.colors.tertiary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.onTertiary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.vectorIcon,
                  height: 40,
                  colorFilter: ColorFilter.mode(
                    context.colors.onTertiary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.isVerySmallScreen ? 32 : 48),
        SlideTransition(
          position: _textSlide,
          child: FadeTransition(
            opacity: _textOpacity,
            child: Column(
              children: [
                Text(
                  context.l10n.checkEmailTitle,
                  textAlign: TextAlign.center,
                  style: context.text.headlineLarge?.copyWith(
                    color: context.colors.onTertiary,
                    fontSize: context.isVerySmallScreen ? 28 : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: context.colors.onTertiary.withValues(alpha: 0.7),
                        height: 1.5,
                        fontSize: isCompact
                            ? context.text.labelMedium?.fontSize
                            : context.text.labelLarge?.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: '${context.l10n.checkEmailSentTo}\n'),
                        TextSpan(
                          text: widget.args.email,
                          style: TextStyle(
                            color: context.colors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '\n\n${context.l10n.checkEmailDescription}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AuthErrorBanner(
                  error: _viewModel.state.errorMessage.readonly(),
                ),
                Watch((_) {
                  final hasError = _viewModel.state.errorMessage.value != null;
                  final isChecking = _viewModel.state.loading.value;
                  final isResending = _viewModel.state.resending.value;

                  return Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (hasError)
                        TextButton.icon(
                          onPressed:
                              isChecking ? null : _startEmailConfirmation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.l10n.commonRetry),
                        ),
                      TextButton(
                        onPressed: isResending ? null : _resendLink,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isResending
                              ? LoadingDots(
                                  key: const ValueKey('resending-email'),
                                  color: context.colors.secondary,
                                  size: 5,
                                  spacing: 2,
                                  rise: 3,
                                )
                              : Text(
                                  context.l10n.checkEmailResend,
                                  key: const ValueKey('resend-email-label'),
                                ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: context.colors.onError,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                child: Padding(
                  padding: context.extraPagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppBackButton(onPressed: _handlePop),
                      ),
                      Expanded(
                        child: Watch(
                          (_) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _viewModel.state.confirmed.value
                                ? EmailConfirmationFeedback(
                                    key: const ValueKey('email-confirmed'),
                                    title: _confirmedTitle(context),
                                    subtitle: _confirmedSubtitle(context),
                                  )
                                : _buildWaitingEmailContent(context),
                          ),
                        ),
                      ),
                    ],
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
