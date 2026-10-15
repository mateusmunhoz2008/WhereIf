import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/navigation/app_router.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/institution/application/institution_package_registry.dart';
import 'package:autth_injustice_app/institution/data/firebase/institution_firebase_options_registry.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_climate_controller.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_performance_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autth_injustice_app/core/network/connection_banner.dart';
import 'package:signals_flutter/signals_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _startApplication();
  } catch (_, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('Application startup failed.'),
      stack: stack,
      library: 'bootstrap',
    ));
    runApp(const _StartupFailureApp());
  }
}

Future<void> _startApplication() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final institutionPackage = InstitutionPackageRegistry.resolve();
  final firebaseOptions = InstitutionFirebaseOptionsRegistry.resolve(
    institutionPackage.backend,
  );

  final firebaseApp = await Firebase.initializeApp(options: firebaseOptions);

  setupDependencies(
    institutionPackage: institutionPackage,
    firebaseApp: firebaseApp,
  );

  await injector.get<MapClimateController>().initialize();
  await injector.get<MapPerformanceController>().initialize();

  final themeController = injector.get<ThemeController>();
  final localeController = injector.get<LocaleController>();

  await themeController.initialize();
  await localeController.initialize();

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
              child: ConnectionBanner(child: child!),
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

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Não foi possível iniciar o aplicativo.\n'
                'Feche e abra novamente. Se continuar, entre em contato com o suporte.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
