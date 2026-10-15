import 'package:autth_injustice_app/map/presentation/pages/map_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';

class MapRouteNames {
  static const map = 'map';
}

class MapPaths {
  static const map = '/map';
}

final mapRoute = GoRoute(
  path: MapPaths.map,
  name: MapRouteNames.map,
  pageBuilder: (context, state) => NoTransitionPage(
    key: ValueKey(state.uri.toString()),
    child: MapPage(
        initialEvent:
            state.extra is EventPreview ? state.extra as EventPreview : null),
  ),
);
