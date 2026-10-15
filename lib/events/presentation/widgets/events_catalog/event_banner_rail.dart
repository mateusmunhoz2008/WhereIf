import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_card_visual_style.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_horizontal_rail.dart';
import 'package:autth_injustice_app/events/presentation/widgets/events_catalog/event_banner.dart';
import 'package:flutter/material.dart';

class EventBannerRail extends StatelessWidget {
  final List<EventPreview> events;
  final bool isCompact;
  final bool large;
  final double? height;
  final ValueChanged<EventPreview> onEventTap;

  const EventBannerRail({
    super.key,
    required this.events,
    required this.isCompact,
    required this.large,
    this.height,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isCompact ? 20.0 : context.extraPagePadding.left;

    final railHeight = height ??
        (large ? (isCompact ? 200.0 : 244.0) : (isCompact ? 200.0 : 222.0));
    final width = railHeight * (large ? 1.295 : 0.748);

    return EventHorizontalRail(
      height: railHeight,
      spacing: isCompact ? 12 : 16,
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];

        return SizedBox(
          width: width,
          child: EventBanner(
            event: event,
            large: large,
            accentColor: EventCardVisualStyle.accentAt(index),
            onTap: () => onEventTap(event),
          ),
        );
      },
    );
  }
}
