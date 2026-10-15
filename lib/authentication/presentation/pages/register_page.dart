import 'dart:async';
import 'dart:ui';

import 'package:autth_injustice_app/authentication/presentation/viewmodels/register/register_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/auth_error_banner.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/forms/password_strength_indicator.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/forms/auth_text_field.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/check_email_args.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/validation/account_name_validator.dart';
import 'package:autth_injustice_app/core/validation/email_validator.dart';
import 'package:autth_injustice_app/core/validation/password_validator.dart';
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/core/widgets/animations/app_step_entrance_transition.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/institution/presentation/widgets/institution_image.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _pageController = PageController();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _surnameFocus = FocusNode();
  final _passFocus = FocusNode();

  late final _stepFocusNodes = [_emailFocus, _nameFocus, _passFocus];
  int _currentPage = 0;
  bool _isProcessingNext = false;

  late final RegisterViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = injector.get<RegisterViewModel>();
    _viewModel.state.reset();

    _passCtrl.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _nameFocus.dispose();
    _surnameFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _focusStep(int index) {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_stepFocusNodes[index]);
  }

  Future<void> _nextStep() async {
    if (_isProcessingNext || _viewModel.state.loading.value) return;

    final step = _currentPage;
    final error = switch (step) {
      0 => EmailValidator.validate(context, _emailCtrl.text),
      1 => AccountNameValidator.validate(
          context,
          firstName: _nameCtrl.text,
          lastName: _surnameCtrl.text,
        ),
      2 => PasswordValidator.validate(context, _passCtrl.text),
      _ => null,
    };

    if (error != null) {
      unawaited(_viewModel.state.showTemporaryError(error));
      return;
    }

    _setProcessingNext(true);

    try {
      if (step < 2) {
        FocusScope.of(context).unfocus();

        await _pageController.nextPage(
          duration: AppStepTransitionSpec.pageDuration,
          curve: AppStepTransitionSpec.pageCurve,
        );

        return;
      }

      if (step == 2) {
        final registered = await _viewModel.commands.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          firstName: _nameCtrl.text,
          lastName: _surnameCtrl.text,
        );

        if (!mounted || !registered) return;

        _viewModel.state.setSuccess(false);
        await context.pushNamed(
          AuthRouteNames.checkEmail,
          extra: CheckEmailArgs(
            email: _emailCtrl.text.trim(),
            flow: EmailVerificationFlow.register,
          ),
        );
        return;
      }
    } finally {
      _setProcessingNext(false);
    }
  }

  void _setProcessingNext(bool value) {
    if (_isProcessingNext == value) return;

    if (!mounted) {
      _isProcessingNext = value;
      return;
    }

    setState(() => _isProcessingNext = value);
  }

  Future<void> _previousStep() async {
    FocusScope.of(context).unfocus();

    if (_pageController.page?.round() == 0) {
      context.pop();
      return;
    }

    _viewModel.state.clearError();
    await _pageController.previousPage(
      duration: AppStepTransitionSpec.pageDuration,
      curve: AppStepTransitionSpec.pageCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: context.colors.onError,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });

          switch (index) {
            case 0:
              _emailFocus.requestFocus();
              break;
            case 1:
              _nameFocus.requestFocus();
              break;
            case 2:
              _passFocus.requestFocus();
              break;
          }
        },
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SignupStepGeneric(
            viewModel: _viewModel,
            isProcessing: _isProcessingNext,
            active: _currentPage == 0,
            onBack: _previousStep,
            title: Text(
              '${context.l10n.whatYour}\n${context.l10n.email}',
              textAlign: TextAlign.start,
              style: context.text.headlineLarge?.copyWith(
                color: context.colors.onTertiary,
                fontSize: context.isVerySmallScreen ? 28 : null,
              ),
            ),
            label: context.l10n.email,
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            buttonText: context.l10n.continueButton,
            textInputAction: TextInputAction.next,
            onNext: _nextStep,
          ),
          SignupStepGeneric(
            viewModel: _viewModel,
            isProcessing: _isProcessingNext,
            active: _currentPage == 1,
            onBack: _previousStep,
            title: Text(
              context.l10n.registerNameTitle,
              textAlign: TextAlign.start,
              style: context.text.headlineLarge?.copyWith(
                color: context.colors.onTertiary,
                fontSize: context.isVerySmallScreen ? 28 : null,
              ),
            ),
            label: context.l10n.firstName,
            controller: _nameCtrl,
            focusNode: _nameFocus,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            secondaryLabel: context.l10n.lastName,
            secondaryController: _surnameCtrl,
            secondaryFocusNode: _surnameFocus,
            secondaryKeyboardType: TextInputType.name,
            secondaryTextCapitalization: TextCapitalization.words,
            secondaryAutofillHints: const [AutofillHints.familyName],
            buttonText: context.l10n.continueButton,
            textInputAction: TextInputAction.next,
            secondaryTextInputAction: TextInputAction.done,
            onNext: _nextStep,
          ),
          SignupStepGeneric(
            viewModel: _viewModel,
            isProcessing: _isProcessingNext,
            active: _currentPage == 2,
            onBack: _previousStep,
            title: Text(
              '${context.l10n.createPassword}\n${context.l10n.password}',
              textAlign: TextAlign.start,
              style: context.text.headlineLarge?.copyWith(
                color: context.colors.onTertiary,
                fontSize: context.isVerySmallScreen ? 28 : null,
              ),
            ),
            label: context.l10n.password,
            controller: _passCtrl,
            focusNode: _passFocus,
            obscureText: true,
            showPasswordStrength: true,
            buttonText: context.l10n.continueButton,
            textInputAction: TextInputAction.done,
            onNext: _nextStep,
          ),
        ],
      ),
    );
  }
}

class SignupStepGeneric extends StatefulWidget {
  final bool active;
  final bool isProcessing;
  final Widget title;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final String? secondaryLabel;
  final TextEditingController? secondaryController;
  final FocusNode? secondaryFocusNode;
  final TextInputType secondaryKeyboardType;
  final TextInputAction secondaryTextInputAction;
  final TextCapitalization secondaryTextCapitalization;
  final Iterable<String>? secondaryAutofillHints;
  final bool obscureText;
  final String buttonText;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool showPasswordStrength;
  final RegisterViewModel viewModel;

  const SignupStepGeneric({
    super.key,
    required this.active,
    required this.isProcessing,
    required this.title,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onNext,
    required this.onBack,
    required this.viewModel,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.secondaryLabel,
    this.secondaryController,
    this.secondaryFocusNode,
    this.secondaryKeyboardType = TextInputType.text,
    this.secondaryTextInputAction = TextInputAction.done,
    this.secondaryTextCapitalization = TextCapitalization.none,
    this.secondaryAutofillHints,
    this.obscureText = false,
    this.buttonText = 'Continue',
    this.showPasswordStrength = false,
  });

  @override
  State<SignupStepGeneric> createState() => _SignupStepGenericState();
}

class _SignupStepGenericState extends State<SignupStepGeneric> {
  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            bottom: -150,
            child: Transform.rotate(
              angle: -0.8,
              child: InstitutionImage(
                resource: context.isDarkMode
                    ? context.institution.branding.logoOnDarkBackground
                    : context.institution.branding.logoOnLightBackground,
                width: context.screenSize.width, // Usa 100% da tela natural
                fit: BoxFit.contain,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: context.extraPagePadding.copyWith(bottom: 0, top: 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBackButton(onPressed: widget.onBack),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: context.extraPagePadding.copyWith(
                      bottom: keyboardHeight +
                          80, // Mantém a rolagem segura do teclado
                      top: context.headerTopSpacing,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppStepEntranceTransition(
                          active: widget.active,
                          child: widget.title,
                        ),
                        SizedBox(height: context.formTopSpacing),
                        AppStepEntranceTransition(
                          active: widget.active,
                          child: AuthTextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            hintText: widget.label,
                            keyboardType: widget.keyboardType,
                            isPassword: widget.obscureText,
                            textInputAction: widget.textInputAction,
                            textCapitalization: widget.textCapitalization,
                            autofillHints: widget.autofillHints,
                            onFieldSubmitted: (_) {
                              final secondaryFocus = widget.secondaryFocusNode;
                              if (secondaryFocus != null) {
                                secondaryFocus.requestFocus();
                                return;
                              }
                              widget.onNext();
                            },
                          ),
                        ),
                        if (widget.secondaryController != null &&
                            widget.secondaryFocusNode != null &&
                            widget.secondaryLabel != null) ...[
                          const SizedBox(height: 14),
                          AppStepEntranceTransition(
                            active: widget.active,
                            child: AuthTextField(
                              controller: widget.secondaryController,
                              focusNode: widget.secondaryFocusNode,
                              hintText: widget.secondaryLabel!,
                              keyboardType: widget.secondaryKeyboardType,
                              textInputAction: widget.secondaryTextInputAction,
                              textCapitalization:
                                  widget.secondaryTextCapitalization,
                              autofillHints: widget.secondaryAutofillHints,
                              onFieldSubmitted: (_) => widget.onNext(),
                            ),
                          ),
                        ],
                        AuthErrorBanner(
                          error: widget.viewModel.state.errorMessage.readonly(),
                        ),
                        if (widget.obscureText) ...[
                          const SizedBox(height: 25),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.colors.onError.withValues(
                                    alpha: 0.45,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: PasswordStrengthIndicator(
                                  controller: widget.controller,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              maintainBottomViewPadding: true,
              child: Padding(
                padding: context.extraPagePadding.copyWith(
                  top: 16,
                  bottom: context.isVerySmallScreen ? 16 : 16,
                ),
                child: AppStepEntranceTransition(
                  active: widget.active,
                  motion: AppStepEntranceMotion.action,
                  child: Watch(
                    (context) {
                      final isLoading = widget.isProcessing ||
                          widget.viewModel.state.loading.value;

                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: AppActionButton(
                          text: widget.buttonText,
                          color: context.tertiary.withValues(alpha: 0.95),
                          foregroundColor: context.onTertiary,
                          isLoading: isLoading,
                          onPressed: isLoading ? null : widget.onNext,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
