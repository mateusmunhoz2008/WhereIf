import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autth_injustice_app/authentication/data/services/remote/i_auth_service.dart';
import 'package:autth_injustice_app/core/failure/failure.dart';
import 'package:autth_injustice_app/core/patterns/result.dart';
import 'package:autth_injustice_app/settings/data/services/i_account_security_service.dart';
import 'package:autth_injustice_app/settings/domain/account_security_types.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseAccountSecurityService implements IAccountSecurityService {
  static const _subcollections = [
    'personalActivityRecords',
    'readNotifications',
  ];
  static const _batchSize = 400;

  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final IAuthService _authService;

  FirebaseAccountSecurityService({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    required IAuthService authService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService;

  @override
  AccountCredentialInfo get credentialInfo {
    final providers = _firebaseAuth.currentUser?.providerData
            .map((info) => info.providerId)
            .toSet() ??
        const <String>{};
    return AccountCredentialInfo(
      hasPassword: providers.contains('password'),
      hasGoogle: providers.contains('google.com'),
    );
  }

  @override
  Future<AccountSecurityResult> changePassword(
    ChangePasswordParams params,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Error(UnauthenticatedFailure());
    if (!credentialInfo.hasPassword) {
      return Error(InvalidInputFailure('accountPasswordNotAvailable'));
    }

    try {
      await _reauthenticateWithPassword(user, params.currentPassword);
      await user.updatePassword(params.newPassword);
      return const Success(null);
    } catch (error) {
      return Error(_mapFailure(error));
    }
  }

  @override
  Future<AccountSecurityResult> requestEmailChange(
    RequestEmailChangeParams params,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Error(UnauthenticatedFailure());
    if (!credentialInfo.hasPassword) {
      return Error(InvalidInputFailure('accountPasswordNotAvailable'));
    }

    final newEmail = params.newEmail.trim();
    if (newEmail.toLowerCase() == (user.email ?? '').toLowerCase()) {
      return Error(InvalidInputFailure('accountEmailSameAsCurrent'));
    }

    try {
      await _reauthenticateWithPassword(user, params.currentPassword);
      await user.verifyBeforeUpdateEmail(newEmail);
      return const Success(null);
    } catch (error) {
      return Error(_mapFailure(error));
    }
  }

  @override
  Future<AccountSecurityResult> deleteAccount(
    DeleteAccountParams params,
  ) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Error(UnauthenticatedFailure());

    try {
      if (credentialInfo.hasPassword) {
        final password = params.currentPassword;
        if (password == null || password.isEmpty) {
          return Error(InvalidInputFailure('accountCurrentPasswordRequired'));
        }
        await _reauthenticateWithPassword(user, password);
      } else {
        final result = await _authService.reauthenticateWithGoogle();
        if (result case Error<void, Failure>(:final value)) {
          return Error(value);
        }
      }

      await _deleteUserData(user.uid);
      await user.delete();

      await _authService.signOut();
      return const Success(null);
    } catch (error) {
      return Error(_mapFailure(error, fallback: 'accountDeleteError'));
    }
  }

  Future<void> _reauthenticateWithPassword(
    fb.User user,
    String password,
  ) async {
    final email = user.email;
    if (email == null) throw DefaultFailure('authUnexpectedError');

    await user.reauthenticateWithCredential(
      fb.EmailAuthProvider.credential(email: email, password: password),
    );
  }

  Future<void> _deleteUserData(String uid) async {
    final accountRef = _firestore.collection('accounts').doc(uid);

    for (final name in _subcollections) {
      final docs = (await accountRef.collection(name).get()).docs;
      for (var start = 0; start < docs.length; start += _batchSize) {
        final end =
            start + _batchSize > docs.length ? docs.length : start + _batchSize;
        final batch = _firestore.batch();
        for (final doc in docs.sublist(start, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    await accountRef.delete();
  }

  Failure _mapFailure(Object error, {String fallback = 'authUnexpectedError'}) {
    if (error is Failure) return error;

    if (error is fb.FirebaseAuthException) {
      return switch (error.code) {
        'wrong-password' ||
        'invalid-credential' =>
          DefaultFailure('accountCurrentPasswordInvalid'),
        'weak-password' => DefaultFailure('authWeakPassword'),
        'email-already-in-use' => DefaultFailure('authEmailAlreadyInUse'),
        'invalid-email' => DefaultFailure('invalidEmail'),
        'too-many-requests' => DefaultFailure('authTooManyRequests'),
        'network-request-failed' => DefaultFailure('authNetworkError'),
        'requires-recent-login' => DefaultFailure('authRequiresRecentLogin'),
        _ => DefaultFailure(fallback),
      };
    }

    if (error is FirebaseException) return RemoteFailure(fallback);
    return DefaultFailure(fallback);
  }
}