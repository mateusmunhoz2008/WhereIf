import 'dart:async';

import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_details/event_details_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_details/event_details_actions.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_details/event_details_hero.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;

  const EventDetailsPage({
    super.key,
    required this.eventId,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  late final EventDetailsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<EventDetailsViewModel>();
    unawaited(_viewModel.commands.loadEvent(widget.eventId));
  }

  @override
  void didUpdateWidget(EventDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      unawaited(_viewModel.commands.loadEvent(widget.eventId));
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openMap(EventPreview event) {
    context.goNamed(MapRouteNames.map,
        queryParameters: {'event': event.id}, extra: event);
  }

  Future<void> _openExternalLink(String value) async {
    final uri = Uri.tryParse(value);
    var opened = false;
    try {
      opened = uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.eventExternalLinkOpenError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact =
        context.isVerySmallScreen || context.screenSize.width < 360;

    return Scaffold(
      backgroundColor: context.tertiary,
      body: Watch(
        (_) {
          final state = _viewModel.state;
          final event = state.event.value;
          final errorMessage = state.errorMessage.value;

          if (state.loading.value && event == null) {
            return const AppStatusView.loading();
          }

          if (event == null) {
            return SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: context.extraPagePadding.left,
                    top: 8,
                    child: AppBackButton(
                      onPressed: context.pop,
                    ),
                  ),
                  Positioned.fill(
                    child: AppStatusView(
                      icon: Icons.event_busy_outlined,
                      title: context.l10n.eventDetailsUnavailable,
                      message: errorMessage == null
                          ? null
                          : context.l10n.eventsLoadError,
                      actionLabel: context.l10n.commonRetry,
                      onAction: () => unawaited(
                        _viewModel.commands.loadEvent(widget.eventId),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: EventDetailsHero(
                  event: event,
                  complementaryHours: state.complementaryHours.value,
                  isCompact: isCompact,
                  onBack: context.pop,
                ),
              ),
              SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: isCompact ? 88 : 102),
                child: Padding(
                  padding: context.extraPagePadding.copyWith(top: 12),
                  child: EventDetailsActions(
                    authenticated:
                        injector.get<AuthorizationService>().isAuthenticated,
                    addedToPersonalHistory: state.addedToPersonalHistory.value,
                    personalRecordUpdating: state.updatingPersonalRecord.value,
                    onPersonalRecordTap:
                        _viewModel.commands.togglePersonalRecord,
                    onMapTap: event.mapLocations.isEmpty
                        ? null
                        : () => _openMap(event),
                    onExternalLinkTap:
                        event.externalUrl?.trim().isNotEmpty != true
                            ? null
                            : () => unawaited(
                                  _openExternalLink(event.externalUrl!),
                                ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
