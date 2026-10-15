import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_resource.dart';
import 'package:flutter/foundation.dart';

@immutable
class InstitutionEventsConfig {
  final List<EventCategory> categories;
  final EventCategory fallbackCategory;
  final List<InstitutionResource> presetImages;
  final bool allowCustomImageUpload;
  final bool allowExternalLinks;

  const InstitutionEventsConfig({
    required this.categories,
    required this.fallbackCategory,
    required this.presetImages,
    required this.allowCustomImageUpload,
    required this.allowExternalLinks,
  });

  EventCategory resolveCategory(String storageValue) {
    return categories.firstWhere(
      (category) => category.storageValue == storageValue,
      orElse: () => fallbackCategory,
    );
  }
}
