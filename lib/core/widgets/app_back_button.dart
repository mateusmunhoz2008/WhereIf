import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final IconData icon;
  final double iconSize;
  final double size;
  final String? tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.icon = Icons.arrow_back_rounded,
    this.iconSize = 24,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Theme.of(context).colorScheme.onTertiary;

    return IconButton(
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: backgroundColor,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: iconSize),
    );
  }
}
