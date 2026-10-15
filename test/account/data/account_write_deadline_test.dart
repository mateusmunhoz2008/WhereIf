// SDK test doubles are confined to this test file.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:autth_injustice_app/account/data/services/account_firestore_service.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/network/firestore_access.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore extends Fake implements FirebaseFirestore {
  final reference = _Document();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'accounts');
    return _Collection(reference);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.reference);
  final _Document reference;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'owner');
    return reference;
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final pendingUpdate = Completer<void>();
  final pendingDelete = Completer<void>();
  final calls = <String>[];
  int get updates => calls.where((call) => call == 'update').length;
  int get deletions => calls.where((call) => call == 'delete').length;

  @override
  Future<void> update(Map<Object, Object?> data) {
    calls.add('update');
    return pendingUpdate.future;
  }

  @override
  Future<void> delete() {
    calls.add('delete');
    return pendingDelete.future;
  }
}

void main() {
  testWidgets('account update returns a controlled failure after its deadline',
      (tester) async {
    final firestore = _Firestore();
    final service = AccountFirestoreService(firestore: firestore);
    final pending = service.updateAccount(Account.initial(
      uid: 'owner',
      email: 'owner@example.com',
      displayName: 'Test Account',
    ));

    await tester.pump(FirestoreAccess.deadline);
    final result = await pending;

    expect(firestore.reference.updates, 1);
    expect(firestore.reference.pendingUpdate.isCompleted, isFalse);
    expect(
      result.failureValueOrNull,
      isA<RemoteFailure>().having(
        (failure) => failure.msg,
        'message',
        'accountUpdateError',
      ),
    );
  });

  testWidgets(
      'account deletion returns a controlled failure after its deadline',
      (tester) async {
    final firestore = _Firestore();
    final service = AccountFirestoreService(firestore: firestore);
    final pending = service.deleteAccount('owner');

    await tester.pump(FirestoreAccess.deadline);
    final result = await pending;

    expect(firestore.reference.deletions, 1);
    expect(firestore.reference.pendingDelete.isCompleted, isFalse);
    expect(
      result.failureValueOrNull,
      isA<RemoteFailure>().having(
        (failure) => failure.msg,
        'message',
        'accountDeleteError',
      ),
    );
  });
}
