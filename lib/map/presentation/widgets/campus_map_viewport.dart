import 'dart:async';
import 'dart:convert';

import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapPerformanceSample {
  final double fps;
  final int drawCalls;
  final int triangles;
  final String graphicsProfile;
  final String graphicsProfilePreference;
  final double restingPixelRatio;
  final double interactionPixelRatio;
  final int shadowMapSize;
  final int atmosphereResolution;

  const MapPerformanceSample({
    required this.fps,
    required this.drawCalls,
    required this.triangles,
    required this.graphicsProfile,
    required this.graphicsProfilePreference,
    required this.restingPixelRatio,
    required this.interactionPixelRatio,
    required this.shadowMapSize,
    required this.atmosphereResolution,
  });
}

class MapRendererState {
  final String graphicsProfile;
  final String graphicsProfilePreference;
  final double restingPixelRatio;
  final double interactionPixelRatio;
  final int shadowMapSize;
  final int atmosphereResolution;

  const MapRendererState({
    required this.graphicsProfile,
    required this.graphicsProfilePreference,
    required this.restingPixelRatio,
    required this.interactionPixelRatio,
    required this.shadowMapSize,
    required this.atmosphereResolution,
  });
}

class CampusMapViewport extends StatefulWidget {
  final String assetPath;
  final String graphicsProfile;
  final List<MapZone> zones;
  final Color backgroundColor;
  final Color accentColor;
  final Color selectionFlashColor;
  final ValueChanged<MapZone?> onZoneSelected;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<MapPerformanceSample> onPerformanceChanged;
  final ValueChanged<MapRendererState> onReady;
  final ValueChanged<Object> onError;

  const CampusMapViewport({
    super.key,
    required this.assetPath,
    required this.graphicsProfile,
    required this.zones,
    required this.backgroundColor,
    required this.accentColor,
    required this.selectionFlashColor,
    required this.onZoneSelected,
    required this.onRotationChanged,
    required this.onPerformanceChanged,
    required this.onReady,
    required this.onError,
  });

  @override
  State<CampusMapViewport> createState() => CampusMapViewportState();
}

class CampusMapViewportState extends State<CampusMapViewport>
    with WidgetsBindingObserver {
  static const _previewLocalTimeMinutes = int.fromEnvironment(
    'MAP_PREVIEW_MINUTES',
    defaultValue: -1,
  );

  late final WebViewController _controller;
  late final Future<String> _modelDataUrl;
  bool _pageLoaded = false;
  Timer? _rotationTimer;
  Timer? _daylightTimer;
  int? _runtimePreviewLocalTimeMinutes;
  bool _followDeviceClock = false;
  final previewMinutes = ValueNotifier<int?>(
    _previewLocalTimeMinutes >= 0 ? _previewLocalTimeMinutes : null,
  );
  double _pendingRotation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _daylightTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshDaylight(),
    );
    _modelDataUrl = _loadModelDataUrl();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..addJavaScriptChannel(
        'MapBridge',
        onMessageReceived: _handleMapMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _pageLoaded = true;
            _prepareViewer();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              widget.onError(error.description);
            }
          },
        ),
      )
      ..loadFlutterAsset(_viewerAssetPath);
  }

  String get _viewerAssetPath {
    final separator = widget.assetPath.lastIndexOf('/');
    if (separator < 0) return 'viewer/index.html';
    return '${widget.assetPath.substring(0, separator)}/viewer/index.html';
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _daylightTimer?.cancel();
    previewMinutes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDaylight();
    }
  }

  @override
  void didUpdateWidget(CampusMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pageLoaded) return;

    if (oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.accentColor != widget.accentColor ||
        oldWidget.selectionFlashColor != widget.selectionFlashColor ||
        oldWidget.zones != widget.zones) {
      _configureViewer();
    }
    if (oldWidget.graphicsProfile != widget.graphicsProfile) {
      _prepareViewer();
    }
  }

  Future<void> _prepareViewer() async {
    try {
      final reloading = await _controller.runJavaScriptReturningResult(
        "window.whereIfMap.ensureGraphicsProfile('${widget.graphicsProfile}')",
      );
      if (reloading == true || reloading == 'true') return;
      await _configureViewer();
    } catch (error) {
      widget.onError(error);
    }
  }

  Future<void> _configureViewer() async {
    try {
      final modelDataUrl = await _modelDataUrl;
      final configuration = <String, Object>{
        'modelUrl': modelDataUrl,
        'backgroundColor': _cssHex(widget.backgroundColor),
        'accentColor': _cssHex(widget.accentColor),
        'selectionFlashColor': _cssHex(widget.selectionFlashColor),
        'localTimeMinutes': _currentLocalTimeMinutes,
        'zones': [
          for (final zone in widget.zones)
            {
              'id': zone.id,
              'nodeName': zone.nodeName,
              'focus': {
                'useVisualCenter': zone.focusOnVisualCenter,
                'constrainToNavigation': zone.constrainFocusToNavigation,
                if (zone.focusDirection case final direction?)
                  'direction': direction,
                'distanceScale': zone.focusDistanceScale,
                if (zone.focusTargetOffset case final targetOffset?)
                  'targetOffset': targetOffset,
              },
            },
        ],
      };

      await _controller.runJavaScript(
        'window.whereIfMap.configure(${jsonEncode(configuration)});',
      );
    } catch (error) {
      widget.onError(error);
    }
  }

  void _refreshDaylight() {
    if (!_pageLoaded) return;
    unawaited(_sendLocalTime());
  }

  int get _currentLocalTimeMinutes {
    if (_runtimePreviewLocalTimeMinutes case final minutes?) return minutes;
    if (!_followDeviceClock && _previewLocalTimeMinutes >= 0) {
      return _previewLocalTimeMinutes;
    }
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  Future<void> setPreviewLocalTimeMinutes(int? minutes) async {
    _runtimePreviewLocalTimeMinutes =
        minutes == null ? null : ((minutes % 1440) + 1440) % 1440;
    if (_pageLoaded) await _sendLocalTime();
  }

  Future<void> _sendLocalTime() async {
    try {
      await _controller.runJavaScript(
        'window.whereIfMap.setLocalTimeMinutes($_currentLocalTimeMinutes);',
      );
    } catch (error) {
      widget.onError(error);
    }
  }

  Future<String> _loadModelDataUrl() async {
    final bytes = await rootBundle.load(widget.assetPath);
    final encoded = base64Encode(bytes.buffer.asUint8List());
    return 'data:model/gltf-binary;base64,$encoded';
  }

  void _handleMapMessage(JavaScriptMessage message) {
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      switch (payload['type']) {
        case 'ready':
          widget.onReady(
            MapRendererState(
              graphicsProfile:
                  payload['graphicsProfile'] as String? ?? 'cinematic',
              graphicsProfilePreference:
                  payload['graphicsProfilePreference'] as String? ?? 'auto',
              restingPixelRatio:
                  (payload['restingPixelRatio'] as num?)?.toDouble() ?? 1.6,
              interactionPixelRatio:
                  (payload['interactionPixelRatio'] as num?)?.toDouble() ?? 0.5,
              shadowMapSize: (payload['shadowMapSize'] as num?)?.toInt() ?? 0,
              atmosphereResolution:
                  (payload['atmosphereResolution'] as num?)?.toInt() ?? 0,
            ),
          );
        case 'selected':
          final zoneId = payload['zoneId'] as String?;
          widget.onZoneSelected(_zoneById(zoneId));
        case 'camera':
          final bearing = payload['bearing'];
          if (bearing is num) {
            widget.onRotationChanged(bearing.toDouble());
          }
        case 'performance':
          final fps = payload['fps'];
          if (fps is num) {
            widget.onPerformanceChanged(
              MapPerformanceSample(
                fps: fps.toDouble(),
                drawCalls: (payload['drawCalls'] as num?)?.toInt() ?? 0,
                triangles: (payload['triangles'] as num?)?.toInt() ?? 0,
                graphicsProfile:
                    payload['graphicsProfile'] as String? ?? 'cinematic',
                graphicsProfilePreference:
                    payload['graphicsProfilePreference'] as String? ?? 'auto',
                restingPixelRatio:
                    (payload['restingPixelRatio'] as num?)?.toDouble() ?? 1.6,
                interactionPixelRatio:
                    (payload['interactionPixelRatio'] as num?)?.toDouble() ??
                        0.5,
                shadowMapSize: (payload['shadowMapSize'] as num?)?.toInt() ?? 0,
                atmosphereResolution:
                    (payload['atmosphereResolution'] as num?)?.toInt() ?? 0,
              ),
            );
          }
        case 'error':
          widget.onError(payload['message'] ?? 'Unknown map renderer error.');
      }
    } catch (error) {
      widget.onError(error);
    }
  }

  MapZone? _zoneById(String? id) {
    if (id == null) return null;
    for (final zone in widget.zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  Future<void> resetCamera() async {
    try {
      await _controller.runJavaScript('window.whereIfMap.resetCamera();');
    } catch (error) {
      widget.onError(error);
    }
  }

  Future<void> resetBearing() => _runDiagnosticCommand('resetBearing()');

  Future<Map<String, dynamic>> visualTestSettings() async {
    final result = await _controller.runJavaScriptReturningResult(
      'JSON.stringify(window.whereIfMap.visualTestSettings())',
    );
    dynamic decoded = result is String ? jsonDecode(result) : result;
    if (decoded is String) decoded = jsonDecode(decoded);
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> configureNightLook(Map<String, Object> settings) =>
      _runDiagnosticCommand('configureNightLook(${jsonEncode(settings)})');

  Future<void> configureBloom(Map<String, Object> settings) =>
      _runDiagnosticCommand('configureBloom(${jsonEncode(settings)})');

  Future<void> setToneMapping(String name) =>
      _runDiagnosticCommand('setToneMapping(${jsonEncode(name)})');

  Future<void> resetNightLook() => _runDiagnosticCommand('resetNightLook()');

  Future<void> previewTime(int? minutes) async {
    final normalized =
        minutes == null ? null : ((minutes % 1440) + 1440) % 1440;
    _followDeviceClock = normalized == null;
    _runtimePreviewLocalTimeMinutes = normalized;
    await _sendLocalTime();
    await _runDiagnosticCommand(normalized == null
        ? 'clearPreviewTime()'
        : 'setPreviewTimeMinutes($normalized)');
    if (mounted) previewMinutes.value = normalized;
  }

  Future<void> setRestingRenderScale(double scale) => _runDiagnosticCommand(
        'setRestingRenderScale(${scale.toStringAsFixed(2)})',
      );

  Future<void> setInteractionRenderScale(double scale) => _runDiagnosticCommand(
        'setInteractionRenderScale(${scale.toStringAsFixed(2)})',
      );

  Future<void> setShadowMapSize(int size) =>
      _runDiagnosticCommand('setShadowMapSize($size)');

  Future<void> setAtmosphereResolution(int resolution) =>
      _runDiagnosticCommand('setAtmosphereResolution($resolution)');

  Future<void> setGraphicsProfile(String profile) =>
      _runDiagnosticCommand("setGraphicsProfile('$profile')");

  Future<void> _runDiagnosticCommand(String command) async {
    if (!_pageLoaded) return;
    try {
      await _controller.runJavaScript('window.whereIfMap.$command;');
    } catch (error) {
      widget.onError(error);
    }
  }

  void rotateBy(double degrees) {
    if (degrees.abs() < 0.001) return;
    _pendingRotation += degrees;
    _rotationTimer ??= Timer(const Duration(milliseconds: 16), () {
      _rotationTimer = null;
      final pending = _pendingRotation;
      _pendingRotation = 0;
      unawaited(_dispatchRotation(pending));
    });
  }

  Future<void> beginRotationGesture() =>
      _runDiagnosticCommand('beginExternalRotation()');

  Future<void> endRotationGesture() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    final pending = _pendingRotation;
    _pendingRotation = 0;
    if (pending.abs() >= 0.001) await _dispatchRotation(pending);
    await _runDiagnosticCommand('endExternalRotation()');
  }

  Future<void> _dispatchRotation(double degrees) async {
    try {
      await _controller.runJavaScript(
        'window.whereIfMap.rotateCameraBy(${degrees.toStringAsFixed(3)});',
      );
    } catch (error) {
      widget.onError(error);
    }
  }

  String _cssHex(Color color) {
    final value = color.toARGB32() & 0x00ffffff;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}
