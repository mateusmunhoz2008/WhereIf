import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_backend_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_branding_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_events_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_features_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_hours_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_localization_config.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_map_manifest.dart';
import 'package:autth_injustice_app/institution/domain/models/institution_theme_config.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_assets.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_event_categories.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_event_images.dart';
import 'package:flutter/material.dart';

class IfprPguaPackage implements InstitutionPackage {
  const IfprPguaPackage();

  @override
  String get id => 'ifpr-pgua';

  @override
  String get version => '1.0.0';

  @override
  InstitutionBrandingConfig get branding => const InstitutionBrandingConfig(
        appName: 'WhereIF',
        institutionName: 'Instituto Federal do Paraná',
        institutionAcronym: 'IFPR',
        campusId: 'pgua',
        campusName: 'Campus Paranaguá',
        supportEmail: 'mateus@ifpr.edu.br',
        websiteUrl: 'https://ifpr.edu.br',
        logoOnLightBackground: IfprPguaAssets.logoBlack,
        logoOnDarkBackground: IfprPguaAssets.logoWhite,
      );

  @override
  InstitutionThemeConfig get theme => const InstitutionThemeConfig(
        light: InstitutionColorPalette(
          primary: Color.fromARGB(255, 213, 62, 255),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color.fromARGB(255, 140, 52, 255),
          onSecondary: Color(0xFFFFFFFF),
          surface: Color.fromARGB(255, 241, 241, 241),
          onSurface: Color(0xFF1C1B1F),
          tertiary: Color(0xFFFFFFFF),
          onTertiary: Color(0xFF000000),
          scaffoldBackground: Color(0xFFFFFFFF),
          card: Color(0xFFF5F5F5),
        ),
        dark: InstitutionColorPalette(
          primary: Color.fromARGB(255, 88, 0, 189),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color.fromARGB(255, 153, 29, 206),
          onSecondary: Color(0xFFFFFFFF),
          surface: Color(0xFF121212),
          onSurface: Color(0xFFFFFFFF),
          tertiary: Color(0xFF000000),
          onTertiary: Color(0xFFFFFFFF),
          scaffoldBackground: Color(0xFF000000),
          card: Color(0xFF1E1E1E),
        ),
      );

  @override
  InstitutionLocalizationConfig get localization =>
      const InstitutionLocalizationConfig(
        defaultLanguageCode: 'pt',
        supportedLanguageCodes: ['pt', 'en', 'es'],
      );

  @override
  InstitutionHoursConfig get complementaryHours => const InstitutionHoursConfig(
        enabled: true,
        isInformalEstimate: true,
        targetMinutes: 150 * Duration.minutesPerHour,
        milestoneMinutes: [
          0,
          50 * Duration.minutesPerHour,
          100 * Duration.minutesPerHour,
          150 * Duration.minutesPerHour,
        ],
      );

  @override
  InstitutionEventsConfig get events => const InstitutionEventsConfig(
        categories: IfprPguaEventCategories.values,
        fallbackCategory: IfprPguaEventCategories.other,
        presetImages: IfprPguaEventImages.values,
        allowCustomImageUpload: true,
        allowExternalLinks: true,
      );

  @override
  InstitutionMapManifest get map => const InstitutionMapManifest.unconfigured(
        mapId: 'ifpr-pgua-main-campus',
        rendererKey: 'three-js-gltf',
      );

  @override
  InstitutionBackendConfig get backend => const InstitutionBackendConfig(
        runtime: InstitutionBackendRuntime.hybridDemo,
        firebaseOptionsKey: 'ifpr-pgua',
        firebaseProjectId: 'whereif-87272',
        storageBucket: 'whereif-87272.firebasestorage.app',
        firestoreDatabaseId: '(default)',
        schemaVersion: 1,
      );

  @override
  InstitutionFeaturesConfig get features => const InstitutionFeaturesConfig(
        map: false,
        complementaryHours: true,
        eventManagement: true,
        eventImageGallery: true,
        notifications: true,
      );
}
