// SDK test doubles are confined to this test file.
// ignore_for_file: subtype_of_sealed_class

import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/events/data/services/events_firestore_service.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _accountPath = 'accounts/student';
const _recordPath = '$_accountPath/personalActivityRecords/event';
const _eventPath = 'events/event';

void main() {
  late _Firestore firestore;
  late EventsFirestoreService service;

  setUp(() {
    firestore = _Firestore({
      _accountPath: {'totalComplementaryMinutes': 60},
      _eventPath: {
        'title': 'Evento de teste',
        'category': 'academic',
        'startsAt': Timestamp.fromDate(DateTime(2026, 10, 15, 10)),
        'endMode': 'manual',
        'complementaryMinutes': 120,
      },
    });
    service = EventsFirestoreService(
      firestore: firestore,
      institutionPackage: const IfprPguaPackage(),
    );
  });

  Future<void> addRecord() async {
    final result = await service.setPersonalRecord(
      uid: 'student',
      eventId: 'event',
      addedToPersonalHistory: true,
    );
    expect(result.isSuccess, isTrue);
    expect(result.successValueOrNull, isTrue);
  }

  Future<void> removeRecord() async {
    final result = await service.setPersonalRecord(
      uid: 'student',
      eventId: 'event',
      addedToPersonalHistory: false,
    );
    expect(result.isSuccess, isTrue);
    expect(result.successValueOrNull, isFalse);
  }

  int total() =>
      firestore.documents[_accountPath]!['totalComplementaryMinutes'] as int;

  group('setPersonalRecord transaction', () {
    test('adding the same event twice does not duplicate minutes', () async {
      await addRecord();
      await addRecord();

      expect(total(), 180);
      expect(firestore.documents[_recordPath], {
        'eventName': 'Evento de teste',
        'eventDate': firestore.documents[_eventPath]!['startsAt'],
        'durationMinutes': 120,
      });
      expect(firestore.committedWrites, 2);
    });

    test('removing the same event twice does not subtract minutes twice',
        () async {
      await addRecord();
      firestore.committedWrites = 0;

      await removeRecord();
      await removeRecord();

      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
      expect(firestore.committedWrites, 2);
    });

    test('removing a larger record clamps the account total to zero', () async {
      await addRecord();
      firestore.documents[_accountPath]!['totalComplementaryMinutes'] = 10;

      await removeRecord();

      expect(total(), 0);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
    });

    test('an invalid negative existing total cannot reduce added minutes',
        () async {
      firestore.documents[_accountPath]!['totalComplementaryMinutes'] = -50;

      await addRecord();

      expect(total(), 120);
    });

    test('a missing event returns a not-found failure without any writes',
        () async {
      firestore.documents.remove(_eventPath);

      final result = await service.setPersonalRecord(
        uid: 'student',
        eventId: 'event',
        addedToPersonalHistory: true,
      );

      expect(result.failureValueOrNull, isA<NotFoundFailure>());
      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
      expect(firestore.committedWrites, 0);
    });

    test('a missing account cannot create a personal record', () async {
      firestore.documents.remove(_accountPath);

      final result = await service.setPersonalRecord(
        uid: 'student',
        eventId: 'event',
        addedToPersonalHistory: true,
      );

      expect(result.failureValueOrNull, isA<UnauthenticatedFailure>());
      expect(firestore.documents.containsKey(_recordPath), isFalse);
      expect(firestore.committedWrites, 0);
    });

    test('negative event minutes fail without changing the account', () async {
      firestore.documents[_eventPath]!['complementaryMinutes'] = -120;

      final result = await service.setPersonalRecord(
        uid: 'student',
        eventId: 'event',
        addedToPersonalHistory: true,
      );

      expect(result.failureValueOrNull, isA<InvalidInputFailure>());
      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
      expect(firestore.committedWrites, 0);
    });

    test('a rejected commit rolls back both the record and account total',
        () async {
      firestore.rejectNextCommit = true;

      final result = await service.setPersonalRecord(
        uid: 'student',
        eventId: 'event',
        addedToPersonalHistory: true,
      );

      expect(result.isFailure, isTrue);
      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
      expect(firestore.committedWrites, 0);

      await addRecord();
      expect(total(), 180);
      expect(firestore.committedWrites, 2);
    });

    test('a rejected removal keeps both the existing record and total',
        () async {
      await addRecord();
      firestore.rejectNextCommit = true;

      final result = await service.setPersonalRecord(
        uid: 'student',
        eventId: 'event',
        addedToPersonalHistory: false,
      );

      expect(result.isFailure, isTrue);
      expect(total(), 180);
      expect(firestore.documents[_recordPath]!['durationMinutes'], 120);

      await removeRecord();
      expect(total(), 60);
    });

    test(
        'an event without hours can be added and removed without changing total',
        () async {
      firestore.documents[_eventPath]!['complementaryMinutes'] = null;

      await addRecord();
      expect(total(), 60);
      expect(firestore.documents[_recordPath]!['durationMinutes'], isNull);

      await removeRecord();
      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
    });

    test('removal uses the saved duration even when the event was deleted',
        () async {
      await addRecord();
      firestore.documents.remove(_eventPath);

      await removeRecord();

      expect(total(), 60);
      expect(firestore.documents.containsKey(_recordPath), isFalse);
    });
  });
}

class _Firestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> documents;
  bool rejectNextCommit = false;
  int committedWrites = 0;

  _Firestore(this.documents);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(collectionPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction({
      for (final entry in documents.entries)
        entry.key: Map<String, dynamic>.of(entry.value),
    });
    final result = await transactionHandler(transaction);
    if (rejectNextCommit) {
      rejectNextCommit = false;
      throw FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied');
    }
    documents
      ..clear()
      ..addAll(transaction.documents);
    committedWrites += transaction.writes;
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  final String path;

  _Collection(this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference('${this.path}/$path');
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;

  _Reference(this.path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection('$path/$collectionPath');
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  final String path;
  final T? value;

  _Snapshot(this.path, this.value);

  @override
  String get id => path.split('/').last;

  @override
  bool get exists => value != null;

  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  final Map<String, Map<String, dynamic>> documents;
  int writes = 0;

  _Transaction(this.documents);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (writes != 0) throw StateError('Transactions must read before writing.');
    return _Snapshot<T>(
        documentReference.path, documents[documentReference.path] as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> documentReference, T data,
      [SetOptions? options]) {
    writes++;
    documents[documentReference.path] =
        Map<String, dynamic>.of(data as Map<String, dynamic>);
    return this;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<Object, Object?> data) {
    final existing = documents[documentReference.path];
    if (existing == null) throw StateError('Cannot update a missing document.');
    writes++;
    existing.addAll(
        {for (final entry in data.entries) entry.key as String: entry.value});
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    writes++;
    documents.remove(documentReference.path);
    return this;
  }
}
