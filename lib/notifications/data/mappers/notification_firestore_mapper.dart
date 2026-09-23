import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';

class NotificationFirestoreMapper {
  static Map<String, dynamic> toMap({
    required AppNotificationType type,
    required String title,
    required String message,
    required DateTime createdAt,
    String? eventId,
    String? authorUid,
    String? externalUrl,
    String? titleL10nKey,
    List<String>? titleL10nArgs,
    String? messageL10nKey,
  }) {
    return {
      'type': type.name,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'eventId': eventId,
      'authorUid': authorUid,
      'externalUrl': externalUrl,
      'titleL10nKey': titleL10nKey,
      'titleL10nArgs': titleL10nArgs,
      'messageL10nKey': messageL10nKey,
    };
  }

  static AppNotification fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required bool isRead,
  }) {
    final data = snapshot.data() ?? const {};
    final rawArgs = data['titleL10nArgs'];

    return AppNotification(
      id: snapshot.id,
      type: AppNotificationType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => AppNotificationType.update,
      ),
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: _timestamp(data['createdAt']),
      isRead: isRead,
      eventId: data['eventId'] as String?,
      authorUid: data['authorUid'] as String?,
      externalUrl: data['externalUrl'] as String?,
      titleL10nKey: data['titleL10nKey'] as String?,
      titleL10nArgs: rawArgs is List
          ? rawArgs.map((value) => value.toString()).toList()
          : null,
      messageL10nKey: data['messageL10nKey'] as String?,
    );
  }

  static DateTime _timestamp(dynamic value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
}