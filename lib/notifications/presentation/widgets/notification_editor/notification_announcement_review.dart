import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_draft.dart';
import 'package:flutter/material.dart';

class NotificationAnnouncementReview extends StatelessWidget {
  final NotificationAnnouncementDraft draft;
  final ValueChanged<int> onEditStep;

  const NotificationAnnouncementReview({
    super.key,
    required this.draft,
    required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnnouncementPreview(draft: draft),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 20,
              color: context.primary,
            ),
            const SizedBox(
              width: 12,
              height: 40,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.notificationEditorAudience,
                    style: context.text.labelSmall?.copyWith(
                      color: context.onTertiary.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.notificationEditorAudienceAll,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.onTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ReviewRow(
          icon: Icons.title_rounded,
          label: context.l10n.notificationEditorTitleLabel,
          value: draft.title,
          onEdit: () => onEditStep(0),
        ),
        _ReviewRow(
          icon: Icons.notes_rounded,
          label: context.l10n.notificationEditorDescriptionLabel,
          value: draft.message,
          onEdit: () => onEditStep(0),
        ),
        _ReviewRow(
          icon: Icons.link_rounded,
          label: context.l10n.notificationEditorLinkLabel,
          value:
              draft.externalUrl ?? context.l10n.notificationEditorNotInformed,
          onEdit: () => onEditStep(1),
        ),
      ],
    );
  }
}

class _AnnouncementPreview extends StatelessWidget {
  final NotificationAnnouncementDraft draft;

  const _AnnouncementPreview({required this.draft});

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: context.isDarkMode ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.notificationUpdate.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(color: accent),
                ),
                const SizedBox(height: 7),
                Text(
                  draft.title,
                  style: context.text.titleLarge?.copyWith(
                    color: context.onTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  draft.message,
                  style: context.text.bodySmall?.copyWith(
                    color: context.onTertiary.withValues(alpha: 0.70),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: context.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: context.onTertiary.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: context.tertiary.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: context.l10n.eventManagementEdit,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: context.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
