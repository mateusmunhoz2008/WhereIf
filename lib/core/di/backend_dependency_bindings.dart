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
import 'package:autth_injustice_app/events/data/services/events_firestore_service.dart';
import 'package:autth_injustice_app/complementary_hours/data/services/complementary_hours_firestore_service.dart';
import 'package:autth_injustice_app/notifications/data/services/notifications_firestore_service.dart';
import 'package:autth_injustice_app/user_management/data/services/user_management_firestore_service.dart';
import 'package:autth_injustice_app/events/data/services/i_events_service.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_backend_config.dart';
import 'package:autth_injustice_app/notifications/data/services/i_notifications_service.dart';
import 'package:autth_injustice_app/settings/data/services/i_account_security_service.dart';
import 'package:autth_injustice_app/settings/data/services/unconfigured_account_security_service.dart';
import 'package:autth_injustice_app/user_management/data/services/i_user_management_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class BackendDependencyBindings {
  static void register(
    AutoInjector injector, {
    required InstitutionPackage institutionPackage,
    required FirebaseApp firebaseApp,
  }) {
    switch (institutionPackage.backend.runtime) {
      case InstitutionBackendRuntime.firebase:
        _registerFirebase(
          injector,
          institutionPackage: institutionPackage,
          firebaseApp: firebaseApp,
        );
    }
  }

  static void _registerFirebase(
    AutoInjector injector, {
    required InstitutionPackage institutionPackage,
    required FirebaseApp firebaseApp,
  }) {
    final backend = institutionPackage.backend;
    if (firebaseApp.options.projectId != backend.firebaseProjectId ||
        firebaseApp.options.storageBucket != backend.storageBucket) {
      throw StateError('Firebase app does not match the institution backend.');
    }

    final firestore = FirebaseFirestore.instanceFor(
      app: firebaseApp,
      databaseId: backend.firestoreDatabaseId,
    );
    final firebaseAuth = FirebaseAuth.instanceFor(app: firebaseApp);

    injector
      ..addInstance<FirebaseFirestore>(firestore)
      ..addInstance<FirebaseAuth>(firebaseAuth)
      ..addSingleton<IAccountRemoteStorage>(
        () => AccountFirestoreService(firestore: firestore),
      )
      ..addSingleton<IAuthService>(
        (IAccountRemoteStorage accountStorage) => FirebaseAuthService(
          firebaseAuth: firebaseAuth,
          accountStorage: accountStorage,
        ),
      )
      ..addSingleton<IEmailVerificationService>(
        () => FirebaseEmailVerificationService(firebaseAuth: firebaseAuth),
      )
      ..addSingleton<IPasswordResetService>(
        UnconfiguredPasswordResetService.new,
      )
      ..addSingleton<IAccountSecurityService>(
        UnconfiguredAccountSecurityService.new,
      )
      ..addSingleton<IEventsService>(
        () => EventsFirestoreService(
          firestore: firestore,
          institutionPackage: institutionPackage,
        ),
      )
      ..addSingleton<INotificationsService>(
        () => NotificationsFirestoreService(
            firestore: firestore, firebaseAuth: firebaseAuth),
      )
      ..addSingleton<IComplementaryHoursService>(
        () => ComplementaryHoursFirestoreService(
          firestore: firestore,
          firebaseAuth: firebaseAuth,
          institutionPackage: institutionPackage,
        ),
      )
      ..addSingleton<IUserManagementService>(
        () => UserManagementFirestoreService(
          firestore: firestore,
          firebaseAuth: firebaseAuth,
          institutionPackage: institutionPackage,
        ),
      )
      ..addSingleton<ICurrentAccountProvider>(
        AuthenticatedCurrentAccountProvider.new,
      );
  }
}
