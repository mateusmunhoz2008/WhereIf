import 'dart:async';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/events_catalog/events_catalog_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/controllers/event_lifecycle_refresh_scheduler.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/map/domain/models/map_event_entry.dart';
import 'package:go_router/go_router.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/responsive/app_responsive.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/core/widgets/app_glass_surface.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_resource.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/map/data/services/institution_map_metadata_loader.dart';
import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:autth_injustice_app/map/domain/models/map_selection_options.dart';
import 'package:autth_injustice_app/map/presentation/widgets/campus_map_viewport.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_overlays.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_search_overlay.dart';
import 'package:autth_injustice_app/map/presentation/widgets/map_loading_transition.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_climate_controller.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_performance_controller.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MapPage extends StatefulWidget {
  final EventPreview? initialEvent;
  const MapPage({super.key, this.initialEvent});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final GlobalKey<CampusMapViewportState> _viewportKey = GlobalKey();
  final _bearing = ValueNotifier<double>(0);
  final _metadataLoader = const InstitutionMapMetadataLoader();
  late final MapClimateController _climateController;
  late final MapPerformanceController _performanceController;
  late final EventsCatalogViewModel _eventsController;
  final _eventLifecycle = EventLifecycleRefreshScheduler();
  List<MapEventEntry> _eventEntries = const [];
  List<MapEventEntry> _visibleEventEntries = const [];
  List<MapZone> _loadedZones = const [];
  String? _selectedEventLocationKey;
  bool _initialEventOpened = false, _openingEventDetails = false;
  Future<List<MapZone>>? _zonesFuture;
  String? _metadataPath;
  MapZone? _selectedZone;
  String? _interiorFloorId;
  String? _interiorSpaceLabel;
  bool _interiorBusy = false;
  MapSelectionOptions _selectionOptions = const MapSelectionOptions();
  bool _rendererReady = false;
  bool _is2D = false;
  Object? _rendererError;

  @override
  void initState() {
    super.initState();
    _climateController = injector.get<MapClimateController>();
    _performanceController = injector.get<MapPerformanceController>();
    _eventsController = injector.get<EventsCatalogViewModel>();
    unawaited(_eventsController.commands.loadCatalog(forceRefresh: true));
  }

  @override
  void dispose() {
    _bearing.dispose();
    _eventLifecycle.dispose();
    super.dispose();
  }

  void _visitEventLocation(MapLocation location) {
    if (!_rendererReady) return;
    _selectedEventLocationKey = location.key;
    final viewport = _viewportKey.currentState;
    if (viewport == null) return;
    unawaited(
        viewport.navigateToMapLocation(location).catchError((Object error) {
      if (mounted && _selectedEventLocationKey == location.key) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.mapLocationUnavailable)));
      }
    }));
  }

  void _eventSelected(Map<String, dynamic> payload) {
    if (payload['mode'] == 'exterior') {
      final candidates =
          _loadedZones.where((zone) => zone.id == payload['zoneId']);
      if (candidates.isEmpty) return;
      final destination = MapEventFloorSummary.fromEntries(
              _visibleEventEntries, candidates.first)
          .destination;
      if (destination != null) _visitEventLocation(destination);
      return;
    }
    final candidates =
        _eventEntries.where((entry) => entry.event.id == payload['eventId']);
    if (candidates.isEmpty) return;
    final entry = candidates.first;
    final references = MapLocation.readList([payload['location']]);
    final destinations = references.isEmpty
        ? const <MapLocation>[]
        : entry.locations
            .where((location) => location == references.first)
            .toList();
    if (destinations.isEmpty) return;
    if (payload['mode'] == 'place') {
      if (_openingEventDetails) return;
      _openingEventDetails = true;
      unawaited(context.pushNamed(EventsRouteNames.details,
          pathParameters: {'eventId': entry.event.id}).whenComplete(() {
        _openingEventDetails = false;
      }));
    } else {
      _visitEventLocation(destinations.first);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final metadata = context.institution.map.metadataResource;
    if (metadata?.location == _metadataPath) return;

    _metadataPath = metadata?.location;
    _rendererReady = false;
    _rendererError = null;
    _selectedZone = null;
    _interiorFloorId = null;
    _interiorSpaceLabel = null;
    _interiorBusy = false;
    _selectionOptions = const MapSelectionOptions();
    _zonesFuture = metadata == null || !metadata.isBundled
        ? Future.value(const <MapZone>[])
        : _metadataLoader.load(metadata.location);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((_) => _buildMap(context));
  }

  Widget _buildMap(BuildContext context) {
    final climateMinutes = _climateController.climate.value.previewMinutes;
    final catalogEvents = <String, EventPreview>{
      for (final event in [
        ..._eventsController.state.featuredEvents.value,
        ..._eventsController.state.futureEvents.value,
      ])
        event.id: event,
    }.values.toList();
    _eventLifecycle.schedule(
        events: catalogEvents,
        onRefresh: () {
          if (mounted) setState(() {});
        });
    final performanceMode = _performanceController.enabled.value;
    final selectedFloorIndex = _selectedZone?.floors
            .indexWhere((floor) => floor.id == _interiorFloorId) ??
        -1;
    final interiorTitle = _interiorSpaceLabel ??
        (selectedFloorIndex >= 0 ? 'Piso ${selectedFloorIndex + 1}' : null);
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
        _loadedZones = zones ?? const [];
        final locationCatalog =
            MapLocationCatalog(institution.id, zones ?? const []);
        final visibleEvents = MapEventEntry.fromEvents(
            catalogEvents, locationCatalog, DateTime.now());
        _visibleEventEntries = visibleEvents;
        _eventEntries = visibleEvents;
        final initial = widget.initialEvent;
        if (initial != null &&
            !_eventEntries.any((entry) => entry.event.id == initial.id)) {
          final places = initial.mapLocations
              .map(locationCatalog.resolve)
              .whereType<MapLocation>()
              .toList();
          if (places.isNotEmpty) {
            _eventEntries = [..._eventEntries, MapEventEntry(initial, places)];
          }
        }
        if (_rendererReady && !_initialEventOpened && initial != null) {
          _initialEventOpened = true;
          final matching =
              _eventEntries.where((entry) => entry.event.id == initial.id);
          if (matching.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _visitEventLocation(matching.first.locations.first);
            });
          }
        }
        String css(Color color) =>
            '#${(color.toARGB32() & 0x00ffffff).toRadixString(16).padLeft(6, '0')}';
        return Stack(fit: StackFit.expand, children: [
          MapLoadingTransition(
            key: ValueKey(resource.location),
            ready: _rendererReady || _rendererError != null,
            primary: context.primary,
            secondary: context.secondary,
            loadingLabel: context.l10n.mapLoading,
            child: ColoredBox(
              color: sceneColor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (zones != null)
                    CampusMapViewport(
                      key: _viewportKey,
                      assetPath: resource.location,
                      graphicsProfile: 'basic',
                      climateMinutes: climateMinutes,
                      performanceMode: performanceMode,
                      eventMarkers: [
                        for (final entry in visibleEvents)
                          {
                            'eventId': entry.event.id,
                            'dark': context.isDarkMode,
                            'title': entry.event.title,
                            'color': css(context.colors.secondary),
                            'foreground': css(context.colors.onSecondary),
                            'surface': css(context.colors.surfaceContainerLow),
                            'onSurface': css(context.colors.onSurface),
                            'stackColor':
                                css(context.colors.secondaryContainer),
                            'stackBackColor':
                                css(context.colors.surfaceContainerHigh),
                            'exteriorLabel':
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'Event'
                                    : 'Evento',
                            'imageUrl': entry.event.imageUrl,
                            'locations': [
                              for (final place in entry.locations)
                                place.toJson()
                            ],
                          }
                      ],
                      onEventSelected: _eventSelected,
                      onEventNavigationChanged: (payload) {
                        if (!mounted ||
                            payload['key'] != _selectedEventLocationKey) {
                          return;
                        }
                        if (payload['ok'] != true) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(context.l10n.mapLocationUnavailable)));
                        }
                      },
                      onPerformanceModeChanged: (enabled) {
                        _performanceController.acceptRendererMode(enabled);
                      },
                      zones: zones,
                      backgroundColor: sceneColor,
                      accentColor: context.secondary,
                      selectionFlashColor: context.colors.error,
                      onZoneSelected: (zone) {
                        if (mounted) setState(() => _selectedZone = zone);
                      },
                      onSelectionOptionsChanged: (options) {
                        if (mounted) {
                          setState(() => _selectionOptions =
                              MapSelectionOptions.fromJson(options));
                        }
                      },
                      onInterfaceBlurChanged: (enabled) {
                        AppGlassSurface.mapBlurTestEnabled.value = enabled;
                      },
                      onNavBlurChanged: (enabled) {
                        AppGlassSurface.mapNavigationBlurTestEnabled.value =
                            enabled;
                      },
                      onRotationChanged: (bearing) => _bearing.value = bearing,
                      onViewModeChanged: (is2D) {
                        if (mounted && _is2D != is2D) {
                          setState(() => _is2D = is2D);
                        }
                      },
                      onInteriorChanged: (state) {
                        if (!mounted) return;
                        setState(() {
                          _interiorFloorId = state['floorId'] as String?;
                          _interiorSpaceLabel = state['spaceLabel'] as String?;
                          _interiorBusy = state['busy'] == true;
                        });
                        if (state['message'] case final String message) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      },
                      onPerformanceChanged: (_) {},
                      onReady: (rendererState) {
                        if (!mounted) return;
                        setState(() {
                          _rendererReady = true;
                        });
                      },
                      onError: (error) {
                        if (mounted) setState(() => _rendererError = error);
                      },
                    ),
                  if (_rendererError != null)
                    ColoredBox(
                      color: sceneColor,
                      child: AppStatusView(
                        icon: Icons.view_in_ar_outlined,
                        message: _rendererError.toString(),
                      ),
                    ),
                  if (_rendererReady && _rendererError == null) ...[
                    if (_selectedZone case final zone?
                        when zone.floors.isNotEmpty && _selectionOptions.floors)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: MapFloorPill(
                              floors: zone.floors,
                              eventCounts: MapEventFloorSummary.fromEntries(
                                      visibleEvents, zone)
                                  .counts,
                              eventCountLabel: context.l10n.mapFloorEventCount,
                              selectedId: _interiorFloorId,
                              busy: _interiorBusy,
                              animationEnabled: _selectionOptions.uiAnimation,
                              blurEnabled: _selectionOptions.glass,
                              onSelected: (id) => _viewportKey.currentState
                                  ?.setInteriorFloor(zone.id, id),
                            ),
                          ),
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
                    Positioned(
                      left: context.extraPagePadding.left,
                      right: context.extraPagePadding.right,
                      bottom: context.responsive.isVeryCompact ? 76 : 80,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _bearing,
                        builder: (context, bearing, _) {
                          return MapBearingControl(
                            bearing: bearing,
                            tooltip: context.l10n.mapRotate,
                            resetTooltip: context.l10n.mapResetView,
                            is2D: _is2D,
                            onToggleView: () =>
                                _viewportKey.currentState?.setTopView(!_is2D),
                            onRotate: (degrees) =>
                                _viewportKey.currentState?.rotateBy(degrees),
                            onRotateStart: () => _viewportKey.currentState
                                ?.beginRotationGesture(),
                            onRotateEnd: () =>
                                _viewportKey.currentState?.endRotationGesture(),
                            onReset: () =>
                                _viewportKey.currentState?.resetBearing(),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: context.extraPagePadding.left,
                      right: context.extraPagePadding.right,
                      bottom: context.responsive.isVeryCompact ? 142 : 166,
                      child: AnimatedSwitcher(
                        duration: _selectionOptions.uiAnimation
                            ? const Duration(milliseconds: 260)
                            : Duration.zero,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          if (!_selectionOptions.uiAnimation) return child;
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
                        child: _selectedZone == null ||
                                !_selectionOptions.labels
                            ? const SizedBox.shrink(key: ValueKey('no-zone'))
                            : MapSelectedZonePill(
                                key: ValueKey('${_selectedZone!.id}-'
                                    '$_interiorFloorId-$_interiorSpaceLabel'),
                                zone: _selectedZone!,
                                blurEnabled: _selectionOptions.glass,
                                title: interiorTitle,
                                icon: _interiorSpaceLabel != null
                                    ? Icons.meeting_room_rounded
                                    : _interiorFloorId != null
                                        ? Icons.layers_rounded
                                        : null,
                                unavailableLabel: _interiorFloorId != null
                                    ? _selectedZone!.label
                                    : _selectedZone!.floors.isNotEmpty
                                        ? 'Escolha um andar à esquerda'
                                        : context.l10n.mapInteriorComingSoon,
                              ),
                      ),
                    ),
                    MapSearchOverlay(
                      locations: locationCatalog.locations,
                      events: visibleEvents,
                      onSelected: (result) =>
                          _visitEventLocation(result.destination),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}
