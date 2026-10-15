import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:autth_injustice_app/complementary_hours/domain/complementary_hours_types.dart';
import 'package:autth_injustice_app/complementary_hours/domain/facades/i_complementary_hours_use_case_facade.dart';
import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_summary.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/commands/complementary_hours_commands.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/viewmodels/summary/complementary_hours_commands_viewmodel.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/viewmodels/summary/complementary_hours_state_viewmodel.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';

class _Facade extends Fake implements IComplementaryHoursUseCaseFacade {
  final old = Completer<ComplementaryHoursSummaryResult>();
  int calls = 0;
  @override
  Future<ComplementaryHoursSummaryResult> getSummary(
      ComplementaryHoursNoParams params) {
    calls++;
    return calls == 1
        ? old.future
        : Future.value(const Success(ComplementaryHoursSummary(
            completedMinutes: 20, targetMinutes: 100, milestoneMinutes: [])));
  }
}

void main() {
  test(
      'switch clears cached summary and ignores previous account late response',
      () async {
    final facade = _Facade();
    final state = ComplementaryHoursState();
    final commands = ComplementaryHoursCommands(
        state: state,
        loadSummaryCommand: LoadComplementaryHoursSummaryCommand(facade));
    state.setSummary(const ComplementaryHoursSummary(
        completedMinutes: 99, targetMinutes: 100, milestoneMinutes: []));
    final pending = commands.loadSummary(forceRefresh: true);
    commands.resetForAccount();
    expect(state.summary.value, isNull);
    expect(state.hasLoaded, false);
    facade.old.complete(const Success(ComplementaryHoursSummary(
        completedMinutes: 88, targetMinutes: 100, milestoneMinutes: [])));
    await pending;
    expect(facade.calls, 2);
    expect(state.summary.value?.completedMinutes, 20);
    expect(state.loading.value, false);
  });

  test('logout does not restart a stale summary load', () async {
    final facade = _Facade();
    final state = ComplementaryHoursState();
    final commands = ComplementaryHoursCommands(
      state: state,
      loadSummaryCommand: LoadComplementaryHoursSummaryCommand(facade),
    );
    final pending = commands.loadSummary();
    commands.resetForAccount(active: false);
    facade.old.complete(const Success(ComplementaryHoursSummary(
      completedMinutes: 88,
      targetMinutes: 100,
      milestoneMinutes: [],
    )));
    await pending;
    expect(facade.calls, 1);
    expect(state.summary.value, isNull);
    expect(state.loading.value, isFalse);
  });

  test('disposed summary commands ignore completion without refreshing',
      () async {
    final facade = _Facade();
    final state = ComplementaryHoursState();
    final commands = ComplementaryHoursCommands(
      state: state,
      loadSummaryCommand: LoadComplementaryHoursSummaryCommand(facade),
    );
    final pending = commands.loadSummary();
    commands.dispose();
    facade.old.complete(const Success(ComplementaryHoursSummary(
      completedMinutes: 88,
      targetMinutes: 100,
      milestoneMinutes: [],
    )));
    await pending;
    expect(facade.calls, 1);
    expect(state.summary.value, isNull);
    expect(state.loading.value, isFalse);
  });
}
