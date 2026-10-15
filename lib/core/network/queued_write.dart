import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'network_status.dart';

abstract final class QueuedWrite {
  static final lateFailure = ValueNotifier<bool>(false);
  static final completed = StreamController<void>.broadcast();

  static Future<void> wait(
      Future<void> operation, DocumentReference<Map<String, dynamic>> reference,
      {Duration deadline = const Duration(seconds: 8)}) async {
    var detached = false;
    final observed = operation.then((_) {
      completed.add(null);
    }, onError: (Object error, StackTrace stack) {
      if (detached) lateFailure.value = true;
      Error.throwWithStackTrace(error, stack);
    });
    try {
      await observed.timeout(deadline);
    } on TimeoutException {
      detached = true;
      // Read markers acknowledge locally after 300 ms. That short UI deadline
      // is not evidence of a broken connection on an otherwise healthy network.
      if (deadline.inSeconds >= 3) NetworkStatus.instance.report(false);
      DocumentSnapshot<Map<String, dynamic>> local;
      try {
        local = await reference
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        throw RemoteFailure('networkWriteUnconfirmed');
      }
      // Only claim a queued save after the local persistent cache confirms it.
      if (local.exists && local.metadata.hasPendingWrites) {
        throw PendingSyncFailure();
      }
      throw RemoteFailure('networkWriteUnconfirmed');
    }
  }
}
