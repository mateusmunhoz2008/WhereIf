import 'package:autth_injustice_app/map/presentation/widgets/map_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Juízo Final button toggles without overflowing a phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var active = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, update) => Align(
            alignment: Alignment.topRight,
            child: MapRawModeButton(
              label: 'Juízo Final',
              tooltip: active ? 'Voltar ao normal' : 'Mostrar mapa cru',
              enabled: active,
              onPressed: () => update(() => active = !active),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Juízo Final'), findsOneWidget);
    await tester.tap(find.text('Juízo Final'));
    await tester.pump();
    expect(active, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'view toggle shares the zero button style and fits a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var is2D = false;
    var resets = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, update) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MapBearingControl(
          bearing: 0,
          tooltip: 'Rotate',
          resetTooltip: 'Reset',
          is2D: is2D,
          onRotate: (_) {},
          onRotateStart: () {},
          onRotateEnd: () {},
          onToggleView: () => update(() => is2D = !is2D),
          onReset: () => update(() {
            is2D = false;
            resets++;
          }),
        ),
      ),
    ))));
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('0°'), findsOneWidget);
    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.text('2D'), findsOneWidget);
    await tester.tap(find.text('2D'));
    await tester.pump();
    expect(find.text('3D'), findsOneWidget);
    await tester.tap(find.text('3D'));
    await tester.pump();
    await tester.tap(find.text('0°'));
    await tester.pump();
    expect(resets, 1);
    expect(find.text('3D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
