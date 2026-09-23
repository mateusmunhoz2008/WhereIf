enum AppNotificationType {
  event,
  reminder,
  update,
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? eventId;
  final String? authorUid;
  final String? externalUrl;

  final String? titleL10nKey;
  final List<String>? titleL10nArgs;
  final String? messageL10nKey;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.eventId,
    this.authorUid,
    this.externalUrl,
    this.titleL10nKey,
    this.titleL10nArgs,
    this.messageL10nKey,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      eventId: eventId,
      authorUid: authorUid,
      externalUrl: externalUrl,
      titleL10nKey: titleL10nKey,
      titleL10nArgs: titleL10nArgs,
      messageL10nKey: messageL10nKey,
    );
  }
}