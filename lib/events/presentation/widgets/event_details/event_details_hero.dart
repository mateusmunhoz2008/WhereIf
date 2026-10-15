import 'package:autth_injustice_app/core/formatters/hours_minutes_formatter.dart';
import 'package:autth_injustice_app/core/formatters/app_date_time_formatter.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/widgets/app_back_button.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/presentation/l10n/event_category_l10n.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_card_visual_style.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_image.dart';
import 'event_location_rail.dart';
import 'package:flutter/material.dart';

class EventDetailsHero extends StatelessWidget {
  final EventPreview event;
  final double? complementaryHours;
  final bool isCompact;
  final VoidCallback onBack;

  const EventDetailsHero({
    super.key,
    required this.event,
    this.complementaryHours,
    required this.isCompact,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = context.extraPagePadding.left;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          EventImage(
            source: event.imageUrl,
            fit: BoxFit.cover,
            error: ColoredBox(
              color: context.colors.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  context.tertiary.withValues(alpha: 0.42),
                  context.tertiary,
                ],
                stops: const [0.32, 0.68, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                top: isCompact ? 10 : 16,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppBackButton(
                  onPressed: onBack,
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
          Positioned(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 96,
            bottom: isCompact ? 28 : 36,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                child: _HeroText(
                  event: event,
                  complementaryHours: complementaryHours,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatefulWidget {
  final EventPreview event;
  final double? complementaryHours;

  const _HeroText({
    required this.event,
    required this.complementaryHours,
  });

  @override
  State<_HeroText> createState() => _HeroTextState();
}

class _HeroTextState extends State<_HeroText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _contentController;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _textSlide =
        Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
      ),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact =
        context.isVerySmallScreen || context.screenSize.width < 360;
    final locationLabels = (widget.event.mapLocations.isEmpty
            ? [widget.event.location]
            : widget.event.mapLocations.map((place) => place.label))
        .where((label) => label.trim().isNotEmpty)
        .toList();
    final metaPills = <Widget>[
      _EventMetaPill(
        icon: Icons.calendar_today_outlined,
        label: AppDateTimeFormatter.eventPeriod(
          context,
          startsAt: widget.event.startsAt,
          endsAt: widget.event.endsAt,
        ),
        isCompact: isCompact,
      ),
      if (widget.complementaryHours case final hours?)
        _EventMetaPill(
          icon: Icons.schedule_outlined,
          label: HoursMinutesFormatter.format(hours),
          isCompact: isCompact,
        ),
    ];

    return SlideTransition(
      position: _textSlide,
      child: FadeTransition(
        opacity: _textOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.category.localizedLabel(context).toUpperCase(),
              style: context.text.labelLarge?.copyWith(
                fontSize: isCompact
                    ? context.text.labelSmall?.fontSize
                    : context.text.labelLarge?.fontSize,
                color: context.primary,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: isCompact ? 6 : 9,
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              widget.event.title,
              style: context.displaySmall?.copyWith(
                fontSize: isCompact
                    ? context.text.displaySmall?.fontSize
                    : context.text.displayMedium?.fontSize,
                color: context.onTertiary,
                shadows: EventCardVisualStyle.textShadows(
                  context,
                  prominent: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: isCompact ? 7 : 10,
              runSpacing: isCompact ? 7 : 10,
              children: metaPills,
            ),
            if (locationLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              EventLocationRail(
                key: ValueKey('event-details-locations-${widget.event.id}'),
                labels: locationLabels,
                isCompact: isCompact,
              ),
            ],
            const SizedBox(height: 8),
            _EventDescription(event: widget.event),
          ],
        ),
      ),
    );
  }
}

void _showEventInfoSheet(BuildContext context,
    {required String title, required Widget child}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 85),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              const CloseButton(),
            ]),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _EventDescription extends StatelessWidget {
  const _EventDescription({required this.event});

  final EventPreview event;

  void _readMore(BuildContext context) => _showEventInfoSheet(
        context,
        title: context.l10n.eventDetailsReadMore,
        child: Scrollbar(
          child: SingleChildScrollView(
            child: SelectableText(event.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final style = context.bodySmall?.copyWith(
            color: context.onTertiary,
            shadows: EventCardVisualStyle.textShadows(context),
          );
          final measurement = TextPainter(
            text: TextSpan(text: event.description, style: style),
            maxLines: 3,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final needsMore = measurement.didExceedMaxLines;
          measurement.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.description,
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: style),
              if (needsMore)
                TextButton(
                  onPressed: () => _readMore(context),
                  style: TextButton.styleFrom(
                    foregroundColor: context.onTertiary,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    context.l10n.eventDetailsReadMore,
                    style: TextStyle(
                      shadows: EventCardVisualStyle.textShadows(context),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _EventMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompact;

  const _EventMetaPill({
    required this.icon,
    required this.label,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.onTertiary;

    final radius = BorderRadius.circular(isCompact ? 8 : 10);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 10,
        vertical: isCompact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: radius,
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isCompact ? 13 : 15,
            color: color.withValues(alpha: 0.82),
          ),
          SizedBox(width: isCompact ? 4 : 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: context.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.88),
                fontSize: isCompact ? 10 : null,
                shadows: EventCardVisualStyle.textShadows(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
