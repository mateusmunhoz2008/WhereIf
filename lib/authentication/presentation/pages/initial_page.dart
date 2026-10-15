import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/presentation/widgets/campus_onboarding.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InitialPage extends StatelessWidget {
  const InitialPage(
      {super.key,
      this.entryRepository,
      this.onCompleted,
      this.preview = false});

  final IAppEntryRepository? entryRepository;
  final VoidCallback? onCompleted;
  final bool preview;

  Future<void> _finish(BuildContext context) async {
    if (!preview) {
      try {
        await (entryRepository ?? injector.get<IAppEntryRepository>())
            .markInitialPageCompleted();
      } catch (_) {}
    }
    if (!context.mounted) return;
    if (onCompleted case final callback?) {
      callback();
    } else {
      context.goNamed(EventsRouteNames.catalog);
    }
  }

  @override
  Widget build(BuildContext context) =>
      CampusOnboarding(onFinished: () => _finish(context));
}
