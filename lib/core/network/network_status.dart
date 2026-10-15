import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Reachability of the backend, not merely association with Wi-Fi.
class NetworkStatus extends ValueNotifier<bool?> {
  NetworkStatus() : super(null);
  static final instance = NetworkStatus();
  Timer? _timer;
  bool _checking = false;
  final restored = StreamController<void>.broadcast();

  void report(bool reachable) {
    final wasOffline = value == false;
    value = reachable;
    if (wasOffline && reachable) restored.add(null);
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => check());
    unawaited(check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final reachable = await (() async {
        final request =
            await client.getUrl(Uri.parse('https://firestore.googleapis.com/'));
        final response = await request.close();
        // An HTTP error such as 404 still proves that the backend answered.
        return response.statusCode < 500 &&
            response.statusCode != 408 &&
            response.statusCode != 429;
      })()
          .timeout(const Duration(seconds: 5));
      report(reachable);
    } catch (_) {
      report(false);
    } finally {
      client.close(force: true);
      _checking = false;
    }
  }
}
