import 'package:autth_injustice_app/institution/domain/institution_package.dart';

abstract final class InstitutionPackageValidator {
  static List<String> validate(
    InstitutionPackage package, {
    Iterable<String> appLanguageCodes = const ['pt', 'en', 'es'],
  }) {
    final errors = <String>[];
    final localization = package.localization;
    final hours = package.complementaryHours;
    final categories = package.events.categories;
    final presetImages = package.events.presetImages;
    final branding = package.branding;
    final bundledAssetPrefix = 'assets/institutions/${package.id}/';

    if (!RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$').hasMatch(package.id)) {
      errors.add('Package id must be stable and URL-safe.');
    }
    if (branding.appName.trim().isEmpty ||
        branding.institutionName.trim().isEmpty ||
        branding.campusId.trim().isEmpty ||
        branding.campusName.trim().isEmpty ||
        !branding.supportEmail.contains('@')) {
      errors.add('Institution branding manifest is incomplete.');
    }

    final languageCodes = localization.supportedLanguageCodes;
    if (languageCodes.isEmpty ||
        languageCodes.toSet().length != languageCodes.length) {
      errors.add('Supported language codes must be non-empty and unique.');
    }
    if (!languageCodes.contains(localization.defaultLanguageCode)) {
      errors.add('Default language must be enabled by the package.');
    }
    if (!languageCodes.every(appLanguageCodes.contains)) {
      errors.add('Package enables a language not compiled into the app.');
    }

    if (hours.enabled) {
      final milestones = hours.milestoneMinutes;
      if (hours.targetMinutes <= 0 ||
          milestones.length < 2 ||
          milestones.first != 0 ||
          milestones.last != hours.targetMinutes) {
        errors.add('Hours milestones must start at 0 and end at the target.');
      }
      for (var index = 1; index < milestones.length; index++) {
        if (milestones[index] <= milestones[index - 1]) {
          errors.add('Hours milestones must be strictly increasing.');
          break;
        }
      }
    }

    final categoryIds =
        categories.map((category) => category.storageValue).toList();
    if (categoryIds.isEmpty ||
        categoryIds.any((id) => id.trim().isEmpty) ||
        categoryIds.toSet().length != categoryIds.length) {
      errors.add('Event category ids must be non-empty and unique.');
    }
    if (!categories.contains(package.events.fallbackCategory)) {
      errors.add('Event fallback category must belong to the package.');
    }
    for (final category in categories) {
      final missingLanguageCodes = languageCodes
          .where((code) =>
              category.localizedLabels[code]?.trim().isNotEmpty != true)
          .toList();
      if (missingLanguageCodes.isNotEmpty) {
        errors.add(
          'Event category "${category.storageValue}" is missing labels for '
          '${missingLanguageCodes.join(', ')}.',
        );
      }
    }

    final presetImageLocations =
        presetImages.map((image) => image.location).toList();
    if (presetImageLocations.toSet().length != presetImageLocations.length) {
      errors.add('Event gallery image locations must be unique.');
    }

    final bundledResources = [
      branding.logoOnLightBackground,
      branding.logoOnDarkBackground,
      ...presetImages,
      ...package.map.allResources,
    ].where((resource) => resource.isBundled);
    for (final resource in bundledResources) {
      if (!resource.location.startsWith(bundledAssetPrefix) ||
          resource.location.contains('\\') ||
          resource.location
              .split('/')
              .any((part) => part == '..' || part == '.')) {
        errors.add(
          'Bundled resource "${resource.location}" must belong to '
          'package "${package.id}".',
        );
      }
    }

    if (package.features.map && !package.map.isConfigured) {
      errors.add('Map feature requires a configured map manifest.');
    }
    if (package.map.isConfigured && package.map.version <= 0) {
      errors.add('Configured map manifest requires a positive version.');
    }
    final mapResourceLocations =
        package.map.allResources.map((resource) => resource.location).toList();
    if (mapResourceLocations.toSet().length != mapResourceLocations.length) {
      errors.add('Map resource locations must be unique.');
    }
    if (package.features.eventImageGallery && presetImages.isEmpty) {
      errors.add('Event image gallery requires at least one image.');
    }

    if (package.backend.firebaseOptionsKey.trim().isEmpty ||
        package.backend.firebaseProjectId.trim().isEmpty ||
        package.backend.storageBucket.trim().isEmpty ||
        package.backend.firestoreDatabaseId.trim().isEmpty ||
        package.backend.firestoreDatabaseId.contains('/') ||
        package.backend.firestoreDatabaseId !=
            package.backend.firestoreDatabaseId.trim() ||
        package.backend.schemaVersion <= 0) {
      errors.add('Backend manifest is incomplete.');
    }

    return List.unmodifiable(errors);
  }

  static void ensureValid(
    InstitutionPackage package, {
    Iterable<String> appLanguageCodes = const ['pt', 'en', 'es'],
  }) {
    final errors = validate(
      package,
      appLanguageCodes: appLanguageCodes,
    );
    if (errors.isEmpty) return;

    throw StateError(
      'Invalid institution package "${package.id}": ${errors.join(' ')}',
    );
  }
}
