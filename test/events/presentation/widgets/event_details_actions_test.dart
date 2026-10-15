import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/core/widgets/app_action_button.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_details/event_details_actions.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final hasLocation in [false, true]) {
    for (final hasLink in [false, true]) {
      testWidgets('actions resize for location=$hasLocation and link=$hasLink',
          (tester) async {
        var mapTaps = 0;
        var linkTaps = 0;
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: EventDetailsActions(
                authenticated: true,
                addedToPersonalHistory: false,
                personalRecordUpdating: false,
                onPersonalRecordTap: () {},
                onMapTap: hasLocation ? () => mapTaps++ : null,
                onExternalLinkTap: hasLink ? () => linkTaps++ : null,
              ),
            ),
          ),
        ));
        expect(find.text('Ver no mapa'),
            hasLocation ? findsOneWidget : findsNothing);
        expect(
            find.text('Acessar link'), hasLink ? findsOneWidget : findsNothing);
        expect(find.text('Adicionar ao meu histórico'), findsOneWidget);
        final availableWidth =
            tester.getSize(find.byType(EventDetailsActions)).width;
        for (final label in [
          if (hasLocation) 'Ver no mapa',
          if (hasLink) 'Acessar link'
        ]) {
          final button = find.widgetWithText(AppActionButton, label);
          expect(
              tester.getSize(button).width,
              closeTo(
                  hasLocation && hasLink
                      ? (availableWidth - 9) / 2
                      : availableWidth,
                  0.01));
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
        expect(mapTaps, hasLocation ? 1 : 0);
        expect(linkTaps, hasLink ? 1 : 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('guest sees only the map action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
        home: Scaffold(
          body: EventDetailsActions(
            authenticated: false,
            addedToPersonalHistory: false,
            personalRecordUpdating: false,
            onPersonalRecordTap: () {},
            onMapTap: () {},
            onExternalLinkTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ver no mapa'), findsOneWidget);
    expect(find.text('Acessar link'), findsNothing);
    expect(find.text('Adicionar ao meu histórico'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
