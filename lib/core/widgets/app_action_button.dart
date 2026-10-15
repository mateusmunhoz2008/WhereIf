import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/loading_dots.dart';
import 'package:flutter/material.dart';

enum AppActionButtonStyle {
  filled,
  outlined,
}

class AppActionButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppActionButtonStyle style;
  final Color? foregroundColor;
  final double? height;
  final bool isLoading;

  const AppActionButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.icon,
    this.style = AppActionButtonStyle.filled,
    this.foregroundColor,
    this.height,
    this.isLoading = false,
  });

  @override
  State<AppActionButton> createState() => _AppActionButtonState();
}

class _AppActionButtonState extends State<AppActionButton> {
  bool _pressed = false;
  bool _handlingTap = false;

  Future<void> _handleTap() async {
    final onPressed = widget.onPressed;
    if (onPressed == null || widget.isLoading || _handlingTap) return;

    _handlingTap = true;
    setState(() => _pressed = true);

    await Future.delayed(const Duration(milliseconds: 90));

    if (!mounted) return;

    setState(() {
      _pressed = false;
      _handlingTap = false;
    });

    // The page may have disabled this action during the press animation.
    if (widget.isLoading || widget.onPressed == null) return;
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final unavailable = widget.onPressed == null && !widget.isLoading;
    final isOutlined = widget.style == AppActionButtonStyle.outlined;
    final isCompact =
        context.isVerySmallScreen || context.screenSize.width < 360;

    final height = widget.height ?? (isCompact ? 50.0 : 56.0);
    final radius = isCompact ? 20.0 : 20.0;
    final iconSize = isCompact ? 18.0 : 20.0;

    final defaultForeground = isOutlined
        ? widget.color
        : ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    final foreground = widget.foregroundColor ?? defaultForeground;
    final effectiveForeground =
        unavailable ? context.onTertiary.withValues(alpha: 0.30) : foreground;
    final baseAlpha = widget.color.a;

    final backgroundColor = unavailable
        ? context.onTertiary.withValues(alpha: 0.055)
        : isOutlined
            ? widget.color.withValues(
                alpha: baseAlpha * (_pressed ? 0.18 : 0.09),
              )
            : widget.color.withValues(
                alpha: baseAlpha *
                    (widget.isLoading
                        ? 0.72
                        : _pressed
                            ? 0.80
                            : 1),
              );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.text,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        offset: _pressed ? const Offset(0, 0.035) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.955 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: unavailable
                    ? context.onTertiary.withValues(alpha: 0.12)
                    : isOutlined
                        ? widget.color.withValues(
                            alpha: _pressed ? 0.75 : 0.40,
                          )
                        : Colors.transparent,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: disabled ? null : _handleTap,
                onTapDown:
                    disabled ? null : (_) => setState(() => _pressed = true),
                onTapCancel:
                    disabled ? null : () => setState(() => _pressed = false),
                splashColor: Colors.white.withValues(alpha: 0.16),
                highlightColor: Colors.transparent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 130),
                        opacity: _pressed ? 0.16 : 0,
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: widget.isLoading
                            ? LoadingDots(
                                key: const ValueKey('loading-dots'),
                                color: effectiveForeground,
                              )
                            : Row(
                                key: const ValueKey('button-content'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.icon != null) ...[
                                    Icon(
                                      widget.icon,
                                      size: iconSize,
                                      color: effectiveForeground,
                                    ),
                                    SizedBox(width: isCompact ? 5 : 10),
                                  ],
                                  Flexible(
                                    child: Text(
                                      widget.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.labelLarge?.copyWith(
                                        fontSize: isCompact
                                            ? context.text.labelMedium?.fontSize
                                            : context.text.labelLarge?.fontSize,
                                        color: effectiveForeground,
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
        ),
      ),
    );
  }
}
