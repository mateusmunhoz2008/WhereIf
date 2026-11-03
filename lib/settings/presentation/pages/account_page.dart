import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/core/widgets/app_entrance_transition.dart';
import 'package:autth_injustice_app/map/presentation/navigation/map_routes.dart';
import 'package:autth_injustice_app/settings/domain/facades/i_account_security_facade.dart';
import 'package:autth_injustice_app/settings/presentation/navigation/settings_routes.dart';
import 'package:autth_injustice_app/settings/presentation/widgets/account/delete_account_dialog.dart';
import 'package:autth_injustice_app/settings/presentation/widgets/settings/settings_option_tile.dart';
import 'package:autth_injustice_app/settings/presentation/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _deleteAccount(
    BuildContext context, {
    required bool requiresPassword,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = context.l10n.accountDeleted;

    final deleted = await showDeleteAccountDialog(
      context,
      requiresPassword: requiresPassword,
    );
    if (!deleted || !context.mounted) return;

    context.goNamed(MapRouteNames.map);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(deletedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final scale = responsive.layoutScale;
    final textScale = responsive.textScale;
    final topPadding = responsive.isCompact ? 12.0 : 18.0;
    final bottomPadding = (36 * scale).clamp(28.0, 48.0);
    final credentials = injector.get<IAccountSecurityFacade>().credentialInfo;

    return Scaffold(
      backgroundColor: context.tertiary,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
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
                      context.l10n.accountTitle,
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
                        title: context.l10n.accountProfileSection,
                        textScale: textScale,
                      ),
                      SizedBox(height: 12 * scale),
                      SettingsOptionTile(
                        icon: Icons.person_outline_rounded,
                        label: context.l10n.accountChangeName,
                        scale: scale,
                        textScale: textScale,
                        showChevron: true,
                        onTap: () => context.pushNamed(
                          SettingsRouteNames.changeName,
                        ),
                      ),
                      SizedBox(height: 18 * scale),
                      SettingsSectionTitle(
                        title: context.l10n.accountSecuritySection,
                        textScale: textScale,
                      ),
                      SizedBox(height: 12 * scale),
                      if (credentials.hasPassword) ...[
                        SettingsOptionTile(
                          icon: Icons.alternate_email_rounded,
                          label: context.l10n.accountChangeEmail,
                          scale: scale,
                          textScale: textScale,
                          showChevron: true,
                          onTap: () => context.pushNamed(
                            SettingsRouteNames.changeEmail,
                          ),
                        ),
                        SettingsOptionTile(
                          icon: Icons.lock_outline_rounded,
                          label: context.l10n.accountChangePassword,
                          scale: scale,
                          textScale: textScale,
                          showChevron: true,
                          onTap: () => context.pushNamed(
                            SettingsRouteNames.changePassword,
                          ),
                        ),
                      ] else if (credentials.isGoogleOnly)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4 * scale,
                            vertical: 8 * scale,
                          ),
                          child: Text(
                            context.l10n.accountManagedByGoogle,
                            style: context.bodySmall?.copyWith(
                              color: context.onTertiary.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      SizedBox(height: 8 * scale),
                      SettingsOptionTile(
                        icon: Icons.delete_outline_rounded,
                        label: context.l10n.accountDelete,
                        scale: scale,
                        textScale: textScale,
                        destructive: true,
                        showChevron: true,
                        onTap: () => _deleteAccount(
                          context,
                          requiresPassword: credentials.hasPassword,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
