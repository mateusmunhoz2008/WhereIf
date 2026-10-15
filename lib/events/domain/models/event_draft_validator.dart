import 'event_editor_draft.dart';
import 'event_external_link.dart';
import 'event_timing.dart';

enum EventDraftValidationIssue {
  invalidTitle('eventEditorInvalidTitle'),
  missingCategory('eventEditorInvalidCategory'),
  missingStart('eventEditorMissingDate'),
  startNotInFuture('eventEditorFutureDate'),
  missingEndMode('eventEditorMissingEndMode'),
  invalidEnd('eventEditorEndAfterStart'),
  invalidLocation('eventEditorInvalidLocation'),
  invalidDescription('eventEditorInvalidDescription'),
  invalidExternalLink('eventEditorInvalidExternalLink'),
  invalidComplementaryHours('eventEditorInvalidHours'),
  missingImage('eventEditorMissingImage'),
  invalidPublication('eventEditorFuturePublication'),
  publicationAfterStart('eventEditorPublishBeforeEvent');

  final String messageKey;

  const EventDraftValidationIssue(this.messageKey);
}

abstract final class EventDraftRules {
  static const titleMinLength = 3;
  static const titleMaxLength = 80;
  static const locationMaxLength = 160;
  static const descriptionMinLength = 10;
  static const descriptionMaxLength = 1000;
  static const maxComplementaryMinutes = (100 * Duration.minutesPerHour) + 55;
}

abstract final class EventDraftValidator {
  static EventDraftValidationIssue? validateIdentity(
    EventEditorDraft draft,
  ) {
    final titleLength = draft.title.trim().length;
    if (titleLength < EventDraftRules.titleMinLength ||
        titleLength > EventDraftRules.titleMaxLength) {
      return EventDraftValidationIssue.invalidTitle;
    }
    if (draft.category == null) {
      return EventDraftValidationIssue.missingCategory;
    }
    return null;
  }

  static EventDraftValidationIssue? validateStart(
    EventEditorDraft draft, {
    required DateTime now,
  }) {
    final startsAt = draft.startsAt;
    if (startsAt == null) return EventDraftValidationIssue.missingStart;
    if (!startsAt.isAfter(now)) {
      return EventDraftValidationIssue.startNotInFuture;
    }
    return null;
  }

  static EventDraftValidationIssue? validateStartForUpdate(
    EventEditorDraft draft,
  ) {
    if (draft.startsAt == null) {
      return EventDraftValidationIssue.missingStart;
    }
    return null;
  }

  static EventDraftValidationIssue? validateEnd(EventEditorDraft draft) {
    final startsAt = draft.startsAt;
    if (startsAt == null) return EventDraftValidationIssue.missingStart;

    final endMode = draft.endMode;
    if (endMode == null) return EventDraftValidationIssue.missingEndMode;
    if (endMode == EventEndMode.automatic &&
        !EventTiming.isValidAutomaticEnd(
          startsAt: startsAt,
          endsAt: draft.endsAt,
        )) {
      return EventDraftValidationIssue.invalidEnd;
    }
    return null;
  }

  static EventDraftValidationIssue? validateLocation(
    EventEditorDraft draft,
  ) {
    if ((draft.location?.trim().length ?? 0) >
        EventDraftRules.locationMaxLength) {
      return EventDraftValidationIssue.invalidLocation;
    }
    if (draft.mapLocations.any((place) => !place.isValid) ||
        draft.mapLocations.map((place) => place.key).toSet().length !=
            draft.mapLocations.length) {
      return EventDraftValidationIssue.invalidLocation;
    }
    return null;
  }

  static EventDraftValidationIssue? validateDescription(
    EventEditorDraft draft,
  ) {
    final length = draft.description.trim().length;
    if (length < EventDraftRules.descriptionMinLength ||
        length > EventDraftRules.descriptionMaxLength) {
      return EventDraftValidationIssue.invalidDescription;
    }
    if (!EventExternalLink.isValidOptional(draft.externalUrl)) {
      return EventDraftValidationIssue.invalidExternalLink;
    }
    return null;
  }

  static EventDraftValidationIssue? validateComplementaryHours(
    EventEditorDraft draft,
  ) {
    final minutes = draft.complementaryMinutes;
    if (minutes != null &&
        (minutes <= 0 || minutes > EventDraftRules.maxComplementaryMinutes)) {
      return EventDraftValidationIssue.invalidComplementaryHours;
    }
    return null;
  }

  static EventDraftValidationIssue? validateImage(EventEditorDraft draft) {
    if (draft.displayImageSource?.trim().isEmpty ?? true) {
      return EventDraftValidationIssue.missingImage;
    }
    return null;
  }

  static EventDraftValidationIssue? validatePublication(
    EventEditorDraft draft, {
    required DateTime now,
  }) {
    final publishAt = draft.publishAt;
    if (publishAt == null) return null;
    final startsAt = draft.startsAt;
    if (startsAt == null) return EventDraftValidationIssue.missingStart;
    if (!publishAt.isAfter(now)) {
      return EventDraftValidationIssue.invalidPublication;
    }
    if (!publishAt.isBefore(startsAt)) {
      return EventDraftValidationIssue.publicationAfterStart;
    }
    return null;
  }

  static EventDraftValidationIssue? validateForCreation(
    EventEditorDraft draft, {
    required DateTime now,
  }) {
    return validateIdentity(draft) ??
        validateStart(draft, now: now) ??
        validateEnd(draft) ??
        validateLocation(draft) ??
        validateDescription(draft) ??
        validateComplementaryHours(draft) ??
        validateImage(draft) ??
        validatePublication(draft, now: now);
  }

  static EventDraftValidationIssue? validateForUpdate(
    EventEditorDraft draft, {
    required DateTime now,
  }) {
    return validateIdentity(draft) ??
        validateStartForUpdate(draft) ??
        validateEnd(draft) ??
        validateLocation(draft) ??
        validateDescription(draft) ??
        validateComplementaryHours(draft) ??
        validateImage(draft) ??
        validatePublication(draft, now: now);
  }
}
