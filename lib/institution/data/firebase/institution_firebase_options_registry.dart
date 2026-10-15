import 'package:autth_injustice_app/institution/packages/ifpr_pgua/firebase_options.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_backend_config.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class InstitutionFirebaseOptionsRegistry {
  static FirebaseOptions resolve(InstitutionBackendConfig backend) {
    final options = switch (backend.firebaseOptionsKey) {
      'ifpr-pgua' => DefaultFirebaseOptions.currentPlatform,
      _ => throw StateError(
          'No FirebaseOptions registered for '
          '"${backend.firebaseOptionsKey}".',
        ),
    };

    if (options.projectId != backend.firebaseProjectId ||
        options.storageBucket != backend.storageBucket) {
      throw StateError(
        'Firebase options do not match the institution backend manifest.',
      );
    }
    return options;
  }
}
