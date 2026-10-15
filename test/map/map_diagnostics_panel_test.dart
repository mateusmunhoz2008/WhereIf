import 'package:autth_injustice_app/map/presentation/viewmodels/map_diagnostics_controller.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_diagnostics_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'readings update every two seconds and can be frozen after a spike',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('whereif/map_diagnostics');
    var reads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (_) async {
      reads++;
      return {
        'cpuPercent': reads * 10.0,
        'graphicsMemoryMb': reads * 100.0,
        'appMemoryMb': 500.0,
        'availableMemoryMb': 3000.0,
        'lowMemory': false
      };
    });
    final controller = MapDiagnosticsController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(18),
      child: Align(
          alignment: Alignment.topCenter,
          child: MapDiagnosticsPanel(controller: controller)),
    ))));
    await tester.pump();
    expect(reads, 1);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(reads, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(reads, 2);
    expect(find.text('20.0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Pausar leitura'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(reads, 3);
    expect(find.text('20.0%'), findsOneWidget,
        reason: 'A frozen reading survives later samples');
    expect(controller.peaks['cpuPercent'], 30);
    expect(controller.history.length, 3);
    await tester.tap(find.byTooltip('Retomar leitura'));
    await tester.pump();
    expect(find.text('30.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
