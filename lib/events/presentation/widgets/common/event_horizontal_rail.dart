import 'package:flutter/material.dart';

class EventHorizontalRail extends StatefulWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final Clip clipBehavior;
  final bool fadeRight;
  final bool fadeLeft;

  const EventHorizontalRail({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    required this.spacing,
    this.padding = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
    this.fadeRight = false,
    this.fadeLeft = false,
  });

  @override
  State<EventHorizontalRail> createState() => _EventHorizontalRailState();
}

class _EventHorizontalRailState extends State<EventHorizontalRail> {
  final _controller = ScrollController();
  bool _hasBefore = false, _hasMore = false, _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleFadeCheck);
  }

  void _scheduleFadeCheck() {
    if ((!widget.fadeRight && !widget.fadeLeft) || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted ||
          !_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      final before = widget.fadeLeft && _controller.position.extentBefore > 0.5;
      final more = widget.fadeRight && _controller.position.extentAfter > 0.5;
      // No widget rebuild for each scroll pixel, only at the content boundary.
      if (before != _hasBefore || more != _hasMore) {
        setState(() {
          _hasBefore = before;
          _hasMore = more;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleFadeCheck();
    final rail = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleFadeCheck();
        return false;
      },
      child: ListView.separated(
        controller: _controller,
        primary: false,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: widget.clipBehavior,
        padding: widget.padding,
        itemCount: widget.itemCount,
        separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
        itemBuilder: widget.itemBuilder,
      ),
    );
    return SizedBox(
      height: widget.height,
      child: widget.fadeRight || widget.fadeLeft
          ? EventRailEdgeFade(left: _hasBefore, right: _hasMore, child: rail)
          : rail,
    );
  }
}

/// Alpha-only fade in the outermost 22 logical pixels, using one mask; no blur.
/// Keep the same subtree when disabled so reaching the end cannot reset scroll.
class EventRailEdgeFade extends StatelessWidget {
  final bool left;
  final bool right;
  final Widget child;
  const EventRailEdgeFade(
      {super.key,
      required this.left,
      required this.right,
      required this.child});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final edge = (22 / bounds.width).clamp(0.0, 0.5).toDouble();
          return LinearGradient(
            colors: [
              left ? Colors.transparent : Colors.white,
              Colors.white,
              Colors.white,
              right ? Colors.transparent : Colors.white
            ],
            stops: [0, edge, 1 - edge, 1],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds);
        },
        child: child,
      );
}
