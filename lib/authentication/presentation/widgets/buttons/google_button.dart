import 'package:autth_injustice_app/core/constants/app_assets.dart';
import 'package:autth_injustice_app/core/extensions/responsive_extensions.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact || context.responsive.isVeryCompact;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        setState(() => _isPressed = true);
        await Future.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          setState(() => _isPressed = false);
          widget.onTap();
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EBE6),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 24,
              vertical: compact ? 13 : 16,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 80),
              opacity: _isPressed ? 0.4 : 1.0,
              child: Row(
                children: [
                  SvgPicture.asset(
                    AppAssets.googleIcon,
                    width: compact ? 21 : 24,
                    height: compact ? 21 : 24,
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: Text(
                      context.l10n.googleButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF616161),
                        fontSize: context.text.bodyMedium?.fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF9E9E9E),
                    size: 18,
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
