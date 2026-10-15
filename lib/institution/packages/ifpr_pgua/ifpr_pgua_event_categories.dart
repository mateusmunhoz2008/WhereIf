import 'package:autth_injustice_app/institution/domain/models/event_category.dart';

abstract final class IfprPguaEventCategories {
  static const academic = EventCategory(
    storageValue: 'academic',
    iconKey: 'academic',
    localizedLabels: {
      'pt': 'Acadêmico',
      'en': 'Academic',
      'es': 'Académico',
    },
  );

  static const artsAndCulture = EventCategory(
    storageValue: 'artsAndCulture',
    iconKey: 'arts',
    localizedLabels: {
      'pt': 'Arte e cultura',
      'en': 'Arts and culture',
      'es': 'Arte y cultura',
    },
  );

  static const scienceAndResearch = EventCategory(
    storageValue: 'scienceAndResearch',
    iconKey: 'science',
    localizedLabels: {
      'pt': 'Ciência e pesquisa',
      'en': 'Science and research',
      'es': 'Ciencia e investigación',
    },
  );

  static const technologyAndInnovation = EventCategory(
    storageValue: 'technologyAndInnovation',
    iconKey: 'technology',
    localizedLabels: {
      'pt': 'Tecnologia e inovação',
      'en': 'Technology and innovation',
      'es': 'Tecnología e innovación',
    },
  );

  static const sportsAndLeisure = EventCategory(
    storageValue: 'sportsAndLeisure',
    iconKey: 'sports',
    localizedLabels: {
      'pt': 'Esporte e lazer',
      'en': 'Sports and leisure',
      'es': 'Deporte y ocio',
    },
  );

  static const healthAndWellness = EventCategory(
    storageValue: 'healthAndWellness',
    iconKey: 'health',
    localizedLabels: {
      'pt': 'Saúde e bem-estar',
      'en': 'Health and wellness',
      'es': 'Salud y bienestar',
    },
  );

  static const environment = EventCategory(
    storageValue: 'environment',
    iconKey: 'environment',
    localizedLabels: {
      'pt': 'Meio ambiente',
      'en': 'Environment',
      'es': 'Medio ambiente',
    },
  );

  static const extension = EventCategory(
    storageValue: 'extension',
    iconKey: 'extension',
    localizedLabels: {
      'pt': 'Extensão',
      'en': 'Extension',
      'es': 'Extensión',
    },
  );

  static const community = EventCategory(
    storageValue: 'community',
    iconKey: 'community',
    localizedLabels: {
      'pt': 'Comunidade',
      'en': 'Community',
      'es': 'Comunidad',
    },
  );

  static const institutional = EventCategory(
    storageValue: 'institutional',
    iconKey: 'institutional',
    localizedLabels: {
      'pt': 'Institucional',
      'en': 'Institutional',
      'es': 'Institucional',
    },
  );

  static const careers = EventCategory(
    storageValue: 'careers',
    iconKey: 'careers',
    localizedLabels: {
      'pt': 'Carreira',
      'en': 'Careers',
      'es': 'Carrera profesional',
    },
  );

  static const other = EventCategory(
    storageValue: 'other',
    iconKey: 'other',
    localizedLabels: {
      'pt': 'Outros',
      'en': 'Other',
      'es': 'Otros',
    },
  );

  static const values = [
    academic,
    artsAndCulture,
    scienceAndResearch,
    technologyAndInnovation,
    sportsAndLeisure,
    healthAndWellness,
    environment,
    extension,
    community,
    institutional,
    careers,
    other,
  ];
}
