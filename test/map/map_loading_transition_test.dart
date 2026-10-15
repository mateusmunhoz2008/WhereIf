import 'dart:io';
import 'dart:ui' as ui;

import 'package:autth_injustice_app/map/presentation/widgets/map_loading_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'curtain blocks map, keeps shell usable and reveals only on ready',
      (tester) async {
    var ready = false;
    var mapTaps = 0;
    var shellTaps = 0;
    late StateSetter update;
    final previewKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return RepaintBoundary(
            key: previewKey,
            child: Stack(fit: StackFit.expand, children: [
              MapLoadingTransition(
                ready: ready,
                primary: const Color(0xFFD53EFF),
                secondary: const Color(0xFF8C34FF),
                loadingLabel: 'Loading map',
                child: ColoredBox(
                  color: const Color(0xFFCBDDCB),
                  child: Center(
                    child: TextButton(
                      onPressed: () => mapTaps++,
                      child: const Text('Map control'),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: () => shellTaps++,
                  child: const Text('App shell'),
                ),
              ),
            ]),
          );
        }),
      ),
    ));
    await tester.pump();
    final curtain = find.byKey(const ValueKey('map-loading-curtain'));
    expect(curtain, findsOneWidget);
    expect(find.text('Map control'), findsNothing,
        reason: 'The map is not mounted during entrance');
    await tester.pump(const Duration(milliseconds: 640));
    await tester.pump();
    await tester.tap(find.text('Map control'), warnIfMissed: false);
    expect(mapTaps, 0);
    await tester.tap(find.text('App shell'));
    expect(shellTaps, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(curtain, findsOneWidget,
        reason: 'No timeout may reveal an unloaded map');

    Future<void> preview(String name) async {
      final directory = Platform.environment['MAP_LOADING_PREVIEW_DIR'];
      if (directory == null) return;
      final boundary = previewKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await preview('map-loading-loop');
    update(() => ready = true);
    await tester.pump();
    expect(curtain, findsOneWidget,
        reason: 'Ready starts the exit, it does not cut');
    await tester.pump(const Duration(milliseconds: 390));
    await preview('map-loading-exit');
    expect(curtain, findsOneWidget);
    await tester.pumpAndSettle();
    expect(curtain, findsNothing);
    await tester.tap(find.text('Map control'));
    expect(mapTaps, 1);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('heavy child is mounted only after the final entrance frame',
      (tester) async {
    var mounts = 0;
    await tester.pumpWidget(MaterialApp(
      home: MapLoadingTransition(
        ready: false,
        primary: Colors.purple,
        secondary: Colors.deepPurple,
        loadingLabel: 'Loading',
        child: Builder(builder: (_) {
          mounts++;
          return const SizedBox.expand();
        }),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(mounts, 0);
    await tester.pump(const Duration(milliseconds: 40));
    expect(mounts, 0, reason: 'Mount is deferred until the next painted frame');
    await tester.pump();
    expect(mounts, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(mounts, 1);
    expect(find.byKey(const ValueKey('map-loading-curtain')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'Pills keep sliding while the child loads');
  });

  testWidgets('fast readiness completes entrance before revealing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MapLoadingTransition(
        ready: true,
        primary: Colors.purple,
        secondary: Colors.deepPurple,
        loadingLabel: 'Loading',
        child: SizedBox.expand(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('map-loading-curtain')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-loading-curtain')), findsNothing);
  });

  testWidgets('reduced motion is static and releases immediately when ready',
      (tester) async {
    var ready = false;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return MapLoadingTransition(
            ready: ready,
            primary: Colors.purple,
            secondary: Colors.deepPurple,
            loadingLabel: 'Loading',
            child: const SizedBox.expand(),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-loading-curtain')), findsOneWidget);
    update(() => ready = true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-loading-curtain')), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
