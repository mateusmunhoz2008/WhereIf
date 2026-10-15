import 'dart:io';
import 'dart:ui' as ui;

import 'package:autth_injustice_app/app_shell/presentation/widgets/compact_shell_navigation_bar.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    int selected = 0,
    bool map = false,
    bool manager = false,
    bool reduceMotion = false,
    ValueChanged<int>? onSelected,
  }) =>
      MaterialApp(
        theme: buildLightTheme(const IfprPguaPackage().theme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduceMotion),
                  child: Scaffold(
                      body: Center(
                          child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RepaintBoundary(
                      key: const ValueKey('dock-preview'),
                      child: CompactShellNavigationBar(
                        currentIndex: selected,
                        canManageEvents: manager,
                        whiteItems: map,
                        onSelected: onSelected ?? (_) {},
                      ),
                    ),
                  ))),
                )),
      );

  testWidgets('Dock stays centered and compact on phones and tablets',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(320, 640),
      const Size(412, 892),
      const Size(800, 1100)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final dock =
          tester.getRect(find.byKey(const ValueKey('shell-navigation-dock')));
      expect(dock.width, size.width < 360 ? 264 : 296);
      expect(dock.height, size.width < 360 ? 54 : 58);
      expect(dock.center.dx, size.width / 2);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
          tester
              .widget<BackdropFilter>(find.byType(BackdropFilter))
              .filter
              .toString(),
          ui.ImageFilter.blur(sigmaX: 2, sigmaY: 5).toString());
      for (final target in tester.widgetList<InkWell>(find.byType(InkWell))) {
        expect(target.onTap, isNotNull);
      }
      final targets = find.byType(InkWell);
      for (var i = 0; i < 4; i++) {
        final bounds = tester.getSize(targets.at(i));
        expect(bounds.width, greaterThanOrEqualTo(48));
        expect(bounds.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Optional design preview', (tester) async {
    if (Platform.environment['NAV_PREVIEW'] != '1') return;
    for (final map in [false, true]) {
      await tester.pumpWidget(host(selected: 1, map: map));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('dock-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/nav-preview').create(recursive: true);
        await File('build/nav-preview/${map ? 'map' : 'light'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('Indicator slides continuously, taps keep all four destinations',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(host(onSelected: (value) => tapped = value));
    await tester.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('shell-navigation-indicator'));
    final start = tester.getRect(indicator);
    await tester.tap(find.byType(InkWell).at(2));
    expect(tapped, 2);
    await tester
        .pumpWidget(host(selected: 2, onSelected: (value) => tapped = value));
    await tester.pump();
    expect(tester.getRect(indicator).left, closeTo(start.left, 0.01));
    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = tester.getRect(indicator);
    await tester.pumpAndSettle();
    final end = tester.getRect(indicator);
    expect(intermediate.left, greaterThan(start.left));
    expect(intermediate.left, lessThan(end.left));
    expect(end.left - start.left, closeTo(start.width * 2, 0.01));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(InkWell).at(i));
      expect(tapped, i);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Map retains white icons; manager icon and reduced motion work',
      (tester) async {
    await tester.pumpWidget(
        host(selected: 0, map: true, manager: true, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Icon>(find.byIcon(Icons.dashboard_customize_rounded))
            .color,
        Colors.white);
    await tester.pumpWidget(
        host(selected: 3, map: true, manager: true, reduceMotion: true));
    await tester.pump();
    final dock =
        tester.getRect(find.byKey(const ValueKey('shell-navigation-dock')));
    final indicator = tester
        .getRect(find.byKey(const ValueKey('shell-navigation-indicator')));
    expect(indicator.right, closeTo(dock.right - 6, 0.01));
    expect(tester.takeException(), isNull);
  });
}
