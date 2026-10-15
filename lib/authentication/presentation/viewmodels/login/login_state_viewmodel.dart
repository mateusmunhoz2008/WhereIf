import 'package:signals_flutter/signals_flutter.dart';

class LoginState {
  final loading = signal(false);
  final errorMessage = signal<String?>(null);
  int _errorRevision = 0;

  void setLoading(bool value) {
    loading.value = value;
  }

  void showError(String message) {
    _errorRevision++;
    errorMessage.value = message;
  }

  void clearError() {
    _errorRevision++;
    errorMessage.value = null;
  }

  Future<void> showTemporaryError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    showError(message);
    final revision = _errorRevision;

    await Future.delayed(duration);

    if (revision == _errorRevision) clearError();
  }
}
