// SDK test doubles are confined to this test file.
// ignore_for_file: subtype_of_sealed_class

import 'package:autth_injustice_app/account/data/mappers/account_firestore_mapper.dart';
import 'package:autth_injustice_app/account/data/services/account_firestore_service.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore extends Fake implements FirebaseFirestore {
  Map<String, dynamic>? stored;
  Map<String, dynamic>? createdConcurrently;
  Object? transactionError;
  int writes = 0;
  int attempts = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'accounts');
    return _Collection();
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (transactionError != null) throw transactionError!;
    attempts++;
    var transaction = _Transaction(this);
    var result = await transactionHandler(transaction);
    if (createdConcurrently != null) {
      stored = Map.of(createdConcurrently!);
      createdConcurrently = null;
      attempts++;
      transaction = _Transaction(this);
      result = await transactionHandler(transaction);
    }
    if (transaction.pendingWrite != null) {
      stored = transaction.pendingWrite;
      writes++;
    }
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'owner');
    return _Document();
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;

  @override
  String get id => 'owner';

  @override
  bool get exists => value != null;

  @override
  Map<String, dynamic>? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.firestore);
  final _Firestore firestore;
  Map<String, dynamic>? pendingWrite;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> reference) async =>
      _Snapshot(firestore.stored == null ? null : Map.of(firestore.stored!))
          as DocumentSnapshot<T>;

  @override
  Transaction set<T>(DocumentReference<T> reference, T data,
      [SetOptions? options]) {
    pendingWrite = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

Account _account(
        {String name = 'New Account',
        AccountRole role = AccountRole.student}) =>
    Account.initial(uid: 'owner', email: 'owner@example.com', displayName: name)
        .copyWith(role: role);

Map<String, dynamic> _existing({AccountRole role = AccountRole.student}) => {
      ...AccountFirestoreMapper.toMap(
          _account(name: 'Existing Account', role: role)),
      'totalComplementaryMinutes': 180,
    };

void main() {
  test('new account is created transactionally only when absent', () async {
    final firestore = _Firestore();
    final service = AccountFirestoreService(firestore: firestore);
    final result = await service.saveAccount(_account());
    expect(result.isSuccess, isTrue);
    expect(firestore.writes, 1);
    expect(firestore.stored!['displayName'], 'New Account');
    expect(firestore.stored!['role'], 'student');
    expect(firestore.stored!['totalComplementaryMinutes'], 0);
  });

  for (final role in [AccountRole.student, AccountRole.administrator]) {
    test('existing $role profile and hours are never overwritten', () async {
      final firestore = _Firestore()..stored = _existing(role: role);
      final original = Map<String, dynamic>.of(firestore.stored!);
      final service = AccountFirestoreService(firestore: firestore);
      expect((await service.saveAccount(_account())).isSuccess, isTrue);
      expect(firestore.writes, 0);
      expect(firestore.stored, original);
    });
  }

  test('transaction retry preserves profile created by another device',
      () async {
    final concurrent = _existing(role: AccountRole.administrator);
    final firestore = _Firestore()..createdConcurrently = concurrent;
    final service = AccountFirestoreService(firestore: firestore);
    expect((await service.saveAccount(_account())).isSuccess, isTrue);
    expect(firestore.attempts, 2);
    expect(firestore.writes, 0);
    expect(firestore.stored, concurrent);
  });

  test('failed transaction returns a controlled error without writing',
      () async {
    final firestore = _Firestore()
      ..transactionError =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    final service = AccountFirestoreService(firestore: firestore);
    final result = await service.saveAccount(_account());
    expect(result.failureValueOrNull, isA<RemoteFailure>());
    expect(firestore.writes, 0);
    expect(firestore.stored, isNull);
  });

  test('malformed existing profile fails safely without overwriting it',
      () async {
    final firestore = _Firestore()..stored = {..._existing(), 'role': 7};
    final service = AccountFirestoreService(firestore: firestore);
    expect((await service.saveAccount(_account())).isFailure, isTrue);
    expect(firestore.writes, 0);
    expect(firestore.stored!['totalComplementaryMinutes'], 180);
  });
}
