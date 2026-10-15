import 'package:autth_injustice_app/institution/domain/models/event_category.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/widgets.dart';

extension EventCategoryL10n on EventCategory {
  String localizedLabel(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return customLabelFor(
          languageCode,
          fallbackLanguageCode:
              context.institution.localization.defaultLanguageCode,
        ) ??
        storageValue;
  }
}
