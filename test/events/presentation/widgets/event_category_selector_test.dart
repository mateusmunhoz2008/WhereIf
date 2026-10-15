import 'package:autth_injustice_app/core/l10n/app_localizations.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart' as app_theme;
import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_editor/event_category_selector.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_event_categories.dart';
import 'package:autth_injustice_app/institution/packages/ifpr_pgua/ifpr_pgua_package.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category cloud fits and selects on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    EventCategory? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: app_theme.buildLightTheme(const IfprPguaPackage().theme),
        home: Scaffold(
          body: InstitutionScope(
            package: const IfprPguaPackage(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return EventCategorySelector(
                    selectedCategory: selected,
                    onSelected: (category) {
                      setState(() => selected = category);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tecnologia e inovação'));
    await tester.pumpAndSettle();

    expect(selected, IfprPguaEventCategories.technologyAndInnovation);
    expect(tester.takeException(), isNull);
  });
}
