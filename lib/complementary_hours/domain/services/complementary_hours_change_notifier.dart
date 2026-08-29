import 'dart:async';

/// Announces changes to the current account's personal activity records.
///
/// The writer (event details) and readers (summary and history) stay
/// independent while still reflecting successful writes immediately.
final class ComplementaryHoursChangeNotifier {
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;

  void notifyChanged() {
    _changes.add(null);
  }
}
