import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/core/typedefs/types_defs.dart';

abstract interface class IAccountRepository {
  Future<AccountResult> getAccount();
  Future<VoidResult> saveAccount(Account account);
  Future<VoidResult> updateAccount(Account account);
  Future<VoidResult> deleteAccount();
}
