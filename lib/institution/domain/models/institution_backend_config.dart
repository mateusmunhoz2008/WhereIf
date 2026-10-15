import 'package:flutter/foundation.dart';

enum InstitutionBackendRuntime {
  firebase,
}

@immutable
class InstitutionBackendConfig {
  final InstitutionBackendRuntime runtime;
  final String firebaseOptionsKey;
  final String firebaseProjectId;
  final String storageBucket;
  final String firestoreDatabaseId;
  final int schemaVersion;
  final bool isolatedFirebaseProject;

  const InstitutionBackendConfig({
    required this.runtime,
    required this.firebaseOptionsKey,
    required this.firebaseProjectId,
    required this.storageBucket,
    required this.firestoreDatabaseId,
    required this.schemaVersion,
    this.isolatedFirebaseProject = true,
  });
}
