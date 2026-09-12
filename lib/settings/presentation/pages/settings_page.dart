import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/core/widgets/app_entrance_transition.dart';
import 'package:autth_injustice_app/core/widgets/dialogs/app_confirmation_dialog.dart';
import 'package:autth_injustice_app/core/widgets/loading_dots.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/settings/settings_viewmodel.dart';
import 'package:autth_injustice_app/settings/presentation/navigation/settings_routes.dart';
import 'package:autth_injustice_app/settings/presentation/widgets/settings/settings_option_tile.dart';
import 'package:autth_injustice_app/settings/presentation/widgets/settings/settings_panel.dart';
import 'package:autth_injustice_app/map/domain/models/map_graphics_quality.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<SettingsViewModel>();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: context.colors.error,
      title: context.l10n.settingsSignOutTitle,
      message: context.l10n.settingsSignOutMessage,
      cancelLabel: context.l10n.settingsCancel,
      cancelColor: context.onTertiary.withValues(alpha: 0.62),
      confirmLabel: context.l10n.settingsConfirmSignOut,
      confirmColor: context.colors.error,
      confirmForegroundColor: context.colors.onError,
      confirmIcon: Icons.logout_rounded,
    );

    if (!confirmed || !mounted) return;

    final signedOut = await _viewModel.commands.signOut();
    if (!mounted) return;

    if (signedOut) {
      context.go(AuthPaths.initial);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _viewModel.state.errorMessage.value ??
              context.l10n.settingsSignOutError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final scale = responsive.layoutScale;
    final textScale = responsive.textScale;
    final topPadding = responsive.isCompact ? 12.0 : 18.0;
    final bottomPadding = (36 * scale).clamp(28.0, 48.0);

    return Scaffold(
      backgroundColor: context.tertiary,
      body: SafeArea(
        bottom: false,
        child: Watch(
          (_) {
            final notificationsEnabled =
                _viewModel.state.notificationsEnabled.value;
            final signingOut = _viewModel.state.loading.value;
            final languageCode = Localizations.localeOf(context).languageCode;
            final mapGraphicsQuality =
                _viewModel.mapGraphicsController.quality.value;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: context.extraPagePadding.copyWith(
                top: topPadding,
                bottom: bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppEntranceTransition(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppBackButton(
                        onPressed: context.pop,
                        iconSize: 25 * scale,
                        foregroundColor: context.onTertiary,
                      ),
                    ),
                  ),
                  SizedBox(height: 18 * scale),
                  AppEntranceTransition(
                    delay: const Duration(milliseconds: 45),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          context.l10n.settingsTitle,
                          maxLines: 1,
                          style: context.displayLarge?.copyWith(
                            color: context.onTertiary,
                            fontSize: 48 * textScale,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30 * scale),
                  AppEntranceTransition(
                    delay: const Duration(milliseconds: 105),
                    child: SettingsPanel(
                      scale: scale,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsSectionTitle(
                            title: context.l10n.settingsAccountSection,
                            textScale: textScale,
                          ),
                          SizedBox(height: 12 * scale),
                          SettingsOptionTile(
                            icon: Icons.person_outline_rounded,
                            label: context.l10n.settingsEditProfile,
                            scale: scale,
                            textScale: textScale,
                            showChevron: true,
                            onTap: () => context.pushNamed(
                              SettingsRouteNames.account,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.dark_mode_outlined,
                            label: context.l10n.settingsDarkMode,
                            scale: scale,
                            textScale: textScale,
                            onTap: () => _viewModel.commands.setDarkMode(
                              !context.isDarkMode,
                            ),
                            trailing: Switch.adaptive(
                              value: context.isDarkMode,
                              activeTrackColor: context.secondary,
                              onChanged: _viewModel.commands.setDarkMode,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.view_in_ar_outlined,
                            label: context.l10n.settingsMapGraphics,
                            scale: scale,
                            textScale: textScale,
                            onTap: () =>
                                _viewModel.commands.setMapGraphicsQuality(
                              mapGraphicsQuality == MapGraphicsQuality.complete
                                  ? MapGraphicsQuality.light
                                  : MapGraphicsQuality.complete,
                            ),
                            trailing: SettingsValueBadge(
                              value: mapGraphicsQuality ==
                                      MapGraphicsQuality.complete
                                  ? context.l10n.settingsMapGraphicsComplete
                                  : context.l10n.settingsMapGraphicsLight,
                              scale: scale,
                              textScale: textScale,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.notifications_none_rounded,
                            label: context.l10n.settingsNotifications,
                            scale: scale,
                            textScale: textScale,
                            onTap: () =>
                                _viewModel.commands.setNotificationsEnabled(
                              !notificationsEnabled,
                            ),
                            trailing: Switch.adaptive(
                              value: notificationsEnabled,
                              activeTrackColor: context.secondary,
                              onChanged:
                                  _viewModel.commands.setNotificationsEnabled,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.translate_rounded,
                            label: context.l10n.settingsLanguage,
                            scale: scale,
                            textScale: textScale,
                            onTap: () => _viewModel.commands.cycleLanguage(
                              languageCode,
                            ),
                            trailing: SettingsLanguageBadge(
                              languageCode: languageCode,
                              scale: scale,
                              textScale: textScale,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.logout_rounded,
                            label: context.l10n.settingsSignOut,
                            scale: scale,
                            textScale: textScale,
                            destructive: true,
                            onTap: signingOut ? null : _confirmSignOut,
                            trailing: signingOut
                                ? LoadingDots(
                                    color: context.colors.error,
                                    size: 5 * scale,
                                    spacing: 2 * scale,
                                    rise: 3 * scale,
                                  )
                                : null,
                          ),
                          SizedBox(height: 22 * scale),
                          SettingsSectionTitle(
                            title: context.l10n.settingsSupportSection,
                            textScale: textScale,
                          ),
                          SizedBox(height: 12 * scale),
                          SettingsOptionTile(
                            icon: Icons.help_outline_rounded,
                            label: context.l10n.settingsHelpSupport,
                            scale: scale,
                            textScale: textScale,
                            showChevron: true,
                            onTap: () => context.pushNamed(
                              SettingsRouteNames.helpSupport,
                            ),
                          ),
                          SettingsOptionTile(
                            icon: Icons.info_outline_rounded,
                            label: context.l10n.settingsAbout,
                            scale: scale,
                            textScale: textScale,
                            showChevron: true,
                            onTap: () => context.pushNamed(
                              SettingsRouteNames.about,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
