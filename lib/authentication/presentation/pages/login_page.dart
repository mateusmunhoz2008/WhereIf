import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/backgrounds/clouds.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/buttons/google_button.dart';
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/auth_error_banner.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/buttons/auth_text_button.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/forms/auth_text_field.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/check_email_args.dart';
import 'package:autth_injustice_app/core/utils/hide_keyboard.dart';
import 'package:autth_injustice_app/core/validation/email_validator.dart';
import 'package:autth_injustice_app/core/validation/password_validator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  final String? returnTo;

  const LoginPage({
    super.key,
    this.returnTo,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final LoginViewModel _viewModel;

  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;

  late final AnimationController _animController;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerOpacity;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _formOpacity;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();

    _viewModel = injector.get<LoginViewModel>();

    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    const premiumCurve = Curves.easeOutQuint;

    _headerSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _sheetSlide =
        Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _formSlide =
        Tween<Offset>(begin: const Offset(0.25, 0.0), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.3, 0.8, curve: premiumCurve)),
    );

    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.3, 0.8, curve: Curves.easeIn)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_viewModel.state.loading.value) return;

    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      await _viewModel.state.showTemporaryError(context.l10n.fieldsRequired);
      return;
    }

    final emailError = EmailValidator.validate(context, email);
    final passwordError = PasswordValidator.validate(context, password);

    if (emailError != null || passwordError != null) {
      await _viewModel.state.showTemporaryError(context.l10n.invalidFields);
      return;
    }

    final didSignIn = await _viewModel.commands.signIn(
      email: email,
      password: password,
    );

    if (!didSignIn) return;

    await _finishLogin();
  }

  Future<void> _handleGoogleLogin() async {
    if (_viewModel.state.loading.value) return;

    hideKeyboard();
    final didSignIn = await _viewModel.commands.signInWithGoogle();
    if (!didSignIn) return;

    await _finishLogin();
  }

  Future<void> _finishLogin() async {
    try {
      await injector.get<IAppEntryRepository>().markInitialPageCompleted();
    } catch (_) {
      // Authentication remains valid even if this local preference fails.
    }

    await _animController.reverse();
    if (!mounted) return;

    final returnTo = widget.returnTo;
    final destination = returnTo != null &&
            returnTo.startsWith('/') &&
            returnTo != AuthPaths.initial
        ? returnTo
        : MapPaths.map;
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isVerySmall = context.isVerySmallScreen;
    final useCompactLayout =
        responsive.heightClass.index <= AppHeightClass.compact.index ||
            responsive.isVeryCompact;
    final sheetTopRatio = switch (responsive.heightClass) {
      AppHeightClass.veryShort => 0.15,
      AppHeightClass.short => 0.19,
      AppHeightClass.compact => 0.24,
      _ => context.authSheetTopRatio,
    };
    final double gapFields =
        responsive.scaled(useCompactLayout ? 8 : 16, min: 7, max: 16);
    final double gapSmall =
        responsive.scaled(useCompactLayout ? 6 : 12, min: 5, max: 12);
    final double actionGap = responsive.scaled(
      useCompactLayout ? 24 : 42,
      min: 20,
      max: 46,
    );
    final formTopPadding =
        responsive.scaled(useCompactLayout ? 25 : 18, min: 14, max: 30);
    final shellIsCompact = isVerySmall || context.screenSize.width < 360;
    final shellBottomClearance = shellIsCompact ? 82.0 : 99.0;
    final headerTopSpacing = isVerySmall
        ? responsive.scaled(8, min: 6, max: 10)
        : context.headerTopSpacing;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: context.initialPageGradient,
          ),
          child: Stack(
            children: [
              const CloudBackground(),

              // HEADER
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: context.extraPagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: headerTopSpacing),
                        SlideTransition(
                          position: _headerSlide,
                          child: FadeTransition(
                            opacity: _headerOpacity,
                            child: Text(
                              '${context.l10n.joinThe}\n${context.l10n.team}',
                              textAlign: TextAlign.start,
                              style: context.text.headlineLarge?.copyWith(
                                color: context.colors.onPrimary,
                                fontSize: responsive.scaled(
                                  36,
                                  min: useCompactLayout ? 25 : 27,
                                  max: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // BOTTOM SHEET
              Positioned(
                top: context.screenSize.height * sheetTopRatio,
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _sheetSlide,
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.tertiary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.onSecondary
                                .withValues(alpha: 0.18),
                            blurRadius: 50,
                            offset: const Offset(0, -5),
                          )
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: context.extraPagePadding.copyWith(
                            top: formTopPadding,
                            bottom: shellBottomClearance,
                          ),
                          child: SlideTransition(
                            position: _formSlide,
                            child: FadeTransition(
                              opacity: _formOpacity,
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AuthTextField(
                                      controller: _emailCtrl,
                                      focusNode: _emailFocus,
                                      hintText: context.l10n.email,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) {
                                        _passwordFocus.requestFocus();
                                      },
                                    ),
                                    SizedBox(height: gapFields),
                                    AuthTextField(
                                      controller: _passCtrl,
                                      focusNode: _passwordFocus,
                                      hintText: context.l10n.password,
                                      isPassword: true,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                    ),
                                    AuthErrorBanner(
                                      error: _viewModel.state.errorMessage,
                                    ),
                                    SizedBox(height: gapSmall),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: AuthTextButton(
                                          style: context.text.bodyMedium,
                                          text: context.l10n.forgot,
                                          color: const Color(0xFF757575),
                                          onTap: () async {
                                            hideKeyboard();

                                            final email =
                                                _emailCtrl.text.trim();
                                            final error =
                                                EmailValidator.validate(
                                                    context, email);

                                            if (error != null) {
                                              await _viewModel.state
                                                  .showTemporaryError(error);
                                              return;
                                            }

                                            if (!mounted) return;

                                            context.push(
                                              AuthPaths.checkEmail,
                                              extra: CheckEmailArgs(
                                                email: email,
                                                flow: EmailVerificationFlow
                                                    .forgotPassword,
                                              ),
                                            );
                                          }),
                                    ),
                                    SizedBox(height: actionGap),
                                    Watch((context) {
                                      final isLoading =
                                          _viewModel.state.loading.value;
                                      return AppActionButton(
                                        text: context.l10n.loginButton,
                                        color: context.onTertiary
                                            .withValues(alpha: 0.08),
                                        foregroundColor: context.onTertiary,
                                        height: useCompactLayout ? 46 : 56,
                                        isLoading: isLoading,
                                        onPressed:
                                            isLoading ? null : _handleLogin,
                                      );
                                    }),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(height: gapSmall),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: AuthTextButtonRich(
                                              style: context.text.bodyMedium,
                                              baseText:
                                                  context.l10n.dontHaveAccount,
                                              actionText:
                                                  context.l10n.signupButton,
                                              actionColor:
                                                  context.colors.secondary,
                                              onTap: () {
                                                hideKeyboard();
                                                context.push(
                                                  AuthPaths.register,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: responsive.scaled(
                                            useCompactLayout ? 10 : 18,
                                            min: 8,
                                            max: 18,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Divider(
                                                color: Color(0xFF424242),
                                                thickness: 1,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    useCompactLayout ? 10 : 16,
                                              ),
                                              child: Text(
                                                context.l10n.or,
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: context
                                                      .text.bodySmall?.fontSize,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: Colors.grey.shade800,
                                                thickness: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: responsive.scaled(
                                            useCompactLayout ? 9 : 15,
                                            min: 8,
                                            max: 15,
                                          ),
                                        ),
                                        GoogleSignInButton(
                                          compact: useCompactLayout,
                                          onTap: _handleGoogleLogin,
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
