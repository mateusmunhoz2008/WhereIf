import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_record.dart';
import 'package:autth_injustice_app/core/formatters/hours_minutes_formatter.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplementaryHoursRecordCard extends StatefulWidget {
  final ComplementaryHoursRecord record;
  final double scale;
  final int index;
  final Animation<double>? swipeHintAnimation;
  final VoidCallback? onSwipeStarted;
  final Future<bool> Function()? onConfirmDelete;
  final VoidCallback? onDismissed;

  const ComplementaryHoursRecordCard({
    super.key,
    required this.record,
    required this.scale,
    required this.index,
    this.swipeHintAnimation,
    this.onSwipeStarted,
    this.onConfirmDelete,
    this.onDismissed,
  });

  @override
  State<ComplementaryHoursRecordCard> createState() =>
      _ComplementaryHoursRecordCardState();
}

class _ComplementaryHoursRecordCardState
    extends State<ComplementaryHoursRecordCard> {
  double _dismissProgress = 0;

  Future<bool> _confirmDismiss() async {
    final onConfirmDelete = widget.onConfirmDelete;
    if (onConfirmDelete == null) return false;

    final confirmed = await onConfirmDelete();
    if (!confirmed && mounted) {
      setState(() => _dismissProgress = 0);
    }
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20 * widget.scale);
    final canDelete =
        widget.onConfirmDelete != null && widget.onDismissed != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (widget.index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (canDelete)
              Positioned.fill(
                child: _DeleteBackground(
                  scale: widget.scale,
                  radius: radius,
                ),
              ),
            Dismissible(
              key: ValueKey('record-${widget.record.id}'),
              direction: canDelete
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              movementDuration: const Duration(milliseconds: 280),
              resizeDuration: const Duration(milliseconds: 260),
              dismissThresholds: const {DismissDirection.endToStart: 0.42},
              confirmDismiss: (_) => _confirmDismiss(),
              onDismissed: (_) => widget.onDismissed?.call(),
              onUpdate: (details) {
                if (!mounted) return;
                if (details.progress > 0) widget.onSwipeStarted?.call();
                setState(() => _dismissProgress = details.progress);
              },
              child: AnimatedBuilder(
                animation: widget.swipeHintAnimation ??
                    const AlwaysStoppedAnimation(0),
                builder: (context, child) {
                  final hintProgress = widget.swipeHintAnimation?.value ?? 0;

                  return Transform.translate(
                    offset: Offset(-92 * widget.scale * hintProgress, 0),
                    child: Opacity(
                      opacity: (1 - (_dismissProgress * 0.82)).clamp(0.08, 1.0),
                      child: child,
                    ),
                  );
                },
                child: ColoredBox(
                  color: context.tertiary,
                  child: _RecordCardContent(
                    record: widget.record,
                    scale: widget.scale,
                    radius: radius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCardContent extends StatelessWidget {
  final ComplementaryHoursRecord record;
  final double scale;
  final BorderRadius radius;

  const _RecordCardContent({
    required this.record,
    required this.scale,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.onTertiary;
    final date = DateFormat('dd/MM/yyyy').format(record.eventDate);
    final durationMinutes = record.durationMinutes;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: context.onTertiary.withValues(alpha: 0.09),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(18 * scale),
        child: Row(
          children: [
            Container(
              width: 46 * scale,
              height: 46 * scale,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15 * scale),
                border: Border.all(
                  color: accent.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 23 * scale,
                color: context.secondary.withValues(alpha: 1),
              ),
            ),
            SizedBox(width: 15 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.eventName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleLarge?.copyWith(
                      color: context.onTertiary,
                      fontSize: 17 * scale,
                    ),
                  ),
                  SizedBox(height: 9 * scale),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14 * scale,
                        color: context.onTertiary.withValues(alpha: 0.48),
                      ),
                      SizedBox(width: 7 * scale),
                      Text(
                        date,
                        style: context.bodySmall?.copyWith(
                          color: context.onTertiary.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            Container(
              constraints: BoxConstraints(maxWidth: 92 * scale),
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 9 * scale,
              ),
              decoration: BoxDecoration(
                color: context.onTertiary.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(14 * scale),
              ),
              child: Text(
                durationMinutes != null
                    ? HoursMinutesFormatter.formatMinutes(durationMinutes)
                    : context.l10n.complementaryHoursNoWorkload,
                textAlign: TextAlign.end,
                style: context.text.labelLarge?.copyWith(
                  color: context.onTertiary.withValues(
                    alpha: durationMinutes == null ? 0.52 : 1,
                  ),
                  fontSize: (durationMinutes == null ? 11 : 13) * scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  final double scale;
  final BorderRadius radius;

  const _DeleteBackground({
    required this.scale,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDarkMode ? 0.36 : 0.22),
        borderRadius: radius,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 24 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.commonDelete,
                style: context.text.labelSmall?.copyWith(
                  color: color,
                  fontSize: 12 * scale,
                ),
              ),
              SizedBox(width: 10 * scale),
              Icon(
                Icons.delete_outline_rounded,
                size: 27 * scale,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
