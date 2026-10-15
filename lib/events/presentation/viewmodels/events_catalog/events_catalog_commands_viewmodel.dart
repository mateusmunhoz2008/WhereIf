import 'package:autth_injustice_app/events/presentation/commands/events_commands.dart';

import 'events_catalog_state_viewmodel.dart';

class EventsCatalogCommands {
  final EventsCatalogState state;
  final LoadEventsCatalogCommand _loadEventsCatalogCommand;

  EventsCatalogCommands({
    required this.state,
    required LoadEventsCatalogCommand loadEventsCatalogCommand,
  }) : _loadEventsCatalogCommand = loadEventsCatalogCommand;

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (state.loading.value || (!forceRefresh && state.hasLoaded)) return;

    state.setLoading(true);
    state.clearError();

    try {
      final result = await _loadEventsCatalogCommand.executeWith(());

      result.fold(
        onSuccess: state.setCatalog,
        onFailure: (failure) => state.showError(failure.msg),
      );
    } catch (_) {
      state.showError('eventsLoadError');
    } finally {
      state.setLoading(false);
    }
  }
}
