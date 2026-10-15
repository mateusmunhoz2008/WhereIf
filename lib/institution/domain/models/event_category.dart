import 'package:flutter/foundation.dart';

@immutable
class EventCategory {
  final String storageValue;
  final String iconKey;
  final Map<String, String> localizedLabels;

  const EventCategory({
    required this.storageValue,
    required this.iconKey,
    required this.localizedLabels,
  }) : assert(storageValue != '');

  String? customLabelFor(
    String languageCode, {
    required String fallbackLanguageCode,
  }) {
    if (localizedLabels.isEmpty) return null;
    return localizedLabels[languageCode] ??
        localizedLabels[fallbackLanguageCode] ??
        localizedLabels.values.first;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EventCategory && storageValue == other.storageValue;
  }

  @override
  int get hashCode => storageValue.hashCode;

  @override
  String toString() => 'EventCategory($storageValue)';
}
