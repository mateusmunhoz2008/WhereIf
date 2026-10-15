import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:equatable/equatable.dart';

/// Expiration metadata; credentials remain managed by Firebase Auth.
class Token extends Equatable {
  final DateTime expiresAt;

  const Token({
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [expiresAt];
}

class AuthSession extends Equatable {
  final Account account;
  final Token token;

  const AuthSession({
    required this.account,
    required this.token,
  });

  bool get isExpired => token.isExpired;

  @override
  List<Object?> get props => [account, token];
}
