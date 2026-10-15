import 'dart:async';
import 'package:autth_injustice_app/core/network/network_status.dart';
import 'package:autth_injustice_app/core/network/queued_write.dart';

import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/presentation/controllers/event_lifecycle_refresh_scheduler.dart';
import 'package:autth_injustice_app/events/presentation/navigation/event_management_routes.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_management/event_management_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_card_visual_style.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_management/event_management_delete_dialog.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_management/event_management_end_dialog.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_management/event_management_header.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_management/managed_event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  late final EventManagementViewModel _viewModel;
  late final ScrollController _scrollController;
  late final ValueNotifier<double> _scrollProgress;
  final _lifecycleRefresh = EventLifecycleRefreshScheduler();
  StreamSubscription<void>? _networkSubscription;
  StreamSubscription<void>? _writeSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<EventManagementViewModel>();
    _scrollController = ScrollController()..addListener(_updateScrollProgress);
    _scrollProgress = ValueNotifier(0);
    unawaited(_viewModel.commands.loadEvents(forceRefresh: true));
    _networkSubscription = NetworkStatus.instance.restored.stream.listen((_) {
      unawaited(_viewModel.commands.loadEvents(forceRefresh: true));
    });
    _writeSubscription = QueuedWrite.completed.stream.listen((_) {
      unawaited(_viewModel.commands.loadEvents(forceRefresh: true));
    });
  }

  void _updateScrollProgress() {
    final value = (_scrollController.offset / 34).clamp(0.0, 1.0);
    if (_scrollProgress.value != value) {
      _scrollProgress.value = value;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _networkSubscription?.cancel();
    _writeSubscription?.cancel();
    _scrollController
      ..removeListener(_updateScrollProgress)
      ..dispose();
    _scrollProgress.dispose();
    _lifecycleRefresh.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2200),
        ),
      );
  }

  void _openEventActions(String eventId) {
    HapticFeedback.selectionClick();
    _viewModel.state.showEventActions(eventId);
  }

  void _closeEventActions() {
    HapticFeedback.selectionClick();
    _viewModel.state.closeEventActions();
  }

  Future<void> _editEvent(EventPreview event) async {
    HapticFeedback.lightImpact();
    _viewModel.state.closeEventActions();
    final updated = await context.pushNamed<bool>(
      EventManagementRouteNames.edit,
      pathParameters: {'eventId': event.id},
    );
    if (updated != true || !mounted) return;

    await _viewModel.commands.loadEvents(forceRefresh: true);
    if (!mounted) return;
    _showMessage(context.l10n.eventEditorUpdated);
  }

  Future<void> _createEvent() async {
    _viewModel.state.closeEventActions();
    final created = await context.pushNamed<bool>(
      EventManagementRouteNames.create,
    );
    if (created != true || !mounted) return;

    await _viewModel.commands.loadEvents(forceRefresh: true);
    if (!mounted) return;
    _showMessage(context.l10n.eventEditorCreated);
  }

  void _viewEvent(EventPreview event) {
    HapticFeedback.selectionClick();
    _viewModel.state.closeEventActions();
    context.pushNamed(
      EventsRouteNames.details,
      pathParameters: {'eventId': event.id},
    );
  }

  Future<void> _deleteEvent(EventPreview event) async {
    final now = DateTime.now();
    final isPublished =
        event.publishAt == null || !event.publishAt!.isAfter(now);
    final decision = await showDialog<EventRemovalDecision>(
      context: context,
      builder: (dialogContext) => EventManagementDeleteDialog(
        eventTitle: event.title,
        isPublished: isPublished,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onConfirm: (decision) => Navigator.of(dialogContext).pop(decision),
      ),
    );
    if (decision == null || !mounted) return;

    HapticFeedback.mediumImpact();
    final removed = decision.isCancellation
        ? await _viewModel.commands.cancelEvent(
            eventId: event.id,
            reason: decision.cancellationReason!,
          )
        : await _viewModel.commands.deleteEvent(event.id);
    if (!mounted) return;

    _showMessage(
      removed
          ? decision.isCancellation
              ? context.l10n.eventManagementCancelled
              : context.l10n.eventManagementDeleted
          : decision.isCancellation
              ? context.l10n.eventManagementCancelError
              : context.l10n.eventManagementDeleteError,
    );
  }

  Future<void> _endEvent(EventPreview event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EventManagementEndDialog(
        eventTitle: event.title,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    final ended = await _viewModel.commands.endEvent(event.id);
    if (!mounted) return;

    _showMessage(
      ended
          ? context.l10n.eventManagementEndedMessage
          : context.l10n.eventManagementEndError,
    );
  }

  Color _accentColor(int index) {
    return EventCardVisualStyle.accentAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final scale = responsive.layoutScale;
    final textScale = responsive.textScale;
    final horizontalPadding = context.extraPagePadding.left;
    final headerHeight = (164.0 * scale).clamp(142.0, 174.0);
    final navigationClearance = (104.0 * scale).clamp(84.0, 112.0);
    final width = MediaQuery.sizeOf(context).width;
    final columnCount = width >= 680 ? 3 : 2;
    final cardRatio = switch (responsive.widthClass) {
      AppWidthClass.micro => 0.58,
      AppWidthClass.tiny => 0.62,
      AppWidthClass.narrow => 0.66,
      AppWidthClass.compact => 0.69,
      _ => 0.72,
    };

    return Scaffold(
      backgroundColor: context.tertiary,
      body: SafeArea(
        bottom: false,
        child: Watch(
          (_) {
            final state = _viewModel.state;
            final events = state.events.value;
            final hasInitialError = state.hasInitialError;
            final isInitialLoading = state.isInitialLoading;
            final deletingEventId = state.deletingEventId.value;
            final endingEventId = state.endingEventId.value;
            final activeEventId = state.activeEventId.value;
            _lifecycleRefresh.schedule(
              events: events,
              onRefresh: () => unawaited(
                _viewModel.commands.loadEvents(forceRefresh: true),
              ),
            );

            return Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        headerHeight + (26 * scale),
                        horizontalPadding,
                        navigationClearance,
                      ),
                      sliver: events.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: isInitialLoading
                                  ? const AppStatusView.loading()
                                  : AppStatusView(
                                      icon: hasInitialError
                                          ? Icons.cloud_off_outlined
                                          : Icons.event_busy_outlined,
                                      title: hasInitialError
                                          ? context
                                              .l10n.eventManagementLoadError
                                          : context
                                              .l10n.eventManagementEmptyTitle,
                                      message: !hasInitialError
                                          ? context
                                              .l10n.eventManagementEmptyMessage
                                          : null,
                                      actionLabel: hasInitialError
                                          ? context.l10n.commonRetry
                                          : null,
                                      onAction: hasInitialError
                                          ? () => unawaited(
                                                _viewModel.commands.loadEvents(
                                                  forceRefresh: true,
                                                ),
                                              )
                                          : null,
                                    ),
                            )
                          : SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                                crossAxisSpacing: 13 * scale,
                                mainAxisSpacing: 15 * scale,
                                childAspectRatio: cardRatio,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final event = events[index];
                                  return ManagedEventCard(
                                    key: ValueKey(event.id),
                                    event: event,
                                    accentColor: _accentColor(index),
                                    scale: scale,
                                    textScale: textScale,
                                    index: index,
                                    isDeleting: deletingEventId == event.id ||
                                        endingEventId == event.id,
                                    showActions: activeEventId == event.id,
                                    onTap: () => _openEventActions(event.id),
                                    onView: () => _viewEvent(event),
                                    onEdit: () => _editEvent(event),
                                    onDelete: () => _deleteEvent(event),
                                    onEnd: () => _endEvent(event),
                                    onClose: _closeEventActions,
                                  );
                                },
                                childCount: events.length,
                              ),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: EventManagementHeader(
                    eventCount: events.length,
                    height: headerHeight,
                    horizontalPadding: horizontalPadding,
                    scale: scale,
                    textScale: textScale,
                    scrollProgress: _scrollProgress,
                    onCreate: () => unawaited(_createEvent()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
