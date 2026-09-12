import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/map/domain/models/map_graphics_quality.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_graphics_controller.dart';

import 'settings_state_viewmodel.dart';

class SettingsCommands {
  final SettingsState state;
  final ThemeController _themeController;
  final LocaleController _localeController;
  final IAuthUseCaseFacade _authFacade;
  final IAppEntryRepository _appEntryRepository;
  final MapGraphicsController _mapGraphicsController;

  SettingsCommands({
    required this.state,
    required ThemeController themeController,
    required LocaleController localeController,
    required IAuthUseCaseFacade authFacade,
    required IAppEntryRepository appEntryRepository,
    required MapGraphicsController mapGraphicsController,
  })  : _themeController = themeController,
        _localeController = localeController,
        _authFacade = authFacade,
        _appEntryRepository = appEntryRepository,
        _mapGraphicsController = mapGraphicsController;

  void setDarkMode(bool enabled) {
    _themeController.setDarkMode(enabled);
  }

  void setNotificationsEnabled(bool enabled) {
    // O adaptador de push persistira a preferencia e pedira permissao nativa.
    state.setNotificationsEnabled(enabled);
  }

  void cycleLanguage(String currentLanguageCode) {
    _localeController.cycleLanguage(currentLanguageCode);
  }

  Future<void> setMapGraphicsQuality(MapGraphicsQuality quality) =>
      _mapGraphicsController.setQuality(quality);

  Future<bool> signOut() async {
    if (state.loading.value) return false;

    state
      ..setLoading(true)
      ..setError(null);

    try {
      final result = await _authFacade.signOutUseCase(());
      final signedOut = result.fold(
        onSuccess: (_) => true,
        onFailure: (failure) {
          state.setError(failure.msg);
          return false;
        },
      );
      if (!signedOut) return false;

      await _appEntryRepository.resetInitialPage();
      return true;
    } finally {
      state.setLoading(false);
    }
  }
}
