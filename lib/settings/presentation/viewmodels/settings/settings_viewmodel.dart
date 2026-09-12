import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_graphics_controller.dart';

import 'settings_commands_viewmodel.dart';
import 'settings_state_viewmodel.dart';

class SettingsViewModel {
  late final SettingsState _state;
  late final SettingsCommands _commands;

  SettingsState get state => _state;
  SettingsCommands get commands => _commands;
  final MapGraphicsController mapGraphicsController;
  SettingsViewModel(
    ThemeController themeController,
    LocaleController localeController,
    IAuthUseCaseFacade authFacade,
    IAppEntryRepository appEntryRepository,
    this.mapGraphicsController,
  ) {
    _state = SettingsState();
    _commands = SettingsCommands(
      state: _state,
      themeController: themeController,
      localeController: localeController,
      authFacade: authFacade,
      appEntryRepository: appEntryRepository,
      mapGraphicsController: mapGraphicsController,
    );
  }
}
