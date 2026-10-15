import 'dart:async';

import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/account/domain/services/i_current_account_provider.dart';
import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authentication/domain/models/auth_session.dart';
import 'package:autth_injustice_app/authentication/presentation/navigation/auth_routes.dart';
import 'package:autth_injustice_app/authentication/presentation/pages/splash_page.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/events/presentation/navigation/events_routes.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth extends Fake implements IAuthRepository {
  bool fail = false;
  int attempts = 0;
  Future<void>? pending;
  @override
  AuthSession? currentSession;

  @override
  Future<void> initSession() async {
    attempts++;
    if (fail) throw StateError('Session initialization failed');
    await pending;
  }
}

class _Entry extends Fake implements IAppEntryRepository {
  bool fail = false;
  Future<bool>? pending;
  @override
  Future<bool> hasCompletedInitialPage() async {
    if (fail) throw StateError('Preferences unavailable');
    return pending ?? Future.value(true);
  }
}

class _AccountProvider implements ICurrentAccountProvider {
  _AccountProvider(this.auth);
  final _Auth auth;
  @override
  Account? get currentAccount => auth.currentSession?.account;
  @override
  String? get currentUid => currentAccount?.uid;
}

Future<GoRouter> _mount(WidgetTester tester, _Auth auth, _Entry entry) async {
  final router = GoRouter(initialLocation: '/splash', routes: [
    GoRoute(
        path: '/splash',
        builder: (context, state) => InstitutionScope(
              package: const IfprPguaPackage(),
              child: SplashPage(
                authRepository: auth,
                entryRepository: entry,
                authorizationService: AuthorizationService(
                    currentAccountProvider: _AccountProvider(auth)),
              ),
            )),
    GoRoute(
        path: '/events',
        name: EventsRouteNames.catalog,
        builder: (context, state) => const Scaffold(body: Text('Catalog'))),
    GoRoute(
        path: '/initial',
        name: AuthRouteNames.initial,
        builder: (context, state) => const Scaffold(body: Text('Onboarding'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
  ));
  return router;
}

void main() {
  testWidgets(
      'failed session initialization stays recoverable and never becomes a guest',
      (tester) async {
    final session = AuthSession(
      account: Account.initial(
          uid: 'persisted', email: 'test@example.com', displayName: 'Student'),
      token: Token(expiresAt: DateTime(2030)),
    );
    final auth = _Auth()
      ..fail = true
      ..currentSession = session;
    final router = await _mount(tester, auth, _Entry());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('splash-initialization-error')),
        findsOneWidget);
    expect(router.routerDelegate.state.uri.path, '/splash');
    expect(auth.currentSession, same(session));
    expect(tester.takeException(), isNull);

    auth.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.attempts, 2);
    expect(find.text('Catalog'), findsOneWidget);
    expect(auth.currentSession, same(session));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable onboarding preference does not block startup',
      (tester) async {
    await _mount(tester, _Auth(), _Entry()..fail = true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving splash ignores late initialization', (tester) async {
    final pending = Completer<void>();
    await _mount(tester, _Auth()..pending = pending.future, _Entry());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
