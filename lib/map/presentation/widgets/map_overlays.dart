import 'dart:ui';

import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/map/domain/models/map_zone.dart';
import 'package:flutter/material.dart';

class MapHeader extends StatelessWidget {
  final String campusName;
  final String hint;

  const MapHeader({
    super.key,
    required this.campusName,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.responsive.layoutScale;

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            campusName,
            style: context.titleLarge?.copyWith(
              color: context.onTertiary,
              fontSize: 21 * scale,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: context.tertiary.withValues(alpha: 0.52),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            style: context.bodySmall?.copyWith(
              color: context.onTertiary.withValues(alpha: 0.58),
              fontSize: 11 * context.responsive.textScale,
            ),
          ),
        ],
      ),
    );
  }
}

class MapControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const MapControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.responsive.layoutScale;
    final radius = BorderRadius.circular(16 * scale);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: context.tertiary.withValues(alpha: 0.42),
            child: SizedBox.square(
              dimension: (46 * scale).clamp(42, 48),
              child: IconButton(
                tooltip: tooltip,
                onPressed: onPressed,
                icon: Icon(
                  icon,
                  color: context.onTertiary,
                  size: 22 * context.responsive.iconScale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapBearingControl extends StatefulWidget {
  final double bearing;
  final String tooltip;
  final String resetTooltip;
  final ValueChanged<double> onRotate;
  final VoidCallback onRotateStart;
  final VoidCallback onRotateEnd;
  final VoidCallback onReset;

  const MapBearingControl({
    super.key,
    required this.bearing,
    required this.tooltip,
    required this.resetTooltip,
    required this.onRotate,
    required this.onRotateStart,
    required this.onRotateEnd,
    required this.onReset,
  });

  @override
  State<MapBearingControl> createState() => _MapBearingControlState();
}

class _MapBearingControlState extends State<MapBearingControl> {
  bool _dragging = false;
  late double _visualBearing;

  @override
  void initState() {
    super.initState();
    _visualBearing = widget.bearing;
  }

  @override
  void didUpdateWidget(MapBearingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) _visualBearing = widget.bearing;
  }

  void _setDragging(bool value) {
    if (_dragging == value) return;
    setState(() => _dragging = value);
  }

  double _normalized(double value) => ((value + 180) % 360 + 360) % 360 - 180;

  void _startDrag() {
    _visualBearing = widget.bearing;
    _setDragging(true);
    widget.onRotateStart();
  }

  void _updateDrag(DragUpdateDetails details) {
    final delta = details.delta.dx * 0.62;
    setState(() => _visualBearing = _normalized(_visualBearing + delta));
    widget.onRotate(delta);
  }

  void _endDrag() {
    _setDragging(false);
    widget.onRotateEnd();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final scale = responsive.layoutScale;
    final radius = BorderRadius.circular(99);
    final foreground = context.onTertiary;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            slider: true,
            label: widget.tooltip,
            value: '${_visualBearing.round()}°',
            child: AnimatedScale(
              scale: _dragging ? 1.015 : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: (190 * scale).clamp(164, 202),
                    height: (30 * scale).clamp(28, 34),
                    decoration: BoxDecoration(
                      color: context.tertiary.withValues(
                        alpha: _dragging ? 0.66 : 0.48,
                      ),
                      borderRadius: radius,
                      border: Border.all(
                        color: foreground.withValues(
                          alpha: _dragging ? 0.24 : 0.12,
                        ),
                      ),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => _startDrag(),
                      onHorizontalDragUpdate: _updateDrag,
                      onHorizontalDragEnd: (_) => _endDrag(),
                      onHorizontalDragCancel: _endDrag,
                      child: CustomPaint(
                        painter: _BearingScalePainter(
                          bearing: _visualBearing,
                          tickColor: foreground,
                          accentColor: context.secondary,
                          dragging: _dragging,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 7 * scale),
          _MapBearingResetButton(
            tooltip: widget.resetTooltip,
            onPressed: widget.onReset,
          ),
        ],
      ),
    );
  }
}

class _MapBearingResetButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _MapBearingResetButton({
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.responsive.layoutScale;
    final dimension = (34 * scale).clamp(32.0, 38.0).toDouble();
    final foreground = context.onTertiary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: (44 * scale).clamp(42.0, 48.0).toDouble(),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.tertiary.withValues(alpha: 0.50),
                border: Border.all(
                  color: foreground.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: onPressed,
                      radius: dimension / 2,
                      child: SizedBox.square(
                        dimension: dimension,
                        child: Center(
                          child: Text(
                            '0°',
                            style: context.text.labelMedium?.copyWith(
                              color: foreground.withValues(alpha: 0.88),
                              fontSize: 11 * context.responsive.textScale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BearingScalePainter extends CustomPainter {
  final double bearing;
  final Color tickColor;
  final Color accentColor;
  final bool dragging;

  const _BearingScalePainter({
    required this.bearing,
    required this.tickColor,
    required this.accentColor,
    required this.dragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const step = 15.0;
    const pixelsPerDegree = 1.08;
    final centerX = size.width / 2;
    final firstDegree =
        ((bearing - size.width / pixelsPerDegree / 2) / step).floor() * step;
    final lastDegree = bearing + size.width / pixelsPerDegree / 2;

    for (double degree = firstDegree; degree <= lastDegree; degree += step) {
      final x = centerX + (degree - bearing) * pixelsPerDegree;
      final normalized = ((degree % 360) + 360) % 360;
      final major = normalized % 90 == 0;
      final medium = normalized % 45 == 0;
      final height = major ? 9.0 : (medium ? 6.0 : 3.5);
      final paint = Paint()
        ..color = tickColor.withValues(alpha: major ? 0.52 : 0.20)
        ..strokeWidth = major ? 1.7 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, size.height / 2 + height / 2),
        Offset(x, size.height / 2 - height / 2),
        paint,
      );
    }

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: dragging ? 0.32 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(Offset(centerX, size.height / 2), 8, glowPaint);

    final markerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.94)
      ..strokeWidth = dragging ? 3.2 : 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, size.height / 2 - 8),
      Offset(centerX, size.height / 2 + 8),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(_BearingScalePainter oldDelegate) {
    return oldDelegate.bearing != bearing ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.dragging != dragging;
  }
}

class MapSelectedZonePill extends StatelessWidget {
  final MapZone zone;
  final String unavailableLabel;

  const MapSelectedZonePill({
    super.key,
    required this.zone,
    required this.unavailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.tertiary.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: context.secondary.withValues(alpha: 0.44),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.secondary.withValues(alpha: 0.16),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    color: context.secondary,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        zone.label,
                        style: context.text.labelLarge?.copyWith(
                          color: context.onTertiary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        unavailableLabel,
                        style: context.bodySmall?.copyWith(
                          color: context.onTertiary.withValues(alpha: 0.52),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
