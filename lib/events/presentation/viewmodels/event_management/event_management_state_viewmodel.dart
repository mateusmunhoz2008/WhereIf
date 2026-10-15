import 'package:autth_injustice_app/core/patterns/async_load_state.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/events_catalog.dart';
import 'package:signals_flutter/signals_flutter.dart';

class EventManagementState with AsyncLoadState {
  final deletingEventId = signal<String?>(null);
  final endingEventId = signal<String?>(null);
  final activeEventId = signal<String?>(null);
  final events = signal<List<EventPreview>>(const []);

  bool get hasEvents => events.value.isNotEmpty;

  void reset() {
    events.value = const [];
    deletingEventId.value = null;
    endingEventId.value = null;
    activeEventId.value = null;
    loading.value = false;
    loaded.value = false;
    clearError();
  }

  void setDeletingEvent(String? eventId) {
    deletingEventId.value = eventId;
  }

  void setEndingEvent(String? eventId) {
    endingEventId.value = eventId;
  }

  void showEventActions(String eventId) {
    activeEventId.value = eventId;
  }

  void closeEventActions() {
    activeEventId.value = null;
  }

  void setCatalog(EventsCatalog catalog) {
    final activeCatalog = catalog.activeAt(DateTime.now());
    final allEvents = [
      ...activeCatalog.featuredEvents,
      ...activeCatalog.futureEvents,
    ];

    allEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    events.value = List.unmodifiable(allEvents);
    markLoaded();
  }

  void removeEvent(String eventId) {
    if (activeEventId.value == eventId) closeEventActions();
    events.value = List.unmodifiable(
      events.value.where((event) => event.id != eventId),
    );
  }
}
