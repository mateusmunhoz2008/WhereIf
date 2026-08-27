import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @userManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get userManagementTitle;

  /// No description provided for @userManagementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users available'**
  String get userManagementEmpty;

  /// No description provided for @userManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email'**
  String get userManagementSearchHint;

  /// No description provided for @userManagementSortNameAscending.
  ///
  /// In en, this message translates to:
  /// **'Name from A to Z'**
  String get userManagementSortNameAscending;

  /// No description provided for @userManagementSortNameDescending.
  ///
  /// In en, this message translates to:
  /// **'Name from Z to A'**
  String get userManagementSortNameDescending;

  /// No description provided for @userManagementSortHoursDescending.
  ///
  /// In en, this message translates to:
  /// **'Most hours first'**
  String get userManagementSortHoursDescending;

  /// No description provided for @userManagementSortHoursAscending.
  ///
  /// In en, this message translates to:
  /// **'Fewest hours first'**
  String get userManagementSortHoursAscending;

  /// No description provided for @userManagementFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get userManagementFilterAll;

  /// No description provided for @userManagementFilterStudents.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get userManagementFilterStudents;

  /// No description provided for @userManagementFilterManagers.
  ///
  /// In en, this message translates to:
  /// **'Event managers'**
  String get userManagementFilterManagers;

  /// No description provided for @userManagementRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userManagementRoleStudent;

  /// No description provided for @userManagementRoleEventManager.
  ///
  /// In en, this message translates to:
  /// **'Event manager'**
  String get userManagementRoleEventManager;

  /// No description provided for @userManagementTotalHours.
  ///
  /// In en, this message translates to:
  /// **'total hours'**
  String get userManagementTotalHours;

  /// No description provided for @userManagementNoResults.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get userManagementNoResults;

  /// No description provided for @userManagementLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load users'**
  String get userManagementLoadError;

  /// No description provided for @userManagementUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to manage users'**
  String get userManagementUnauthorized;

  /// No description provided for @userDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'User details'**
  String get userDetailsTitle;

  /// No description provided for @userDetailsHoursProgress.
  ///
  /// In en, this message translates to:
  /// **'Hours progress'**
  String get userDetailsHoursProgress;

  /// No description provided for @userDetailsRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get userDetailsRecordsTitle;

  /// No description provided for @userDetailsRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get userDetailsRecordsEmpty;

  /// No description provided for @userDetailsPromote.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get userDetailsPromote;

  /// No description provided for @userDetailsDemote.
  ///
  /// In en, this message translates to:
  /// **'Demote'**
  String get userDetailsDemote;

  /// No description provided for @userDetailsPromoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Promote user?'**
  String get userDetailsPromoteTitle;

  /// No description provided for @userDetailsPromoteMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will be able to create and manage events. Do you want to continue?'**
  String userDetailsPromoteMessage(String name);

  /// No description provided for @userDetailsDemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Demote user?'**
  String get userDetailsDemoteTitle;

  /// No description provided for @userDetailsDemoteMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose event management permissions. Do you want to continue?'**
  String userDetailsDemoteMessage(String name);

  /// No description provided for @userDetailsRoleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Role updated successfully.'**
  String get userDetailsRoleUpdated;

  /// No description provided for @userDetailsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load user details.'**
  String get userDetailsLoadError;

  /// No description provided for @userDetailsNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found.'**
  String get userDetailsNotFound;

  /// No description provided for @userDetailsInvalidUser.
  ///
  /// In en, this message translates to:
  /// **'Invalid user.'**
  String get userDetailsInvalidUser;

  /// No description provided for @userDetailsInvalidRole.
  ///
  /// In en, this message translates to:
  /// **'Invalid role.'**
  String get userDetailsInvalidRole;

  /// No description provided for @userDetailsRoleUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to change roles.'**
  String get userDetailsRoleUnauthorized;

  /// No description provided for @userDetailsRoleChangeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to change the role.'**
  String get userDetailsRoleChangeError;

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome To'**
  String get welcomeTo;

  /// No description provided for @whereIf.
  ///
  /// In en, this message translates to:
  /// **'Where IF'**
  String get whereIf;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @joinThe.
  ///
  /// In en, this message translates to:
  /// **'Join the'**
  String get joinThe;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgot;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get loginButton;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signupButton;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @googleButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleButton;

  /// No description provided for @whatYour.
  ///
  /// In en, this message translates to:
  /// **'What\'s your'**
  String get whatYour;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a'**
  String get createPassword;

  /// No description provided for @registerNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we\ncall you?'**
  String get registerNameTitle;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @invalidFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter a first name with at least 2 characters.'**
  String get invalidFirstName;

  /// No description provided for @invalidLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter a last name with at least 2 characters.'**
  String get invalidLastName;

  /// No description provided for @accountInvalidFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your first and last name.'**
  String get accountInvalidFullName;

  /// No description provided for @fieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the fields'**
  String get fieldsRequired;

  /// No description provided for @invalidFields.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get invalidFields;

  /// No description provided for @authEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already linked to an account.'**
  String get authEmailAlreadyInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password does not meet the security requirements.'**
  String get authWeakPassword;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authNetworkError;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authTooManyRequests;

  /// No description provided for @authAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled.'**
  String get authAccountDisabled;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Authentication could not be completed.'**
  String get authUnexpectedError;

  /// No description provided for @authBackendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Authentication is not connected to the server yet.'**
  String get authBackendUnavailable;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found.'**
  String get authUserNotFound;

  /// No description provided for @authGoogleCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was canceled.'**
  String get authGoogleCanceled;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a email'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email'**
  String get invalidEmail;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters long'**
  String get passwordMinLength;

  /// No description provided for @passwordRequireLowercaseAndUppercase.
  ///
  /// In en, this message translates to:
  /// **'Uppercase and lowercase letters'**
  String get passwordRequireLowercaseAndUppercase;

  /// No description provided for @passwordRequireNumber.
  ///
  /// In en, this message translates to:
  /// **'Include at least one number'**
  String get passwordRequireNumber;

  /// No description provided for @passwordRequireSymbol.
  ///
  /// In en, this message translates to:
  /// **'Include at least one symbol'**
  String get passwordRequireSymbol;

  /// No description provided for @passwordStrengthEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get passwordStrengthEmpty;

  /// No description provided for @passwordStrengthVeryWeak.
  ///
  /// In en, this message translates to:
  /// **'Very weak'**
  String get passwordStrengthVeryWeak;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordStrengthGood;

  /// No description provided for @passwordStrengthExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get passwordStrengthExcellent;

  /// No description provided for @checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to:'**
  String get checkEmailSentTo;

  /// No description provided for @checkEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Click the link to continue.'**
  String get checkEmailDescription;

  /// No description provided for @checkEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get checkEmailResend;

  /// No description provided for @checkEmailLinkResent.
  ///
  /// In en, this message translates to:
  /// **'We sent a new link to your email.'**
  String get checkEmailLinkResent;

  /// No description provided for @emailVerificationExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired. Request a new one to continue.'**
  String get emailVerificationExpired;

  /// No description provided for @emailVerificationUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'We could not verify the email right now.'**
  String get emailVerificationUnexpectedError;

  /// No description provided for @emailVerificationResendFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not resend the link.'**
  String get emailVerificationResendFailed;

  /// No description provided for @emailConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed!'**
  String get emailConfirmedTitle;

  /// No description provided for @emailConfirmedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All set. Now let\'s continue so you can create your new password.'**
  String get emailConfirmedSubtitle;

  /// No description provided for @accountConfirmedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been confirmed. You can now continue.'**
  String get accountConfirmedSubtitle;

  /// No description provided for @passwordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your\nnew password'**
  String get passwordResetTitle;

  /// No description provided for @passwordResetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm the new password'**
  String get passwordResetConfirmation;

  /// No description provided for @passwordResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get passwordResetButton;

  /// No description provided for @passwordResetMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get passwordResetMismatch;

  /// No description provided for @passwordResetInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'This password reset link is invalid or has already been used.'**
  String get passwordResetInvalidLink;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not reset your password.'**
  String get passwordResetFailed;

  /// No description provided for @passwordResetChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Password reset!'**
  String get passwordResetChangedTitle;

  /// No description provided for @passwordResetChangedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All set. You can now sign in using your new password.'**
  String get passwordResetChangedSubtitle;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventsTitle;

  /// No description provided for @navigationMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navigationMap;

  /// No description provided for @navigationEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navigationEvents;

  /// No description provided for @navigationNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navigationNotifications;

  /// No description provided for @navigationHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get navigationHours;

  /// No description provided for @mapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get mapLoading;

  /// No description provided for @mapComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Map coming soon'**
  String get mapComingSoon;

  /// No description provided for @featuredEvents.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredEvents;

  /// No description provided for @futureEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get futureEvents;

  /// No description provided for @addToPersonalHistory.
  ///
  /// In en, this message translates to:
  /// **'Add to my history'**
  String get addToPersonalHistory;

  /// No description provided for @personalHistoryAdded.
  ///
  /// In en, this message translates to:
  /// **'Saved to my history'**
  String get personalHistoryAdded;

  /// No description provided for @personalRecordUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating my history...'**
  String get personalRecordUpdating;

  /// No description provided for @personalRecordNotice.
  ///
  /// In en, this message translates to:
  /// **'Personal record. It does not prove attendance or grant official hours.'**
  String get personalRecordNotice;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @accessLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get accessLink;

  /// No description provided for @eventExternalLinkOpenError.
  ///
  /// In en, this message translates to:
  /// **'This link could not be opened.'**
  String get eventExternalLinkOpenError;

  /// No description provided for @eventsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Events could not be loaded.'**
  String get eventsLoadError;

  /// No description provided for @eventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events.'**
  String get eventsEmpty;

  /// No description provided for @eventDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Event unavailable.'**
  String get eventDetailsUnavailable;

  /// No description provided for @eventEditorImageUploadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Uploading an image from your device is not yet available. Choose an image from the catalog'**
  String get eventEditorImageUploadUnavailable;

  /// No description provided for @notificationEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get notificationEvent;

  /// No description provided for @notificationReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notificationReminder;

  /// No description provided for @notificationUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get notificationUpdate;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationManagementCreate.
  ///
  /// In en, this message translates to:
  /// **'New announcement'**
  String get notificationManagementCreate;

  /// No description provided for @notificationManagementCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Send an update to everyone'**
  String get notificationManagementCreateHint;

  /// No description provided for @notificationEditorContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Write the\nannouncement'**
  String get notificationEditorContentTitle;

  /// No description provided for @notificationEditorContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a clear title and include the information everyone needs.'**
  String get notificationEditorContentSubtitle;

  /// No description provided for @notificationEditorTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notificationEditorTitleLabel;

  /// No description provided for @notificationEditorDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get notificationEditorDescriptionLabel;

  /// No description provided for @notificationEditorLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a\nhelpful link'**
  String get notificationEditorLinkTitle;

  /// No description provided for @notificationEditorLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Include a page where people can learn more or take action.'**
  String get notificationEditorLinkSubtitle;

  /// No description provided for @notificationEditorLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'External link'**
  String get notificationEditorLinkLabel;

  /// No description provided for @notificationEditorLinkHint.
  ///
  /// In en, this message translates to:
  /// **'example.edu/page'**
  String get notificationEditorLinkHint;

  /// No description provided for @notificationEditorReview.
  ///
  /// In en, this message translates to:
  /// **'Review announcement'**
  String get notificationEditorReview;

  /// No description provided for @notificationEditorReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before\npublishing'**
  String get notificationEditorReviewTitle;

  /// No description provided for @notificationEditorReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This update will be published immediately for everyone in this campus app.'**
  String get notificationEditorReviewSubtitle;

  /// No description provided for @notificationEditorPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish announcement'**
  String get notificationEditorPublish;

  /// No description provided for @notificationEditorAudience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get notificationEditorAudience;

  /// No description provided for @notificationEditorAudienceAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone using this campus app'**
  String get notificationEditorAudienceAll;

  /// No description provided for @notificationEditorNotInformed.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notificationEditorNotInformed;

  /// No description provided for @notificationEditorInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title between 3 and 80 characters.'**
  String get notificationEditorInvalidTitle;

  /// No description provided for @notificationEditorInvalidDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a description between 10 and 1000 characters.'**
  String get notificationEditorInvalidDescription;

  /// No description provided for @notificationEditorInvalidExternalLink.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS link.'**
  String get notificationEditorInvalidExternalLink;

  /// No description provided for @notificationEditorRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Complete the required announcement fields.'**
  String get notificationEditorRequiredFields;

  /// No description provided for @notificationEditorPublishError.
  ///
  /// In en, this message translates to:
  /// **'The announcement could not be published.'**
  String get notificationEditorPublishError;

  /// No description provided for @notificationManagementUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to publish announcements.'**
  String get notificationManagementUnauthorized;

  /// No description provided for @notificationEditorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard announcement?'**
  String get notificationEditorDiscardTitle;

  /// No description provided for @notificationEditorDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'The information entered so far will be lost.'**
  String get notificationEditorDiscardMessage;

  /// No description provided for @notificationEditorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get notificationEditorKeepEditing;

  /// No description provided for @notificationEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get notificationEditorDiscard;

  /// No description provided for @notificationEditorBackToReview.
  ///
  /// In en, this message translates to:
  /// **'Back to review'**
  String get notificationEditorBackToReview;

  /// No description provided for @notificationOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get notificationOpenLink;

  /// No description provided for @notificationOpenLinkError.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened.'**
  String get notificationOpenLinkError;

  /// No description provided for @notificationsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be loaded.'**
  String get notificationsLoadErrorTitle;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get notificationsLoadErrorMessage;

  /// No description provided for @notificationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Important updates will appear here.'**
  String get notificationsEmptyMessage;

  /// No description provided for @notificationTimeNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get notificationTimeNow;

  /// No description provided for @notificationTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String notificationTimeMinutesAgo(int count);

  /// No description provided for @notificationTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notificationTimeHoursAgo(int count);

  /// No description provided for @notificationTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationTimeYesterday;

  /// No description provided for @notificationTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String notificationTimeDaysAgo(int count);

  /// No description provided for @notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// No description provided for @notificationsFilterEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get notificationsFilterEvents;

  /// No description provided for @notificationsFilterReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsFilterReminders;

  /// No description provided for @notificationsFilterUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notificationsFilterUpdates;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get settingsEditProfile;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSupportSection.
  ///
  /// In en, this message translates to:
  /// **'Support and about'**
  String get settingsSupportSection;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This option will be available soon.'**
  String get settingsComingSoon;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to access the app.'**
  String get settingsSignOutMessage;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsConfirmSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsConfirmSignOut;

  /// No description provided for @settingsSignOutError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign out.'**
  String get settingsSignOutError;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Events, navigation, and a personal history of your activities.'**
  String get aboutDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutAcademicProject.
  ///
  /// In en, this message translates to:
  /// **'Project developed as an undergraduate final project.'**
  String get aboutAcademicProject;

  /// No description provided for @aboutTeam.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get aboutTeam;

  /// No description provided for @aboutDeveloperRole.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloperRole;

  /// No description provided for @aboutLegalInformation.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get aboutLegalInformation;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get aboutTermsOfUse;

  /// No description provided for @helpIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get helpIntroTitle;

  /// No description provided for @helpIntroDescription.
  ///
  /// In en, this message translates to:
  /// **'Find quick answers about the main {appName} features.'**
  String helpIntroDescription(String appName);

  /// No description provided for @helpTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help topics'**
  String get helpTopicsTitle;

  /// No description provided for @helpPersonalHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'How do I record an activity in my history?'**
  String get helpPersonalHistoryTitle;

  /// No description provided for @helpPersonalHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the event details and tap Add to my history. This is a personal note and does not prove attendance or replace {institutionAcronym} validation.'**
  String helpPersonalHistoryDescription(String institutionAcronym);

  /// No description provided for @helpHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'How are complementary hours calculated?'**
  String get helpHoursTitle;

  /// No description provided for @helpHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'The counter estimates the hours listed for events added to your history. It is a personal reference and does not replace {institutionAcronym}\'s official records.'**
  String helpHoursDescription(String institutionAcronym);

  /// No description provided for @helpRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'How do I delete a record?'**
  String get helpRecordsTitle;

  /// No description provided for @helpRecordsDescription.
  ///
  /// In en, this message translates to:
  /// **'On the hours screen, open the records drawer and swipe a card sideways. Confirm the deletion when the prompt appears.'**
  String get helpRecordsDescription;

  /// No description provided for @helpNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'How do notifications work?'**
  String get helpNotificationsTitle;

  /// No description provided for @helpNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the filters to find updates, events, and reminders. Tap a notification to expand or collapse its content.'**
  String get helpNotificationsDescription;

  /// No description provided for @helpAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'How do I change my email or password?'**
  String get helpAccountTitle;

  /// No description provided for @helpAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'Open Settings, select Edit account, and choose the information you want to change. Some changes require a security confirmation.'**
  String get helpAccountDescription;

  /// No description provided for @helpContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get helpContactTitle;

  /// No description provided for @helpContactDescription.
  ///
  /// In en, this message translates to:
  /// **'Contact the team. Tap the address below to copy it.'**
  String get helpContactDescription;

  /// No description provided for @helpCopyEmail.
  ///
  /// In en, this message translates to:
  /// **'Copy email'**
  String get helpCopyEmail;

  /// No description provided for @helpEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Support email copied.'**
  String get helpEmailCopied;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountProfileSection.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfileSection;

  /// No description provided for @accountSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSecuritySection;

  /// No description provided for @accountChangeName.
  ///
  /// In en, this message translates to:
  /// **'Change name'**
  String get accountChangeName;

  /// No description provided for @accountChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get accountChangeEmail;

  /// No description provided for @accountChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePassword;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountCurrentPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your\ncurrent password'**
  String get accountCurrentPasswordTitle;

  /// No description provided for @accountCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get accountCurrentPassword;

  /// No description provided for @accountCurrentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get accountCurrentPasswordRequired;

  /// No description provided for @accountNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a\nnew password'**
  String get accountNewPasswordTitle;

  /// No description provided for @accountNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accountNewPassword;

  /// No description provided for @accountPasswordMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'The new password must be different from the current one'**
  String get accountPasswordMustDiffer;

  /// No description provided for @accountChangePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePasswordButton;

  /// No description provided for @accountPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get accountPasswordChanged;

  /// No description provided for @accountNewEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your\nnew email'**
  String get accountNewEmailTitle;

  /// No description provided for @accountNewEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get accountNewEmail;

  /// No description provided for @accountEmailChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed!'**
  String get accountEmailChangedTitle;

  /// No description provided for @accountEmailChangedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All set. Your new email is now linked to your account.'**
  String get accountEmailChangedSubtitle;

  /// No description provided for @accountEmailChanged.
  ///
  /// In en, this message translates to:
  /// **'Email changed successfully.'**
  String get accountEmailChanged;

  /// No description provided for @accountNewNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we\ncall you?'**
  String get accountNewNameTitle;

  /// No description provided for @accountNameChanged.
  ///
  /// In en, this message translates to:
  /// **'Name changed successfully.'**
  String get accountNameChanged;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @complementaryHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'My\nprogress'**
  String get complementaryHoursTitle;

  /// No description provided for @complementaryHoursInformalNotice.
  ///
  /// In en, this message translates to:
  /// **'Personal estimate. It does not prove attendance or replace {institutionAcronym} records.'**
  String complementaryHoursInformalNotice(String institutionAcronym);

  /// No description provided for @complementaryHoursLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the hours counter.'**
  String get complementaryHoursLoadError;

  /// No description provided for @complementaryHoursProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {target}'**
  String complementaryHoursProgressSemantics(String completed, String target);

  /// No description provided for @complementaryHoursRecords.
  ///
  /// In en, this message translates to:
  /// **'My records'**
  String get complementaryHoursRecords;

  /// No description provided for @complementaryHoursRecordsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the records.'**
  String get complementaryHoursRecordsLoadError;

  /// No description provided for @complementaryHoursRecordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get complementaryHoursRecordsEmpty;

  /// No description provided for @complementaryHoursNoWorkload.
  ///
  /// In en, this message translates to:
  /// **'No credited hours'**
  String get complementaryHoursNoWorkload;

  /// No description provided for @complementaryHoursDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record?'**
  String get complementaryHoursDeleteTitle;

  /// No description provided for @complementaryHoursDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{eventName}” will be removed from your informal counter.'**
  String complementaryHoursDeleteMessage(String eventName);

  /// No description provided for @complementaryHoursDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the record.'**
  String get complementaryHoursDeleteError;

  /// No description provided for @complementaryHoursDeleted.
  ///
  /// In en, this message translates to:
  /// **'Record deleted.'**
  String get complementaryHoursDeleted;

  /// No description provided for @navigationManageEvents.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navigationManageEvents;

  /// No description provided for @eventManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage events'**
  String get eventManagementTitle;

  /// No description provided for @eventManagementCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No events in the catalog} =1 {1 event in the catalog} other {{count} events in the catalog}}'**
  String eventManagementCount(int count);

  /// No description provided for @eventManagementCreate.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get eventManagementCreate;

  /// No description provided for @eventManagementCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Add to catalog'**
  String get eventManagementCreateHint;

  /// No description provided for @eventManagementScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get eventManagementScheduled;

  /// No description provided for @eventManagementPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get eventManagementPublished;

  /// No description provided for @eventManagementOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get eventManagementOngoing;

  /// No description provided for @eventManagementEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get eventManagementEnded;

  /// No description provided for @eventManagementView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get eventManagementView;

  /// No description provided for @eventManagementEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get eventManagementEdit;

  /// No description provided for @eventManagementDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get eventManagementDelete;

  /// No description provided for @eventManagementDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get eventManagementDeleteTitle;

  /// No description provided for @eventManagementDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{eventName}” will be removed from the catalog.'**
  String eventManagementDeleteMessage(String eventName);

  /// No description provided for @eventManagementDeleted.
  ///
  /// In en, this message translates to:
  /// **'Event deleted.'**
  String get eventManagementDeleted;

  /// No description provided for @eventManagementDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the event.'**
  String get eventManagementDeleteError;

  /// No description provided for @eventManagementCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel event?'**
  String get eventManagementCancelTitle;

  /// No description provided for @eventManagementCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'“{eventName}” is already visible in the app. Cancelling it will remove it from the catalog and notify everyone.'**
  String eventManagementCancelMessage(String eventName);

  /// No description provided for @eventManagementCancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get eventManagementCancelReasonLabel;

  /// No description provided for @eventManagementCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Clearly explain why the event will not take place.'**
  String get eventManagementCancelReasonHint;

  /// No description provided for @eventManagementInvalidCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason with at least 10 characters.'**
  String get eventManagementInvalidCancelReason;

  /// No description provided for @eventManagementConfirmCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancel event'**
  String get eventManagementConfirmCancellation;

  /// No description provided for @eventManagementCampusNotification.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATION FOR THE ENTIRE CAMPUS'**
  String get eventManagementCampusNotification;

  /// No description provided for @eventManagementCancellationNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled: {eventName}'**
  String eventManagementCancellationNotificationTitle(String eventName);

  /// No description provided for @eventManagementCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled and notification sent.'**
  String get eventManagementCancelled;

  /// No description provided for @eventManagementCancelError.
  ///
  /// In en, this message translates to:
  /// **'Unable to cancel the event.'**
  String get eventManagementCancelError;

  /// No description provided for @eventManagementEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get eventManagementEnd;

  /// No description provided for @eventManagementEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End event?'**
  String get eventManagementEndTitle;

  /// No description provided for @eventManagementEndMessage.
  ///
  /// In en, this message translates to:
  /// **'“{eventName}” will be removed from the catalog.'**
  String eventManagementEndMessage(String eventName);

  /// No description provided for @eventManagementEndedMessage.
  ///
  /// In en, this message translates to:
  /// **'Event ended.'**
  String get eventManagementEndedMessage;

  /// No description provided for @eventManagementEndError.
  ///
  /// In en, this message translates to:
  /// **'Unable to end the event.'**
  String get eventManagementEndError;

  /// No description provided for @eventManagementLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load events.'**
  String get eventManagementLoadError;

  /// No description provided for @eventManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty catalog'**
  String get eventManagementEmptyTitle;

  /// No description provided for @eventManagementEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create the first event to get started.'**
  String get eventManagementEmptyMessage;

  /// No description provided for @eventManagementCreateComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Event creation will be added in the next step.'**
  String get eventManagementCreateComingSoon;

  /// No description provided for @eventManagementUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot manage events.'**
  String get eventManagementUnauthorized;

  /// No description provided for @eventEditorStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String eventEditorStep(int current, int total);

  /// No description provided for @editorStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String editorStep(int current, int total);

  /// No description provided for @eventEditorIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'What is the event?'**
  String get eventEditorIdentityTitle;

  /// No description provided for @eventEditorIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start with the name and category that best identify the activity.'**
  String get eventEditorIdentitySubtitle;

  /// No description provided for @eventEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventEditorTitle;

  /// No description provided for @eventEditorCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get eventEditorCategory;

  /// No description provided for @eventEditorDateTitle.
  ///
  /// In en, this message translates to:
  /// **'When will it happen?'**
  String get eventEditorDateTitle;

  /// No description provided for @eventEditorDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set the event start date and time.'**
  String get eventEditorDateSubtitle;

  /// No description provided for @eventEditorDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get eventEditorDate;

  /// No description provided for @eventEditorTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get eventEditorTime;

  /// No description provided for @eventEditorChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get eventEditorChooseDate;

  /// No description provided for @eventEditorChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose time'**
  String get eventEditorChooseTime;

  /// No description provided for @eventEditorEndTitle.
  ///
  /// In en, this message translates to:
  /// **'How does the event end?'**
  String get eventEditorEndTitle;

  /// No description provided for @eventEditorEndSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an end time or end the event manually when it is over.'**
  String get eventEditorEndSubtitle;

  /// No description provided for @eventEditorAutomaticEnd.
  ///
  /// In en, this message translates to:
  /// **'Defined end time'**
  String get eventEditorAutomaticEnd;

  /// No description provided for @eventEditorAutomaticEndDescription.
  ///
  /// In en, this message translates to:
  /// **'The event ends automatically at the selected date and time.'**
  String get eventEditorAutomaticEndDescription;

  /// No description provided for @eventEditorManualEnd.
  ///
  /// In en, this message translates to:
  /// **'Manual ending'**
  String get eventEditorManualEnd;

  /// No description provided for @eventEditorManualEndDescription.
  ///
  /// In en, this message translates to:
  /// **'Use this when the duration is uncertain. An administrator must end the event.'**
  String get eventEditorManualEndDescription;

  /// No description provided for @eventEditorEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get eventEditorEndDate;

  /// No description provided for @eventEditorEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get eventEditorEndTime;

  /// No description provided for @eventEditorLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where will it be?'**
  String get eventEditorLocationTitle;

  /// No description provided for @eventEditorLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The location is optional and can be added or changed later.'**
  String get eventEditorLocationSubtitle;

  /// No description provided for @eventEditorLocation.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get eventEditorLocation;

  /// No description provided for @eventEditorDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Describe the event'**
  String get eventEditorDescriptionTitle;

  /// No description provided for @eventEditorDescriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Present the event and, if available, include an official page or registration form.'**
  String get eventEditorDescriptionSubtitle;

  /// No description provided for @eventEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventEditorDescription;

  /// No description provided for @eventEditorExternalLink.
  ///
  /// In en, this message translates to:
  /// **'External link (optional)'**
  String get eventEditorExternalLink;

  /// No description provided for @eventEditorExternalLinkHint.
  ///
  /// In en, this message translates to:
  /// **'example.com/register'**
  String get eventEditorExternalLinkHint;

  /// No description provided for @eventEditorHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Workload'**
  String get eventEditorHoursTitle;

  /// No description provided for @eventEditorHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only add this when the activity offers complementary hours.'**
  String get eventEditorHoursSubtitle;

  /// No description provided for @eventEditorHasHours.
  ///
  /// In en, this message translates to:
  /// **'Offers complementary hours'**
  String get eventEditorHasHours;

  /// No description provided for @eventEditorHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get eventEditorHours;

  /// No description provided for @eventEditorMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get eventEditorMinutes;

  /// No description provided for @eventEditorImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the image'**
  String get eventEditorImageTitle;

  /// No description provided for @eventEditorImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preview the real crop in both catalog formats.'**
  String get eventEditorImageSubtitle;

  /// No description provided for @eventEditorChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Select image'**
  String get eventEditorChooseImage;

  /// No description provided for @eventEditorChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get eventEditorChangeImage;

  /// No description provided for @eventEditorImageGallery.
  ///
  /// In en, this message translates to:
  /// **'Institution gallery'**
  String get eventEditorImageGallery;

  /// No description provided for @eventEditorUseDeviceImage.
  ///
  /// In en, this message translates to:
  /// **'Use image from device'**
  String get eventEditorUseDeviceImage;

  /// No description provided for @eventEditorExpandImage.
  ///
  /// In en, this message translates to:
  /// **'Expand image'**
  String get eventEditorExpandImage;

  /// No description provided for @eventEditorExpandGallery.
  ///
  /// In en, this message translates to:
  /// **'Show all images'**
  String get eventEditorExpandGallery;

  /// No description provided for @eventEditorCollapseGallery.
  ///
  /// In en, this message translates to:
  /// **'Collapse gallery'**
  String get eventEditorCollapseGallery;

  /// No description provided for @eventEditorImageSelected.
  ///
  /// In en, this message translates to:
  /// **'Image selected'**
  String get eventEditorImageSelected;

  /// No description provided for @eventEditorGalleryImage.
  ///
  /// In en, this message translates to:
  /// **'Image {number}'**
  String eventEditorGalleryImage(int number);

  /// No description provided for @eventEditorReview.
  ///
  /// In en, this message translates to:
  /// **'Review event'**
  String get eventEditorReview;

  /// No description provided for @eventEditorReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review and publish'**
  String get eventEditorReviewTitle;

  /// No description provided for @eventEditorReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the details and choose when the event should appear in the app.'**
  String get eventEditorReviewSubtitle;

  /// No description provided for @eventEditorPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get eventEditorPublishNow;

  /// No description provided for @eventEditorSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get eventEditorSchedule;

  /// No description provided for @eventEditorPublicationDate.
  ///
  /// In en, this message translates to:
  /// **'Publication date'**
  String get eventEditorPublicationDate;

  /// No description provided for @eventEditorPublicationTime.
  ///
  /// In en, this message translates to:
  /// **'Publication time'**
  String get eventEditorPublicationTime;

  /// No description provided for @eventEditorPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish event'**
  String get eventEditorPublish;

  /// No description provided for @eventEditorScheduleEvent.
  ///
  /// In en, this message translates to:
  /// **'Schedule event'**
  String get eventEditorScheduleEvent;

  /// No description provided for @eventEditorDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get eventEditorDateAndTime;

  /// No description provided for @eventEditorEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get eventEditorEnd;

  /// No description provided for @eventEditorManualEndReview.
  ///
  /// In en, this message translates to:
  /// **'Ended manually by an administrator'**
  String get eventEditorManualEndReview;

  /// No description provided for @eventEditorComplementaryHours.
  ///
  /// In en, this message translates to:
  /// **'Workload'**
  String get eventEditorComplementaryHours;

  /// No description provided for @eventEditorNotOffered.
  ///
  /// In en, this message translates to:
  /// **'Not offered'**
  String get eventEditorNotOffered;

  /// No description provided for @eventEditorHoursAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}min'**
  String eventEditorHoursAndMinutes(int hours, int minutes);

  /// No description provided for @eventEditorInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title with at least 3 characters.'**
  String get eventEditorInvalidTitle;

  /// No description provided for @eventEditorInvalidCategory.
  ///
  /// In en, this message translates to:
  /// **'Enter the event category.'**
  String get eventEditorInvalidCategory;

  /// No description provided for @eventEditorMissingDate.
  ///
  /// In en, this message translates to:
  /// **'Choose the event date and time.'**
  String get eventEditorMissingDate;

  /// No description provided for @eventEditorFutureDate.
  ///
  /// In en, this message translates to:
  /// **'The event must start at a future date.'**
  String get eventEditorFutureDate;

  /// No description provided for @eventEditorMissingEndMode.
  ///
  /// In en, this message translates to:
  /// **'Choose how the event will end.'**
  String get eventEditorMissingEndMode;

  /// No description provided for @eventEditorEndAfterStart.
  ///
  /// In en, this message translates to:
  /// **'The event must end after it starts.'**
  String get eventEditorEndAfterStart;

  /// No description provided for @eventEditorInvalidLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter a location with up to 160 characters.'**
  String get eventEditorInvalidLocation;

  /// No description provided for @eventEditorInvalidDescription.
  ///
  /// In en, this message translates to:
  /// **'Write a description with at least 10 characters.'**
  String get eventEditorInvalidDescription;

  /// No description provided for @eventEditorInvalidExternalLink.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid link, such as example.com/register.'**
  String get eventEditorInvalidExternalLink;

  /// No description provided for @eventEditorInvalidHours.
  ///
  /// In en, this message translates to:
  /// **'Enter a workload greater than zero.'**
  String get eventEditorInvalidHours;

  /// No description provided for @eventEditorMissingImage.
  ///
  /// In en, this message translates to:
  /// **'Select an image for the event.'**
  String get eventEditorMissingImage;

  /// No description provided for @eventEditorImageError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the selected image.'**
  String get eventEditorImageError;

  /// No description provided for @eventEditorFuturePublication.
  ///
  /// In en, this message translates to:
  /// **'The scheduled publication must be in the future.'**
  String get eventEditorFuturePublication;

  /// No description provided for @eventEditorPublishBeforeEvent.
  ///
  /// In en, this message translates to:
  /// **'Publication must happen before the event starts.'**
  String get eventEditorPublishBeforeEvent;

  /// No description provided for @eventEditorRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Review the required event fields.'**
  String get eventEditorRequiredFields;

  /// No description provided for @eventEditorCreateError.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the event.'**
  String get eventEditorCreateError;

  /// No description provided for @eventEditorCreated.
  ///
  /// In en, this message translates to:
  /// **'Event created successfully.'**
  String get eventEditorCreated;

  /// No description provided for @eventEditorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard event?'**
  String get eventEditorDiscardTitle;

  /// No description provided for @eventEditorDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'The information you entered will be lost.'**
  String get eventEditorDiscardMessage;

  /// No description provided for @eventEditorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get eventEditorKeepEditing;

  /// No description provided for @eventEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get eventEditorDiscard;

  /// No description provided for @eventEditorNotInformed.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get eventEditorNotInformed;

  /// No description provided for @eventEditorBackToReview.
  ///
  /// In en, this message translates to:
  /// **'Back to review'**
  String get eventEditorBackToReview;

  /// No description provided for @eventEditorEditReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEditorEditReviewTitle;

  /// No description provided for @eventEditorEditReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the event and change only what is needed.'**
  String get eventEditorEditReviewSubtitle;

  /// No description provided for @eventEditorSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get eventEditorSaveChanges;

  /// No description provided for @eventEditorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event updated successfully.'**
  String get eventEditorUpdated;

  /// No description provided for @eventEditorUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the event.'**
  String get eventEditorUpdateError;

  /// No description provided for @eventEditorLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the event details.'**
  String get eventEditorLoadError;

  /// No description provided for @eventEditorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get eventEditorTryAgain;

  /// No description provided for @eventEditorDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get eventEditorDiscardChangesTitle;

  /// No description provided for @eventEditorDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'The changes made to this event will be lost.'**
  String get eventEditorDiscardChangesMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
