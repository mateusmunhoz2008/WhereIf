import 'dart:async';
import 'dart:math' as math;

import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/viewmodels/summary/complementary_hours_viewmodel.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/widgets/records/complementary_hours_records_drawer.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/widgets/summary/complementary_hours_header.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/widgets/summary/complementary_hours_progress_gauge.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/settings/presentation/navigation/settings_routes.dart';
import 'package:autth_injustice_app/user_management/presentation/navigation/user_management_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ComplementaryHoursPage extends StatefulWidget {
  const ComplementaryHoursPage({super.key});

  @override
  State<ComplementaryHoursPage> createState() => _ComplementaryHoursPageState();
}

class _ComplementaryHoursPageState extends State<ComplementaryHoursPage> {
  late final ComplementaryHoursViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<ComplementaryHoursViewModel>();
    unawaited(_viewModel.commands.loadSummary());
    unawaited(_viewModel.commands.loadSummary(forceRefresh: true));
  }

  void _openSettings() {
    context.pushNamed(SettingsRouteNames.settings);
  }

  void _openUsers() {
    context.pushNamed(UserManagementRouteNames.users);
  }

  void _refreshSummary() {
    unawaited(_viewModel.commands.loadSummary(forceRefresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final gaugeSizing = _HoursGaugeSizing.fromWidthClass(
      responsive.widthClass,
    );
    final scale = responsive.layoutScale;
    final pagePadding = context.extraPagePadding;
    final canManageAccounts =
        injector.get<AuthorizationService>().canManageAccounts;

    return Scaffold(
      backgroundColor: context.tertiary,
      body: SafeArea(
        bottom: false,
        child: Watch(
          (_) {
            final state = _viewModel.state;
            final summary = state.summary.value;

            if (state.isInitialLoading) {
              return const AppStatusView.loading();
            }

            if (summary == null) {
              return AppStatusView(
                icon: Icons.hourglass_disabled_rounded,
                title: context.l10n.complementaryHoursLoadError,
                actionLabel: context.l10n.commonRetry,
                onAction: () => unawaited(
                  _viewModel.commands.loadSummary(forceRefresh: true),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = responsive.isCompact;
                final usesCompactNavigation =
                    context.isVerySmallScreen || context.screenSize.width < 360;
                final headerTop = isCompact ? 24.0 : 34.0;
                final headerGap = isCompact ? 21.0 : 70.0;
                final drawerBottomOffset = usesCompactNavigation ? 88.0 : 102.0;
                final drawerHandleHeight = 58 * scale;
                final gaugeTop = headerTop + (100 * scale) + headerGap;
                final drawerTop = constraints.maxHeight -
                    drawerBottomOffset -
                    drawerHandleHeight;
                final gaugeBottomGap = 16 * scale;
                final availableGaugeHeight = math.max(
                  0.0,
                  drawerTop - gaugeBottomGap - gaugeTop,
                );
                final preferredGaugeHeight = (constraints.maxHeight * 0.55)
                    .clamp(
                      gaugeSizing.minHeight,
                      gaugeSizing.maxHeight,
                    )
                    .toDouble();
                final progressHeight = math.min(
                  preferredGaugeHeight,
                  availableGaugeHeight,
                );
                final centeredGaugeTop =
                    (constraints.maxHeight - progressHeight) / 2;
                final maximumGaugeTop = math.max(
                  gaugeTop,
                  drawerTop - gaugeBottomGap - progressHeight,
                );
                final positionedGaugeTop = centeredGaugeTop.clamp(
                  gaugeTop,
                  maximumGaugeTop,
                );

                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Padding(
                        padding: pagePadding.copyWith(top: headerTop),
                        child: ComplementaryHoursHeader(
                          scale: scale,
                          onSettingsPressed: _openSettings,
                          onUsersPressed: canManageAccounts ? _openUsers : null,
                        ),
                      ),
                      Positioned(
                        top: positionedGaugeTop,
                        left: pagePadding.left,
                        right: pagePadding.right,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: gaugeSizing.maxWidth,
                            ),
                            child: ComplementaryHoursProgressGauge(
                              summary: summary,
                              height: progressHeight,
                              scale: scale,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        bottom: drawerBottomOffset,
                        child: ComplementaryHoursRecordsDrawer(
                          scale: scale,
                          onRecordsChanged: _refreshSummary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HoursGaugeSizing {
  final double minHeight;
  final double maxHeight;
  final double maxWidth;

  const _HoursGaugeSizing({
    required this.minHeight,
    required this.maxHeight,
    required this.maxWidth,
  });

  factory _HoursGaugeSizing.fromWidthClass(AppWidthClass widthClass) {
    return switch (widthClass) {
      AppWidthClass.micro => const _HoursGaugeSizing(
          minHeight: 230,
          maxHeight: 270,
          maxWidth: 300,
        ),
      AppWidthClass.tiny => const _HoursGaugeSizing(
          minHeight: 245,
          maxHeight: 300,
          maxWidth: 330,
        ),
      AppWidthClass.narrow => const _HoursGaugeSizing(
          minHeight: 260,
          maxHeight: 330,
          maxWidth: 360,
        ),
      AppWidthClass.compact => const _HoursGaugeSizing(
          minHeight: 275,
          maxHeight: 360,
          maxWidth: 390,
        ),
      AppWidthClass.standard => const _HoursGaugeSizing(
          minHeight: 285,
          maxHeight: 390,
          maxWidth: 420,
        ),
      AppWidthClass.largePhone => const _HoursGaugeSizing(
          minHeight: 300,
          maxHeight: 430,
          maxWidth: 460,
        ),
      AppWidthClass.tablet => const _HoursGaugeSizing(
          minHeight: 320,
          maxHeight: 460,
          maxWidth: 520,
        ),
      AppWidthClass.expanded => const _HoursGaugeSizing(
          minHeight: 340,
          maxHeight: 500,
          maxWidth: 560,
        ),
    };
  }
}
