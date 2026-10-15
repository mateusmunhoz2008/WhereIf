import 'package:autth_injustice_app/core/formatters/app_date_time_formatter.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/presentation/l10n/event_category_l10n.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_card_visual_style.dart';
import 'package:autth_injustice_app/events/presentation/widgets/common/event_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManagedEventCard extends StatefulWidget {
  final EventPreview event;
  final Color accentColor;
  final double scale;
  final double textScale;
  final int index;
  final bool isDeleting;
  final bool showActions;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEnd;
  final VoidCallback onClose;

  const ManagedEventCard({
    super.key,
    required this.event,
    required this.accentColor,
    required this.scale,
    required this.textScale,
    required this.index,
    required this.isDeleting,
    required this.showActions,
    required this.onTap,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onEnd,
    required this.onClose,
  });

  @override
  State<ManagedEventCard> createState() => _ManagedEventCardState();
}

class _ManagedEventCardState extends State<ManagedEventCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18 * widget.scale);

    return TapRegion(
      onTapOutside: widget.showActions ? (_) => widget.onClose() : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 330 + (widget.index.clamp(0, 7) * 55)),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 18 * widget.scale),
              child: child,
            ),
          );
        },
        child: AnimatedSlide(
          offset: widget.isDeleting ? const Offset(1.15, 0) : Offset.zero,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInCubic,
          child: AnimatedScale(
            scale: widget.isDeleting ? 0.88 : (_pressed ? 0.965 : 1),
            duration: Duration(milliseconds: _pressed ? 45 : 160),
            curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: EventCardVisualStyle.shadows(
                  context,
                  accentColor: widget.accentColor,
                  scale: widget.scale,
                ),
              ),
              child: Material(
                color: context.isDarkMode
                    ? const Color(0xFF151515)
                    : const Color(0xFFF8F8FA),
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSlide(
                      offset: widget.showActions
                          ? const Offset(-1, 0)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: widget.showActions,
                        child: Listener(
                          onPointerDown: widget.isDeleting
                              ? null
                              : (_) => _setPressed(true),
                          onPointerUp: (_) => _setPressed(false),
                          onPointerCancel: (_) => _setPressed(false),
                          child: InkWell(
                            onTap: widget.isDeleting ? null : widget.onTap,
                            splashFactory: InkRipple.splashFactory,
                            splashColor:
                                widget.accentColor.withValues(alpha: 0.16),
                            highlightColor: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 56,
                                        child: _EventImage(
                                          event: widget.event,
                                          accentColor: widget.accentColor,
                                          scale: widget.scale,
                                          textScale: widget.textScale,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 44,
                                        child: _EventInformation(
                                          event: widget.event,
                                          accentColor: widget.accentColor,
                                          scale: widget.scale,
                                          textScale: widget.textScale,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IgnorePointer(
                                    child: AnimatedContainer(
                                      duration: Duration(
                                        milliseconds: _pressed ? 45 : 110,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      color: widget.accentColor.withValues(
                                        alpha: _pressed ? 0.075 : 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSlide(
                      offset:
                          widget.showActions ? Offset.zero : const Offset(1, 0),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !widget.showActions,
                        child: _EventActionsSurface(
                          active: widget.showActions,
                          accentColor: widget.accentColor,
                          scale: widget.scale,
                          textScale: widget.textScale,
                          onView: widget.onView,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onEnd: widget.onEnd,
                          isOngoing: widget.event.isOngoingAt(DateTime.now()),
                          onClose: widget.onClose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventActionsSurface extends StatelessWidget {
  final bool active;
  final Color accentColor;
  final double scale;
  final double textScale;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEnd;
  final VoidCallback onClose;
  final bool isOngoing;

  const _EventActionsSurface({
    required this.active,
    required this.accentColor,
    required this.scale,
    required this.textScale,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onEnd,
    required this.onClose,
    required this.isOngoing,
  });

  @override
  Widget build(BuildContext context) {
    final viewColor = context.colors.primary;
    final destructiveColor =
        isOngoing ? const Color(0xFFFFA62B) : const Color(0xFFFF4267);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (context.isDarkMode
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.7)),
                (context.isDarkMode
                    ? context.primary.withValues(alpha: 0.5)
                    : context.primary.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ActionReveal(
                active: active,
                order: 0,
                child: _CardActionArea(
                  order: 1,
                  icon: Icons.visibility_rounded,
                  label: context.l10n.eventManagementView,
                  color: viewColor,
                  scale: scale,
                  textScale: textScale,
                  onTap: onView,
                ),
              ),
            ),
            Expanded(
              child: _ActionReveal(
                active: active,
                order: 1,
                child: _CardActionArea(
                  order: 2,
                  icon: Icons.edit_rounded,
                  label: context.l10n.eventManagementEdit,
                  color: accentColor,
                  scale: scale,
                  textScale: textScale,
                  onTap: onEdit,
                ),
              ),
            ),
            Expanded(
              child: _ActionReveal(
                active: active,
                order: 2,
                child: _CardActionArea(
                  order: 3,
                  icon: isOngoing
                      ? Icons.stop_circle_rounded
                      : Icons.delete_rounded,
                  label: isOngoing
                      ? context.l10n.eventManagementEnd
                      : context.l10n.eventManagementDelete,
                  color: destructiveColor,
                  scale: scale,
                  textScale: textScale,
                  onTap: isOngoing ? onEnd : onDelete,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 3 * scale,
          right: 3 * scale,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0.20, 0),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Tooltip(
                message: MaterialLocalizations.of(context).closeButtonTooltip,
                child: InkResponse(
                  onTap: onClose,
                  radius: 22 * scale,
                  child: SizedBox.square(
                    dimension: 44 * scale,
                    child: Center(
                      child: Container(
                        width: 29 * scale,
                        height: 29 * scale,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF11141B).withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 12 * scale,
                              offset: Offset(0, 3 * scale),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17 * scale,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionReveal extends StatelessWidget {
  final bool active;
  final int order;
  final Widget child;

  const _ActionReveal({
    required this.active,
    required this.order,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: active ? Offset.zero : Offset(0.20 + (order * 0.06), 0),
      duration: Duration(milliseconds: 250 + (order * 55)),
      curve: active ? Curves.easeOutBack : Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: Duration(milliseconds: 170 + (order * 45)),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _CardActionArea extends StatefulWidget {
  final int order;
  final IconData icon;
  final String label;
  final Color color;
  final double scale;
  final double textScale;
  final VoidCallback onTap;

  const _CardActionArea({
    required this.order,
    required this.icon,
    required this.label,
    required this.color,
    required this.scale,
    required this.textScale,
    required this.onTap,
  });

  @override
  State<_CardActionArea> createState() => _CardActionAreaState();
}

class _CardActionAreaState extends State<_CardActionArea> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final scale = widget.scale;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          splashFactory: InkSparkle.splashFactory,
          splashColor: Colors.white.withValues(alpha: 0.13),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withValues(alpha: _pressed ? 0.78 : 0.55),
                  color.withValues(alpha: _pressed ? 0.42 : 0.24),
                  color.withValues(alpha: _pressed ? 0.16 : 0.04),
                ],
                stops: const [0, 0.58, 1],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.075),
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ActionSurfacePatternPainter(
                      accentColor: color,
                      scale: scale,
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: _pressed ? 0.965 : 1,
                  duration: Duration(milliseconds: _pressed ? 55 : 180),
                  curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 13 * scale,
                      right: (widget.order == 1 ? 46 : 13) * scale,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 170),
                          width: 30 * scale,
                          height: 39 * scale,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: _pressed ? 0.18 : 0.11,
                            ),
                            borderRadius: BorderRadius.circular(12 * scale),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: _pressed ? 0.34 : 0.17,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(
                                  alpha: _pressed ? 0.48 : 0.28,
                                ),
                                blurRadius: (_pressed ? 18 : 12) * scale,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 20 * scale,
                          ),
                        ),
                        SizedBox(width: 11 * scale),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 12.5 * widget.textScale,
                              fontWeight: FontWeight.w900,
                            ),
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
      ),
    );
  }
}

class _ActionSurfacePatternPainter extends CustomPainter {
  final Color accentColor;
  final double scale;

  const _ActionSurfacePatternPainter({
    required this.accentColor,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = scale;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.055)
      ..strokeWidth = 1.5 * scale;
    final spacing = 30 * scale;

    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }

    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.68),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActionSurfacePatternPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.scale != scale;
  }
}

class _EventImage extends StatelessWidget {
  final EventPreview event;
  final Color accentColor;
  final double scale;
  final double textScale;

  const _EventImage({
    required this.event,
    required this.accentColor,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EventImage(
          source: event.imageUrl,
          fit: BoxFit.cover,
          error: ColoredBox(
            color: accentColor.withValues(alpha: 0.12),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: accentColor.withValues(alpha: 0.70),
              size: 30 * scale,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x1F000000),
                Colors.transparent,
                Color(0x52000000),
              ],
              stops: [0, 0.54, 1],
            ),
          ),
        ),
        Positioned(
          left: 10 * scale,
          top: 10 * scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 9 * scale,
                vertical: 5 * scale,
              ),
              child: Text(
                event.category.localizedLabel(context).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9.5 * textScale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventInformation extends StatelessWidget {
  final EventPreview event;
  final Color accentColor;
  final double scale;
  final double textScale;

  const _EventInformation({
    required this.event,
    required this.accentColor,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPublicationScheduled =
        event.publishAt != null && event.publishAt!.isAfter(now);
    final lifecycle = event.lifecycleAt(now);
    final status = isPublicationScheduled
        ? context.l10n.eventManagementScheduled
        : switch (lifecycle) {
            EventLifecycleStatus.ongoing => context.l10n.eventManagementOngoing,
            EventLifecycleStatus.ended => context.l10n.eventManagementEnded,
            EventLifecycleStatus.upcoming =>
              context.l10n.eventManagementPublished,
          };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        12 * scale,
        11 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6 * scale,
                height: 6 * scale,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.45),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                child: Text(
                  status.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: accentColor,
                    fontSize: 9.5 * textScale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge?.copyWith(
              color: context.onTertiary,
              fontSize: 14.5 * textScale,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _MetadataLine(
            icon: Icons.schedule_rounded,
            label: AppDateTimeFormatter.eventDateTime(
              context,
              event.startsAt,
            ),
            scale: scale,
            textScale: textScale,
          ),
          if (event.displayLocation.trim().isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            _MetadataLine(
              icon: Icons.location_on_outlined,
              label: event.displayLocation,
              scale: scale,
              textScale: textScale,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final double scale;
  final double textScale;

  const _MetadataLine({
    required this.icon,
    required this.label,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13 * scale,
          color: context.onTertiary.withValues(alpha: 0.45),
        ),
        SizedBox(width: 5 * scale),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.onTertiary.withValues(alpha: 0.56),
              fontSize: 10 * textScale,
            ),
          ),
        ),
      ],
    );
  }
}
