import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';

class AccountFirestoreMapper {
  static Map<String, dynamic> toMap(Account account) {
    return {
      'email': account.email,
      'displayName': account.displayName,
      'createdAt': Timestamp.fromDate(account.createdAt),
      'updatedAt': Timestamp.fromDate(account.updatedAt),
      'isProfileConfigured': account.isProfileConfigured,
      'role': account.role.name,
      'totalComplementaryMinutes': 0, 
    };
  }

  /// o cargo só pode ser alterado por um adm
  static Map<String, dynamic> toProfileUpdateMap(Account account) {
    return {
      'email': account.email,
      'displayName': account.displayName,
      'updatedAt': Timestamp.fromDate(account.updatedAt),
      'isProfileConfigured': account.isProfileConfigured,
    };
  }

  static Account fromMap(Map<String, dynamic> map, {required String uid}) {
    return Account(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      isProfileConfigured: map['isProfileConfigured'] as bool? ?? false,
      role: AccountRole.fromStorage(map['role'] as String?),
    );
  }

  static Account fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Documento de Account vazio para uid: ${snapshot.id}');
    }
    return fromMap(data, uid: snapshot.id);
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
