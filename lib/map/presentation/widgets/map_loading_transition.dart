import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A painted curtain in the map page, below the app shell navigation.
/// Only this small paint layer ticks; the WebView is never rebuilt by a frame.
class MapLoadingTransition extends StatefulWidget {
  const MapLoadingTransition({
    super.key,
    required this.ready,
    required this.primary,
    required this.secondary,
    required this.loadingLabel,
    required this.child,
    this.onLoadStarted,
  });

  final bool ready;
  final Color primary;
  final Color secondary;
  final String loadingLabel;
  final Widget child;
  final VoidCallback? onLoadStarted;

  @override
  State<MapLoadingTransition> createState() => _MapLoadingTransitionState();
}

class _MapLoadingTransitionState extends State<MapLoadingTransition>
    with TickerProviderStateMixin {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _startLoadAfterEntrance();
    });
  late final _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _flow.stop();
        setState(() => _finished = true);
      }
    });
  late final _repaint = Listenable.merge([_flow, _entrance, _exit]);
  bool _started = false;
  bool _finished = false;
  bool _reducedMotion = false;
  bool _loadStarted = false;
  bool _loadScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _flow.stop();
      _entrance.value = 1;
      if (widget.ready) _exit.value = 1;
    } else if (!_finished) {
      if (!_flow.isAnimating) _flow.repeat();
      if (!_started) _entrance.forward();
    }
    _started = true;
    if (_entrance.isCompleted) _startLoadAfterEntrance();
    _revealWhenReady();
  }

  @override
  void didUpdateWidget(MapLoadingTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ready && oldWidget.ready) {
      _finished = false;
      _exit.reset();
      if (!_reducedMotion && !_flow.isAnimating) _flow.repeat();
    }
    _revealWhenReady();
  }

  void _startLoadAfterEntrance() {
    if (_loadStarted || _loadScheduled) return;
    _loadScheduled = true;
    // Commit the entrance's final painted frame before creating the WebView
    // or reading the GLB. Heavy work must not overlap the entrance animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _loadStarted = true);
      widget.onLoadStarted?.call();
      _revealWhenReady();
    });
  }

  void _revealWhenReady() {
    if (!widget.ready || !_loadStarted || _finished || _exit.isAnimating) {
      return;
    }
    if (_reducedMotion) {
      _exit.value = 1;
    } else if (_entrance.isCompleted) {
      _flow.repeat();
      _exit.forward();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _entrance.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          if (_loadStarted)
            ExcludeSemantics(
              excluding: !_finished,
              child: IgnorePointer(ignoring: !_finished, child: widget.child),
            ),
          if (!_finished)
            Positioned.fill(
              child: Semantics(
                label: widget.loadingLabel,
                liveRegion: true,
                child: AbsorbPointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('map-loading-curtain'),
                      painter: _DiagonalCurtainPainter(
                        flow: _flow,
                        entrance: _entrance,
                        exit: _exit,
                        primary: widget.primary,
                        secondary: widget.secondary,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _DiagonalCurtainPainter extends CustomPainter {
  _DiagonalCurtainPainter({
    required this.flow,
    required this.entrance,
    required this.exit,
    required this.primary,
    required this.secondary,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Animation<double> flow;
  final Animation<double> entrance;
  final Animation<double> exit;
  final Color primary;
  final Color secondary;

  double _stagger(double value, double delay, double span) =>
      ((value - delay) / span).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const angle = math.pi / 8;
    // Project the viewport into the diagonal coordinate system. All rows and
    // wrapping capsules extend past its bounds, so no loop seam is visible.
    final width = size.width * math.cos(angle) + size.height * math.sin(angle);
    final height = size.height * math.cos(angle) + size.width * math.sin(angle);
    final halfWidth = width / 2 + 64;
    final pitch = (size.shortestSide / 10).clamp(32.0, 46.0);
    final radius = pitch * 0.24;
    final period = pitch * 7.2;
    final rows = (height / pitch).ceil() + 2;
    final background = Color.lerp(const Color(0xFF151124), secondary, 0.22)!;
    final stripe = Color.lerp(secondary, const Color(0xFFB5A4FF), 0.32)!;
    final cap = Color.lerp(secondary, const Color(0xFF2F1968), 0.40)!;
    final dot = Color.lerp(primary, const Color(0xFFFF80DF), 0.48)!;
    final paint = Paint()..isAntiAlias = true;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The loading curtain is opaque from its first frame, including before
    // the staggered entrance, so the incomplete WebView cannot flash through.
    if (exit.value == 0) canvas.drawColor(background, BlendMode.srcOver);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);

    for (var row = 0; row < rows; row++) {
      final y = (row - (rows - 1) / 2) * pitch;
      final order = row / math.max(1, rows - 1);
      final arrived = Curves.easeOutCubic.transform(
        _stagger(entrance.value, order * 0.22, 0.78),
      );
      final departed = Curves.easeInOutCubic.transform(
        _stagger(exit.value, order * 0.20, 0.80),
      );
      if (departed >= 1) continue;
      final curtainLeft = -halfWidth + (2 * halfWidth + pitch) * departed;
      canvas.save();
      // On completion each entire diagonal lane peels away with a rounded
      // leading edge. The moving pattern and its background leave together.
      canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(curtainLeft, y - pitch / 2 - 0.5, halfWidth + pitch,
            y + pitch / 2 + 0.5),
        Radius.circular(pitch / 2),
      ));
      canvas.drawRect(
        Rect.fromLTRB(-halfWidth, y - pitch, halfWidth + pitch, y + pitch),
        paint..color = background,
      );
      final shift = flow.value * period +
          (row * 0.381966 % 1) * period +
          departed * period * 0.6;
      final entranceOffset = (1 - arrived) * (width + period);
      final length = period * (0.52 + (row % 3) * 0.065);
      // Entrance clipping creates a wave of growing, moving lanes. Once in,
      // wrapping uses an exact period, including rows with different phases.
      canvas.clipRect(Rect.fromLTRB(
          -halfWidth, y - pitch, halfWidth - entranceOffset, y + pitch));
      for (double x = -halfWidth - period + shift % period;
          x < halfWidth + period;
          x += period) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y - radius, length, radius * 2),
            Radius.circular(radius),
          ),
          paint..color = stripe,
        );
        canvas.drawCircle(
            Offset(x + length - radius, y), radius, paint..color = cap);
        canvas.drawCircle(Offset(x + length + (period - length) * 0.50, y),
            radius, paint..color = dot);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalCurtainPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.flow != flow ||
      oldDelegate.entrance != entrance ||
      oldDelegate.exit != exit;
}
