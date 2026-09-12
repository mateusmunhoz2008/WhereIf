// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get userManagementTitle => 'Users';

  @override
  String get userManagementEmpty => 'No users available';

  @override
  String get userManagementSearchHint => 'Search by name or email';

  @override
  String get userManagementSortNameAscending => 'Name from A to Z';

  @override
  String get userManagementSortNameDescending => 'Name from Z to A';

  @override
  String get userManagementSortHoursDescending => 'Most hours first';

  @override
  String get userManagementSortHoursAscending => 'Fewest hours first';

  @override
  String get userManagementFilterAll => 'All';

  @override
  String get userManagementFilterStudents => 'Users';

  @override
  String get userManagementFilterManagers => 'Event managers';

  @override
  String get userManagementRoleStudent => 'User';

  @override
  String get userManagementRoleEventManager => 'Event manager';

  @override
  String get userManagementTotalHours => 'total hours';

  @override
  String get userManagementNoResults => 'No users found';

  @override
  String get userManagementLoadError => 'Unable to load users';

  @override
  String get userManagementUnauthorized =>
      'You do not have permission to manage users';

  @override
  String get userDetailsTitle => 'User details';

  @override
  String get userDetailsHoursProgress => 'Hours progress';

  @override
  String get userDetailsRecordsTitle => 'Records';

  @override
  String get userDetailsRecordsEmpty => 'No records found';

  @override
  String get userDetailsPromote => 'Promote';

  @override
  String get userDetailsDemote => 'Demote';

  @override
  String get userDetailsPromoteTitle => 'Promote user?';

  @override
  String userDetailsPromoteMessage(String name) {
    return '$name will be able to create and manage events. Do you want to continue?';
  }

  @override
  String get userDetailsDemoteTitle => 'Demote user?';

  @override
  String userDetailsDemoteMessage(String name) {
    return '$name will lose event management permissions. Do you want to continue?';
  }

  @override
  String get userDetailsRoleUpdated => 'Role updated successfully.';

  @override
  String get userDetailsLoadError => 'Unable to load user details.';

  @override
  String get userDetailsNotFound => 'User not found.';

  @override
  String get userDetailsInvalidUser => 'Invalid user.';

  @override
  String get userDetailsInvalidRole => 'Invalid role.';

  @override
  String get userDetailsRoleUnauthorized =>
      'You do not have permission to change roles.';

  @override
  String get userDetailsRoleChangeError => 'Unable to change the role.';

  @override
  String get welcomeTo => 'Welcome To';

  @override
  String get whereIf => 'Where IF';

  @override
  String get continueButton => 'Continue';

  @override
  String get joinThe => 'Join the';

  @override
  String get team => 'Team';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgot => 'Forgot your password?';

  @override
  String get loginButton => 'Enter';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signupButton => 'Sign up';

  @override
  String get or => 'or';

  @override
  String get googleButton => 'Sign in with Google';

  @override
  String get whatYour => 'What\'s your';

  @override
  String get createPassword => 'Create a';

  @override
  String get registerNameTitle => 'What should we\ncall you?';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get invalidFirstName =>
      'Enter a first name with at least 2 characters.';

  @override
  String get invalidLastName => 'Enter a last name with at least 2 characters.';

  @override
  String get accountInvalidFullName => 'Enter your first and last name.';

  @override
  String get fieldsRequired => 'Please fill in the fields';

  @override
  String get invalidFields => 'Incorrect email or password';

  @override
  String get authEmailAlreadyInUse =>
      'This email is already linked to an account.';

  @override
  String get authWeakPassword =>
      'The password does not meet the security requirements.';

  @override
  String get authNetworkError =>
      'No connection. Check your internet and try again.';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authAccountDisabled => 'This account is disabled.';

  @override
  String get authUnexpectedError => 'Authentication could not be completed.';

  @override
  String get authBackendUnavailable =>
      'Authentication is not connected to the server yet.';

  @override
  String get authUserNotFound => 'Account not found.';

  @override
  String get authGoogleCanceled => 'Google sign-in was canceled.';

  @override
  String get emailRequired => 'Please enter a email';

  @override
  String get invalidEmail => 'Incorrect email';

  @override
  String get passwordRequired => 'Please enter a password';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters long';

  @override
  String get passwordRequireLowercaseAndUppercase =>
      'Uppercase and lowercase letters';

  @override
  String get passwordRequireNumber => 'Include at least one number';

  @override
  String get passwordRequireSymbol => 'Include at least one symbol';

  @override
  String get passwordStrengthEmpty => 'Enter a password';

  @override
  String get passwordStrengthVeryWeak => 'Very weak';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthGood => 'Good';

  @override
  String get passwordStrengthExcellent => 'Excellent';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String get checkEmailSentTo => 'We sent a link to:';

  @override
  String get checkEmailDescription => 'Click the link to continue.';

  @override
  String get checkEmailResend => 'Resend link';

  @override
  String get checkEmailLinkResent => 'We sent a new link to your email.';

  @override
  String get emailVerificationExpired =>
      'This link has expired. Request a new one to continue.';

  @override
  String get emailVerificationUnexpectedError =>
      'We could not verify the email right now.';

  @override
  String get emailVerificationResendFailed => 'We could not resend the link.';

  @override
  String get emailConfirmedTitle => 'Email confirmed!';

  @override
  String get emailConfirmedSubtitle =>
      'All set. Now let\'s continue so you can create your new password.';

  @override
  String get accountConfirmedSubtitle =>
      'Your account has been confirmed. You can now continue.';

  @override
  String get passwordResetTitle => 'Create your\nnew password';

  @override
  String get passwordResetConfirmation => 'Confirm the new password';

  @override
  String get passwordResetButton => 'Reset password';

  @override
  String get passwordResetMismatch => 'The passwords do not match.';

  @override
  String get passwordResetInvalidLink =>
      'This password reset link is invalid or has already been used.';

  @override
  String get passwordResetFailed => 'We could not reset your password.';

  @override
  String get passwordResetChangedTitle => 'Password reset!';

  @override
  String get passwordResetChangedSubtitle =>
      'All set. You can now sign in using your new password.';

  @override
  String get eventsTitle => 'Events';

  @override
  String get navigationMap => 'Map';

  @override
  String get navigationEvents => 'Events';

  @override
  String get navigationNotifications => 'Notifications';

  @override
  String get navigationHours => 'Hours';

  @override
  String get mapLoading => 'Loading map...';

  @override
  String get mapComingSoon => 'Map coming soon';

  @override
  String get featuredEvents => 'Featured';

  @override
  String get futureEvents => 'Upcoming events';

  @override
  String get addToPersonalHistory => 'Add to my history';

  @override
  String get personalHistoryAdded => 'Saved to my history';

  @override
  String get personalRecordUpdating => 'Updating my history...';

  @override
  String get personalRecordNotice =>
      'Personal record. It does not prove attendance or grant official hours.';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get accessLink => 'Open link';

  @override
  String get eventExternalLinkOpenError => 'This link could not be opened.';

  @override
  String get eventsLoadError => 'Events could not be loaded.';

  @override
  String get eventsEmpty => 'No events.';

  @override
  String get eventDetailsUnavailable => 'Event unavailable.';

  @override
  String get eventEditorImageUploadUnavailable =>
      'Uploading an image from your device is not yet available. Choose an image from the catalog';

  @override
  String get notificationEvent => 'Event';

  @override
  String get notificationReminder => 'Reminder';

  @override
  String get notificationUpdate => 'Update';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationManagementCreate => 'New announcement';

  @override
  String get notificationManagementCreateHint => 'Send an update to everyone';

  @override
  String get notificationEditorContentTitle => 'Write the\nannouncement';

  @override
  String get notificationEditorContentSubtitle =>
      'Use a clear title and include the information everyone needs.';

  @override
  String get notificationEditorTitleLabel => 'Title';

  @override
  String get notificationEditorDescriptionLabel => 'Description';

  @override
  String get notificationEditorLinkTitle => 'Add a\nhelpful link';

  @override
  String get notificationEditorLinkSubtitle =>
      'Optional. Include a page where people can learn more or take action.';

  @override
  String get notificationEditorLinkLabel => 'External link';

  @override
  String get notificationEditorLinkHint => 'example.edu/page';

  @override
  String get notificationEditorReview => 'Review announcement';

  @override
  String get notificationEditorReviewTitle => 'Review before\npublishing';

  @override
  String get notificationEditorReviewSubtitle =>
      'This update will be published immediately for everyone in this campus app.';

  @override
  String get notificationEditorPublish => 'Publish announcement';

  @override
  String get notificationEditorAudience => 'Audience';

  @override
  String get notificationEditorAudienceAll => 'Everyone using this campus app';

  @override
  String get notificationEditorNotInformed => 'Not provided';

  @override
  String get notificationEditorInvalidTitle =>
      'Enter a title between 3 and 80 characters.';

  @override
  String get notificationEditorInvalidDescription =>
      'Enter a description between 10 and 1000 characters.';

  @override
  String get notificationEditorInvalidExternalLink =>
      'Enter a valid HTTP or HTTPS link.';

  @override
  String get notificationEditorRequiredFields =>
      'Complete the required announcement fields.';

  @override
  String get notificationEditorPublishError =>
      'The announcement could not be published.';

  @override
  String get notificationManagementUnauthorized =>
      'You do not have permission to publish announcements.';

  @override
  String get notificationEditorDiscardTitle => 'Discard announcement?';

  @override
  String get notificationEditorDiscardMessage =>
      'The information entered so far will be lost.';

  @override
  String get notificationEditorKeepEditing => 'Keep editing';

  @override
  String get notificationEditorDiscard => 'Discard';

  @override
  String get notificationEditorBackToReview => 'Back to review';

  @override
  String get notificationOpenLink => 'Open link';

  @override
  String get notificationOpenLinkError => 'The link could not be opened.';

  @override
  String get notificationsLoadErrorTitle =>
      'Notifications could not be loaded.';

  @override
  String get notificationsEmptyTitle => 'Nothing here yet.';

  @override
  String get notificationsLoadErrorMessage =>
      'Check your connection and try again.';

  @override
  String get notificationsEmptyMessage => 'Important updates will appear here.';

  @override
  String get notificationTimeNow => 'Now';

  @override
  String notificationTimeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String notificationTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get notificationTimeYesterday => 'Yesterday';

  @override
  String notificationTimeDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterEvents => 'Events';

  @override
  String get notificationsFilterReminders => 'Reminders';

  @override
  String get notificationsFilterUpdates => 'Updates';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsEditProfile => 'Edit account';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSupportSection => 'Support and about';

  @override
  String get settingsHelpSupport => 'Help and support';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsComingSoon => 'This option will be available soon.';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSignOutMessage =>
      'You will need to sign in again to access the app.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsConfirmSignOut => 'Sign out';

  @override
  String get settingsSignOutError => 'Unable to sign out.';

  @override
  String get aboutDescription =>
      'Events, navigation, and a personal history of your activities.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutAcademicProject =>
      'Project developed as an undergraduate final project.';

  @override
  String get aboutTeam => 'Developed by';

  @override
  String get aboutDeveloperRole => 'Developer';

  @override
  String get aboutLegalInformation => 'Legal information';

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutTermsOfUse => 'Terms of use';

  @override
  String get helpIntroTitle => 'How can we help?';

  @override
  String helpIntroDescription(String appName) {
    return 'Find quick answers about the main $appName features.';
  }

  @override
  String get helpTopicsTitle => 'Help topics';

  @override
  String get helpPersonalHistoryTitle =>
      'How do I record an activity in my history?';

  @override
  String helpPersonalHistoryDescription(String institutionAcronym) {
    return 'Open the event details and tap Add to my history. This is a personal note and does not prove attendance or replace $institutionAcronym validation.';
  }

  @override
  String get helpHoursTitle => 'How are complementary hours calculated?';

  @override
  String helpHoursDescription(String institutionAcronym) {
    return 'The counter estimates the hours listed for events added to your history. It is a personal reference and does not replace $institutionAcronym\'s official records.';
  }

  @override
  String get helpRecordsTitle => 'How do I delete a record?';

  @override
  String get helpRecordsDescription =>
      'On the hours screen, open the records drawer and swipe a card sideways. Confirm the deletion when the prompt appears.';

  @override
  String get helpNotificationsTitle => 'How do notifications work?';

  @override
  String get helpNotificationsDescription =>
      'Use the filters to find updates, events, and reminders. Tap a notification to expand or collapse its content.';

  @override
  String get helpAccountTitle => 'How do I change my email or password?';

  @override
  String get helpAccountDescription =>
      'Open Settings, select Edit account, and choose the information you want to change. Some changes require a security confirmation.';

  @override
  String get helpContactTitle => 'Still need help?';

  @override
  String get helpContactDescription =>
      'Contact the team. Tap the address below to copy it.';

  @override
  String get helpCopyEmail => 'Copy email';

  @override
  String get helpEmailCopied => 'Support email copied.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountProfileSection => 'Profile';

  @override
  String get accountSecuritySection => 'Security';

  @override
  String get accountChangeName => 'Change name';

  @override
  String get accountChangeEmail => 'Change email';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountCurrentPasswordTitle => 'Confirm your\ncurrent password';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountCurrentPasswordRequired => 'Enter your current password';

  @override
  String get accountNewPasswordTitle => 'Create a\nnew password';

  @override
  String get accountNewPassword => 'New password';

  @override
  String get accountPasswordMustDiffer =>
      'The new password must be different from the current one';

  @override
  String get accountChangePasswordButton => 'Change password';

  @override
  String get accountPasswordChanged => 'Password changed successfully.';

  @override
  String get accountNewEmailTitle => 'Enter your\nnew email';

  @override
  String get accountNewEmail => 'New email';

  @override
  String get accountEmailChangedTitle => 'Email confirmed!';

  @override
  String get accountEmailChangedSubtitle =>
      'All set. Your new email is now linked to your account.';

  @override
  String get accountEmailChanged => 'Email changed successfully.';

  @override
  String get accountNewNameTitle => 'What should we\ncall you?';

  @override
  String get accountNameChanged => 'Name changed successfully.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get complementaryHoursTitle => 'My\nprogress';

  @override
  String complementaryHoursInformalNotice(String institutionAcronym) {
    return 'Personal estimate. It does not prove attendance or replace $institutionAcronym records.';
  }

  @override
  String get complementaryHoursLoadError => 'Unable to load the hours counter.';

  @override
  String complementaryHoursProgressSemantics(String completed, String target) {
    return '$completed of $target';
  }

  @override
  String get complementaryHoursRecords => 'My records';

  @override
  String get complementaryHoursRecordsLoadError =>
      'Unable to load the records.';

  @override
  String get complementaryHoursRecordsEmpty => 'No records yet.';

  @override
  String get complementaryHoursNoWorkload => 'No credited hours';

  @override
  String get complementaryHoursDeleteTitle => 'Delete record?';

  @override
  String complementaryHoursDeleteMessage(String eventName) {
    return '“$eventName” will be removed from your informal counter.';
  }

  @override
  String get complementaryHoursDeleteError => 'Unable to delete the record.';

  @override
  String get complementaryHoursDeleted => 'Record deleted.';

  @override
  String get navigationManageEvents => 'Manage';

  @override
  String get eventManagementTitle => 'Manage events';

  @override
  String eventManagementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events in the catalog',
      one: '1 event in the catalog',
      zero: 'No events in the catalog',
    );
    return '$_temp0';
  }

  @override
  String get eventManagementCreate => 'New event';

  @override
  String get eventManagementCreateHint => 'Add to catalog';

  @override
  String get eventManagementScheduled => 'Scheduled';

  @override
  String get eventManagementPublished => 'Published';

  @override
  String get eventManagementOngoing => 'Ongoing';

  @override
  String get eventManagementEnded => 'Ended';

  @override
  String get eventManagementView => 'View';

  @override
  String get eventManagementEdit => 'Edit';

  @override
  String get eventManagementDelete => 'Delete';

  @override
  String get eventManagementDeleteTitle => 'Delete event?';

  @override
  String eventManagementDeleteMessage(String eventName) {
    return '“$eventName” will be removed from the catalog.';
  }

  @override
  String get eventManagementDeleted => 'Event deleted.';

  @override
  String get eventManagementDeleteError => 'Unable to delete the event.';

  @override
  String get eventManagementCancelTitle => 'Cancel event?';

  @override
  String eventManagementCancelMessage(String eventName) {
    return '“$eventName” is already visible in the app. Cancelling it will remove it from the catalog and notify everyone.';
  }

  @override
  String get eventManagementCancelReasonLabel => 'Cancellation reason';

  @override
  String get eventManagementCancelReasonHint =>
      'Clearly explain why the event will not take place.';

  @override
  String get eventManagementInvalidCancelReason =>
      'Enter a reason with at least 10 characters.';

  @override
  String get eventManagementConfirmCancellation => 'Cancel event';

  @override
  String get eventManagementCampusNotification =>
      'NOTIFICATION FOR THE ENTIRE CAMPUS';

  @override
  String eventManagementCancellationNotificationTitle(String eventName) {
    return 'Event cancelled: $eventName';
  }

  @override
  String get eventManagementCancelled =>
      'Event cancelled and notification sent.';

  @override
  String get eventManagementCancelError => 'Unable to cancel the event.';

  @override
  String get eventManagementEnd => 'End';

  @override
  String get eventManagementEndTitle => 'End event?';

  @override
  String eventManagementEndMessage(String eventName) {
    return '“$eventName” will be removed from the catalog.';
  }

  @override
  String get eventManagementEndedMessage => 'Event ended.';

  @override
  String get eventManagementEndError => 'Unable to end the event.';

  @override
  String get eventManagementLoadError => 'Unable to load events.';

  @override
  String get eventManagementEmptyTitle => 'Empty catalog';

  @override
  String get eventManagementEmptyMessage =>
      'Create the first event to get started.';

  @override
  String get eventManagementCreateComingSoon =>
      'Event creation will be added in the next step.';

  @override
  String get eventManagementUnauthorized =>
      'Your account cannot manage events.';

  @override
  String eventEditorStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String editorStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get eventEditorIdentityTitle => 'What is the event?';

  @override
  String get eventEditorIdentitySubtitle =>
      'Start with the name and category that best identify the activity.';

  @override
  String get eventEditorTitle => 'Event title';

  @override
  String get eventEditorCategory => 'Category';

  @override
  String get eventEditorDateTitle => 'When will it happen?';

  @override
  String get eventEditorDateSubtitle => 'Set the event start date and time.';

  @override
  String get eventEditorDate => 'Date';

  @override
  String get eventEditorTime => 'Time';

  @override
  String get eventEditorChooseDate => 'Choose date';

  @override
  String get eventEditorChooseTime => 'Choose time';

  @override
  String get eventEditorEndTitle => 'How does the event end?';

  @override
  String get eventEditorEndSubtitle =>
      'Choose an end time or end the event manually when it is over.';

  @override
  String get eventEditorAutomaticEnd => 'Defined end time';

  @override
  String get eventEditorAutomaticEndDescription =>
      'The event ends automatically at the selected date and time.';

  @override
  String get eventEditorManualEnd => 'Manual ending';

  @override
  String get eventEditorManualEndDescription =>
      'Use this when the duration is uncertain. An administrator must end the event.';

  @override
  String get eventEditorEndDate => 'End date';

  @override
  String get eventEditorEndTime => 'End time';

  @override
  String get eventEditorLocationTitle => 'Where will it be?';

  @override
  String get eventEditorLocationSubtitle =>
      'The location is optional and can be added or changed later.';

  @override
  String get eventEditorLocation => 'Location (optional)';

  @override
  String get eventEditorDescriptionTitle => 'Describe the event';

  @override
  String get eventEditorDescriptionSubtitle =>
      'Present the event and, if available, include an official page or registration form.';

  @override
  String get eventEditorDescription => 'Description';

  @override
  String get eventEditorExternalLink => 'External link (optional)';

  @override
  String get eventEditorExternalLinkHint => 'example.com/register';

  @override
  String get eventEditorHoursTitle => 'Workload';

  @override
  String get eventEditorHoursSubtitle =>
      'Only add this when the activity offers complementary hours.';

  @override
  String get eventEditorHasHours => 'Offers complementary hours';

  @override
  String get eventEditorHours => 'Hours';

  @override
  String get eventEditorMinutes => 'Minutes';

  @override
  String get eventEditorImageTitle => 'Choose the image';

  @override
  String get eventEditorImageSubtitle =>
      'Preview the real crop in both catalog formats.';

  @override
  String get eventEditorChooseImage => 'Select image';

  @override
  String get eventEditorChangeImage => 'Change image';

  @override
  String get eventEditorImageGallery => 'Institution gallery';

  @override
  String get eventEditorUseDeviceImage => 'Use image from device';

  @override
  String get eventEditorExpandImage => 'Expand image';

  @override
  String get eventEditorExpandGallery => 'Show all images';

  @override
  String get eventEditorCollapseGallery => 'Collapse gallery';

  @override
  String get eventEditorImageSelected => 'Image selected';

  @override
  String eventEditorGalleryImage(int number) {
    return 'Image $number';
  }

  @override
  String get eventEditorReview => 'Review event';

  @override
  String get eventEditorReviewTitle => 'Review and publish';

  @override
  String get eventEditorReviewSubtitle =>
      'Check the details and choose when the event should appear in the app.';

  @override
  String get eventEditorPublishNow => 'Publish now';

  @override
  String get eventEditorSchedule => 'Schedule';

  @override
  String get eventEditorPublicationDate => 'Publication date';

  @override
  String get eventEditorPublicationTime => 'Publication time';

  @override
  String get eventEditorPublish => 'Publish event';

  @override
  String get eventEditorScheduleEvent => 'Schedule event';

  @override
  String get eventEditorDateAndTime => 'Date and time';

  @override
  String get eventEditorEnd => 'End';

  @override
  String get eventEditorManualEndReview => 'Ended manually by an administrator';

  @override
  String get eventEditorComplementaryHours => 'Workload';

  @override
  String get eventEditorNotOffered => 'Not offered';

  @override
  String eventEditorHoursAndMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get eventEditorInvalidTitle =>
      'Enter a title with at least 3 characters.';

  @override
  String get eventEditorInvalidCategory => 'Enter the event category.';

  @override
  String get eventEditorMissingDate => 'Choose the event date and time.';

  @override
  String get eventEditorFutureDate => 'The event must start at a future date.';

  @override
  String get eventEditorMissingEndMode => 'Choose how the event will end.';

  @override
  String get eventEditorEndAfterStart => 'The event must end after it starts.';

  @override
  String get eventEditorInvalidLocation =>
      'Enter a location with up to 160 characters.';

  @override
  String get eventEditorInvalidDescription =>
      'Write a description with at least 10 characters.';

  @override
  String get eventEditorInvalidExternalLink =>
      'Enter a valid link, such as example.com/register.';

  @override
  String get eventEditorInvalidHours => 'Enter a workload greater than zero.';

  @override
  String get eventEditorMissingImage => 'Select an image for the event.';

  @override
  String get eventEditorImageError => 'Unable to open the selected image.';

  @override
  String get eventEditorFuturePublication =>
      'The scheduled publication must be in the future.';

  @override
  String get eventEditorPublishBeforeEvent =>
      'Publication must happen before the event starts.';

  @override
  String get eventEditorRequiredFields => 'Review the required event fields.';

  @override
  String get eventEditorCreateError => 'Unable to create the event.';

  @override
  String get eventEditorCreated => 'Event created successfully.';

  @override
  String get eventEditorDiscardTitle => 'Discard event?';

  @override
  String get eventEditorDiscardMessage =>
      'The information you entered will be lost.';

  @override
  String get eventEditorKeepEditing => 'Keep editing';

  @override
  String get eventEditorDiscard => 'Discard';

  @override
  String get eventEditorNotInformed => 'Not provided';

  @override
  String get eventEditorBackToReview => 'Back to review';

  @override
  String get eventEditorEditReviewTitle => 'Edit event';

  @override
  String get eventEditorEditReviewSubtitle =>
      'Review the event and change only what is needed.';

  @override
  String get eventEditorSaveChanges => 'Save changes';

  @override
  String get eventEditorUpdated => 'Event updated successfully.';

  @override
  String get eventEditorUpdateError => 'Unable to update the event.';

  @override
  String get eventEditorLoadError => 'Unable to load the event details.';

  @override
  String get eventEditorTryAgain => 'Try again';

  @override
  String get eventEditorDiscardChangesTitle => 'Discard changes?';

  @override
  String get eventEditorDiscardChangesMessage =>
      'The changes made to this event will be lost.';

  @override
  String get mapInteractionHint => 'Drag to explore and tap a building';

  @override
  String get mapResetView => 'Reset map rotation';

  @override
  String get mapInteriorComingSoon => 'Interior coming soon';

  @override
  String get mapSearch => 'Search the map';

  @override
  String get mapSearchComingSoon =>
      'Room and building search will be available soon.';

  @override
  String get mapRotate => 'Drag to rotate the map';

  @override
  String get settingsMapGraphics => 'Map graphics';

  @override
  String get settingsMapGraphicsLight => 'Light';

  @override
  String get settingsMapGraphicsComplete => 'Complete';
}
