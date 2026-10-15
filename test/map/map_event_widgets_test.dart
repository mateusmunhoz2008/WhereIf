import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_editor/event_map_location_selector.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:flutter_test/flutter_test.dart';

const places = [
  MapLocation(
      institutionId: 'ifpr-pgua',
      zoneId: 'bloco-didatico',
      label: 'Bloco Didático'),
  MapLocation(
      institutionId: 'ifpr-pgua',
      zoneId: 'bloco-didatico',
      floorId: 'didatico-p2',
      label: 'Piso 2 · Bloco Didático'),
  MapLocation(
      institutionId: 'ifpr-pgua',
      zoneId: 'bloco-didatico',
      floorId: 'didatico-p2',
      spaceNodeName: 'sala_1_did',
      label: 'Sala 1 · Piso 2 · Bloco Didático'),
];
Widget app(Widget child, {bool dark = false}) => MaterialApp(
    locale: const Locale('pt'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark
        ? app_theme.buildDarkTheme(const IfprPguaPackage().theme)
        : app_theme.buildLightTheme(const IfprPguaPackage().theme),
    home: InstitutionScope(
        package: const IfprPguaPackage(), child: Scaffold(body: child)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    await (FontLoader('ArchivoBlack')
          ..addFont(rootBundle.load('assets/fonts/ArchivoBlack-Regular.ttf')))
        .load();
  });
  testWidgets(
      'picker searches accents, selects multiple levels and returns stable IDs',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<MapLocation>? result;
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<List<MapLocation>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const EventMapLocationPicker(
                      locations: places, selected: []));
            },
            child: const Text('Abrir')))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('event-location-search')), 'didatico');
    await tester.pump();
    for (final place in places) {
      await tester.tap(find.byKey(ValueKey('location-${place.key}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('event-location-confirm')));
    await tester.pumpAndSettle();
    expect(result, places);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small-screen keyboard does not overflow the location picker',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
        app(const EventMapLocationPicker(locations: places, selected: [])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
