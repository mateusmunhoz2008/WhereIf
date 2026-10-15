import 'dart:ui' as ui;

import 'package:autth_injustice_app/app_shell/presentation/widgets/compact_shell_navigation_bar.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/widgets/app_glass_surface.dart';
import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zone =
      MapZone(id: 'didatico', nodeName: 'didatico', label: 'Bloco Didático');

  testWidgets(
      'Map wide blur removes every backdrop, while nav blur isolates the dock',
      (tester) async {
    AppGlassSurface.mapNavigationBlurTestEnabled.value = true;
    addTearDown(
        () => AppGlassSurface.mapNavigationBlurTestEnabled.value = true);
    var allBlur = true;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return GlassBlurScope(
          enabled: allBlur,
          child: Scaffold(
            body: Column(children: [
              CompactShellNavigationBar(
                currentIndex: 1,
                canManageEvents: false,
                whiteItems: true,
                mapBlurDiagnostic: true,
                onSelected: (_) {},
              ),
              MapControlButton(
                  tooltip: 'Pesquisa',
                  icon: Icons.search_rounded,
                  onPressed: () {}),
              const MapHeader(campusName: 'Campus', hint: 'Explore'),
              const MapSelectedZonePill(
                  zone: zone, unavailableLabel: 'Bloco', blurEnabled: true),
              MapFloorPill(
                floors: const [
                  MapFloor(id: 'p1', label: 'Piso 1', nodeNames: [], spaces: [])
                ],
                selectedId: 'p1',
                busy: false,
                blurEnabled: true,
                onSelected: (_) {},
              ),
            ]),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    final dockBlur = find.descendant(
      of: find.byType(CompactShellNavigationBar),
      matching: find.byType(BackdropFilter),
    );
    expect(dockBlur, findsOneWidget);
    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(4));
    AppGlassSurface.mapNavigationBlurTestEnabled.value = false;
    await tester.pump();
    expect(dockBlur, findsNothing);
    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(3));
    AppGlassSurface.mapNavigationBlurTestEnabled.value = true;
    update(() => allBlur = false);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('Piso 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-navigation-dock')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Selection blur can be switched on and removed without changing labels',
      (tester) async {
    var blur = true;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Column(children: [
          MapSelectedZonePill(
              zone: zone,
              unavailableLabel: 'Bloco Didático',
              title: 'Sala 7',
              blurEnabled: blur),
          MapFloorPill(
            floors: const [
              MapFloor(id: 'p1', label: 'Piso 1', nodeNames: [], spaces: [])
            ],
            selectedId: 'p1',
            busy: false,
            blurEnabled: blur,
            onSelected: (_) {},
          ),
        ]);
      },
    ))));
    expect(find.byType(BackdropFilter), findsNWidgets(4));
    update(() => blur = false);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Sala 7'), findsOneWidget);
    expect(find.text('Piso 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Map glass stays neutral while navigation retains its purple preset',
      (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: Column(children: [
          CompactShellNavigationBar(
              currentIndex: 1,
              canManageEvents: false,
              whiteItems: true,
              onSelected: (_) {}),
          MapControlButton(
              tooltip: 'Pesquisar',
              icon: Icons.search_rounded,
              onPressed: () {}),
          MapBearingControl(
              bearing: 0,
              tooltip: 'Ângulo',
              resetTooltip: 'Restaurar',
              onRotate: (_) {},
              onRotateStart: () {},
              onRotateEnd: () {},
              onReset: () {},
              is2D: false,
              onToggleView: () {}),
          const MapSelectedZonePill(
              zone: zone, unavailableLabel: 'Bloco Didático', title: 'Sala 7'),
          MapFloorPill(
            floors: const [
              MapFloor(id: 'p1', label: 'Piso 1', nodeNames: [], spaces: []),
              MapFloor(id: 'p2', label: 'Piso 2', nodeNames: [], spaces: []),
            ],
            selectedId: 'p1',
            busy: false,
            onSelected: (_) {},
          ),
        ])),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AppGlassSurface), findsNWidgets(9));
      expect(
          find.descendant(
              of: find.byType(MapSelectedZonePill),
              matching: find.byType(BackdropFilter)),
          findsNothing,
          reason: 'Selection identification must not blur the live map again');
      expect(
          find.descendant(
              of: find.byType(MapFloorPill),
              matching: find.byType(BackdropFilter)),
          findsNothing,
          reason:
              'Floor controls keep glass colors without live framebuffer filters');
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.gradient != null)
          .toList();
      expect(gradients, hasLength(9));
      for (final (index, decoration) in gradients.indexed) {
        final gradient = decoration.gradient! as LinearGradient;
        expect(
            gradient.colors,
            index == 0
                ? AppGlassSurface.darkColors
                : AppGlassSurface.neutralDarkColors);
        if (index > 0) {
          for (final color in gradient.colors) {
            expect(color.r, color.g);
            expect(color.g, color.b);
          }
        }
        expect(gradient.stops, [0.0, 0.08, 0.38, 1.0]);
        expect((decoration.border! as Border).top.width, 0.2);
        expect(
            (decoration.border! as Border).top.color,
            brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.80));
      }
      for (final blur
          in tester.widgetList<BackdropFilter>(find.byType(BackdropFilter))) {
        expect(blur.filter.toString(),
            ui.ImageFilter.blur(sigmaX: 2, sigmaY: 5).toString());
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Search, view toggle, reset and bearing drag still work',
      (tester) async {
    var searches = 0;
    var resets = 0;
    var toggles = 0;
    var starts = 0;
    var ends = 0;
    var rotation = 0.0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      MapControlButton(
          tooltip: 'Pesquisar',
          icon: Icons.search_rounded,
          onPressed: () => searches++),
      MapBearingControl(
          bearing: 0,
          tooltip: 'Ângulo',
          resetTooltip: 'Restaurar',
          onRotate: (delta) => rotation += delta,
          onRotateStart: () => starts++,
          onRotateEnd: () => ends++,
          onReset: () => resets++,
          is2D: false,
          onToggleView: () => toggles++),
    ]))));
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.tap(find.text('0°'));
    await tester.tap(find.text('3D'));
    final ruler = find.descendant(
        of: find.byType(MapBearingControl), matching: find.byType(CustomPaint));
    await tester.drag(ruler, const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(searches, 1);
    expect(resets, 1);
    expect(toggles, 1);
    expect(starts, 1);
    expect(ends, 1);
    expect(rotation, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
