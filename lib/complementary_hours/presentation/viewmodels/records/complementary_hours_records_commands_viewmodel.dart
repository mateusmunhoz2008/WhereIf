import 'package:autth_injustice_app/complementary_hours/presentation/commands/complementary_hours_commands.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';

import 'complementary_hours_records_state_viewmodel.dart';

class ComplementaryHoursRecordsCommands {
  final ComplementaryHoursRecordsState state;
  final LoadComplementaryHoursRecordsCommand _loadRecordsCommand;
  final DeleteComplementaryHoursRecordCommand Function() _deleteRecordCommand;
  int _generation = 0;
  bool _disposed = false;
  bool _active = true;
  final _deletedIds = <String>{};

  void resetForAccount({bool active = true}) {
    _generation++;
    _active = active;
    _deletedIds.clear();
    state.records.value = const [];
    state.deletingIds.value = const {};
    state.loaded.value = false;
    state.clearError();
  }

  void dispose() {
    _disposed = true;
    resetForAccount(active: false);
    state.setLoading(false);
  }

  ComplementaryHoursRecordsCommands({
    required this.state,
    required LoadComplementaryHoursRecordsCommand loadRecordsCommand,
    required DeleteComplementaryHoursRecordCommand Function()
        deleteRecordCommand,
  })  : _loadRecordsCommand = loadRecordsCommand,
        _deleteRecordCommand = deleteRecordCommand;

  Future<void> loadRecords({bool forceRefresh = false}) async {
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
      final result = await _loadRecordsCommand.executeWith(());
      if (generation != _generation) return;
      result.fold(
        onSuccess: state.setRecords,
        onFailure: (failure) {
          if (failure is ForbiddenFailure ||
              failure is UnauthenticatedFailure) {
            state.records.value = const [];
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
          await loadRecords(forceRefresh: true);
        }
      }
    }
  }

  Future<bool> deleteRecord(String recordId) async {
    if (_disposed || !_active || !state.startDeleting(recordId)) return false;

    state.clearError();
    var deleted = false;
    final generation = _generation;

    try {
      final result = await _deleteRecordCommand().executeWith(
        (recordId: recordId),
      );
      if (generation != _generation) return false;
      result.fold(
        onSuccess: (_) {
          deleted = true;
          _deletedIds.add(recordId);
        },
        onFailure: (failure) => state.showError(failure.msg),
      );
    } catch (_) {
      if (!_disposed && generation == _generation) {
        state.showError('complementaryHoursDeleteError');
      }
    } finally {
      if (!_disposed && generation == _generation) {
        state.finishDeleting(recordId);
      }
    }

    return deleted;
  }

  void completeDismissal(String recordId) {
    if (!_disposed && _active && _deletedIds.remove(recordId)) {
      state.removeRecord(recordId);
    }
  }
}
