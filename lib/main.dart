import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/navigation/app_router.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/institution/application/institution_package_registry.dart';
import 'package:autth_injustice_app/institution/data/firebase/institution_firebase_options_registry.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals_flutter/signals_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final institutionPackage = InstitutionPackageRegistry.resolve();
  final firebaseOptions = InstitutionFirebaseOptionsRegistry.resolve(
    institutionPackage.backend,
  );

  await Firebase.initializeApp(options: firebaseOptions);

  setupDependencies(institutionPackage: institutionPackage);

  final themeController = injector.get<ThemeController>();
  final localeController = injector.get<LocaleController>();

  runApp(
    Watch(
      (_) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: institutionPackage.branding.appName,
        theme: app_theme.buildLightTheme(institutionPackage.theme),
        darkTheme: app_theme.buildDarkTheme(institutionPackage.theme),
        themeMode: themeController.themeMode.value,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          final media = MediaQuery.of(context);

          return InstitutionScope(
            package: institutionPackage,
            child: MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            ),
          );
        },
        locale: localeController.locale.value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: institutionPackage.localization
            .resolveSupportedLocales(AppLocalizations.supportedLocales),
      ),
    ),
  );
}
