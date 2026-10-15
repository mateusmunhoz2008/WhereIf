import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/account/domain/services/i_current_account_provider.dart';
import 'package:autth_injustice_app/app_shell/presentation/pages/app_shell_page.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/login_page.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_viewmodel.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:autth_injustice_app/core/widgets/loading_dots.dart';
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';

void main() {
  setUp(() => injector.dispose());
  testWidgets('login input emits no temporary IME logs or credentials',
      (tester) async {
    await _mountLogin(tester);
    final lines = <String>[];
    for (final name in ['email', 'password']) {
      final input = tester.widget<TextField>(find.descendant(
          of: find.byKey(ValueKey('login-$name')),
          matching: find.byType(TextField)));
      runZoned(() {
        input.onTap!();
        input.onChanged?.call('private-$name-do-not-log');
      },
          zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => lines.add(line)));
    }
    expect(lines.where((line) => line.contains('[LOGIN_IME]')), isEmpty);
    expect(lines.join('\n'), isNot(contains('private-')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving an active login cancels and ignores its late result',
      (tester) async {
    final facade = _PendingLoginFacade();
    final model = await _mountLogin(tester, routed: true, facade: facade);
    await tester.enterText(
        find.byKey(const ValueKey('login-email')), 'estudante@email.com');
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), 'Senha123!');
    await tester.tap(find.byKey(const ValueKey('login-gradient-button')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(model.state.loading.value, isTrue);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('login-gradient-button')));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(facade.calls, 1);
    final router = GoRouter.of(tester.element(find.byType(LoginPage)));
    router.push('/register');
    await tester.pumpAndSettle();
    expect(model.state.loading.value, isFalse);
    facade.response.complete(Error(InvalidInputFailure('invalidFields')));
    await tester.pump();
    expect(model.state.errorMessage.value, isNull);
    router.pop();
    await tester.pumpAndSettle();
    final password = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(TextField)));
    expect(password.controller!.text, isEmpty);
    expect(password.obscureText, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('validation blocks repeated taps and clears on leaving login',
      (tester) async {
    final model = await _mountLogin(tester, routed: true);
    final login = find.byKey(const ValueKey('login-gradient-button'));
    await tester.tap(login);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    final action = tester.widget<AppActionButton>(
        find.descendant(of: login, matching: find.byType(AppActionButton)));
    expect(action.onPressed, isNull);
    expect(model.state.errorMessage.value, isNotNull);
    final router = GoRouter.of(tester.element(find.byType(LoginPage)));
    router.push('/register');
    await tester.pumpAndSettle();
    expect(model.state.errorMessage.value, isNull);
    expect(model.state.loading.value, isFalse);
    router.pop();
    await tester.pumpAndSettle();
    final returned = tester.widget<AppActionButton>(
        find.descendant(of: login, matching: find.byType(AppActionButton)));
    expect(returned.onPressed, isNotNull);
    expect(model.state.errorMessage.value, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 568),
      const Size(412, 892),
      const Size(720, 360)
    ]) {
      testWidgets('new login fits $size dark=$dark', (tester) async {
        await _mountLogin(tester, size: size, dark: dark);
        expect(find.text('WhereIF'), findsOneWidget);
        expect(find.text('exemplo@email.com'), findsOneWidget);
        expect(find.text('or'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(
            find.byKey(const ValueKey('login-adaptive-fit')), findsOneWidget);
        expect(find.byKey(const ValueKey('login-google')), findsOneWidget);
        expect(
            find.byKey(const ValueKey('login-create-account')), findsOneWidget);
        final email = tester.widget<TextField>(find.descendant(
            of: find.byKey(const ValueKey('login-email')),
            matching: find.byType(TextField)));
        expect(email.decoration?.hintText, 'exemplo@email.com');
        expect(email.textAlign, TextAlign.center);
        expect(email.style?.color, dark ? Colors.white : Colors.black);
        expect(email.decoration?.fillColor,
            dark ? const Color(0xFF202020) : const Color(0xFFEFEFEF));
        final create = tester.widget<AppActionButton>(
            find.byKey(const ValueKey('login-create-account')));
        expect(create.color, dark ? Colors.white : Colors.black);
        expect(create.foregroundColor, dark ? Colors.black : Colors.white);
        final scaffold = tester.widget<Scaffold>(find.descendant(
            of: find.byType(LoginPage), matching: find.byType(Scaffold)));
        expect(scaffold.backgroundColor, dark ? Colors.black : Colors.white);
        final header = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('login-header-gradient')));
        final gradient =
            (header.decoration as BoxDecoration).gradient! as LinearGradient;
        final scheme =
            Theme.of(tester.element(find.byType(LoginPage))).colorScheme;
        expect(gradient.colors, [
          scheme.secondary,
          scheme.primary,
          Color.lerp(scheme.primary, scheme.secondary, .35),
        ]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('password visibility and loading dots remain available',
      (tester) async {
    final model = await _mountLogin(tester);
    final password = find.byKey(const ValueKey('login-password'));
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)))
            .obscureText,
        isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)))
            .obscureText,
        isFalse);
    model.state.setLoading(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(LoadingDots), findsOneWidget);
    final create = tester.widget<AppActionButton>(
        find.byKey(const ValueKey('login-create-account')));
    expect(create.onPressed, isNull);
    expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('login-google')))
            .onTap,
        isNull);
    model.state.setLoading(false);
    await tester.pumpAndSettle();
    expect(find.byType(LoadingDots), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible focused input and layout do not move with keyboard',
      (tester) async {
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await _mountLogin(tester);
    final email = find.byKey(const ValueKey('login-email'));
    await tester.tap(email);
    await tester.pumpAndSettle();
    final fixed = [
      email,
      find.byKey(const ValueKey('login-password')),
      find.text('WhereIF'),
      find.text('Entrar').first,
      find.byKey(const ValueKey('login-gradient-button')),
      find.byKey(const ValueKey('login-create-account'))
    ];
    final before = fixed.map(tester.getRect).toList();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    for (var i = 0; i < fixed.length; i++) {
      expect(tester.getRect(fixed[i]), before[i]);
    }
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('repeated focus never changes the form scale on a small screen',
      (tester) async {
    await _mountLogin(tester, size: const Size(320, 568));
    final email = find.byKey(const ValueKey('login-email'));
    final password = find.byKey(const ValueKey('login-password'));
    final create = find.byKey(const ValueKey('login-create-account'));
    final sizes = [
      tester.getSize(email),
      tester.getSize(password),
      tester.getSize(create)
    ];
    for (var repeat = 0; repeat < 3; repeat++) {
      for (final field in [email, password]) {
        tester
            .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)))
            .focusNode!
            .requestFocus();
        await tester.pumpAndSettle();
        expect(tester.getSize(email), sizes[0]);
        expect(tester.getSize(password), sizes[1]);
        expect(tester.getSize(create), sizes[2]);
      }
    }
  });

  testWidgets('other input fades without collapsing and Next switches inputs',
      (tester) async {
    await _mountLogin(tester, size: const Size(320, 568));
    final email = find.byKey(const ValueKey('login-email'));
    final password = find.byKey(const ValueKey('login-password'));
    final originalPassword = tester.getRect(password);
    final originalEmail = tester.getRect(email);
    await tester.enterText(email, 'estudante@email.com');
    await tester.pumpAndSettle();
    double opacity(String field) => tester
        .widget<AnimatedOpacity>(
            find.byKey(ValueKey('login-$field-visibility')))
        .opacity;
    expect(opacity('email'), 1);
    expect(opacity('password'), 0);
    expect(tester.getRect(password), originalPassword);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(opacity('email'), 0);
    expect(opacity('password'), 1);
    expect(tester.getRect(email), originalEmail);
    await tester.tap(find.text('WhereIF'));
    await tester.pumpAndSettle();
    expect(opacity('email'), 1);
    expect(opacity('password'), 1);
    final input = tester.widget<TextField>(
        find.descendant(of: email, matching: find.byType(TextField)));
    expect(input.controller!.text, 'estudante@email.com');
  });

  testWidgets(
      'Android viewport resize and keyboard heights cannot shrink canvas',
      (tester) async {
    await _mountLogin(tester, size: const Size(320, 568));
    final password = find.byKey(const ValueKey('login-password'));
    await tester.tap(password);
    await tester.pumpAndSettle();
    final passwordSize = tester.getSize(password);
    final fixed = [
      find.byKey(const ValueKey('login-email')),
      find.text('WhereIF'),
      find.text('Entrar').first,
      find.byKey(const ValueKey('login-gradient-button')),
      find.byKey(const ValueKey('login-create-account'))
    ];
    final before = fixed.map(tester.getRect).toList();
    addTearDown(tester.view.resetViewInsets);
    for (final keyboard in [280.0, 220.0, 300.0, 180.0]) {
      tester.view.physicalSize = Size(320, 568 - keyboard);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      expect(tester.getSize(password), passwordSize);
      for (var i = 0; i < fixed.length; i++) {
        expect(tester.getRect(fixed[i]), before[i]);
      }
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getSize(password), passwordSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'closing keyboard deselects inputs and restores both automatically',
      (tester) async {
    await _mountLogin(tester);
    final email = find.byKey(const ValueKey('login-email'));
    final password = find.byKey(const ValueKey('login-password'));
    final fields = [email, password];
    final sizes = fields.map(tester.getSize).toList();
    addTearDown(tester.view.resetViewInsets);
    for (final field in fields) {
      final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      input.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      // A different keyboard height is not a dismissal.
      expect(input.focusNode!.hasFocus, isTrue);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
      for (var index = 0; index < fields.length; index++) {
        final name = index == 0 ? 'email' : 'password';
        expect(
            tester
                .widget<AnimatedOpacity>(
                    find.byKey(ValueKey('login-$name-visibility')))
                .opacity,
            1);
        expect(tester.getSize(fields[index]), sizes[index]);
      }
    }
    expect(tester.takeException(), isNull);
  });

  for (final name in ['email', 'password']) {
    for (final transientZero in [true, false]) {
      testWidgets(
          'replays Android late opening and old close: $name '
          'transientZero=$transientZero', (tester) async {
        await _mountLogin(tester);
        addTearDown(tester.view.resetViewInsets);
        final field = find.byKey(ValueKey('login-$name'));
        final input = tester.widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)));
        await tester.tap(field);
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 13.12);
        await tester.pump();
        await tester.tap(find.text('WhereIF'));
        await tester.pump(const Duration(milliseconds: 20));
        expect(input.focusNode!.hasFocus, isFalse);
        // The cancelled opening arrives late while the input is unfocused.
        tester.view.viewInsets = const FakeViewPadding(bottom: 403.52);
        await tester.pump();
        // No arbitrary 600 ms timeout may erase the ownership of this hide.
        await tester.pump(const Duration(milliseconds: 700));
        tester.view.viewInsets = const FakeViewPadding(bottom: 138.88);
        await tester.pump();
        await tester.tap(field);
        await tester.pump(const Duration(milliseconds: 20));
        expect(input.focusNode!.hasFocus, isTrue);
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 14));
        expect(input.focusNode!.hasFocus, isTrue);
        if (transientZero) {
          // This is the 0 -> 403.52 jump in the supplied real-device log.
          tester.view.viewInsets = const FakeViewPadding(bottom: 403.52);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(input.focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(field, 'still-editable');
        expect(input.controller!.text, 'still-editable');
        // Once the new keyboard really opens, Back must dismiss normally.
        tester.view.viewInsets = const FakeViewPadding(bottom: 403.52);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();
        expect(input.focusNode!.hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('retapping a focused input invalidates a queued Back dismissal',
      (tester) async {
    await _mountLogin(tester);
    addTearDown(tester.view.resetViewInsets);
    for (final name in ['email', 'password']) {
      final field = find.byKey(ValueKey('login-$name'));
      final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      await tester.tap(field);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // Android Back doesn't initially unfocus: this tap emits no focus change.
      await tester.tap(field);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid reentry ignores the previous keyboard dismissal',
      (tester) async {
    await _mountLogin(tester);
    addTearDown(tester.view.resetViewInsets);
    for (final name in ['email', 'password']) {
      final field = find.byKey(ValueKey('login-$name'));
      final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)));
      await tester.tap(field);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhereIF'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(input.focusNode!.hasFocus, isFalse);
      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 20));
      expect(input.focusNode!.hasFocus, isTrue);
      // The old Android hide completes after the second tap.
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      // An intentional dismissal of this new session must still work.
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the covered focused field slides up without resizing',
      (tester) async {
    await _mountLogin(tester);
    final password = find.byKey(const ValueKey('login-password'));
    await tester.tap(password);
    await tester.pumpAndSettle();
    final original = tester.getRect(password);
    final label = find.byKey(const ValueKey('login-password-label'));
    final originalLabel = tester.getRect(label);
    final fixed = [
      find.byKey(const ValueKey('login-email')),
      find.text('WhereIF'),
      find.text('Entrar').first,
      find.byKey(const ValueKey('login-gradient-button')),
      find.byKey(const ValueKey('login-create-account'))
    ];
    final before = fixed.map(tester.getRect).toList();
    // Lift beyond the input's original bounds, as a real tall keyboard does.
    final keyboardTop = original.top - 80;
    tester.view.viewInsets = FakeViewPadding(bottom: 892 - keyboardTop);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final during = tester.getRect(password);
    expect(tester.getRect(label).top - originalLabel.top,
        closeTo(during.top - original.top, .01));
    expect(during.top, lessThan(original.top));
    await tester.pumpAndSettle();
    final lifted = tester.getRect(password);
    expect(tester.getRect(label).top - originalLabel.top,
        closeTo(lifted.top - original.top, .01));
    expect(lifted.bottom, closeTo(keyboardTop - 12, .01));
    expect(lifted.size, original.size);
    expect(during.top, greaterThan(lifted.top));
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: password, matching: find.byType(TextField)))
            .obscureText,
        isFalse);
    for (var i = 0; i < fixed.length; i++) {
      expect(tester.getRect(fixed[i]), before[i]);
    }
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(password), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional login preview with real fonts', (tester) async {
    if (Platform.environment['LOGIN_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      for (final family in ['ArchivoBlack', 'Inter']) {
        final loader = FontLoader(family);
        loader.addFont(rootBundle.load(family == 'Inter'
            ? 'assets/fonts/Inter.ttf'
            : 'assets/fonts/ArchivoBlack-Regular.ttf'));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    for (final variant in [
      (small: false, dark: false),
      (small: true, dark: false),
      (small: false, dark: true),
      (small: true, dark: true),
    ]) {
      final small = variant.small;
      await tester.pumpWidget(const SizedBox());
      await _mountLogin(tester,
          size: small ? const Size(320, 568) : const Size(412, 892),
          dark: variant.dark);
      final createBounds =
          tester.getRect(find.byKey(const ValueKey('login-create-account')));
      expect(createBounds.bottom, lessThanOrEqualTo(small ? 492 : 802));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('login-preview')));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/login-preview')
          ..createSync(recursive: true);
        await File(
                '${directory.path}/${variant.dark ? 'dark-' : ''}${small ? 'small' : 'normal'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
  testWidgets('login fits inside the app shell on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    injector
      ..addInstance<LoginViewModel>(LoginViewModel(_FakeAuthFacade()))
      ..addInstance<AuthorizationService>(
        AuthorizationService(
          currentAccountProvider: _GuestAccountProvider(),
        ),
      )
      ..commit();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
        home: InstitutionScope(
          package: const IfprPguaPackage(),
          child: const AppShellPage(
            currentIndex: 2,
            currentPath: '/login',
            child: LoginPage(returnTo: '/notifications'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginPage), findsOneWidget);
    final originalCreateBounds =
        tester.getRect(find.byKey(const ValueKey('login-create-account')));
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final createBounds =
        tester.getRect(find.byKey(const ValueKey('login-create-account')));
    expect(createBounds, originalCreateBounds);
    expect(tester.takeException(), isNull);
  });
}

Future<LoginViewModel> _mountLogin(
  WidgetTester tester, {
  Size size = const Size(412, 892),
  bool dark = false,
  bool routed = false,
  IAuthUseCaseFacade? facade,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final model = LoginViewModel(facade ?? _FakeAuthFacade());
  injector.dispose();
  injector
    ..addInstance<LoginViewModel>(model)
    ..addInstance<AuthorizationService>(
        AuthorizationService(currentAccountProvider: _GuestAccountProvider()))
    ..commit();
  final home = RepaintBoundary(
    key: const ValueKey('login-preview'),
    child: InstitutionScope(
      package: const IfprPguaPackage(),
      child: const AppShellPage(
          currentIndex: 2,
          currentPath: '/login',
          child: LoginPage(returnTo: '/notifications')),
    ),
  );
  final theme = dark
      ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
      : app_theme.buildLightTheme(const IfprPguaPackage().theme);
  if (routed) {
    final router = GoRouter(initialLocation: '/login', routes: [
      GoRoute(path: '/login', builder: (context, state) => home),
      GoRoute(path: '/register', builder: (context, state) => const Scaffold()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
    ));
  } else {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: home,
    ));
  }
  await tester.pumpAndSettle();
  return model;
}

class _GuestAccountProvider implements ICurrentAccountProvider {
  @override
  Account? get currentAccount => null;

  @override
  String? get currentUid => null;
}

class _FakeAuthFacade implements IAuthUseCaseFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingLoginFacade extends Fake implements IAuthUseCaseFacade {
  final response = Completer<AuthSessionResult>();
  int calls = 0;

  @override
  Future<AuthSessionResult> signInUseCase(SignInParams params) {
    calls++;
    return response.future;
  }
}
