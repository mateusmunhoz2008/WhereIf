import 'package:autth_injustice_app/complementary_hours/presentation/commands/complementary_hours_commands.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';

import 'complementary_hours_state_viewmodel.dart';

class ComplementaryHoursCommands {
  final ComplementaryHoursState state;
  final LoadComplementaryHoursSummaryCommand _loadSummaryCommand;
  int _generation = 0;
  bool _disposed = false;
  bool _active = true;

  void resetForAccount({bool active = true}) {
    _generation++;
    _active = active;
    state.summary.value = null;
    state.loaded.value = false;
    state.clearError();
  }

  void dispose() {
    _disposed = true;
    resetForAccount(active: false);
    state.setLoading(false);
  }

  ComplementaryHoursCommands({
    required this.state,
    required LoadComplementaryHoursSummaryCommand loadSummaryCommand,
  }) : _loadSummaryCommand = loadSummaryCommand;

  Future<void> loadSummary({bool forceRefresh = false}) async {
    if (_disposed ||
        !_active ||
        state.loading.value ||
        (!forceRefresh && state.hasLoaded)) {
      return;
    }

    state.setLoading(true);
    state.clearError();
    final generation = _generation;

    try {
      final result = await _loadSummaryCommand.executeWith(());
      if (generation != _generation) return;
      result.fold(
        onSuccess: state.setSummary,
        onFailure: (failure) {
          if (failure is ForbiddenFailure ||
              failure is UnauthenticatedFailure) {
            state.summary.value = null;
            state.loaded.value = false;
          }
          state.showError(failure.msg);
        },
      );
    } catch (_) {
      if (!_disposed && generation == _generation) {
        state.showError('complementaryHoursLoadError');
      }
    } finally {
      if (!_disposed) {
        state.setLoading(false);
        if (generation != _generation && _active) {
          await loadSummary(forceRefresh: true);
        }
      }
    }
  }
}
