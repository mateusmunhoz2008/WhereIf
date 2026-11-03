import 'package:signals_flutter/signals_flutter.dart';

class DeleteAccountState {
  final loading = signal(false);
  final errorMessage = signal<String?>(null);

  void setLoading(bool value) => loading.value = value;
  void setError(String message) => errorMessage.value = message;
  void clearError() => errorMessage.value = null;

  void reset() {
    loading.value = false;
    errorMessage.value = null;
  }
}