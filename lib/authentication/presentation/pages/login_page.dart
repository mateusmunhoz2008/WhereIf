import 'dart:async';
import 'dart:math' as math;
import 'package:autth_injustice_app/core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_viewmodel.dart';
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/auth_error_banner.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/check_email_args.dart';
import 'package:autth_injustice_app/core/utils/hide_keyboard.dart';
import 'package:autth_injustice_app/core/validation/email_validator.dart';
import 'package:autth_injustice_app/core/validation/password_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _imeFocusSession = 0;
  final _formKey = GlobalKey<FormState>();
  final _emailAnchor = GlobalKey();
  final _passwordAnchor = GlobalKey();
  double _emailLift = 0;
  double _passwordLift = 0;
  bool _visibilityCheckScheduled = false;
  bool _keyboardWasVisible = false;
  FocusNode? _editingField;
  int? _keyboardClosingSession;
  int? _keyboardReopeningSession;
  bool get _keyboardDismissalPending => _keyboardClosingSession != null;
  bool get _ignorePreviousKeyboardClose =>
      _keyboardReopeningSession == _imeFocusSession &&
      _keyboardClosingSession != null &&
      _keyboardClosingSession != _imeFocusSession;
  double _lastKeyboardHeight = 0;
  bool _keyboardIsFalling = false;
  Timer? _keyboardSettleTimer;
  int _keyboardCheckRevision = 0;
  bool _passwordVisible = false;
  Size? _restCanvasSize;
  EdgeInsets? _restCanvasInsets;
  double _reportedCanvasHeight = 0;
  late final LoginViewModel _viewModel;
  GoRouter? _router;
  bool _loginActive = true;
  bool _submitting = false;
  int _operationId = 0;

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
    _viewModel.commands.cancel();

    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _emailFocus.addListener(_onFieldFocusChanged);
    _passwordFocus.addListener(_onFieldFocusChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    const premiumCurve = Curves.easeOutQuint;

    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -.12), end: Offset.zero).animate(
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
        Tween<Offset>(begin: const Offset(0, -.16), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _formSlide =
        Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero).animate(
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

  void _unfocus() {
    FocusScope.of(context).unfocus();
  }

  void _onFieldTapped(FocusNode field) {
    // A tap on an already-focused input is also a new request to keep editing.
    // Invalidate a queued close even when FocusNode emits no change event.
    if (field.hasFocus) {
      if (_keyboardWasVisible &&
          (_keyboardIsFalling || _lastKeyboardHeight == 0)) {
        _keyboardClosingSession ??= _imeFocusSession;
      }
      _imeFocusSession++;
      if (_keyboardDismissalPending) {
        _keyboardReopeningSession = _imeFocusSession;
      }
      _keyboardSettleTimer?.cancel();
      _keyboardCheckRevision++;
      _scheduleFieldVisibility();
    }
  }

  void _confirmKeyboardState(double height) {
    _keyboardSettleTimer?.cancel();
    final revision = ++_keyboardCheckRevision;
    final session = _imeFocusSession;
    final focused = _editingField;
    // Insets can briefly jump to zero when Android cancels/reverses an IME
    // animation. Only accept a settled state owned by this editing session.
    _keyboardSettleTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted ||
          !_loginActive ||
          revision != _keyboardCheckRevision ||
          session != _imeFocusSession ||
          !identical(focused, _editingField) ||
          height != _lastKeyboardHeight) {
        return;
      }
      if (height > 0) {
        // Never let a late opening frame clear a hide while nothing is focused.
        if (focused != null && focused.hasFocus) {
          _keyboardClosingSession = null;
          _keyboardReopeningSession = null;
          _keyboardIsFalling = false;
        }
        return;
      }
      // Check raw Android insets too, not just a previous MediaQuery frame.
      if (View.of(context).viewInsets.bottom > 0) return;
      final wasVisible = _keyboardWasVisible;
      _keyboardWasVisible = false;
      final reopening = _ignorePreviousKeyboardClose;
      _keyboardClosingSession = null;
      _keyboardReopeningSession = null;
      if (focused == null || !focused.hasFocus) return;
      if (reopening) {
        unawaited(SystemChannels.textInput
            .invokeMethod<void>('TextInput.show')
            .catchError((Object _) {}));
      } else if (wasVisible) {
        _unfocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router?.routerDelegate.addListener(_onRouteChanged);
    }
    _scheduleFieldVisibility();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final active = _router!.routerDelegate.state.uri.path == AuthPaths.login;
    if (active == _loginActive) return;
    _loginActive = active;
    _resetLogin();
    if (active) _animController.forward();
    setState(() {});
  }

  void _resetLogin() {
    _operationId++;
    _submitting = false;
    _viewModel.commands.cancel();
    _keyboardSettleTimer?.cancel();
    _keyboardCheckRevision++;
    _keyboardClosingSession = null;
    _keyboardReopeningSession = null;
    _passwordVisible = false;
    _passCtrl.clear();
    _emailFocus.unfocus();
    _passwordFocus.unfocus();
    _animController.stop();
  }

  void _scheduleFieldVisibility() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) return;
      final canvasHeight =
          _restCanvasSize?.height ?? MediaQuery.sizeOf(context).height;
      final keyboard = math.max(MediaQuery.viewInsetsOf(context).bottom,
          math.max(0.0, canvasHeight - _reportedCanvasHeight));
      if (keyboard != _lastKeyboardHeight) {
        _keyboardIsFalling = keyboard < _lastKeyboardHeight;
      }
      if (keyboard > 0) {
        _keyboardWasVisible = true;
      }
      _lastKeyboardHeight = keyboard;
      _confirmKeyboardState(keyboard);
      final keyboardTop = canvasHeight - keyboard;
      double liftFor(GlobalKey anchor, FocusNode focus) {
        if (keyboard <= 0 || !focus.hasFocus) return 0;
        final box = anchor.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || box.size.height <= 0) return 0;
        // The anchor stays in its original place; only its input is translated.
        final top = box.localToGlobal(Offset.zero).dy;
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        if (bottom <= keyboardTop) return 0;
        final scale = (bottom - top) / box.size.height;
        return scale > 0 ? (bottom - keyboardTop + 12) / scale : 0;
      }

      final emailLift = liftFor(_emailAnchor, _emailFocus);
      final passwordLift = liftFor(_passwordAnchor, _passwordFocus);
      if ((_emailLift - emailLift).abs() < .01 &&
          (_passwordLift - passwordLift).abs() < .01) {
        return;
      }
      setState(() {
        _emailLift = emailLift;
        _passwordLift = passwordLift;
      });
    });
  }

  void _onFieldFocusChanged() {
    if (!mounted) return;
    final focused = _emailFocus.hasFocus
        ? _emailFocus
        : _passwordFocus.hasFocus
            ? _passwordFocus
            : null;
    if (focused != null && !identical(focused, _editingField)) {
      _imeFocusSession++;
    }
    _keyboardSettleTimer?.cancel();
    _keyboardCheckRevision++;
    if (focused == null && _editingField != null) {
      _keyboardClosingSession = _imeFocusSession;
      _keyboardReopeningSession = null;
    } else if (focused != null &&
        _editingField == null &&
        _keyboardDismissalPending) {
      _keyboardReopeningSession = _imeFocusSession;
    }
    _editingField = focused;
    setState(() {});
    _scheduleFieldVisibility();
  }

  Widget _stableCanvas(Widget child) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      _reportedCanvasHeight = constraints.maxHeight;
      final editing = _emailFocus.hasFocus ||
          _passwordFocus.hasFocus ||
          media.viewInsets.bottom > 0;
      if (_restCanvasSize == null ||
          !editing ||
          _restCanvasSize!.width != constraints.maxWidth) {
        _restCanvasSize = constraints.biggest;
        _restCanvasInsets = media.viewPadding;
      }
      final size = _restCanvasSize!;
      return OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: MediaQuery(
          data: media.copyWith(size: size, viewPadding: _restCanvasInsets),
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _loginActive = false;
    _operationId++;
    _keyboardSettleTimer?.cancel();
    _keyboardCheckRevision++;
    _viewModel.commands.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    await _runLogin(() async {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      if (email.isEmpty || password.isEmpty) {
        await _viewModel.state.showTemporaryError(context.l10n.fieldsRequired);
        return false;
      }
      final emailError = EmailValidator.validate(context, email);
      final passwordError = PasswordValidator.validate(context, password);
      if (emailError != null || passwordError != null) {
        await _viewModel.state.showTemporaryError(context.l10n.invalidFields);
        return false;
      }
      return _viewModel.commands.signIn(email: email, password: password);
    });
  }

  Future<void> _handleGoogleLogin() async {
    await _runLogin(_viewModel.commands.signInWithGoogle);
  }

  Future<void> _runLogin(Future<bool> Function() action) async {
    if (!_loginActive || _submitting || _viewModel.state.loading.value) return;
    final operation = ++_operationId;
    setState(() => _submitting = true);
    _unfocus();
    _viewModel.state.clearError();
    try {
      final success = await action();
      if (!mounted || !_loginActive || operation != _operationId || !success) {
        return;
      }
      await _finishLogin(operation);
    } finally {
      if (mounted && operation == _operationId) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _finishLogin(int operation) async {
    try {
      await _animController.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || !_loginActive || operation != _operationId) return;

    final returnTo = widget.returnTo;
    final destination = returnTo != null &&
            returnTo.startsWith('/') &&
            returnTo != AuthPaths.initial
        ? returnTo
        : MapPaths.map;
    context.go(destination);
  }

  Future<void> _handleForgotPassword() async {
    hideKeyboard();
    final email = _emailCtrl.text.trim();
    final error = EmailValidator.validate(context, email);
    if (error != null) {
      await _viewModel.state.showTemporaryError(error);
      return;
    }
    if (!mounted) return;
    _resetLogin();
    context.push(
      AuthPaths.checkEmail,
      extra: CheckEmailArgs(
        email: email,
        flow: EmailVerificationFlow.forgotPassword,
      ),
    );
  }

  Widget _field({required bool password, required bool compact}) {
    final dark = context.isDarkMode;
    final fill = dark ? const Color(0xFF202020) : const Color(0xFFEFEFEF);
    final foreground = dark ? Colors.white : Colors.black;
    final muted = dark ? const Color(0xFF929292) : const Color(0xFF666666);
    final hidden = password ? _emailFocus.hasFocus : _passwordFocus.hasFocus;
    final fadeDuration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 140);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    );
    return TweenAnimationBuilder<double>(
      key: password ? _passwordAnchor : _emailAnchor,
      tween:
          Tween<double>(begin: 0, end: password ? _passwordLift : _emailLift),
      duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220),
      curve: Curves.easeOutCubic,
      builder: (context, lift, child) => Transform.translate(
        offset: Offset(0, -lift),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: fadeDuration,
            child: ExcludeSemantics(
                excluding: hidden,
                child: Text(
                  key: ValueKey(
                      password ? 'login-password-label' : 'login-email-label'),
                  password ? context.l10n.password : context.l10n.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: dark
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF555555),
                    fontSize: 12,
                  ),
                )),
          ),
          SizedBox(height: compact ? 6 : 8),
          IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              key: ValueKey(password
                  ? 'login-password-visibility'
                  : 'login-email-visibility'),
              opacity: hidden ? 0 : 1,
              duration: fadeDuration,
              child: ExcludeSemantics(
                excluding: hidden,
                child: Semantics(
                  label: password ? context.l10n.password : context.l10n.email,
                  child: TextFormField(
                    key: ValueKey(password ? 'login-password' : 'login-email'),
                    controller: password ? _passCtrl : _emailCtrl,
                    focusNode: password ? _passwordFocus : _emailFocus,
                    onTapAlwaysCalled: true,
                    onTap: () =>
                        _onFieldTapped(password ? _passwordFocus : _emailFocus),
                    textAlign: TextAlign.center,
                    keyboardType: password
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    textInputAction:
                        password ? TextInputAction.done : TextInputAction.next,
                    autofillHints: password
                        ? const [AutofillHints.password]
                        : const [AutofillHints.username, AutofillHints.email],
                    obscureText: password && !_passwordVisible,
                    autocorrect: false,
                    enableSuggestions: !password,
                    scrollPadding: EdgeInsets.zero,
                    cursorColor: context.primary,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: foreground,
                      fontSize: 14,
                    ),
                    onFieldSubmitted: (_) {
                      if (password) {
                        _handleLogin();
                      } else {
                        _passwordFocus.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: password ? '••••••••' : 'exemplo@email.com',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: muted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: fill,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: compact ? 13 : 16,
                      ),
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide:
                            BorderSide(color: context.primary, width: 1.5),
                      ),
                      prefixIcon: password ? const SizedBox(width: 44) : null,
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 44, minHeight: 40),
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 44, minHeight: 40),
                      suffixIcon: password
                          ? IconButton(
                              tooltip: context.l10n.loginTogglePassword,
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: muted,
                                  size: 18),
                              onPressed: () {
                                setState(
                                    () => _passwordVisible = !_passwordVisible);
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final background = dark ? Colors.black : Colors.white;
    final foreground = dark ? Colors.white : Colors.black;
    final colors = Theme.of(context).colorScheme;
    final headerInk = dark ? Colors.white : const Color(0xFF17101F);
    final muted = dark ? const Color(0xFF929292) : const Color(0xFF666666);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _unfocus,
          child: _stableCanvas(LayoutBuilder(builder: (context, constraints) {
            final insets =
                _restCanvasInsets ?? MediaQuery.viewPaddingOf(context);
            final visibleHeight = constraints.maxHeight;
            final compact = visibleHeight < 650;
            final headerHeight = (visibleHeight * (compact ? .22 : .3)).clamp(
              compact ? 125.0 : 150.0,
              compact ? 180.0 : 260.0,
            );
            final bottom = insets.bottom + (compact ? 76 : 90);
            return Stack(children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight + 40,
                child: SlideTransition(
                  position: _sheetSlide,
                  child: ClipPath(
                    clipper: const _LoginHeaderClipper(),
                    child: DecoratedBox(
                      key: const ValueKey('login-header-gradient'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.secondary,
                            colors.primary,
                            Color.lerp(colors.primary, colors.secondary, .35)!,
                          ],
                          stops: const [0, .6, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: insets.top + 8,
                left: 26,
                right: 26,
                child: FadeTransition(
                  opacity: _headerOpacity,
                  child: Text(
                    'WhereIF',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: 'ArchivoBlack',
                      fontSize: 21,
                      color: headerInk,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: math.max(insets.top + 58, headerHeight * .46),
                left: 28,
                right: 28,
                child: SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerOpacity,
                    child: Text(
                      context.l10n.loginButton,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'ArchivoBlack',
                        fontSize: compact ? 34 : 42,
                        height: 1.05,
                        letterSpacing: -1.2,
                        color: headerInk,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: headerHeight + (compact ? 32 : 18),
                left: 0,
                right: 0,
                bottom: bottom,
                child: LayoutBuilder(builder: (context, formConstraints) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: FittedBox(
                        key: const ValueKey('login-adaptive-fit'),
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: math.max(1.0,
                              math.min(420.0, formConstraints.maxWidth - 56)),
                          child: SlideTransition(
                            position: _formSlide,
                            child: FadeTransition(
                              opacity: _formOpacity,
                              child: AutofillGroup(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _field(password: false, compact: compact),
                                      SizedBox(height: compact ? 12 : 24),
                                      _field(password: true, compact: compact),
                                      AuthErrorBanner(
                                          error: _viewModel.state.errorMessage),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: muted,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            minimumSize: const Size(48, 32),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11),
                                          ),
                                          onPressed: _handleForgotPassword,
                                          child: Text(context.l10n.forgot),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 8 : 24),
                                      Watch((context) {
                                        final loading =
                                            _viewModel.state.loading.value;
                                        return DecoratedBox(
                                          key: const ValueKey(
                                              'login-gradient-button'),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                context.primary,
                                                context.secondary
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(1.5),
                                            child: AppActionButton(
                                              text: context.l10n.loginButton,
                                              color: background,
                                              foregroundColor: foreground,
                                              icon: Icons.login_rounded,
                                              height: compact ? 44 : 50,
                                              isLoading: loading,
                                              onPressed: loading || _submitting
                                                  ? null
                                                  : _handleLogin,
                                            ),
                                          ),
                                        );
                                      }),
                                      SizedBox(height: compact ? 16 : 46),
                                      Text(
                                        'or',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 12 : 20),
                                      Watch((context) {
                                        final loading =
                                            _viewModel.state.loading.value;
                                        return Row(children: [
                                          SizedBox(
                                            width: compact ? 48 : 52,
                                            height: compact ? 48 : 52,
                                            child: Semantics(
                                              button: true,
                                              label: context.l10n.googleButton,
                                              enabled: !loading,
                                              child: Tooltip(
                                                message:
                                                    context.l10n.googleButton,
                                                child: Material(
                                                  color: dark
                                                      ? const Color(0xFF202020)
                                                      : const Color(0xFFEFEFEF),
                                                  shape: const CircleBorder(),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: InkWell(
                                                    key: const ValueKey(
                                                        'login-google'),
                                                    onTap: loading ||
                                                            _submitting
                                                        ? null
                                                        : _handleGoogleLogin,
                                                    child: Center(
                                                      child: SvgPicture.asset(
                                                        AppAssets.googleIcon,
                                                        width: 23,
                                                        height: 23,
                                                        excludeFromSemantics:
                                                            true,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: AppActionButton(
                                              key: const ValueKey(
                                                  'login-create-account'),
                                              text: context
                                                  .l10n.loginCreateAccount,
                                              color: foreground,
                                              foregroundColor: background,
                                              height: compact ? 48 : 52,
                                              onPressed: loading
                                                  ? null
                                                  : () {
                                                      hideKeyboard();
                                                      _resetLogin();
                                                      context.push(
                                                          AuthPaths.register);
                                                    },
                                            ),
                                          ),
                                        ]);
                                      }),
                                      SizedBox(height: compact ? 4 : 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ]);
          })),
        ),
      ),
    );
  }
}

class _LoginHeaderClipper extends CustomClipper<Path> {
  const _LoginHeaderClipper();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height * .76)
    ..cubicTo(size.width * .28, size.height * .76, size.width * .34,
        size.height * .9, size.width * .55, size.height * .9)
    ..cubicTo(size.width * .76, size.height * .9, size.width * .84,
        size.height * .68, size.width, size.height * .68)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_LoginHeaderClipper oldClipper) => false;
}
