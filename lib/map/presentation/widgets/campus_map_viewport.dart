import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'map_viewer_navigation_policy.dart';

// Keep the asset compressed across the platform bridge. Decompression here
// is only a compatibility fallback for old WebViews without gzip streams.
String _encodeMapAsset((Uint8List, bool) input) {
  final bytes = input.$2 ? GZipCodec().decode(input.$1) : input.$1;
  return base64Encode(bytes);
}

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
  final int? climateMinutes;
  final bool? performanceMode;
  final ValueChanged<bool>? onPerformanceModeChanged;
  final List<Map<String, Object?>> eventMarkers;
  final ValueChanged<Map<String, dynamic>>? onEventSelected;
  final ValueChanged<Map<String, dynamic>>? onEventNavigationChanged;
  final Color backgroundColor;
  final Color accentColor;
  final Color selectionFlashColor;
  final ValueChanged<MapZone?> onZoneSelected;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<bool>? onViewModeChanged;
  final ValueChanged<Map<String, dynamic>>? onInteriorChanged;
  final ValueChanged<Map<String, dynamic>>? onSelectionOptionsChanged;
  final ValueChanged<bool>? onInterfaceBlurChanged;
  final ValueChanged<bool>? onNavBlurChanged;
  final ValueChanged<bool>? onRawModeChanged;
  final ValueChanged<MapPerformanceSample> onPerformanceChanged;
  final ValueChanged<MapRendererState> onReady;
  final ValueChanged<Map<String, dynamic>>? onDiagnosticsChanged;
  final ValueChanged<String>? onLoadingStage;
  final ValueChanged<Object> onError;

  const CampusMapViewport({
    super.key,
    required this.assetPath,
    required this.graphicsProfile,
    this.climateMinutes,
    this.performanceMode,
    this.onPerformanceModeChanged,
    this.eventMarkers = const [],
    this.onEventSelected,
    this.onEventNavigationChanged,
    required this.zones,
    required this.backgroundColor,
    required this.accentColor,
    required this.selectionFlashColor,
    required this.onZoneSelected,
    required this.onRotationChanged,
    this.onViewModeChanged,
    this.onInteriorChanged,
    this.onSelectionOptionsChanged,
    this.onInterfaceBlurChanged,
    this.onNavBlurChanged,
    this.onRawModeChanged,
    required this.onPerformanceChanged,
    required this.onReady,
    this.onDiagnosticsChanged,
    this.onLoadingStage,
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
  static const _runtimeChannel = MethodChannel('whereif/map_runtime');

  Future<void> _setNativeMapActive(bool active) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _runtimeChannel.invokeMethod<void>('setActive', {'active': active});
    } on PlatformException catch (_) {
      // Refresh-rate hints are optional; rendering still works if rejected.
    } on MissingPluginException catch (_) {}
  }

  Future<String>? _modelDataUrl;
  bool _pageLoaded = false;
  bool _modelUploaded = false;
  bool _configurationRunning = false;
  bool _configurationPending = false;
  bool _eventsRunning = false;
  bool _eventsPending = false;
  int _viewerGeneration = 0;
  String? _lastEventsConfiguration;
  Timer? _rotationTimer;
  Timer? _daylightTimer;
  int? _runtimePreviewLocalTimeMinutes;
  bool _followDeviceClock = false;
  double _pendingRotation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setNativeMapActive(true));
    _runtimePreviewLocalTimeMinutes = widget.climateMinutes;
    _followDeviceClock = widget.climateMinutes == null;
    _daylightTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshDaylight(),
    );
    _modelDataUrl = _loadModelDataUrl();
    _observeModelLoading();
    _controller = WebViewController();
    unawaited(_initializeViewer());
  }

  void _observeModelLoading() {
    final future = _modelDataUrl;
    unawaited(_modelDataUrl?.then<void>((_) {}, onError: (Object error) {
      if (mounted && identical(future, _modelDataUrl)) widget.onError(error);
    }));
  }

  Future<void> _initializeViewer() async {
    try {
      if (const bool.fromEnvironment('MAP_CAMERA_CAPTURE') &&
          defaultTargetPlatform == TargetPlatform.android) {
        await AndroidWebViewController.enableDebugging(true);
        if (!mounted) return;
      }
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      await _controller.setBackgroundColor(widget.backgroundColor);
      if (!mounted) return;
      await _controller.addJavaScriptChannel(
        'MapBridge',
        onMessageReceived: _handleMapMessage,
      );
      if (!mounted) return;
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => mounted &&
                  isMapViewerNavigationAllowed(request.url, _viewerAssetPath)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (_) {
            if (!mounted) return;
            _viewerGeneration++;
            _pageLoaded = false;
            _modelUploaded = false;
            _lastEventsConfiguration = null;
          },
          onPageFinished: (url) {
            if (!mounted ||
                !isMapViewerNavigationAllowed(url, _viewerAssetPath)) {
              return;
            }
            final resumed = WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;
            unawaited(_setNativeMapActive(resumed));
            _pageLoaded = true;
            unawaited(_prepareViewer());
            if (!resumed) {
              unawaited(_runViewerCommand('setVisible(false)'));
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              widget.onError(error.description);
            }
          },
        ),
      );
      if (!mounted) return;
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setAllowFileAccess(false);
        if (!mounted) return;
        await platform.setAllowContentAccess(false);
      }
      if (mounted) await _controller.loadFlutterAsset(_viewerAssetPath);
    } catch (error) {
      if (mounted) widget.onError(error);
    }
  }

  String get _viewerAssetPath {
    final separator = widget.assetPath.lastIndexOf('/');
    if (separator < 0) return 'viewer/index.html';
    return '${widget.assetPath.substring(0, separator)}/viewer/index.html';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.platform is AndroidWebViewController &&
        const bool.fromEnvironment('MAP_DIRECT_COMPOSITION')) {
      // A/B switch for the same map/settings. Native composition avoids
      // redirecting each WebGL frame through an Android SurfaceTexture.
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: _controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }

  @override
  void dispose() {
    _viewerGeneration++;
    _pageLoaded = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_setNativeMapActive(false));
    _rotationTimer?.cancel();
    _daylightTimer?.cancel();
    // Explicitly release the WebGL context. Removing a platform view alone
    // may leave its large GPU resources alive until Chromium collects it.
    unawaited(_controller
        .runJavaScript('window.whereIfMap?.disposeViewer?.();')
        .catchError((Object _) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_setNativeMapActive(state == AppLifecycleState.resumed));
    if (_pageLoaded) {
      unawaited(_controller
          .runJavaScript(
            'window.whereIfMap?.setVisible?.(${state == AppLifecycleState.resumed});',
          )
          .catchError((Object _) {}));
    }
    if (state == AppLifecycleState.resumed) {
      _refreshDaylight();
    }
  }

  @override
  void didUpdateWidget(CampusMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _viewerGeneration++;
      _pageLoaded = false;
      _modelUploaded = false;
      _lastEventsConfiguration = null;
      _modelDataUrl = _loadModelDataUrl();
      _observeModelLoading();
      unawaited(_reloadViewer());
      return;
    }
    if (oldWidget.climateMinutes != widget.climateMinutes) {
      _runtimePreviewLocalTimeMinutes = widget.climateMinutes;
      _followDeviceClock = widget.climateMinutes == null;
      if (_pageLoaded) unawaited(previewTime(widget.climateMinutes));
    }
    if (!_pageLoaded) return;
    unawaited(_sendEventConfiguration());

    if (oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.performanceMode != widget.performanceMode ||
        oldWidget.accentColor != widget.accentColor ||
        oldWidget.selectionFlashColor != widget.selectionFlashColor ||
        oldWidget.zones != widget.zones) {
      unawaited(_configureViewer());
    }
    if (oldWidget.graphicsProfile != widget.graphicsProfile) {
      unawaited(_prepareViewer());
    }
  }

  Future<void> _prepareViewer() async {
    if (!mounted || !_pageLoaded) return;
    final generation = _viewerGeneration;
    try {
      final reloading = await _controller.runJavaScriptReturningResult(
        'window.whereIfMap.ensureGraphicsProfile(${jsonEncode(widget.graphicsProfile)})',
      );
      if (!mounted || generation != _viewerGeneration) return;
      if (reloading == true || reloading == 'true') return;
      await _configureViewer();
    } catch (error) {
      if (mounted && generation == _viewerGeneration) widget.onError(error);
    }
  }

  Future<void> _reloadViewer() async {
    final generation = _viewerGeneration;
    try {
      await _controller.runJavaScript('window.whereIfMap?.disposeViewer?.();');
      if (mounted && generation == _viewerGeneration) {
        await _controller.loadFlutterAsset(_viewerAssetPath);
      }
    } catch (error) {
      if (mounted && generation == _viewerGeneration) widget.onError(error);
    }
  }

  Future<void> _configureViewer() async {
    if (!mounted || !_pageLoaded) return;
    if (_configurationRunning) {
      _configurationPending = true;
      return;
    }
    _configurationRunning = true;
    final generation = _viewerGeneration;
    bool isCurrent() =>
        mounted && generation == _viewerGeneration && _pageLoaded;
    try {
      if (!_modelUploaded) {
        widget.onLoadingStage?.call('Transferindo mapa');
        final supportsGzip = await _controller.runJavaScriptReturningResult(
          "typeof DecompressionStream === 'function'",
        );
        if (!isCurrent()) return;
        final gzipAsset = widget.assetPath.endsWith('.gz');
        final compressed =
            gzipAsset && (supportsGzip == true || supportsGzip == 'true');
        final encoded = gzipAsset && !compressed
            ? await _loadModelDataUrl(decompress: true)
            : await (_modelDataUrl ??= _loadModelDataUrl());
        if (!isCurrent()) return;
        await _controller.runJavaScript(
          'window.whereIfMap.beginModelTransfer(${jsonEncode(compressed ? 'gzip' : 'glb')}, ${encoded.length});',
        );
        // Bound each platform message: copying/parsing a single giant JS
        // string on Android's main thread stalls the whole loading animation.
        const chunkSize = 64 * 1024; // Multiple of four for independent base64.
        final transferSlice = Stopwatch()..start();
        for (var offset = 0; offset < encoded.length; offset += chunkSize) {
          if (!isCurrent()) return;
          final end = (offset + chunkSize).clamp(0, encoded.length);
          final chunk = encoded.substring(offset, end);
          await _controller.runJavaScript(
            "window.whereIfMap.appendModelChunk('$chunk');",
          );
          // Yield after a short work slice rather than sleeping after every
          // message. Messages stay small and the loading animation can paint.
          if (transferSlice.elapsedMilliseconds >= 6) {
            await Future<void>.delayed(Duration.zero);
            transferSlice.reset();
          }
        }
        if (!isCurrent()) return;
        _modelUploaded = true;
        _modelDataUrl = null;
        rootBundle.evict(widget.assetPath);
      }
      if (!isCurrent()) return;
      final configuration = <String, Object>{
        'diagnosticsEnabled': widget.onDiagnosticsChanged != null,
        'backgroundColor': _cssHex(widget.backgroundColor),
        'accentColor': _cssHex(widget.accentColor),
        'selectionFlashColor': _cssHex(widget.selectionFlashColor),
        'localTimeMinutes': _currentLocalTimeMinutes,
        if (widget.performanceMode case final enabled?)
          'performanceMode': enabled,
        'zones': [
          for (final zone in widget.zones)
            {
              'id': zone.id,
              'nodeName': zone.nodeName,
              'floors': [for (final floor in zone.floors) floor.toJson()],
              'focus': {
                'useVisualCenter': zone.focusOnVisualCenter,
                'constrainToNavigation': zone.constrainFocusToNavigation,
                if (zone.focusDirection case final direction?)
                  'direction': direction,
                'distanceScale': zone.focusDistanceScale,
                if (zone.focusTargetOffset case final targetOffset?)
                  'targetOffset': targetOffset,
                if (zone.focusPosition case final position?)
                  'position': position,
                if (zone.focusTarget case final target?) 'target': target,
              },
            },
        ],
      };

      await _controller.runJavaScript(
        'window.whereIfMap.configure(${jsonEncode(configuration)});',
      );
      if (!isCurrent()) return;
      await _sendEventConfiguration();
    } catch (error) {
      if (isCurrent()) widget.onError(error);
    } finally {
      _configurationRunning = false;
      if (_configurationPending && mounted) {
        _configurationPending = false;
        unawaited(_configureViewer());
      }
    }
  }

  void _refreshDaylight() {
    if (!_pageLoaded) return;
    unawaited(_sendLocalTime());
  }

  Future<void> _sendEventConfiguration() async {
    if (!mounted || !_pageLoaded) return;
    if (_eventsRunning) {
      _eventsPending = true;
      return;
    }
    _eventsRunning = true;
    final generation = _viewerGeneration;
    try {
      final encoded = jsonEncode(widget.eventMarkers);
      if (encoded == _lastEventsConfiguration) return;
      await _controller
          .runJavaScript('window.whereIfMap.setEventMarkers($encoded);');
      if (mounted && generation == _viewerGeneration) {
        _lastEventsConfiguration = encoded;
      }
    } catch (error) {
      if (mounted && generation == _viewerGeneration) widget.onError(error);
    } finally {
      _eventsRunning = false;
      if (_eventsPending && mounted) {
        _eventsPending = false;
        unawaited(_sendEventConfiguration());
      }
    }
  }

  int get _currentLocalTimeMinutes {
    if (_runtimePreviewLocalTimeMinutes case final minutes?) return minutes;
    if (!_followDeviceClock && _previewLocalTimeMinutes >= 0) {
      return _previewLocalTimeMinutes;
    }
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  Future<void> _sendLocalTime() async {
    await _runViewerCommand('setLocalTimeMinutes($_currentLocalTimeMinutes)');
  }

  Future<String> _loadModelDataUrl({bool decompress = false}) async {
    final bytes = await rootBundle.load(widget.assetPath);
    final assetBytes = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    return compute(_encodeMapAsset, (assetBytes, decompress));
  }

  void _handleMapMessage(JavaScriptMessage message) {
    if (!mounted || !_pageLoaded) return;
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      switch (payload['type']) {
        case 'eventSelected':
          widget.onEventSelected?.call(payload);
        case 'eventNavigation':
          widget.onEventNavigationChanged?.call(payload);
        case 'performanceMode':
          final enabled = payload['enabled'];
          if (enabled is bool &&
              payload['source'] != 'request' &&
              (payload['source'] != 'initial' ||
                  widget.performanceMode == null)) {
            widget.onPerformanceModeChanged?.call(enabled);
          }
        case 'interior':
          widget.onInteriorChanged?.call(payload);
        case 'selectionOptions':
          final options = payload['options'];
          if (options is Map<String, dynamic>) {
            widget.onSelectionOptionsChanged?.call(options);
          }
        case 'interfaceBlur':
          final enabled = payload['enabled'];
          if (enabled is bool) widget.onInterfaceBlurChanged?.call(enabled);
        case 'navBlur':
          final enabled = payload['enabled'];
          if (enabled is bool) widget.onNavBlurChanged?.call(enabled);
        case 'rawMode':
          widget.onRawModeChanged?.call(payload['enabled'] == true);
        case 'diagnostics':
          widget.onDiagnosticsChanged?.call(payload);
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
        case 'viewMode':
          widget.onViewModeChanged?.call(payload['mode'] == '2d');
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
    await _runViewerCommand('resetCamera()');
  }

  Future<void> resetBearing() => _runViewerCommand('resetBearing()');

  Future<void> setTopView(bool enabled) =>
      _runViewerCommand("setMapViewMode('${enabled ? '2d' : '3d'}')");

  Future<void> setInteriorFloor(String zoneId, String? floorId) =>
      _runViewerCommand(
        'setInteriorFloor(${jsonEncode(zoneId)}, ${jsonEncode(floorId)})',
      );

  Future<void> navigateToMapLocation(MapLocation location) => _runViewerCommand(
      'navigateToMapLocation(${jsonEncode(location.toJson())})'
      '.then(ok=>MapBridge.postMessage(JSON.stringify({type:"eventNavigation",key:${jsonEncode(location.key)},ok})))'
      '.catch(()=>MapBridge.postMessage(JSON.stringify({type:"eventNavigation",key:${jsonEncode(location.key)},ok:false})));');
  Future<void> cancelEventNavigation() =>
      _runViewerCommand('cancelEventNavigation()');

  Future<void> previewTime(int? minutes) async {
    final normalized =
        minutes == null ? null : ((minutes % 1440) + 1440) % 1440;
    _followDeviceClock = normalized == null;
    _runtimePreviewLocalTimeMinutes = normalized;
    await _sendLocalTime();
    await _runViewerCommand(normalized == null
        ? 'clearPreviewTime()'
        : 'setPreviewTimeMinutes($normalized)');
  }

  Future<void> _runViewerCommand(String command) async {
    if (!mounted || !_pageLoaded) return;
    final generation = _viewerGeneration;
    try {
      await _controller.runJavaScript('window.whereIfMap.$command;');
    } catch (error) {
      if (mounted && generation == _viewerGeneration) widget.onError(error);
    }
  }

  void rotateBy(double degrees) {
    if (!mounted ||
        !_pageLoaded ||
        !degrees.isFinite ||
        degrees.abs() < 0.001) {
      return;
    }
    _pendingRotation += degrees;
    _rotationTimer ??= Timer(const Duration(milliseconds: 16), () {
      _rotationTimer = null;
      final pending = _pendingRotation;
      _pendingRotation = 0;
      unawaited(_dispatchRotation(pending));
    });
  }

  Future<void> beginRotationGesture() =>
      _runViewerCommand('beginExternalRotation()');

  Future<void> endRotationGesture() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    final pending = _pendingRotation;
    _pendingRotation = 0;
    if (pending.abs() >= 0.001) await _dispatchRotation(pending);
    await _runViewerCommand('endExternalRotation()');
  }

  Future<void> _dispatchRotation(double degrees) async {
    await _runViewerCommand('rotateCameraBy(${degrees.toStringAsFixed(3)})');
  }

  String _cssHex(Color color) {
    final value = color.toARGB32() & 0x00ffffff;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}
