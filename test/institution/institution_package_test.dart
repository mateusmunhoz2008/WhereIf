import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/dev/demo_backend/demo_backend_store.dart';
import 'package:autth_injustice_app/events/domain/models/event_category.dart';
import 'package:autth_injustice_app/institution/application/institution_package_registry.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/institution/domain/institution_package_validator.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_backend_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_branding_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_events_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_features_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_hours_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_localization_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_map_manifest.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_resource.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_theme_config.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_event_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ifpr = IfprPguaPackage();

  group('IfprPguaPackage', () {
    test('satisfies the institution package contract', () {
      expect(
        InstitutionPackageValidator.validate(
          ifpr,
          appLanguageCodes: AppLocalizations.supportedLocales.map(
            (locale) => locale.languageCode,
          ),
        ),
        isEmpty,
      );
      expect(ifpr.branding.campusId, 'pgua');
      expect(ifpr.backend.isolatedFirebaseProject, isTrue);
      expect(ifpr.events.categories, IfprPguaEventCategories.values);
      expect(
        ifpr.events.fallbackCategory,
        IfprPguaEventCategories.other,
      );
      expect(ifpr.features.eventImageGallery, isTrue);
      expect(ifpr.events.presetImages, hasLength(7));
      expect(
        ifpr.map.primaryResource?.location,
        endsWith('campus_exterior_standard.glb'),
      );
    });

    test('bundles every declared institutional image', () async {
      final resources = [
        ifpr.branding.logoOnLightBackground,
        ifpr.branding.logoOnDarkBackground,
        ...ifpr.events.presetImages,
      ];

      for (final resource in resources) {
        expect(
          resource.location,
          startsWith('assets/institutions/${ifpr.id}/'),
        );
        final bytes = await rootBundle.load(resource.location);
        expect(bytes.lengthInBytes, greaterThan(0));
      }
    });

    testWidgets('builds the current visual identity from package tokens',
        (tester) async {
      final light = buildLightTheme(ifpr.theme);
      final dark = buildDarkTheme(ifpr.theme);

      await tester.pumpWidget(
        MaterialApp(
          theme: light,
          darkTheme: dark,
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      expect(light.colorScheme.primary, ifpr.theme.light.primary);
      expect(dark.colorScheme.primary, ifpr.theme.dark.primary);
      expect(light.scaffoldBackgroundColor, Colors.white);
      expect(dark.scaffoldBackgroundColor, Colors.black);
    });

    test('controls hours policy consumed by the backend adapter', () {
      final customPackage = _PackageOverride(
        base: ifpr,
        hours: const InstitutionHoursConfig(
          enabled: true,
          isInformalEstimate: true,
          targetMinutes: 200 * Duration.minutesPerHour,
          milestoneMinutes: [
            0,
            100 * Duration.minutesPerHour,
            200 * Duration.minutesPerHour,
          ],
        ),
      );
      final store = DemoBackendStore(institutionPackage: customPackage);

      final summary = store.complementaryHoursSummary(store.currentUser.uid);

      expect(summary.targetMinutes, 200 * Duration.minutesPerHour);
      expect(
        summary.milestoneMinutes,
        [0, 6000, 12000],
      );
    });

    test('resolves package aliases and rejects unknown packages', () {
      expect(
        InstitutionPackageRegistry.resolve(packageId: 'ifpr').id,
        ifpr.id,
      );
      expect(
        () => InstitutionPackageRegistry.resolve(packageId: 'unknown'),
        throwsStateError,
      );
    });
  });

  group('Extensibility', () {
    test('supports institution-defined event categories', () {
      const robotics = EventCategory(
        storageValue: 'robotics',
        iconKey: 'technology',
        localizedLabels: {
          'pt': 'Robótica',
          'en': 'Robotics',
        },
      );
      const events = InstitutionEventsConfig(
        categories: [robotics],
        fallbackCategory: robotics,
        presetImages: [],
        allowCustomImageUpload: true,
        allowExternalLinks: false,
      );

      expect(events.resolveCategory('robotics'), robotics);
      expect(
        robotics.customLabelFor('en', fallbackLanguageCode: 'pt'),
        'Robotics',
      );
      expect(
        robotics.customLabelFor('es', fallbackLanguageCode: 'pt'),
        'Robótica',
      );
    });

    test('requires category labels for every package language', () {
      const incomplete = EventCategory(
        storageValue: 'incomplete',
        iconKey: 'other',
        localizedLabels: {'pt': 'Incompleta'},
      );
      final invalid = _PackageOverride(
        base: ifpr,
        events: const InstitutionEventsConfig(
          categories: [incomplete],
          fallbackCategory: incomplete,
          presetImages: [],
          allowCustomImageUpload: true,
          allowExternalLinks: true,
        ),
      );

      expect(
        InstitutionPackageValidator.validate(invalid),
        contains(
          'Event category "incomplete" is missing labels for en, es.',
        ),
      );
    });

    test('rejects an enabled map without a resource manifest', () {
      final invalid = _PackageOverride(
        base: ifpr,
        map: const InstitutionMapManifest.unconfigured(
          mapId: 'missing-map',
          rendererKey: 'three-js-gltf',
        ),
        features: const InstitutionFeaturesConfig(
          map: true,
          complementaryHours: true,
          eventManagement: true,
          eventImageGallery: false,
          notifications: true,
        ),
      );

      expect(
        InstitutionPackageValidator.validate(invalid),
        contains('Map feature requires a configured map manifest.'),
      );
    });

    test('supports a versioned map made of multiple resources', () {
      const map = InstitutionMapManifest(
        mapId: 'test-campus',
        version: 1,
        rendererKey: 'three-js-gltf',
        format: InstitutionMapFormat.gltf,
        primaryResource: InstitutionResource.asset(
          path: 'assets/institutions/ifpr-pgua/map/campus.gltf',
          kind: InstitutionResourceKind.mapBundle,
        ),
        metadataResource: InstitutionResource.asset(
          path: 'assets/institutions/ifpr-pgua/map/places.json',
          kind: InstitutionResourceKind.mapMetadata,
        ),
        supportingResources: [
          InstitutionResource.asset(
            path: 'assets/institutions/ifpr-pgua/map/campus.bin',
            kind: InstitutionResourceKind.other,
          ),
          InstitutionResource.asset(
            path: 'assets/institutions/ifpr-pgua/map/atlas.webp',
            kind: InstitutionResourceKind.rasterImage,
          ),
        ],
      );
      final package = _PackageOverride(
        base: ifpr,
        map: map,
        features: const InstitutionFeaturesConfig(
          map: true,
          complementaryHours: true,
          eventManagement: true,
          eventImageGallery: false,
          notifications: true,
        ),
      );

      expect(map.allResources, hasLength(4));
      expect(InstitutionPackageValidator.validate(package), isEmpty);
    });
  });
}

class _PackageOverride implements InstitutionPackage {
  final InstitutionPackage base;
  final InstitutionHoursConfig? hours;
  final InstitutionEventsConfig? overriddenEvents;
  final InstitutionFeaturesConfig? overriddenFeatures;
  final InstitutionMapManifest? overriddenMap;

  const _PackageOverride({
    required this.base,
    this.hours,
    InstitutionEventsConfig? events,
    InstitutionFeaturesConfig? features,
    InstitutionMapManifest? map,
  })  : overriddenEvents = events,
        overriddenFeatures = features,
        overriddenMap = map;

  @override
  String get id => base.id;

  @override
  String get version => base.version;

  @override
  InstitutionBackendConfig get backend => base.backend;

  @override
  InstitutionBrandingConfig get branding => base.branding;

  @override
  InstitutionHoursConfig get complementaryHours =>
      hours ?? base.complementaryHours;

  @override
  InstitutionEventsConfig get events => overriddenEvents ?? base.events;

  @override
  InstitutionFeaturesConfig get features => overriddenFeatures ?? base.features;

  @override
  InstitutionLocalizationConfig get localization => base.localization;

  @override
  InstitutionMapManifest get map => overriddenMap ?? base.map;

  @override
  InstitutionThemeConfig get theme => base.theme;
}
