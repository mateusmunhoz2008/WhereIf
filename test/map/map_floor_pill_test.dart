import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'other floors use three quiet pulses followed by a real idle pause',
      (tester) async {
    String? selected = 'p1';
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return MapFloorPill(
            floors: const [
              MapFloor(id: 'p1', label: 'Piso 1', nodeNames: [], spaces: []),
              MapFloor(id: 'p2', label: 'Piso 2', nodeNames: [], spaces: []),
            ],
            selectedId: selected,
            busy: false,
            eventCounts: const {'p1': 1, 'p2': 2},
            onSelected: (id) => setState(() => selected = id));
      },
    ))));
    final signal = find.byKey(const ValueKey('map-floor-event-p2'));
    expect(signal, findsOneWidget);
    expect(find.byKey(const ValueKey('map-floor-event-p1')), findsNothing);
    expect(find.byTooltip('Piso 2 · 2 eventos'), findsOneWidget);
    double alpha() => ((tester
                .widget<AnimatedContainer>(find.descendant(
                    of: signal, matching: find.byType(AnimatedContainer)))
                .decoration as BoxDecoration)
            .color!)
        .a;
    final bright = alpha();
    await tester.pump(const Duration(milliseconds: 160));
    final quiet = alpha();
    expect(quiet, 0, reason: 'No always-lit background between pulses');
    expect(bright, greaterThan(quiet));
    final decoration = tester
        .widget<AnimatedContainer>(find.descendant(
            of: signal, matching: find.byType(AnimatedContainer)))
        .decoration as BoxDecoration;
    expect(decoration.border, isNull, reason: 'No permanent colored ring');
    expect(find.descendant(of: signal, matching: find.byType(Positioned)),
        findsNothing,
        reason: 'No corner dot');
    expect(
        tester
            .widget<AnimatedDefaultTextStyle>(find.descendant(
                of: signal, matching: find.byType(AnimatedDefaultTextStyle)))
            .style
            .color,
        Colors.white70);
    await tester.pump(const Duration(milliseconds: 190));
    expect(alpha(), bright);
    await tester.pump(const Duration(milliseconds: 160));
    expect(alpha(), quiet);
    await tester.pump(const Duration(milliseconds: 190));
    expect(alpha(), bright);
    await tester.pump(const Duration(milliseconds: 160));
    expect(alpha(), quiet);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(alpha(), quiet);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'No repeating frame animation during the four-second pause');
    await tester.pump(const Duration(milliseconds: 2199));
    expect(alpha(), quiet);
    await tester.pump(const Duration(milliseconds: 1));
    expect(alpha(), bright);
    update(() => selected = 'p2');
    await tester.pump();
    expect(signal, findsNothing);
    expect(find.byKey(const ValueKey('map-floor-event-p1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'event floors look normal when hidden, reduced motion or busy; lifecycle suspends pulses',
      (tester) async {
    var busy = false, reduced = true, visible = true;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: TickerMode(
              enabled: visible,
              child: MapFloorPill(
                  floors: const [
                    MapFloor(
                        id: 'p1', label: 'Piso 1', nodeNames: [], spaces: []),
                    MapFloor(
                        id: 'p2', label: 'Piso 2', nodeNames: [], spaces: []),
                  ],
                  selectedId: 'p1',
                  busy: busy,
                  eventCounts: const {'p2': 1},
                  onSelected: (_) {})));
    }))));
    final signal = find.byKey(const ValueKey('map-floor-event-p2'));
    double alpha() => ((tester
                .widget<AnimatedContainer>(find.descendant(
                    of: signal, matching: find.byType(AnimatedContainer)))
                .decoration as BoxDecoration)
            .color!)
        .a;
    final quiet = alpha();
    expect(quiet, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(alpha(), quiet);
    update(() {
      reduced = false;
      busy = true;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(alpha(), quiet);
    update(() {
      busy = false;
      visible = false;
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(alpha(), quiet);
    update(() => visible = true);
    await tester.pump();
    expect(alpha(), greaterThan(quiet));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(alpha(), quiet);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(alpha(), greaterThan(quiet));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Disabling pill animation mid-slide snaps and keeps floor access',
      (tester) async {
    var animation = true;
    String? selected = 'p1';
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Center(
            child: MapFloorPill(
          floors: const [
            MapFloor(id: 'p1', label: 'Piso 1', nodeNames: [], spaces: []),
            MapFloor(id: 'p2', label: 'Piso 2', nodeNames: [], spaces: []),
          ],
          selectedId: selected,
          busy: false,
          animationEnabled: animation,
          onSelected: (id) => setState(() => selected = id),
        ));
      },
    ))));
    final marker = find.byKey(const ValueKey('map-floor-selection'));
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(marker).height, greaterThan(28));
    update(() => animation = false);
    await tester.pump();
    expect(tester.getRect(marker).height, 28);
    final top = tester.getRect(marker).top;
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(selected, 'p1');
    expect(tester.getRect(marker).height, 28);
    expect(tester.getRect(marker).top - top, 32);
    await tester.tap(find.byIcon(Icons.apartment_rounded));
    await tester.pump();
    expect(selected, isNull);
    expect(find.byKey(const ValueKey('map-floor-selection')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reference capsule extends first and its trailing end catches up',
      (tester) async {
    rootBundle.evict('assets/institutions/ifpr-pgua/map/campus_map.json');
    final json = jsonDecode(await rootBundle
            .loadString('assets/institutions/ifpr-pgua/map/campus_map.json'))
        as Map<String, dynamic>;
    final zone = (json['zones'] as List)
        .map((value) => MapZone.fromJson(value as Map<String, dynamic>))
        .firstWhere((zone) => zone.id == 'bloco-didatico');
    String? selected = 'didatico-p2';
    late StateSetter update;
    const previewKey = ValueKey('pill-reference-preview');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Center(
            child: RepaintBoundary(
                key: previewKey,
                child: SizedBox(
                    width: 150,
                    height: 130,
                    child: ColoredBox(
                        color: const Color(0xFF484451),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: MapFloorPill(
                                floors: zone.floors,
                                selectedId: selected,
                                busy: false,
                                onSelected: (id) =>
                                    setState(() => selected = id)))))));
      },
    ))));
    Future<void> capture(String name) async {
      if (Platform.environment['PILL_PREVIEW'] != '1') return;
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(previewKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/pill-preview').create(recursive: true);
        await File('build/pill-preview/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final marker = find.byKey(const ValueKey('map-floor-selection'));
    final origin = tester.getRect(marker);
    expect(origin.width, closeTo(28, 0.01));
    expect(origin.height, closeTo(28, 0.01));
    await capture('0-rest');
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final extended = tester.getRect(marker);
    expect(extended.top, greaterThan(origin.top),
        reason: 'The trailing end starts before the leading end arrives');
    expect(extended.height, greaterThan(28));
    expect(extended.height, lessThan(60));
    expect(extended.width, 28);
    await capture('1-extend');
    await tester.pump(const Duration(milliseconds: 84));
    expect(tester.getRect(marker).top, greaterThan(extended.top));
    await capture('2-hold');
    await tester.pump(const Duration(milliseconds: 128));
    expect(tester.getRect(marker).height, greaterThan(28));
    expect(tester.getRect(marker).height, lessThan(60));
    await capture('3-catch-up');
    await tester.pumpAndSettle();
    expect(tester.getRect(marker).width, closeTo(28, 0.01));
    expect(tester.getRect(marker).height, closeTo(28, 0.01));
    expect(tester.getRect(marker).top - origin.top, closeTo(32, 0.01));
    await capture('4-rest');
    update(() => selected = 'didatico-p2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    final beforeInterrupt = tester.getRect(marker);
    update(() => selected = 'didatico-p1');
    await tester.pump();
    expect(tester.getRect(marker).top, closeTo(beforeInterrupt.top, 0.01),
        reason: 'Changing direction mid-animation preserves both ends');
    expect(
        tester.getRect(marker).bottom, closeTo(beforeInterrupt.bottom, 0.01));
    await tester.pumpAndSettle();
    final exterior = find.byKey(const ValueKey('map-exterior-button'));
    final buttonBefore = tester.getRect(exterior);
    expect(
        buttonBefore.top - tester.getRect(find.byType(MapFloorPill)).top - 70,
        closeTo(12, 0.01),
        reason: 'Exterior is separated from the floor track');
    await tester.tap(find.byIcon(Icons.apartment_rounded));
    await tester.pump();
    expect(find.byKey(const ValueKey('map-floor-selection')), findsNothing,
        reason: 'Exterior never participates in the sliding selection');
    await tester.pumpAndSettle();
    expect(tester.getRect(exterior), buttonBefore);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Floor pill keeps its size and slides selection between levels',
      (tester) async {
    rootBundle.evict('assets/institutions/ifpr-pgua/map/campus_map.json');
    final json = jsonDecode(await rootBundle
            .loadString('assets/institutions/ifpr-pgua/map/campus_map.json'))
        as Map<String, dynamic>;
    final zone = (json['zones'] as List)
        .map((value) => MapZone.fromJson(value as Map<String, dynamic>))
        .firstWhere((zone) => zone.id == 'bloco-didatico');
    String? selected = 'didatico-p1';
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Align(
            alignment: Alignment.centerLeft,
            child: MapFloorPill(
                floors: zone.floors,
                selectedId: selected,
                busy: false,
                onSelected: (id) => setState(() => selected = id)));
      },
    ))));
    expect(tester.getSize(find.byType(MapFloorPill)), const Size(44, 114));
    final marker = find.byKey(const ValueKey('map-floor-selection'));
    final before = tester.getCenter(marker).dy;
    update(() => selected = 'didatico-p2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final halfway = tester.getCenter(marker).dy;
    await tester.pumpAndSettle();
    final after = tester.getCenter(marker).dy;
    expect(halfway, lessThan(before));
    expect(halfway, greaterThan(after));
    expect(before - after, closeTo(32, 0.1));
    tester.view.physicalSize = const Size(2400, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MapFloorPill)), const Size(44, 114));
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpAndSettle();
  });
  testWidgets('Interior caption shows the floor or room above the block name',
      (tester) async {
    const zone = MapZone(
        id: 'bloco-didatico',
        nodeName: 'bloco_didatico',
        label: 'Bloco Didático');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: MapSelectedZonePill(
          zone: zone,
          title: 'Piso 2',
          unavailableLabel: 'Bloco Didático',
          icon: Icons.layers_rounded),
    )));
    expect(find.text('Piso 2'), findsOneWidget);
    expect(find.text('Bloco Didático'), findsOneWidget);
    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: MapSelectedZonePill(
          zone: zone,
          title: 'Sala 7',
          unavailableLabel: 'Bloco Didático',
          icon: Icons.meeting_room_rounded),
    )));
    expect(find.text('Sala 7'), findsOneWidget);
    expect(find.text('Bloco Didático'), findsOneWidget);
  });

  testWidgets(
      'Didatico levels select floors, block loading taps and return outside',
      (tester) async {
    // Avoid awaiting an asset Future cached in a previous test's fake clock.
    rootBundle.evict('assets/institutions/ifpr-pgua/map/campus_map.json');
    final json = jsonDecode(await rootBundle
            .loadString('assets/institutions/ifpr-pgua/map/campus_map.json'))
        as Map<String, dynamic>;
    final zone = (json['zones'] as List)
        .map((value) => MapZone.fromJson(value as Map<String, dynamic>))
        .firstWhere((z) => z.id == 'bloco-didatico');
    expect(zone.floors, hasLength(2));
    expect(zone.floors.expand((f) => f.spaces), hasLength(31));
    String? selected;
    var busy = false;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return Align(
            alignment: Alignment.centerLeft,
            child: MapFloorPill(
              floors: zone.floors,
              selectedId: selected,
              busy: busy,
              onSelected: (id) => setState(() => selected = id),
            ));
      },
    ))));
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(selected, 'didatico-p2');
    update(() => busy = true);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(selected, 'didatico-p2');
    update(() => busy = false);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.apartment_rounded));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    final pill = tester.getTopLeft(find.byType(MapFloorPill));
    final drag = await tester.startGesture(pill + const Offset(22, 51));
    await drag.moveBy(const Offset(0, -35));
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, 'didatico-p2');
    expect(tester.takeException(), isNull);
  });
}
