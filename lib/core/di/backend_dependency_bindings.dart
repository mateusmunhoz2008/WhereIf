import 'package:auto_injector/auto_injector.dart';
import 'package:autth_injustice_app/account/data/services/account_firestore_service.dart';
import 'package:autth_injustice_app/account/data/services/authenticated_current_account_provider.dart';
import 'package:autth_injustice_app/account/data/services/i_account_remote_storage.dart';
import 'package:autth_injustice_app/account/domain/services/i_current_account_provider.dart';
import 'package:autth_injustice_app/authentication/data/services/email_verification/i_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/data/services/email_verification/firebase_email_verification_service.dart';
import 'package:autth_injustice_app/authentication/data/services/password_reset/i_password_reset_service.dart';
import 'package:autth_injustice_app/authentication/data/services/password_reset/unconfigured_password_reset_service.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/i_auth_service.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/firebase_auth_service.dart';
import 'package:autth_injustice_app/complementary_hours/data/services/i_complementary_hours_service.dart';
import 'package:autth_injustice_app/dev/demo_backend/demo_backend_seed.dart';
import 'package:autth_injustice_app/dev/demo_backend/demo_backend_store.dart';
import 'package:autth_injustice_app/events/data/services/events_firestore_service.dart';
import 'package:autth_injustice_app/complementary_hours/data/services/complementary_hours_firestore_service.dart';
import 'package:autth_injustice_app/dev/demo_backend/services/demo_current_account_provider.dart';
import 'package:autth_injustice_app/dev/demo_backend/services/demo_notifications_service.dart';
import 'package:autth_injustice_app/dev/demo_backend/services/demo_user_management_service.dart';
import 'package:autth_injustice_app/events/data/services/i_events_service.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_backend_config.dart';
import 'package:autth_injustice_app/notifications/data/services/i_notifications_service.dart';
import 'package:autth_injustice_app/settings/data/services/i_account_security_service.dart';
import 'package:autth_injustice_app/settings/data/services/unconfigured_account_security_service.dart';
import 'package:autth_injustice_app/user_management/data/services/i_user_management_service.dart';
import 'package:flutter/foundation.dart';

/// Centraliza os adaptadores que serao substituidos pelo backend real.
abstract final class BackendDependencyBindings {
  static void register(
    AutoInjector injector, {
    required InstitutionPackage institutionPackage,
  }) {
    switch (institutionPackage.backend.runtime) {
      case InstitutionBackendRuntime.hybridDemo:
        _registerHybridDemo(injector);
      case InstitutionBackendRuntime.demo:
      case InstitutionBackendRuntime.firebase:
        throw UnsupportedError(
          'Backend runtime "${institutionPackage.backend.runtime.name}" has '
          'no registered adapters yet.',
        );
    }
  }

  static void _registerHybridDemo(AutoInjector injector) {
    injector
      ..addSingleton<IAccountRemoteStorage>(AccountFirestoreService.new)
      ..addSingleton<IAuthService>(FirebaseAuthService.new)
      ..addSingleton<IEmailVerificationService>(
        FirebaseEmailVerificationService.new,
      )
      ..addSingleton<IPasswordResetService>(
        UnconfiguredPasswordResetService.new,
      )
      ..addSingleton<IAccountSecurityService>(
        UnconfiguredAccountSecurityService.new,
      )
      ..addSingleton<DemoBackendStore>(DemoBackendStore.new)
      ..addSingleton<IEventsService>(EventsFirestoreService.new)
      ..addSingleton<INotificationsService>(DemoNotificationsService.new)
      ..addSingleton<IComplementaryHoursService>(
        ComplementaryHoursFirestoreService.new,
      )
      ..addSingleton<IUserManagementService>(
        DemoUserManagementService.new,
      );

    _registerCurrentAccount(injector);
  }

  static void _registerCurrentAccount(AutoInjector injector) {
    const demoRole = String.fromEnvironment('DEMO_ROLE');

    if (!kDebugMode || demoRole.isEmpty) {
      injector.addSingleton<ICurrentAccountProvider>(
        AuthenticatedCurrentAccountProvider.new,
      );
      return;
    }

    final account = switch (demoRole) {
      'student' => DemoBackendSeed.studentAccount,
      'eventManager' => DemoBackendSeed.eventManagerAccount,
      'administrator' => DemoBackendSeed.administratorAccount,
      _ => throw ArgumentError.value(
          demoRole,
          'DEMO_ROLE',
          'Use student, eventManager or administrator.',
        ),
    };

    injector.addInstance<ICurrentAccountProvider>(
      DemoCurrentAccountProvider(account),
    );
  }
}
