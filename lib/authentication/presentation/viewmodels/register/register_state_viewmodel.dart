import 'package:signals_flutter/signals_flutter.dart';

class RegisterState {
  final loading = signal(false);

  final errorMessage = signal<String?>(null);
  final success = signal(false);
  int _errorRevision = 0;

  void setLoading(bool value) {
    loading.value = value;
  }

  void showError(String message) {
    _errorRevision++;
    errorMessage.value = message;
  }

  void setSuccess(bool value) {
    success.value = value;
  }

  void reset() {
    _errorRevision++;
    loading.value = false;
    errorMessage.value = null;
    success.value = false;
  }

  Future<void> showTemporaryError(String message) async {
    showError(message);
    final revision = _errorRevision;

    await Future.delayed(const Duration(seconds: 3));

    if (revision == _errorRevision) clearError();
  }

  void clearError() {
    _errorRevision++;
    errorMessage.value = null;
  }
}
