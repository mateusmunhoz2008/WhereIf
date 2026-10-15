import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/map/domain/models/map_event_entry.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/map/domain/models/map_search_index.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_search_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_event_categories.dart';

const _places = [
  MapLocation(institutionId: 'ifpr-pgua', zoneId: 'quadra', label: 'Quadra'),
  MapLocation(
      institutionId: 'ifpr-pgua', zoneId: 'didatico', label: 'Bloco Didático'),
  MapLocation(
      institutionId: 'ifpr-pgua',
      zoneId: 'didatico',
      floorId: 'p2',
      label: 'Piso 2 · Bloco Didático'),
  MapLocation(
      institutionId: 'ifpr-pgua',
      zoneId: 'didatico',
      floorId: 'p2',
      spaceNodeName: 'lab',
      label: 'Laboratório de Música · Piso 2 · Bloco Didático'),
];
MapEventEntry _event(String id, String title, List<MapLocation> locations) =>
    MapEventEntry(
        EventPreview(
          id: id,
          title: title,
          category: TestEventCategories.academic,
          startsAt: DateTime(2027, 1, 1),
          location: '',
          mapLocations: locations,
          description: 'Não deve aparecer na pesquisa',
          imageUrl: '',
          endMode: EventEndMode.manual,
        ),
        locations);

Widget _app(
        {required ValueChanged<MapSearchResult> onSelected,
        bool dark = true,
        bool reduced = false,
        bool resize = false}) =>
    MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark
          ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
          : app_theme.buildLightTheme(const IfprPguaPackage().theme),
      home: Builder(
          builder: (context) => MediaQuery(
                data:
                    MediaQuery.of(context).copyWith(disableAnimations: reduced),
                child: Scaffold(
                  resizeToAvoidBottomInset: resize,
                  body: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: Colors.blue),
                    MapSearchOverlay(
                        locations: _places,
                        events: [
                          _event('music', 'Festival de Música',
                              [_places.last, _places.first])
                        ],
                        onSelected: onSelected),
                  ]),
                ),
              )),
    );

void main() {
  test(
      'local index searches accents and origins, preserving stable destinations',
      () {
    final index = MapSearchIndex(_places, [
      _event('one', 'Feira de Projetos', [_places.last, _places.first])
    ]);
    final rooms =
        index.search('laboratorio didatico').where((result) => !result.isEvent);
    expect(rooms.single.title, 'Laboratório de Música');
    expect(rooms.single.origin, 'Piso 2 · Bloco Didático');
    expect(rooms.single.destination, _places.last);
    final events = index.search('feira');
    expect(events.single.isEvent, isTrue);
    expect(events.single.origin, _places.last.label);
    expect(events.single.destination, _places.last);
    expect(index.search('QUADRA').first.title, 'Quadra');
    expect(index.search('zzz'), isEmpty);
  });
  test(
      'index deduplicates events with several locations and ignores no-location entries',
      () {
    final event = _event('one', 'Evento', _places);
    final index = MapSearchIndex([..._places, _places.first],
        [event, event, _event('none', 'Sem local', [])]);
    final all = index.search(' ');
    expect(all.where((result) => result.isEvent), hasLength(1));
    expect(all, hasLength(_places.length + 1));
    expect(all.map((result) => result.id).toSet(), hasLength(all.length));
  });

  for (final size in [
    const Size(320, 568),
    const Size(432, 936),
    const Size(800, 1000),
    const Size(640, 360)
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
          'search opens with keyboard, filters and selects at $size dark=$dark',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final chosen = <MapSearchResult>[];
        await tester.pumpWidget(_app(dark: dark, onSelected: chosen.add));
        expect(find.byType(TextField), findsNothing);
        final button = find.byKey(const ValueKey('map-search-open'));
        final icon = tester.widget<Icon>(
            find.descendant(of: button, matching: find.byType(Icon)));
        expect(icon.color, dark ? Colors.white : Colors.black);
        await tester.tap(button);
        await tester.pump();
        final field = find.byKey(const ValueKey('map-search-field'));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        final decoration = tester.widget<TextField>(field).decoration!;
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(tester.getSize(field).height, greaterThanOrEqualTo(54));
        // Show results while the keyboard rises; the top never moves/shrinks.
        final top = tester.getTopLeft(field).dy;
        tester.view.viewInsets =
            FakeViewPadding(bottom: size.height < 500 ? 140 : 250);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(field).dy, top);
        expect(tester.getBottomRight(find.byType(ListView)).dy,
            lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom));
        expect(find.text('Não deve aparecer na pesquisa'), findsNothing);
        await tester.enterText(field, 'musica');
        await tester.pump(const Duration(milliseconds: 95));
        await tester.pumpAndSettle();
        expect(find.text('Festival de Música'), findsOneWidget);
        expect(find.text(_places.last.label), findsOneWidget,
            reason: 'Events show their destination below the title');
        final eventCard = find.byKey(const ValueKey('event:music'));
        expect(tester.getSize(eventCard).height, greaterThanOrEqualTo(84));
        final titleStyle =
            tester.widget<Text>(find.text('Festival de Música')).style!;
        final subtitleStyle =
            tester.widget<Text>(find.text(_places.last.label)).style!;
        expect(titleStyle.color, Colors.white);
        expect(subtitleStyle.color, Colors.white.withValues(alpha: .55));
        expect(titleStyle.shadows, hasLength(1));
        expect(titleStyle.shadows!.single.blurRadius, greaterThanOrEqualTo(8));
        expect(titleStyle.shadows!.single.offset, const Offset(0, 1));
        expect(subtitleStyle.shadows, hasLength(1));
        expect(
            subtitleStyle.shadows!.single.blurRadius, greaterThanOrEqualTo(6));
        expect(
            tester
                .widget<Icon>(
                    find.descendant(of: eventCard, matching: find.byType(Icon)))
                .color,
            Colors.white.withValues(alpha: .85));
        expect(subtitleStyle.fontSize, lessThan(titleStyle.fontSize!));
        expect(subtitleStyle.color!.a, lessThan(titleStyle.color!.a));
        expect(find.text('Laboratório de Música'), findsOneWidget);
        expect(
            tester
                .widget<Text>(find.text('Laboratório de Música'))
                .style!
                .shadows,
            anyOf(isNull, isEmpty),
            reason: 'Keep the change scoped to event text');
        expect(
            tester
                .widget<Text>(find.text('Laboratório de Música'))
                .style!
                .color,
            dark ? Colors.white : Colors.black,
            reason: 'Only event cards stay white in the light theme');
        expect(find.text('Piso 2 · Bloco Didático'), findsOneWidget);
        await tester.enterText(field, 'zzzz');
        await tester.pump(const Duration(milliseconds: 95));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('map-search-empty')), findsOneWidget);
        await tester.enterText(field, 'quadra');
        await tester.pump(const Duration(milliseconds: 95));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(ListView)).height, lessThan(280),
            reason: 'Two matching results must not leave a large empty panel');
        await tester.tap(find.text('Quadra'));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pumpAndSettle();
        expect(chosen, hasLength(1));
        expect(chosen.single.destination, _places.first);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('rapid typing, close/reopen and double taps never choose twice',
      (tester) async {
    final chosen = <MapSearchResult>[];
    await tester.pumpWidget(_app(onSelected: chosen.add));
    final open = find.byKey(const ValueKey('map-search-open'));
    final field = find.byKey(const ValueKey('map-search-field'));
    await tester.tap(open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(20, 550));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    for (final query in ['musica', 'quadra', 'zzzz', 'festival']) {
      await tester.enterText(field, query);
      await tester.pump(const Duration(milliseconds: 95));
    }
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('event:music'));
    expect(tester.getSize(find.byType(ListView)).height, lessThan(160),
        reason: 'A single result must shrink the results panel');
    final tap = tester
        .widget<InkWell>(
            find.descendant(of: tile, matching: find.byType(InkWell)))
        .onTap!;
    tap();
    tap();
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();
    expect(chosen, hasLength(1));
    expect(chosen.single.eventId, 'music');
    expect(tester.takeException(), isNull);
  });
  testWidgets('outside, back and disposal cancel pending selections safely',
      (tester) async {
    final chosen = <MapSearchResult>[];
    await tester.pumpWidget(_app(onSelected: chosen.add));
    final open = find.byKey(const ValueKey('map-search-open'));
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Festival de Música'));
    await tester.tapAt(const Offset(20, 550));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpAndSettle();
    expect(chosen, isEmpty);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'quadra');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
  testWidgets('opening stays gradual while the keyboard already has focus',
      (tester) async {
    await tester.pumpWidget(_app(onSelected: (_) {}));
    await tester.tap(find.byKey(const ValueKey('map-search-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final reveal =
        tester.widget<Align>(find.byKey(const ValueKey('map-search-reveal')));
    expect(reveal.widthFactor, greaterThan(.05));
    expect(reveal.widthFactor, lessThan(.7),
        reason: 'The entrance must not finish abruptly in the first 200 ms');
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Align>(find.byKey(const ValueKey('map-search-reveal')))
            .widthFactor,
        1);
    await tester.tap(find.byKey(const ValueKey('map-search-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion and resized hosts remain usable with keyboard',
      (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final chosen = <MapSearchResult>[];
    await tester
        .pumpWidget(_app(onSelected: chosen.add, reduced: true, resize: true));
    await tester.tap(find.byKey(const ValueKey('map-search-open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'quadra');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quadra'));
    await tester.pumpAndSettle();
    expect(chosen, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
