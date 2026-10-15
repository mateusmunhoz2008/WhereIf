import 'package:autth_injustice_app/app_startup/data/repositories/app_entry_repository_impl.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_climate_controller.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_performance_controller.dart';
import 'package:autth_injustice_app/settings/presentation/pages/settings_page.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/settings/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthFacade extends Fake implements IAuthUseCaseFacade {}

void main() {
  testWidgets('performance switch works in both themes and all three languages',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = MapPerformanceController();
    final viewModel = SettingsViewModel(
      ThemeController(),
      LocaleController(institutionPackage: const IfprPguaPackage()),
      _AuthFacade(),
      const AppEntryRepositoryImpl(),
      MapClimateController(),
      controller,
    );
    injector.addInstance<SettingsViewModel>(viewModel);
    injector.commit();
    addTearDown(injector.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      for (final language in ['pt', 'en', 'es']) {
        await controller.setEnabled(false);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: dark
              ? buildDarkTheme(const IfprPguaPackage().theme)
              : buildLightTheme(const IfprPguaPackage().theme),
          home: const SettingsPage(),
        ));
        await tester.pumpAndSettle();
        final tile = find.byKey(const ValueKey('settings-map-performance'));
        final toggle = find.descendant(of: tile, matching: find.byType(Switch));
        await tester.ensureVisible(tile);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isTrue);
        expect(
            (await SharedPreferences.getInstance())
                .getBool(MapPerformanceController.preferenceKey),
            isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(controller.enabled.value, isFalse);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
