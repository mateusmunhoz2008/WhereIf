// SDK test doubles only; no production implementation of these sealed types.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';
import 'package:autth_injustice_app/core/network/network_status.dart';
import 'package:autth_injustice_app/core/network/queued_write.dart';

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.hasPendingWrites);
  @override
  final bool hasPendingWrites;
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot({this.exists = true, bool pending = false})
      : metadata = _Metadata(pending);
  @override
  final bool exists;
  @override
  final SnapshotMetadata metadata;
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference({required this.cache, this.serverError});
  final DocumentSnapshot<Map<String, dynamic>> cache;
  final Object? serverError;
  int cacheReads = 0;
  int serverReads = 0;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    if (options?.source == Source.cache) {
      cacheReads++;
      return cache;
    }
    serverReads++;
    if (serverError != null) throw serverError!;
    return _Snapshot();
  }
}

void main() {
  setUp(() {
    NetworkStatus.instance.value = null;
    QueuedWrite.lateFailure.value = false;
  });
  test('cached event opens without waiting for the server', () async {
    final ref = _Reference(cache: _Snapshot());
    expect(
        await FirestoreAccess.document(ref, cacheFirst: true), same(ref.cache));
    expect(ref.serverReads, 0);
  });
  test('unreachable server falls back to existing cached data', () async {
    final ref =
        _Reference(cache: _Snapshot(), serverError: TimeoutException('slow'));
    expect(await FirestoreAccess.document(ref), same(ref.cache));
    expect(NetworkStatus.instance.value, false);
  });
  test('offline cache miss is not authoritative document absence', () async {
    final ref = _Reference(
        cache: _Snapshot(exists: false), serverError: TimeoutException('slow'));
    await expectLater(
        FirestoreAccess.document(ref), throwsA(isA<TimeoutException>()));
  });
  test('permission denial never falls back to cached private data', () async {
    final ref = _Reference(
        cache: _Snapshot(),
        serverError: FirebaseException(
            plugin: 'cloud_firestore', code: 'permission-denied'));
    await expectLater(
        FirestoreAccess.document(ref), throwsA(isA<FirebaseException>()));
    expect(ref.cacheReads, 0);
  });
  test('pending message requires an actual local pending write', () async {
    final operation = Completer<void>();
    final ref = _Reference(cache: _Snapshot(pending: true));
    await expectLater(
        QueuedWrite.wait(operation.future, ref,
            deadline: const Duration(milliseconds: 1)),
        throwsA(isA<PendingSyncFailure>()));
    operation.complete();
    await Future<void>.delayed(Duration.zero);
  });
  test('unconfirmed write does not claim a saved draft', () async {
    final operation = Completer<void>();
    final ref = _Reference(cache: _Snapshot(exists: false));
    await expectLater(
        QueuedWrite.wait(operation.future, ref,
            deadline: const Duration(milliseconds: 1)),
        throwsA(isA<RemoteFailure>()));
    operation.complete();
    await Future<void>.delayed(Duration.zero);
  });
  test('late rejected pending write exposes a failure notice', () async {
    final operation = Completer<void>();
    final ref = _Reference(cache: _Snapshot(pending: true));
    await expectLater(
        QueuedWrite.wait(operation.future, ref,
            deadline: const Duration(milliseconds: 1)),
        throwsA(isA<PendingSyncFailure>()));
    operation.completeError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(QueuedWrite.lateFailure.value, true);
  });
}
