import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/responsive/app_responsive.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_resource.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/map/data/services/institution_map_metadata_loader.dart';
import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/presentation/widgets/campus_map_viewport.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_overlays.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_visual_test_panel.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_time_control.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_graphics_controller.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _viewportKey = GlobalKey<CampusMapViewportState>();
  final _bearing = ValueNotifier<double>(0);
  final _metadataLoader = const InstitutionMapMetadataLoader();
  late final MapGraphicsController _graphicsController;
  Future<List<MapZone>>? _zonesFuture;
  String? _metadataPath;
  MapZone? _selectedZone;
  bool _rendererReady = false;
  Object? _rendererError;
  bool _showVisualTests = false;

  @override
  void initState() {
    super.initState();
    _graphicsController = injector.get<MapGraphicsController>();
  }

  @override
  void dispose() {
    _bearing.dispose();
    super.dispose();
  }

  void _showSearchPlaceholder() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.mapSearchComingSoon),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final metadata = context.institution.map.metadataResource;
    if (metadata?.location == _metadataPath) return;

    _metadataPath = metadata?.location;
    _zonesFuture = metadata == null || !metadata.isBundled
        ? Future.value(const <MapZone>[])
        : _metadataLoader.load(metadata.location);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((_) => _buildMap(context));
  }

  Widget _buildMap(BuildContext context) {
    final graphicsProfile = _graphicsController.requestedRendererProfile;
    final institution = context.institution;
    final map = institution.map;
    final resource = map.primaryResource;
    final sceneColor =
        context.isDarkMode ? const Color(0xFF090A0D) : const Color(0xFFE8EAEE);

    if (!map.isConfigured || resource == null) {
      return ColoredBox(
        color: sceneColor,
        child: AppStatusView(
          icon: Icons.map_outlined,
          message: context.l10n.mapComingSoon,
        ),
      );
    }

    if (!resource.isBundled ||
        resource.kind != InstitutionResourceKind.mapBundle) {
      return ColoredBox(
        color: sceneColor,
        child: AppStatusView(
          icon: Icons.error_outline_rounded,
          message: context.l10n.mapComingSoon,
        ),
      );
    }

    return FutureBuilder<List<MapZone>>(
      future: _zonesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ColoredBox(
            color: sceneColor,
            child: AppStatusView(
              icon: Icons.error_outline_rounded,
              message: context.l10n.mapComingSoon,
            ),
          );
        }

        final zones = snapshot.data;
        if (zones == null) {
          return ColoredBox(
            color: sceneColor,
            child: AppStatusView.loading(color: context.secondary),
          );
        }

        return ColoredBox(
          color: sceneColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CampusMapViewport(
                key: _viewportKey,
                assetPath: resource.location,
                graphicsProfile: graphicsProfile,
                zones: zones,
                backgroundColor: sceneColor,
                accentColor: context.secondary,
                selectionFlashColor: context.colors.error,
                onZoneSelected: (zone) {
                  if (mounted) setState(() => _selectedZone = zone);
                },
                onRotationChanged: (bearing) => _bearing.value = bearing,
                onPerformanceChanged: (_) {},
                onReady: (rendererState) {
                  if (!mounted) return;
                  _graphicsController.acceptDetectedProfile(
                    rendererState.graphicsProfile,
                  );
                  setState(() {
                    _rendererReady = true;
                  });
                },
                onError: (error) {
                  if (mounted) setState(() => _rendererError = error);
                },
              ),
              if (!_rendererReady && _rendererError == null)
                ColoredBox(
                  color: sceneColor,
                  child: AppStatusView.loading(color: context.secondary),
                ),
              if (_rendererError != null)
                ColoredBox(
                  color: sceneColor,
                  child: AppStatusView(
                    icon: Icons.view_in_ar_outlined,
                    message: context.l10n.mapComingSoon,
                  ),
                ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: context.extraPagePadding.copyWith(top: 18),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: MapHeader(
                      campusName: institution.branding.campusName,
                      hint: context.l10n.mapInteractionHint,
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: context.extraPagePadding.copyWith(top: 14),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: MapControlButton(
                      tooltip: context.l10n.mapSearch,
                      icon: Icons.search_rounded,
                      onPressed: _showSearchPlaceholder,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: context.extraPagePadding.left,
                right: context.extraPagePadding.right,
                bottom: context.responsive.isVeryCompact ? 76 : 92,
                child: ValueListenableBuilder<double>(
                  valueListenable: _bearing,
                  builder: (context, bearing, _) {
                    return MapBearingControl(
                      bearing: bearing,
                      tooltip: context.l10n.mapRotate,
                      resetTooltip: context.l10n.mapResetView,
                      onRotate: (degrees) =>
                          _viewportKey.currentState?.rotateBy(degrees),
                      onRotateStart: () =>
                          _viewportKey.currentState?.beginRotationGesture(),
                      onRotateEnd: () =>
                          _viewportKey.currentState?.endRotationGesture(),
                      onReset: () => _viewportKey.currentState?.resetBearing(),
                    );
                  },
                ),
              ),
              Positioned(
                left: context.extraPagePadding.left,
                right: context.extraPagePadding.right,
                bottom: context.responsive.isVeryCompact ? 142 : 166,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                      reverseCurve: Curves.easeInCubic,
                    );
                    return ScaleTransition(
                      scale: Tween(begin: 0.94, end: 1.0).animate(curved),
                      child: FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _selectedZone == null
                      ? const SizedBox.shrink(key: ValueKey('no-zone'))
                      : MapSelectedZonePill(
                          key: ValueKey(_selectedZone!.id),
                          zone: _selectedZone!,
                          unavailableLabel: context.l10n.mapInteriorComingSoon,
                        ),
                ),
              ),
              if (_rendererReady && _viewportKey.currentState != null)
                Positioned(
                  left: context.extraPagePadding.left,
                  right: context.extraPagePadding.right,
                  top: MediaQuery.paddingOf(context).top + 74,
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(
                        child: MapTimeControl(
                            viewport: _viewportKey.currentState!)),
                    const SizedBox(width: 8),
                    MapControlButton(
                      tooltip: 'Testar iluminação e texturas',
                      icon: Icons.tune_rounded,
                      onPressed: () =>
                          setState(() => _showVisualTests = !_showVisualTests),
                    ),
                  ]),
                ),
              if (_rendererReady &&
                  _showVisualTests &&
                  _viewportKey.currentState != null)
                Positioned(
                  left: context.extraPagePadding.left,
                  right: context.extraPagePadding.right,
                  top: MediaQuery.paddingOf(context).top + 130,
                  height: (MediaQuery.sizeOf(context).height * 0.46)
                      .clamp(220.0, 420.0),
                  child: MapVisualTestPanel(
                    viewport: _viewportKey.currentState!,
                    onClose: () => setState(() => _showVisualTests = false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
