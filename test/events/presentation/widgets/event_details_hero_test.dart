import 'package:autth_injustice_app/core/formatters/app_date_time_formatter.dart';
import 'package:autth_injustice_app/core/formatters/hours_minutes_formatter.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_details/event_details_hero.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_details/event_location_rail.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_horizontal_rail.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_event_categories.dart';

void main() {
  for (final (size, brightness) in [
    (const Size(320, 640), Brightness.light),
    (const Size(432, 936), Brightness.light),
    (const Size(320, 640), Brightness.dark),
    (const Size(432, 936), Brightness.dark),
  ]) {
    testWidgets(
        'shadowed details keep horizontal locations stable at $size $brightness',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const roomLabel = 'Sala 9 · Piso 1 · Bloco Didático';
      final event = EventPreview(
        id: 'room-and-court',
        title: 'Missa do Sétimo Dia',
        category: TestEventCategories.academic,
        startsAt: DateTime(2026, 10, 25, 13, 18),
        location: '',
        mapLocations: const [
          MapLocation(
              institutionId: 'ifpr-pgua',
              zoneId: 'bloco-didatico',
              floorId: 'didatico-p1',
              spaceNodeName: 'sala_9_did',
              label: roomLabel),
          MapLocation(
              institutionId: 'ifpr-pgua', zoneId: 'quadra', label: 'Quadra'),
        ],
        description: 'Dois locais no campus.',
        imageUrl: '',
        endMode: EventEndMode.manual,
      );
      await tester.pumpWidget(InstitutionScope(
        package: const IfprPguaPackage(),
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: brightness == Brightness.dark
              ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
              : app_theme.buildLightTheme(const IfprPguaPackage().theme),
          home: Scaffold(
              body: EventDetailsHero(
                  event: event,
                  complementaryHours: 2,
                  isCompact: size.width < 360,
                  onBack: () {})),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final titleBefore = tester.getRect(find.text(event.title));
      final titleShadows =
          tester.widget<Text>(find.text(event.title)).style!.shadows!;
      expect(titleShadows, hasLength(1));
      expect(titleShadows.single.offset, const Offset(0, 2));
      final heroContext = tester.element(find.byType(EventDetailsHero));
      for (final label in [
        AppDateTimeFormatter.eventPeriod(heroContext, startsAt: event.startsAt),
        HoursMinutesFormatter.format(2),
        event.description,
      ]) {
        final shadows = tester.widget<Text>(find.text(label)).style!.shadows!;
        expect(shadows, hasLength(1));
        expect(shadows.single.offset, const Offset(0, 1));
        expect(shadows.single.blurRadius,
            lessThan(titleShadows.single.blurRadius));
        expect(shadows.single.color.a, greaterThan(0));
      }
      final rail = find.byType(EventLocationRail);
      expect(rail, findsOneWidget);
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: rail, matching: find.byType(Scrollable)).first);
      expect(scroll.position.axis, Axis.horizontal);
      expect(scroll.position.physics, isA<BouncingScrollPhysics>());
      expect(
          tester
              .widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade))
              .right,
          scroll.position.extentAfter > 0.5);
      expect(
          tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).left,
          isFalse);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final label in [roomLabel, 'Quadra']) {
        final location = find.text(label);
        expect(location, findsOneWidget);
        final text = tester.widget<Text>(location);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.style!.shadows, hasLength(1));
        expect(text.style!.shadows!.single.offset, const Offset(0, 1));
      }
      expect(tester.getRect(find.text('Quadra')).right,
          lessThanOrEqualTo(tester.getRect(rail).right));
      expect(
          tester
              .widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade))
              .right,
          isFalse,
          reason: 'The last location must remain completely visible');
      expect(
          tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).left,
          scroll.position.extentBefore > 0.5);
      final end = scroll.position.pixels;
      await tester.pump();
      expect(scroll.position.pixels, end,
          reason: 'Changing fade cannot reset scroll');
      expect(find.text(event.displayLocation), findsNothing,
          reason:
              'Locations are individual labels, not a one-line joined value');
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
          tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).left,
          isFalse,
          reason: 'The first card must not fade when back at the start');
      expect(find.byType(CloseButton), findsNothing);
      expect(tester.getRect(find.text(event.title)), titleBefore);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'many locations stay in one horizontal row, with empty and legacy support',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final places = List.generate(
        14,
        (index) => MapLocation(
            institutionId: 'ifpr-pgua',
            zoneId: 'bloco-didatico',
            floorId: 'didatico-p1',
            spaceNodeName: 'sala_${index + 1}_did',
            label: 'Sala ${index + 1} · Piso 1 · Bloco Didático'));
    EventPreview event(List<MapLocation> locations, {String legacy = ''}) =>
        EventPreview(
            id: 'many-locations',
            title: 'Evento',
            category: TestEventCategories.academic,
            startsAt: DateTime(2026, 10, 25),
            location: legacy,
            mapLocations: locations,
            description: 'Descrição curta.',
            imageUrl: '',
            endMode: EventEndMode.manual);
    Future<void> show(EventPreview value) async {
      await tester.pumpWidget(InstitutionScope(
        package: const IfprPguaPackage(),
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: app_theme.buildDarkTheme(const IfprPguaPackage().theme),
          home: Scaffold(
              body: Column(children: [
            Expanded(
                child: EventDetailsHero(
                    event: value, isCompact: true, onBack: () {})),
            const SizedBox(height: 120, child: Text('Ações do evento')),
          ])),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show(event(places));
    expect(tester.takeException(), isNull);
    expect(find.byType(EventLocationRail), findsOneWidget);
    expect(find.text(places.last.label), findsNothing,
        reason: 'Cards are lazily built');
    final heroScroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(heroScroll.position.maxScrollExtent, 0,
        reason: 'A long location list must not expand the event page');
    final titleBefore = tester.getRect(find.text('Evento'));
    final list = find.byType(EventLocationRail);
    final middle = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first);
    middle.position.jumpTo(middle.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    final both =
        tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade));
    expect(both.left, isTrue);
    expect(both.right, isTrue);
    final last = find.text(places.last.label);
    await tester.scrollUntilVisible(last, 300,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(last, findsOneWidget);
    expect(tester.takeException(), isNull);
    final horizontal = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first);
    horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(horizontal.position.extentAfter, closeTo(0, 0.5));
    expect(
        tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).right,
        isFalse);
    expect(tester.getRect(find.text('Evento')), titleBefore);
    await show(event(const []));
    expect(find.byType(EventLocationRail), findsNothing);
    await show(event(const [], legacy: 'Campus'));
    expect(find.text('Campus'), findsOneWidget);
    expect(
        tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).right,
        isFalse);
    expect(
        tester.widget<EventRailEdgeFade>(find.byType(EventRailEdgeFade)).left,
        isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('long descriptions fit small screens and can be read completely',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final description =
        List.filled(30, 'Descrição extensa do evento para leitura.').join('\n');
    final event = EventPreview(
      id: 'long-description',
      title: 'Evento com descrição longa',
      category: TestEventCategories.academic,
      startsAt: DateTime(2026, 10, 1, 12),
      location: 'Campus',
      description: description,
      imageUrl: '',
      endMode: EventEndMode.manual,
    );
    await tester.pumpWidget(InstitutionScope(
      package: const IfprPguaPackage(),
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
        home: Scaffold(
          body: Column(children: [
            Expanded(
                child: EventDetailsHero(
                    event: event, isCompact: true, onBack: () {})),
            const SizedBox(height: 120, child: Text('Ações do evento')),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ler mais'), findsOneWidget);
    final preview = tester.widget<Text>(find.text(description));
    expect(preview.maxLines, 3);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(find.text('Ações do evento'), findsOneWidget);
    await tester.tap(find.text('Ler mais'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
        description);
    final descriptionScroll = find.ancestor(
      of: find.byType(SelectableText),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(descriptionScroll, const Offset(0, -250));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find
        .ancestor(
            of: find.byType(SelectableText), matching: find.byType(Scrollable))
        .first);
    expect(scroll.position.pixels, greaterThan(0));
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
