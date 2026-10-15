import 'package:autth_injustice_app/core/formatters/app_date_time_formatter.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/events/domain/models/event_editor_draft.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/presentation/l10n/event_category_l10n.dart';
import 'package:autth_injustice_app/events/presentation/widgets/events_catalog/event_banner.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';

class EventReviewSummary extends StatelessWidget {
  final EventEditorDraft draft;
  final ValueChanged<int> onEditStep;

  const EventReviewSummary({
    super.key,
    required this.draft,
    required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = draft.complementaryMinutes;
    final hoursLabel = minutes == null
        ? context.l10n.eventEditorNotOffered
        : context.l10n.eventEditorHoursAndMinutes(
            minutes ~/ Duration.minutesPerHour,
            minutes % Duration.minutesPerHour,
          );
    final endLabel = draft.endMode == EventEndMode.automatic
        ? AppDateTimeFormatter.eventDateTime(context, draft.endsAt!)
        : context.l10n.eventEditorManualEndReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.295,
              child: EventBanner(
                event: draft.toDisplayPreview(
                  fallbackCategory: context.institution.events.fallbackCategory,
                ),
                large: true,
                onTap: () {},
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _EditButton(
                onPressed: () => onEditStep(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _ReviewRow(
          icon: Icons.title_rounded,
          label: context.l10n.eventEditorTitle,
          value: draft.title,
          onEdit: () => onEditStep(0),
        ),
        _ReviewRow(
          icon: Icons.category_outlined,
          label: context.l10n.eventEditorCategory,
          value: draft.category?.localizedLabel(context) ?? '',
          onEdit: () => onEditStep(0),
        ),
        _ReviewRow(
          icon: Icons.calendar_today_outlined,
          label: context.l10n.eventEditorDateAndTime,
          value: AppDateTimeFormatter.eventDateTime(
            context,
            draft.startsAt!,
          ),
          onEdit: () => onEditStep(1),
        ),
        _ReviewRow(
          icon: draft.endMode == EventEndMode.automatic
              ? Icons.event_busy_outlined
              : Icons.touch_app_outlined,
          label: context.l10n.eventEditorEnd,
          value: endLabel,
          onEdit: () => onEditStep(2),
        ),
        _ReviewRow(
          icon: Icons.location_on_outlined,
          label: context.l10n.eventEditorLocation,
          value: draft.displayLocation ?? context.l10n.eventEditorNotInformed,
          onEdit: () => onEditStep(3),
        ),
        _ReviewRow(
          icon: Icons.notes_rounded,
          label: context.l10n.eventEditorDescription,
          value: draft.description,
          onEdit: () => onEditStep(4),
        ),
        _ReviewRow(
          icon: Icons.link_rounded,
          label: context.l10n.eventEditorExternalLink,
          value: draft.externalUrl ?? context.l10n.eventEditorNotInformed,
          onEdit: () => onEditStep(4),
        ),
        _ReviewRow(
          icon: Icons.workspace_premium_outlined,
          label: context.l10n.eventEditorComplementaryHours,
          value: hoursLabel,
          onEdit: () => onEditStep(5),
        ),
      ],
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
          _EditButton(onPressed: onEdit),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EditButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tertiary.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: context.l10n.eventManagementEdit,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          Icons.edit_rounded,
          size: 18,
          color: context.primary,
        ),
      ),
    );
  }
}
