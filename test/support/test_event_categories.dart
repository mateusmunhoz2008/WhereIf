import 'package:autth_injustice_app/institution/domain/models/event_category.dart';

abstract final class TestEventCategories {
  static const academic = EventCategory(
    storageValue: 'test-academic',
    iconKey: 'academic',
    localizedLabels: {
      'pt': 'Acadêmico',
      'en': 'Academic',
      'es': 'Académico',
    },
  );

  static const other = EventCategory(
    storageValue: 'test-other',
    iconKey: 'other',
    localizedLabels: {
      'pt': 'Outros',
      'en': 'Other',
      'es': 'Otros',
    },
  );
}
