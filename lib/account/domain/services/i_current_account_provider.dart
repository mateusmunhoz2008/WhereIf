import 'package:autth_injustice_app/account/domain/models/account.dart';

abstract interface class ICurrentAccountProvider {
  Account? get currentAccount;

  String? get currentUid => currentAccount?.uid;
}
