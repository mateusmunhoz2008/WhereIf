import 'package:flutter/material.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_diagnostics_controller.dart';

class MapDiagnosticsPanel extends StatefulWidget {
  const MapDiagnosticsPanel(
      {super.key, required this.controller, this.compact = false});
  final MapDiagnosticsController controller;
  final bool compact;
  @override
  State<MapDiagnosticsPanel> createState() => _MapDiagnosticsPanelState();
}

class _MapDiagnosticsPanelState extends State<MapDiagnosticsPanel> {
  bool _expanded = true;
  MapDiagnosticsSample? _frozen;
  Map<String, double>? _frozenPeaks;
  @override
  void didUpdateWidget(MapDiagnosticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact && !oldWidget.compact) _expanded = false;
  }

  String _number(num? value, {String unit = '', int decimals = 1}) =>
      value == null ? '—' : '${value.toStringAsFixed(decimals)}$unit';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final sample = _frozen ?? controller.latest;
          final peaks = _frozenPeaks ?? controller.peaks;
          final renderer = sample?.renderer ?? const <String, dynamic>{};
          final lowMemory = sample?.native['lowMemory'] == true;
          Widget row(String label, String value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child:
                    Row(children: [Expanded(child: Text(label)), Text(value)]),
              );
          return Material(
            color: const Color(0xEE14121C),
            borderRadius: BorderRadius.circular(16),
            child: DefaultTextStyle(
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, height: 1.25),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
                    child: Row(children: [
                      const Icon(Icons.monitor_heart_outlined,
                          size: 18, color: Color(0xFFE393FF)),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Desempenho · 2 s',
                              style: TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _frozen == null
                            ? 'Pausar leitura'
                            : 'Retomar leitura',
                        onPressed: () => setState(() {
                          if (_frozen == null) {
                            _frozen = controller.latest;
                            _frozenPeaks = Map.of(controller.peaks);
                          } else {
                            _frozen = null;
                            _frozenPeaks = null;
                          }
                        }),
                        icon: Icon(
                            _frozen == null
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 19),
                      ),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70, size: 19),
                      const SizedBox(width: 5),
                    ]),
                  ),
                ),
                if (_expanded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 275),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                '${sample?.stage ?? controller.stage} · '
                                '${_frozen != null ? 'leitura pausada' : 'amostra'} '
                                '${_number(sample?.seconds, unit: ' s')}',
                                style:
                                    const TextStyle(color: Color(0xFFE393FF))),
                            const SizedBox(height: 6),
                            row('Visual do mapa',
                                renderer['rawMode'] == true ? 'Cru' : 'Normal'),
                            row(
                                'CPU app · todos os núcleos',
                                _number(sample?.value('cpuPercent'),
                                    unit: '%')),
                            row(
                                'Memória app (PSS)',
                                _number(sample?.value('appMemoryMb'),
                                    unit: ' MB', decimals: 0)),
                            row(
                                'Memória gráfica Android',
                                _number(sample?.value('graphicsMemoryMb'),
                                    unit: ' MB', decimals: 0)),
                            row(
                                'RAM livre no aparelho',
                                _number(sample?.value('availableMemoryMb'),
                                    unit: ' MB', decimals: 0)),
                            if (lowMemory)
                              const Text('Android sinalizou pouca memória',
                                  style: TextStyle(color: Color(0xFFFFA5A5))),
                            row('UI / desenho Flutter · p95',
                                '${_number(sample?.uiP95Ms)} / ${_number(sample?.rasterP95Ms)} ms'),
                            row('Quadros lentos / amostra',
                                '${sample?.slowFrames ?? 0} / ${sample?.frames ?? 0}'),
                            row(
                                'CPU render · pior quadro',
                                _number(renderer['renderCpuMaxMs'] as num?,
                                    unit: ' ms')),
                            row(
                                'GPU · último quadro medido',
                                renderer['gpuAvailable'] == false
                                    ? 'indisponível'
                                    : _number(renderer['gpuMaxMs'] as num?,
                                        unit: ' ms')),
                            row('Chamadas / triângulos',
                                '${renderer['drawCalls'] ?? '—'} / ${renderer['triangles'] ?? '—'}'),
                            row(
                                'Atraso do monitor',
                                _number(sample?.sampleDelayMs,
                                    unit: ' ms', decimals: 0)),
                            const Divider(color: Colors.white24, height: 16),
                            Text(
                                'Picos guardados · CPU ${_number(peaks['cpuPercent'], unit: '%')} · '
                                'gráficos ${_number(peaks['graphicsMemoryMb'], unit: ' MB', decimals: 0)}\n'
                                'Quadro ${_number(peaks['maxFrameMs'], unit: ' ms')} · '
                                'render ${_number(peaks['renderCpuMaxMs'], unit: ' ms')}',
                                style:
                                    const TextStyle(color: Color(0xFFFFCEA6))),
                            const SizedBox(height: 8),
                            const Text('Últimas amostras · toque para congelar',
                                style: TextStyle(color: Colors.white70)),
                            for (final previous
                                in controller.history.reversed.take(6))
                              InkWell(
                                onTap: () => setState(() {
                                  _frozen = previous;
                                  _frozenPeaks = Map.of(controller.peaks);
                                }),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Text(
                                      '${previous.seconds.toStringAsFixed(1)}s · ${previous.stage} · '
                                      '${_number(previous.value('graphicsMemoryMb'), unit: ' MB', decimals: 0)} · '
                                      'quadro ${previous.maxFrameMs.toStringAsFixed(1)} ms'),
                                ),
                              ),
                            for (final event
                                in controller.stages.reversed.take(5))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(event,
                                    style:
                                        const TextStyle(color: Colors.white60)),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                                'CPU é do processo do app; não inclui todo o processo isolado do WebView. '
                                'GPU é tempo de quadro, não % de ocupação. Picos ficam até sair desta aba.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          ]),
                    ),
                  ),
              ]),
            ),
          );
        },
      );
}
