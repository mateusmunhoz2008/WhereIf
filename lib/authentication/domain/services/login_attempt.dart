import 'dart:async';

/// Cancels the app's interest in a login. Native authentication is serialized
/// and cleaned up when it completes; Firebase itself has no cancellation API.
class LoginAttempt {
  static LoginAttempt? current;
  final _cancelled = Completer<void>();
  bool timedOut = false;
  bool get cancelled => _cancelled.isCompleted;
  Future<void> get cancellation => _cancelled.future;

  static LoginAttempt begin() {
    current?.cancel();
    return current = LoginAttempt();
  }

  void cancel() {
    if (!cancelled) _cancelled.complete();
  }
}
