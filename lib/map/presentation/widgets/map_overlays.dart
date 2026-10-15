import 'dart:async';

import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_glass_surface.dart';
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
    final blurAllowed = GlassBlurScope.enabledOf(context);

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            campusName,
            style: context.titleLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 21 * scale,
              fontWeight: FontWeight.w800,
              shadows: blurAllowed
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.52),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            style: context.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
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
    return AppGlassSurface(
      forceDark: true,
      neutralTint: true,
      borderRadius: BorderRadius.circular(16 * scale),
      child: Material(
        color: Colors.transparent,
        child: SizedBox.square(
          dimension: (46 * scale).clamp(42, 48),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon,
                color: Colors.white.withValues(alpha: 0.6),
                size: 22 * context.responsive.iconScale),
          ),
        ),
      ),
    );
  }
}

class MapRawModeButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const MapRawModeButton({
    super.key,
    required this.label,
    required this.tooltip,
    this.icon = Icons.flash_off_rounded,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.responsive.layoutScale;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: enabled,
        label: label,
        child: AppGlassSurface(
          forceDark: true,
          neutralTint: true,
          borderRadius: BorderRadius.circular(16 * scale),
          child: Material(
            color: enabled
                ? context.secondary.withValues(alpha: 0.22)
                : Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale, vertical: 10 * scale),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 17 * scale),
                    SizedBox(width: 6 * scale),
                    Text(label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12 * context.responsive.textScale,
                          fontWeight: FontWeight.w700,
                        )),
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

class MapBearingControl extends StatefulWidget {
  final double bearing;
  final String tooltip;
  final String resetTooltip;
  final ValueChanged<double> onRotate;
  final VoidCallback onRotateStart;
  final VoidCallback onRotateEnd;
  final VoidCallback onReset;
  final bool is2D;
  final VoidCallback onToggleView;

  const MapBearingControl({
    super.key,
    required this.bearing,
    required this.tooltip,
    required this.resetTooltip,
    required this.onRotate,
    required this.onRotateStart,
    required this.onRotateEnd,
    required this.onReset,
    required this.is2D,
    required this.onToggleView,
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
    final scale = context.responsive.layoutScale;
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
              child: AppGlassSurface(
                forceDark: true,
                neutralTint: true,
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  width: (190 * scale).clamp(164, 202),
                  height: (30 * scale).clamp(28, 34),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _startDrag(),
                    onHorizontalDragUpdate: _updateDrag,
                    onHorizontalDragEnd: (_) => _endDrag(),
                    onHorizontalDragCancel: _endDrag,
                    child: CustomPaint(
                      painter: _BearingScalePainter(
                        bearing: _visualBearing,
                        tickColor: Colors.white.withValues(alpha: 0.32),
                        accentColor: context.secondary.withValues(alpha: 0.8),
                        dragging: _dragging,
                        blurEnabled: GlassBlurScope.enabledOf(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 7 * scale),
          _MapBearingResetButton(
              tooltip: widget.resetTooltip, onPressed: widget.onReset),
          SizedBox(width: 3 * scale),
          _MapBearingResetButton(
            tooltip: '2D / 3D',
            label: widget.is2D ? '2D' : '3D',
            onPressed: widget.onToggleView,
          ),
        ],
      ),
    );
  }
}

class _MapBearingResetButton extends StatelessWidget {
  final String tooltip;
  final String label;
  final VoidCallback onPressed;

  const _MapBearingResetButton({
    required this.tooltip,
    this.label = '0°',
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.responsive.layoutScale;
    final dimension = (34 * scale).clamp(32.0, 38.0).toDouble();
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: (44 * scale).clamp(42.0, 48.0).toDouble(),
          child: Center(
            child: SizedBox.square(
              dimension: dimension,
              child: AppGlassSurface(
                forceDark: true,
                neutralTint: true,
                borderRadius: BorderRadius.circular(dimension / 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkResponse(
                    onTap: onPressed,
                    radius: dimension / 2,
                    child: Center(
                      child: Text(label,
                          style: context.text.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11 * context.responsive.textScale,
                            fontWeight: FontWeight.w400,
                          )),
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
  final bool blurEnabled;

  const _BearingScalePainter({
    required this.bearing,
    required this.tickColor,
    required this.accentColor,
    required this.dragging,
    required this.blurEnabled,
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

    if (blurEnabled) {
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: dragging ? 0.32 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset(centerX, size.height / 2), 8, glowPaint);
    }

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
        oldDelegate.dragging != dragging ||
        oldDelegate.blurEnabled != blurEnabled;
  }
}

class MapFloorPill extends StatefulWidget {
  final List<MapFloor> floors;
  final Map<String, int> eventCounts;
  final String Function(int)? eventCountLabel;
  final String? selectedId;
  final bool busy;
  final bool animationEnabled;
  final bool blurEnabled;
  final ValueChanged<String?> onSelected;

  const MapFloorPill(
      {super.key,
      required this.floors,
      this.eventCounts = const {},
      this.eventCountLabel,
      required this.selectedId,
      required this.busy,
      this.animationEnabled = true,
      this.blurEnabled = false,
      required this.onSelected});

  @override
  State<MapFloorPill> createState() => _MapFloorPillState();
}

class _MapFloorPillState extends State<MapFloorPill>
    with SingleTickerProviderStateMixin {
  static const _step = 32.0;
  static const _width = 32.0;
  static const _padding = 3.0;
  late final AnimationController _motion;
  late double _headFrom;
  late double _tailFrom;
  late double _to;
  String? _visualId;
  double? _dragPosition;

  int get _selectedIndex {
    final index = widget.floors.indexWhere((floor) => floor.id == _visualId);
    return index < 0
        ? widget.floors.length - 1
        : widget.floors.length - index - 1;
  }

  double get _position =>
      _dragPosition ??
      _headFrom +
          (_to - _headFrom) *
              Curves.easeInOutCubic
                  .transform((_motion.value / 0.40).clamp(0.0, 1.0));
  double get _tailPosition => !widget.animationEnabled
      ? _position
      : _dragPosition != null
          ? _tailFrom
          : _tailFrom +
              (_to - _tailFrom) *
                  Curves.easeOutCubic.transform(
                      ((_motion.value - 0.25) / 0.75).clamp(0.0, 1.0));

  void _setVisualSelection(String? id) {
    final wasExterior = _visualId == null;
    _visualId = id;
    if (id == null || wasExterior) {
      _dragPosition = null;
      _headFrom = _tailFrom = _to = _selectedIndex.toDouble();
      _motion.stop();
      _motion.value = 1;
    } else {
      _animateSelection();
    }
  }

  void _animateSelection() {
    final head = _position;
    final tail = _tailPosition;
    final destination = _selectedIndex.toDouble();
    final goingDown = destination >= (head + tail) / 2;
    _headFrom =
        goingDown ? (head > tail ? head : tail) : (head < tail ? head : tail);
    _tailFrom =
        goingDown ? (head < tail ? head : tail) : (head > tail ? head : tail);
    _dragPosition = null;
    _to = destination;
    if (!widget.animationEnabled || MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  void _choose(String? id) {
    if (widget.busy) return;
    setState(() {
      _setVisualSelection(id);
    });
    if (id != widget.selectedId) widget.onSelected(id);
  }

  @override
  void initState() {
    super.initState();
    _visualId = widget.selectedId;
    _headFrom = _tailFrom = _to = _selectedIndex.toDouble();
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560), value: 1);
  }

  @override
  void didUpdateWidget(MapFloorPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animationEnabled && oldWidget.animationEnabled) {
      _dragPosition = null;
      _headFrom = _tailFrom = _to = _selectedIndex.toDouble();
      _motion.stop();
      _motion.value = 1;
    }
    if (oldWidget.selectedId != widget.selectedId ||
        (oldWidget.busy && !widget.busy)) {
      if (_visualId != widget.selectedId) {
        _setVisualSelection(widget.selectedId);
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = dark ? Colors.black : Colors.white;
    final selectedInk = dark ? Colors.white : Colors.black;
    const iconColor = Colors.white;
    Widget level(String? id, String label, Widget symbol) {
      final selected = _visualId == id;
      final count = widget.eventCounts[id] ?? 0;
      final description = count == 0
          ? label
          : '$label · ${widget.eventCountLabel?.call(count) ?? '$count evento${count == 1 ? '' : 's'}'}';
      return Semantics(
        button: true,
        selected: selected,
        label: description,
        child: Tooltip(
          message: description,
          child: SizedBox(
            width: 44,
            height: _step,
            child: InkWell(
              customBorder: const CircleBorder(),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              onTap: widget.busy ? null : () => _choose(id),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? selectedInk : Colors.white70),
                  child: IconTheme(
                      data: IconThemeData(
                          size: 14,
                          color: selected ? selectedInk : Colors.white70),
                      child: id != null && count > 0 && !selected
                          ? _MapFloorEventSignal(
                              key: ValueKey('map-floor-event-$id'),
                              enabled: widget.animationEnabled && !widget.busy,
                              child: symbol,
                            )
                          : symbol),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Logical pixels, not a fraction of the display: the same compact size
    // on phones and tablets, with a wider invisible horizontal touch area.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1.15,
      child: RepaintBoundary(
        child: SizedBox(
          width: 44,
          height: widget.floors.length * _step + _padding * 2 + 44,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 44,
                height: widget.floors.length * _step + _padding * 2,
                child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: widget.busy
                        ? null
                        : (details) {
                            setState(() {
                              _tailFrom = _tailPosition;
                              _dragPosition = ((details.localPosition.dy -
                                          _padding -
                                          _step / 2) /
                                      _step)
                                  .clamp(0.0,
                                      (widget.floors.length - 1).toDouble());
                              _motion.stop();
                            });
                          },
                    onVerticalDragUpdate: widget.busy
                        ? null
                        : (details) {
                            setState(() {
                              _dragPosition = ((details.localPosition.dy -
                                          _padding -
                                          _step / 2) /
                                      _step)
                                  .clamp(0.0,
                                      (widget.floors.length - 1).toDouble());
                            });
                          },
                    onVerticalDragEnd: widget.busy
                        ? null
                        : (_) {
                            final index = _position.round();
                            _choose(widget
                                .floors[widget.floors.length - index - 1].id);
                          },
                    onVerticalDragCancel: () => setState(_animateSelection),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        left: 6,
                        right: 6,
                        child: AppGlassSurface(
                          blurEnabled: widget.blurEnabled,
                          forceDark: true,
                          neutralTint: true,
                          borderRadius: BorderRadius.circular(_width / 2),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (_visualId != null)
                        AnimatedBuilder(
                            animation: _motion,
                            builder: (context, child) {
                              final head = _position;
                              final tail = _tailPosition;
                              final top = head < tail ? head : tail;
                              final length = (head - tail).abs() * _step;
                              return Positioned(
                                  left: 8,
                                  top: _padding + top * _step + 2,
                                  child: Container(
                                      key:
                                          const ValueKey('map-floor-selection'),
                                      width: 28,
                                      height: 28 + length,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          color: selectedColor)));
                            }),
                      if (_visualId != null)
                        AnimatedBuilder(
                            animation: _motion,
                            child: AppGlassSurface(
                              blurEnabled: widget.blurEnabled,
                              forceDark: true,
                              neutralTint: true,
                              borderRadius: BorderRadius.circular(7),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                child: Text(
                                  widget.floors
                                      .firstWhere((f) => f.id == _visualId,
                                          orElse: () => widget.floors.first)
                                      .label,
                                  style: const TextStyle(
                                      color: iconColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            builder: (context, child) {
                              final opacity = Curves.easeOut.transform(
                                  (_motion.value / 0.40).clamp(0.0, 1.0));
                              return Positioned(
                                  left: 40,
                                  top: _padding + _position * _step + 6,
                                  child: IgnorePointer(
                                      child: Opacity(
                                          opacity: opacity.clamp(0, 1),
                                          child: child)));
                            }),
                      Positioned.fill(
                          top: _padding,
                          bottom: _padding,
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var index = widget.floors.length - 1;
                                      index >= 0;
                                      index--)
                                    level(
                                        widget.floors[index].id,
                                        widget.floors[index].label,
                                        Text('${index + 1}')),
                                ]),
                          )),
                    ]))),
            const SizedBox(height: 12),
            _MapExteriorButton(
                selected: _visualId == null,
                enabled: !widget.busy,
                animationEnabled: widget.animationEnabled,
                blurEnabled: widget.blurEnabled,
                onTap: () => _choose(null)),
          ]),
        ),
      ),
    );
  }
}

/// Three brief pulses, then a real idle interval (no repeating frame ticker).
class _MapFloorEventSignal extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const _MapFloorEventSignal(
      {super.key, required this.enabled, required this.child});
  @override
  State<_MapFloorEventSignal> createState() => _MapFloorEventSignalState();
}

class _MapFloorEventSignalState extends State<_MapFloorEventSignal>
    with WidgetsBindingObserver {
  static const _durations = [160, 190, 160, 190, 160, 4200];
  Timer? _timer;
  var _phase = 0;
  var _lit = false;
  var _canAnimate = false;
  var _resumed = true;

  @override
  void initState() {
    super.initState();
    _resumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canAnimate = TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(_MapFloorEventSignal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncPulse();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (mounted) setState(_syncPulse);
  }

  void _syncPulse() {
    if (!widget.enabled || !_canAnimate || !_resumed) {
      _timer?.cancel();
      _timer = null;
      _lit = false;
      _phase = 0;
    } else if (_timer == null) {
      _phase = 0;
      _lit = true;
      _schedule();
    }
  }

  void _schedule() {
    _timer = Timer(Duration(milliseconds: _durations[_phase]), () {
      if (!mounted) return;
      setState(() {
        _phase = (_phase + 1) % _durations.length;
        _lit = _phase.isEven;
      });
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final animated = widget.enabled && _canAnimate && _resumed;
    final duration =
        animated ? const Duration(milliseconds: 80) : Duration.zero;
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: _lit ? .38 : 0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
            child: AnimatedDefaultTextStyle(
          duration: duration,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _lit ? Colors.white : Colors.white70),
          child: widget.child,
        )),
      ),
    );
  }
}

class _MapExteriorButton extends StatefulWidget {
  final bool selected;
  final bool enabled;
  final bool animationEnabled;
  final bool blurEnabled;
  final VoidCallback onTap;
  const _MapExteriorButton(
      {required this.selected,
      required this.enabled,
      required this.animationEnabled,
      required this.blurEnabled,
      required this.onTap});
  @override
  State<_MapExteriorButton> createState() => _MapExteriorButtonState();
}

class _MapExteriorButtonState extends State<_MapExteriorButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _click;
  late final Animation<double> _scale;
  @override
  void didUpdateWidget(_MapExteriorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animationEnabled) {
      _click.stop();
      _click.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _click = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.90)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 45),
      TweenSequenceItem(
          tween: Tween(begin: 0.90, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 55),
    ]).animate(_click);
  }

  @override
  void dispose() {
    _click.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Exterior',
      child: Tooltip(
        message: 'Exterior',
        child: GestureDetector(
          onTap: widget.enabled
              ? () {
                  if (widget.animationEnabled &&
                      !MediaQuery.disableAnimationsOf(context)) {
                    _click.forward(from: 0);
                  }
                  widget.onTap();
                }
              : null,
          child: ScaleTransition(
            scale: _scale,
            child: SizedBox(
              key: const ValueKey('map-exterior-button'),
              width: 32,
              height: 32,
              child: AppGlassSurface(
                forceDark: true,
                neutralTint: true,
                borderRadius: BorderRadius.circular(9),
                blurEnabled: widget.blurEnabled,
                child: const Center(
                    child: Icon(Icons.apartment_rounded,
                        size: 16, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapSelectedZonePill extends StatelessWidget {
  final MapZone zone;
  final String unavailableLabel;
  final String? title;
  final IconData? icon;
  final bool blurEnabled;

  const MapSelectedZonePill({
    super.key,
    required this.zone,
    required this.unavailableLabel,
    this.title,
    this.icon,
    this.blurEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppGlassSurface(
        blurEnabled: blurEnabled,
        forceDark: true,
        neutralTint: true,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? Icons.apartment_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 21),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title ?? zone.label,
                      style: context.text.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w800,
                      )),
                  Text(unavailableLabel,
                      style: context.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 10,
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
