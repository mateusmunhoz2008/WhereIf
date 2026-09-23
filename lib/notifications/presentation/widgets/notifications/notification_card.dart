import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:flutter/material.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final double scale;
  final double textScale;
  final bool isExpanded;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onExternalLinkTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.scale,
    required this.textScale,
    required this.isExpanded,
    required this.index,
    required this.onTap,
    this.onExternalLinkTap,
  });

  String _resolvedTitle(BuildContext context) {
    final key = notification.titleL10nKey;
    final args = notification.titleL10nArgs ?? const [];
    final eventTitle = args.isNotEmpty ? args[0] : '';

    return switch (key) {
      'notificationEventCreatedTitle' =>
        context.l10n.notificationEventCreatedTitle(eventTitle),
      'notificationEventCancelledTitle' =>
        context.l10n.notificationEventCancelledTitle(eventTitle),
      'notificationEventEndedTitle' =>
        context.l10n.notificationEventEndedTitle(eventTitle),
      _ => notification.title,
    };
  }

  String _resolvedMessage(BuildContext context) {
    return switch (notification.messageL10nKey) {
      'notificationEventEndedMessage' =>
        context.l10n.notificationEventEndedMessage,
      _ => notification.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _NotificationStyle.from(
      context,
      notification.type,
    );
    final radius = BorderRadius.circular(22 * scale);
    final title = _resolvedTitle(context);
    final message = _resolvedMessage(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 26),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: style.color.withValues(
              alpha: context.isDarkMode ?  (notification.isRead ? 0 : 0.18) : (notification.isRead ? 0 : 0.15),
            ),
            width: 1,
          ),
          boxShadow: [
          
            BoxShadow(
              color: style.color.withValues(
                alpha: context.isDarkMode ? 0.08 : 0.09,
              ),
              blurRadius: 50 * scale,
              offset: Offset(0, 6 * scale),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: style.color.withValues(alpha: 0.12),
            child: Ink(
              decoration: BoxDecoration(
                color: notification.isRead
                    ? Colors.transparent
                    : style.color.withValues(alpha: 0.15),
                borderRadius: radius,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      22 * scale,
                      20 * scale,
                      20 * scale,
                      20 * scale,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotificationIcon(style: style, scale: scale),
                        SizedBox(width: 16 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      style.label.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.labelSmall?.copyWith(
                                        color: style.color,
                                        fontSize: (context.text.labelSmall
                                                    ?.fontSize ??
                                                11) *
                                            textScale,
                                      ),
                                    ),
                                  ),
                                  if (!notification.isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: style.color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: style.color.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 7 * scale),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  title,
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: context.text.titleLarge?.copyWith(
                                    fontSize: 18 * textScale,
                                    color: context.onTertiary,
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  reverseDuration:
                                      const Duration(milliseconds: 180),
                                  transitionBuilder: (child, animation) {
                                    final slide = Tween<Offset>(
                                      begin: const Offset(0, -0.16),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      ),
                                    );

                                    return ClipRect(
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: slide,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: isExpanded
                                      ? _NotificationDescription(
                                          key: const ValueKey('description'),
                                          message: message,
                                          externalUrl: notification.externalUrl,
                                          onExternalLinkTap: onExternalLinkTap,
                                          scale: scale,
                                          textScale: textScale,
                                        )
                                      : const SizedBox(
                                          key:
                                              ValueKey('collapsed-description'),
                                        ),
                                ),
                              ),
                              SizedBox(height: 14 * scale),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _relativeTime(
                                        context,
                                        notification.createdAt,
                                      ),
                                      style: context.text.labelSmall?.copyWith(
                                        color: context.onTertiary.withValues(
                                          alpha: 0.46,
                                        ),
                                        fontSize: (context.text.labelSmall
                                                    ?.fontSize ??
                                                11) *
                                            textScale,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 21 * scale,
                                      color: context.onTertiary.withValues(
                                        alpha: 0.46,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) return context.l10n.notificationTimeNow;
    if (difference.inMinutes < 60) {
      return context.l10n.notificationTimeMinutesAgo(difference.inMinutes);
    }
    if (difference.inHours < 24) {
      return context.l10n.notificationTimeHoursAgo(difference.inHours);
    }
    if (difference.inDays == 1) {
      return context.l10n.notificationTimeYesterday;
    }
    return context.l10n.notificationTimeDaysAgo(difference.inDays);
  }
}

class _NotificationDescription extends StatelessWidget {
  final String message;
  final String? externalUrl;
  final VoidCallback? onExternalLinkTap;
  final double scale;
  final double textScale;

  const _NotificationDescription({
    super.key,
    required this.message,
    required this.externalUrl,
    required this.onExternalLinkTap,
    required this.scale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            color: context.onTertiary.withValues(alpha: 0.10),
          ),
          SizedBox(height: 13 * scale),
          Text(
            message,
            style: context.bodySmall?.copyWith(
              color: context.onTertiary.withValues(alpha: 0.72),
              fontSize: (context.bodySmall?.fontSize ?? 12) * textScale,
            ),
          ),
          if (externalUrl != null && onExternalLinkTap != null) ...[
            SizedBox(height: 12 * scale),
            TextButton.icon(
              onPressed: onExternalLinkTap,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: Text(context.l10n.notificationOpenLink),
              style: TextButton.styleFrom(
                foregroundColor: context.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 7 * scale,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final _NotificationStyle style;
  final double scale;

  const _NotificationIcon({required this.style, required this.scale});

  @override
  Widget build(BuildContext context) {
    final size = 48.0 * scale;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: context.isDarkMode ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: style.color.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: style.color.withValues(alpha: 0.24),
            blurRadius: 14,
          ),
        ],
      ),
      child: Icon(
        style.icon,
        size: 24 * scale,
        color: style.color,
      ),
    );
  }
}

class _NotificationStyle {
  final String label;
  final IconData icon;
  final Color color;

  const _NotificationStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
  factory _NotificationStyle.from(
    BuildContext context,
    AppNotificationType type,
  ) {
    return switch (type) {
      AppNotificationType.event => _NotificationStyle(
          label: context.l10n.notificationEvent,
          icon: Icons.calendar_month_rounded,
          color: context.secondary,
        ),
      AppNotificationType.reminder => _NotificationStyle(
          label: context.l10n.notificationReminder,
          icon: Icons.timer_outlined,
          color: context.primary,
        ),
      AppNotificationType.update => _NotificationStyle(
          label: context.l10n.notificationUpdate,
          icon: Icons.auto_awesome_rounded,
          color: context.colors.error,
        ),
    };
  }
}