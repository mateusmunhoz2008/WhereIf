import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:flutter/material.dart';

class EventDetailsActions extends StatelessWidget {
  final bool addedToPersonalHistory;
  final bool personalRecordUpdating;
  final bool authenticated;
  final VoidCallback? onPersonalRecordTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onExternalLinkTap;

  const EventDetailsActions({
    super.key,
    required this.addedToPersonalHistory,
    required this.personalRecordUpdating,
    required this.authenticated,
    required this.onPersonalRecordTap,
    required this.onMapTap,
    this.onExternalLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryActions = <Widget>[
      if (authenticated && onExternalLinkTap != null)
        AppActionButton(
          text: context.l10n.accessLink,
          color: context.onTertiary,
          style: AppActionButtonStyle.outlined,
          icon: Icons.open_in_new_rounded,
          onPressed: onExternalLinkTap,
        ),
      if (onMapTap != null)
        AppActionButton(
          text: context.l10n.viewOnMap,
          color: context.onTertiary,
          style: AppActionButtonStyle.outlined,
          icon: Icons.map_outlined,
          onPressed: onMapTap,
        ),
    ];
    if (!authenticated && secondaryActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (authenticated) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: context.onTertiary.withValues(alpha: 0.48),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.personalRecordNotice,
                  style: context.bodySmall?.copyWith(
                    color: context.onTertiary.withValues(alpha: 0.52),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppActionButton(
            text: personalRecordUpdating
                ? context.l10n.personalRecordUpdating
                : addedToPersonalHistory
                    ? context.l10n.personalHistoryAdded
                    : context.l10n.addToPersonalHistory,
            color: context.secondary,
            icon: addedToPersonalHistory
                ? Icons.bookmark_added_rounded
                : Icons.bookmark_add_outlined,
            onPressed: personalRecordUpdating ? null : onPersonalRecordTap,
          ),
        ],
        if (authenticated && secondaryActions.isNotEmpty)
          const SizedBox(height: 9),
        if (secondaryActions.length == 2)
          Row(
            children: [
              Expanded(child: secondaryActions[0]),
              const SizedBox(width: 9),
              Expanded(child: secondaryActions[1]),
            ],
          )
        else if (secondaryActions.isNotEmpty)
          secondaryActions.single,
      ],
    );
  }
}
