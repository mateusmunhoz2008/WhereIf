import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class MapDiagnosticsSample {
  const MapDiagnosticsSample(
      {required this.seconds,
      required this.stage,
      required this.native,
      required this.renderer,
      required this.uiP95Ms,
      required this.rasterP95Ms,
      required this.maxFrameMs,
      required this.slowFrames,
      required this.frames,
      required this.sampleDelayMs});
  final double seconds;
  final String stage;
  final Map<String, dynamic> native;
  final Map<String, dynamic> renderer;
  final double uiP95Ms, rasterP95Ms, maxFrameMs, sampleDelayMs;
  final int slowFrames, frames;
  double? value(String name) => (native[name] as num?)?.toDouble();
}

class MapDiagnosticsController extends ChangeNotifier {
  static const _channel = MethodChannel('whereif/map_diagnostics');
  final _clock = Stopwatch()..start();
  final List<FrameTiming> _frames = [];
  final List<MapDiagnosticsSample> history = [];
  final List<String> stages = [];
  final Map<String, double> peaks = {};
  Map<String, dynamic> _renderer = {};
  String stage = 'Entrada';
  Timer? _timer;
  double frameBudgetMs = 16.67;
  bool _busy = false, _disposed = false;
  int _lastSampleMs = 0;
  MapDiagnosticsSample? get latest => history.isEmpty ? null : history.last;

  MapDiagnosticsController() {
    SchedulerBinding.instance.addTimingsCallback(_collectFrames);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _sample());
    unawaited(_sample());
  }

  void _collectFrames(List<FrameTiming> frames) {
    _frames.addAll(frames);
    if (_frames.length > 600) _frames.removeRange(0, _frames.length - 600);
  }

  void setStage(String next, {double? previousMs}) {
    if (_disposed || next == stage) return;
    stages.add(
        '${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s · $stage'
        '${previousMs == null ? '' : ' (${previousMs.round()} ms)'} → $next');
    if (stages.length > 12) stages.removeAt(0);
    stage = next;
    notifyListeners();
  }

  void updateRenderer(Map<String, dynamic> sample) {
    if (_disposed) return;
    final next = sample['stage'] as String?;
    if (next != null) {
      setStage(next,
          previousMs: (sample['previousStageMs'] as num?)?.toDouble());
    }
    _renderer = Map.of(sample);
    // Preserve short renderer spikes even between native samples.
    for (final key in ['renderCpuMaxMs', 'gpuMaxMs']) {
      final value = (sample[key] as num?)?.toDouble();
      if (value != null) peaks[key] = math.max(peaks[key] ?? 0, value);
    }
  }

  double _p95(List<double> values) {
    if (values.isEmpty) return 0;
    values.sort();
    return values[(values.length * 0.95).ceil() - 1];
  }

  Future<void> _sample() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      Map<String, dynamic> native;
      try {
        native = Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('sample') ?? {});
      } catch (_) {
        native = {'unavailable': true};
      }
      if (_disposed) return;
      final elapsed = _clock.elapsedMilliseconds;
      final frames = List<FrameTiming>.of(_frames);
      _frames.clear();
      final total =
          frames.map((f) => f.totalSpan.inMicroseconds / 1000).toList();
      final sample = MapDiagnosticsSample(
          seconds: elapsed / 1000,
          stage: stage,
          native: native,
          renderer: Map.of(_renderer),
          uiP95Ms: _p95(frames
              .map((f) => f.buildDuration.inMicroseconds / 1000)
              .toList()),
          rasterP95Ms: _p95(frames
              .map((f) => f.rasterDuration.inMicroseconds / 1000)
              .toList()),
          maxFrameMs: total.fold(0.0, math.max),
          frames: frames.length,
          slowFrames: total.where((ms) => ms > frameBudgetMs * 1.5).length,
          sampleDelayMs: _lastSampleMs == 0
              ? 0
              : math.max(0, elapsed - _lastSampleMs - 2000).toDouble());
      _lastSampleMs = elapsed;
      history.add(sample);
      if (history.length > 30) history.removeAt(0);
      for (final key in ['cpuPercent', 'appMemoryMb', 'graphicsMemoryMb']) {
        final value = sample.value(key);
        if (value != null) peaks[key] = math.max(peaks[key] ?? 0, value);
      }
      peaks['maxFrameMs'] =
          math.max(peaks['maxFrameMs'] ?? 0, sample.maxFrameMs);
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_collectFrames);
    super.dispose();
  }
}
