import 'dart:io';
import 'dart:ui' as ui;

import 'package:autth_injustice_app/app_startup/data/repositories/app_entry_repository_impl.dart';
import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/initial_page.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

const _next = ValueKey('onboarding-next');
const _skip = ValueKey('onboarding-skip');
const _capture = ValueKey('onboarding-capture');

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(412, 892),
  String language = 'pt',
  IAppEntryRepository? repository,
  VoidCallback? onCompleted,
  bool reducedMotion = false,
  double textScale = 1,
  bool dark = false,
  bool settleEntrance = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark
        ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
        : app_theme.buildLightTheme(const IfprPguaPackage().theme),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: RepaintBoundary(
      key: _capture,
      child: InitialPage(
        entryRepository: repository ?? const AppEntryRepositoryImpl(),
        onCompleted: onCompleted ?? () {},
      ),
    ),
  ));
  if (!settleEntrance) return;
  await tester.pumpAndSettle();
  // Give real asynchronous asset decoding time before captures.
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
}

Future<void> _advance(WidgetTester tester) async {
  await tester.tap(find.byKey(_next));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets(
        'entry starts with exact Splash color and reveals gradient '
        'dark=$dark', (tester) async {
      final theme = dark
          ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
          : app_theme.buildLightTheme(const IfprPguaPackage().theme);
      final splashColor = theme.colorScheme.tertiary;
      await _mount(tester, dark: dark, settleEntrance: false);
      final bridge = find.byKey(const ValueKey('onboarding-splash-bridge'));
      double coverOpacity() =>
          tester.widget<FadeTransition>(bridge).opacity.value;
      expect(coverOpacity(), 1);
      expect(
          tester
              .widget<ColoredBox>(
                  find.byKey(const ValueKey('onboarding-splash-color')))
              .color,
          splashColor);
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
      expect(overlay.value.systemNavigationBarColor, splashColor);
      // Verify painted pixels, not just the decoration hidden underneath.
      final firstFrame = await _screenSamples(tester);
      expect(firstFrame, everyElement(splashColor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(coverOpacity(), greaterThan(0));
      expect(coverOpacity(), lessThan(1));
      final middleFrame = await _screenSamples(tester);
      expect(middleFrame.any((color) => color != splashColor), isTrue);
      await tester.pumpAndSettle();
      expect(coverOpacity(), 0);
      // The bridge is only for initial entry, not page changes or final exit.
      await _advance(tester);
      expect(coverOpacity(), 0);
      await _advance(tester);
      await tester.tap(find.byKey(_next));
      await tester.pump(const Duration(milliseconds: 100));
      expect(coverOpacity(), 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('first entrance staggers text and controls', (tester) async {
    await _mount(tester, settleEntrance: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    double textOpacity() => tester
        .widget<Opacity>(find.byKey(const ValueKey('onboarding-text-fade-0')))
        .opacity;
    double controlsOpacity() => tester
        .widget<FadeTransition>(
            find.byKey(const ValueKey('onboarding-controls-entrance')))
        .opacity
        .value;
    expect(textOpacity(), 0);
    expect(controlsOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(textOpacity(), greaterThan(0));
    expect(textOpacity(), lessThan(1));
    expect(controlsOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(controlsOpacity(), greaterThan(0));
    expect(controlsOpacity(), lessThan(1));
    await tester.pumpAndSettle();
    expect(textOpacity(), 1);
    expect(controlsOpacity(), 1);
  });

  testWidgets('only the final arrow persists completion, once', (tester) async {
    const repository = AppEntryRepositoryImpl();
    var completed = 0;
    await _mount(tester, onCompleted: () => completed++);
    expect(await repository.hasCompletedInitialPage(), isFalse);
    await _advance(tester);
    expect(find.byKey(const ValueKey('onboarding-title-1')), findsOneWidget);
    expect(await repository.hasCompletedInitialPage(), isFalse);
    await _advance(tester);
    expect(find.byKey(const ValueKey('onboarding-title-2')), findsOneWidget);
    expect(await repository.hasCompletedInitialPage(), isFalse);
    await _advance(tester);
    expect(await repository.hasCompletedInitialPage(), isTrue);
    expect(completed, 1);
    await tester.tap(find.byKey(_next), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('skip jumps to the last page without saving', (tester) async {
    const repository = AppEntryRepositoryImpl();
    await _mount(tester);
    await tester.tap(find.byKey(_skip));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-title-2')), findsOneWidget);
    expect(find.byKey(_skip), findsNothing);
    expect(await repository.hasCompletedInitialPage(), isFalse);
    await tester.pumpWidget(const SizedBox());
    await _mount(tester);
    expect(find.byKey(const ValueKey('onboarding-title-0')), findsOneWidget);
    expect(await repository.hasCompletedInitialPage(), isFalse);
  });

  testWidgets('swipes and progress indicators do not change steps',
      (tester) async {
    await _mount(tester);
    await tester.drag(
        find.byKey(const ValueKey('onboarding-pages')), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-title-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-step-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-title-0')), findsOneWidget);
    expect(await const AppEntryRepositoryImpl().hasCompletedInitialPage(),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preference failure still allows entering as a visitor',
      (tester) async {
    var completed = 0;
    await _mount(tester,
        repository: _UnavailablePreferences(), onCompleted: () => completed++);
    await tester.tap(find.byKey(_skip));
    await tester.pumpAndSettle();
    await _advance(tester);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still navigates and completes', (tester) async {
    await _mount(tester, reducedMotion: true);
    expect(
        tester
            .widget<FadeTransition>(
                find.byKey(const ValueKey('onboarding-splash-bridge')))
            .opacity
            .value,
        0);
    await _advance(tester);
    await _advance(tester);
    expect(await const AppEntryRepositoryImpl().hasCompletedInitialPage(),
        isFalse);
    await _advance(tester);
    expect(
        await const AppEntryRepositoryImpl().hasCompletedInitialPage(), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['pt', 'en', 'es']) {
    for (final size in [
      const Size(320, 568),
      const Size(412, 892),
      const Size(768, 1024),
      const Size(720, 360)
    ]) {
      testWidgets('all pages fit $language ${size.width}x${size.height}',
          (tester) async {
        await _mount(tester, size: size, language: language);
        for (var step = 0; step < 3; step++) {
          expect(find.byType(SingleChildScrollView), findsNothing);
          expect(
              find.byKey(ValueKey('onboarding-title-$step')), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (step < 2) await _advance(tester);
        }
      });
    }
  }

  testWidgets('large text fits completely without vertical scrolling',
      (tester) async {
    await _mount(tester, size: const Size(320, 568), textScale: 1.5);
    for (var step = 0; step < 3; step++) {
      expect(find.byType(SingleChildScrollView), findsNothing);
      final copy = find.byKey(ValueKey('onboarding-copy-$step'));
      final title = find.byKey(ValueKey('onboarding-title-$step'));
      final copyBounds = tester.getRect(copy);
      final titleBounds = tester.getRect(title);
      expect(titleBounds.top, greaterThanOrEqualTo(copyBounds.top - .1));
      expect(titleBounds.bottom, lessThanOrEqualTo(copyBounds.bottom + .1));
      expect(
          copyBounds.bottom, lessThan(tester.getRect(find.byKey(_next)).top));
      expect(tester.takeException(), isNull);
      if (step < 2) await _advance(tester);
    }
  });

  testWidgets('dark theme colors cover the page, cards and text',
      (tester) async {
    await _mount(tester, dark: true);
    final colors =
        app_theme.buildDarkTheme(const IfprPguaPackage().theme).colorScheme;
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        colors.surface);
    final gradient = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>()
        .first;
    expect(gradient.colors, [
      Color.lerp(colors.surface, colors.primary, .38),
      Color.lerp(colors.surface, colors.secondary, .38),
      Color.lerp(colors.surface, colors.error, .38),
    ]);
    for (var step = 0; step < 3; step++) {
      final title =
          tester.widget<Text>(find.byKey(ValueKey('onboarding-title-$step')));
      expect(title.style?.color, colors.onSurface);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
      if (step < 2) await _advance(tester);
    }
  });

  testWidgets('button navigation fades and slides text through the transition',
      (tester) async {
    await _mount(tester);
    final initialBounds =
        tester.getRect(find.byKey(const ValueKey('onboarding-title-0')));
    await tester.tap(find.byKey(_next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final opacity = tester
        .widget<Opacity>(find.byKey(const ValueKey('onboarding-text-fade-0')))
        .opacity;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    expect(
        tester.getRect(find.byKey(const ValueKey('onboarding-title-0'))).left,
        lessThan(initialBounds.left));
    expect(
        tester
            .widget<FractionalTranslation>(
                find.byKey(const ValueKey('onboarding-text-slide-0')))
            .translation
            .dy,
        lessThan(0));
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final incomingOpacity = tester
        .widget<Opacity>(find.byKey(const ValueKey('onboarding-text-fade-1')))
        .opacity;
    expect(incomingOpacity, greaterThan(0));
    expect(incomingOpacity, lessThan(1));
    expect(
        tester
            .widget<FractionalTranslation>(
                find.byKey(const ValueKey('onboarding-text-slide-1')))
            .translation
            .dy,
        lessThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-title-1')), findsOneWidget);
    expect(
        tester
            .widget<Opacity>(
                find.byKey(const ValueKey('onboarding-text-fade-1')))
            .opacity,
        1);
    expect(
        tester
            .widget<FractionalTranslation>(
                find.byKey(const ValueKey('onboarding-text-slide-1')))
            .translation,
        Offset.zero);
  });

  for (final alreadyCompleted in [false, true]) {
    testWidgets(
        'settings replay returns without changing completion=$alreadyCompleted',
        (tester) async {
      const repository = AppEntryRepositoryImpl();
      if (alreadyCompleted) await repository.markInitialPageCompleted();
      final router = GoRouter(
        initialLocation: '/settings-test',
        routes: [
          ...rootAuthRoutes,
          GoRoute(
              path: '/settings-test',
              builder: (context, state) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          context.pushNamed(AuthRouteNames.onboardingPreview),
                      child: const Text('Ver apresentação'),
                    ),
                  )),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ));
      await tester.tap(find.text('Ver apresentação'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_skip));
      await tester.pumpAndSettle();
      await _advance(tester);
      expect(find.text('Ver apresentação'), findsOneWidget);
      expect(await repository.hasCompletedInitialPage(), alreadyCompleted);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('optional real-font previews', (tester) async {
    if (Platform.environment['ONBOARDING_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      for (final font in ['ArchivoBlack', 'Inter']) {
        final loader = FontLoader(font);
        loader.addFont(rootBundle.load(font == 'Inter'
            ? 'assets/fonts/Inter.ttf'
            : 'assets/fonts/ArchivoBlack-Regular.ttf'));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    for (final dark in [false, true]) {
      for (final small in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        await _mount(tester,
            dark: dark,
            size: small ? const Size(320, 568) : const Size(412, 892));
        for (var step = 0; step < 3; step++) {
          await tester.runAsync(() async {
            final boundary = tester
                .renderObject<RenderRepaintBoundary>(find.byKey(_capture));
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/onboarding-preview')
              ..createSync(recursive: true);
            final name =
                '${small ? 'small-' : ''}${dark ? 'dark-' : ''}step-${step + 1}.png';
            await File('${directory.path}/$name')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
          if (step < 2) await _advance(tester);
        }
      }
    }
  });
}

Future<List<Color>> _screenSamples(WidgetTester tester) async {
  final samples = await tester.runAsync<List<Color>>(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_capture));
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      return [
        for (var row = 0; row < 9; row++)
          for (var column = 0; column < 9; column++)
            Color.fromARGB(
              bytes[((row * (image.height - 1) ~/ 8) * image.width +
                          column * (image.width - 1) ~/ 8) *
                      4 +
                  3],
              bytes[((row * (image.height - 1) ~/ 8) * image.width +
                      column * (image.width - 1) ~/ 8) *
                  4],
              bytes[((row * (image.height - 1) ~/ 8) * image.width +
                          column * (image.width - 1) ~/ 8) *
                      4 +
                  1],
              bytes[((row * (image.height - 1) ~/ 8) * image.width +
                          column * (image.width - 1) ~/ 8) *
                      4 +
                  2],
            ),
      ];
    } finally {
      image.dispose();
    }
  });
  return samples!;
}

class _UnavailablePreferences implements IAppEntryRepository {
  @override
  Future<bool> hasCompletedInitialPage() async => false;
  @override
  Future<void> markInitialPageCompleted() async =>
      throw StateError('Unavailable');
  @override
  Future<void> resetInitialPage() async {}
}
