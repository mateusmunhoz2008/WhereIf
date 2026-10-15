import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_card_visual_style.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_horizontal_rail.dart';
import 'package:flutter/material.dart';

class EventLocationRail extends StatelessWidget {
  final List<String> labels;
  final bool isCompact;
  const EventLocationRail(
      {super.key, required this.labels, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final color = context.onTertiary;
    final style = context.bodySmall?.copyWith(
      color: color.withValues(alpha: 0.88),
      fontSize: isCompact ? 10 : null,
      shadows: EventCardVisualStyle.textShadows(context),
    );
    final textHeight =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) *
            (style?.height ?? 1.4);
    return EventHorizontalRail(
      height: (textHeight + 20).ceilToDouble(),
      itemCount: labels.length,
      spacing: isCompact ? 12 : 16,
      clipBehavior: Clip.hardEdge,
      fadeRight: true,
      fadeLeft: true,
      itemBuilder: (_, index) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_outlined,
              size: isCompact ? 13 : 15, color: color.withValues(alpha: 0.82)),
          const SizedBox(width: 6),
          Text(labels[index], maxLines: 1, softWrap: false, style: style),
        ]),
      ),
    );
  }
}
