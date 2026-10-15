import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'network_status.dart';

/// Bounded reads; authorization failures never fall back to cached private data.
abstract final class FirestoreAccess {
  static const deadline = Duration(seconds: 5);
  static bool networkError(Object error) =>
      error is TimeoutException ||
      error is FirebaseException &&
          ['unavailable', 'deadline-exceeded', 'network-request-failed']
              .contains(error.code);

  static Future<DocumentSnapshot<Map<String, dynamic>>> document(
      DocumentReference<Map<String, dynamic>> reference,
      {bool cacheFirst = false}) async {
    if (cacheFirst || NetworkStatus.instance.value == false) {
      try {
        final cached = await reference
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 1));
        if (cached.exists) return cached;
      } catch (_) {/* Cache miss: try the server with a deadline. */}
    }
    try {
      final result = await reference
          .get(const GetOptions(source: Source.server))
          .timeout(deadline);
      NetworkStatus.instance.report(true);
      return result;
    } catch (error) {
      if (!networkError(error)) rethrow;
      NetworkStatus.instance.report(false);
      final cached = await reference
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 1));
      // A cache miss is not proof that a server document does not exist.
      // In particular, never create/overwrite an account after an offline miss.
      if (!cached.exists) rethrow;
      return cached;
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> query(
      Query<Map<String, dynamic>> query) async {
    try {
      final result = await query
          .get(const GetOptions(source: Source.server))
          .timeout(deadline);
      NetworkStatus.instance.report(true);
      return result;
    } catch (error) {
      if (!networkError(error)) rethrow;
      NetworkStatus.instance.report(false);
      return query
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 1));
    }
  }
}
