import 'package:auto_injector/auto_injector.dart';
import 'package:autth_injustice_app/app_startup/data/repositories/app_entry_repository_impl.dart';
import 'package:autth_injustice_app/app_startup/domain/repositories/i_app_entry_repository.dart';
import 'package:autth_injustice_app/authentication/data/repositories/email_verification_repository_impl.dart';
import 'package:autth_injustice_app/authentication/data/repositories/auth_repository_impl.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_email_verification_repository.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_auth_repository.dart';
import 'package:autth_injustice_app/authentication/data/repositories/i_password_reset_repository.dart';
import 'package:autth_injustice_app/authentication/data/repositories/password_reset_repository_impl.dart';
import 'package:autth_injustice_app/authentication/domain/facades/email_verification_facade_impl.dart';
import 'package:autth_injustice_app/authentication/domain/facades/auth_use_case_facade_impl.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_email_verification_facade.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_auth_use_case_facade.dart';
import 'package:autth_injustice_app/authentication/domain/facades/i_password_reset_facade.dart';
import 'package:autth_injustice_app/authentication/domain/facades/password_reset_facade_impl.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/email_verification_usecases_impl.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/auth_usecases_impl.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/i_email_verification_usecases.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/i_auth_usecases.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/i_password_reset_usecase.dart';
import 'package:autth_injustice_app/authentication/domain/usecases/password_reset_usecase_impl.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/check_email/check_email_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/login/login_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/register/register_viewmodel.dart';
import 'package:autth_injustice_app/authentication/presentation/viewmodels/password_reset/password_reset_viewmodel.dart';
import 'package:autth_injustice_app/authorization/domain/services/authorization_service.dart';
import 'package:autth_injustice_app/complementary_hours/data/repositories/complementary_hours_repository_impl.dart';
import 'package:autth_injustice_app/complementary_hours/domain/facades/complementary_hours_use_case_facade_impl.dart';
import 'package:autth_injustice_app/complementary_hours/domain/facades/i_complementary_hours_use_case_facade.dart';
import 'package:autth_injustice_app/complementary_hours/data/repositories/i_complementary_hours_repository.dart';
import 'package:autth_injustice_app/complementary_hours/domain/usecases/complementary_hours_usecases_impl.dart';
import 'package:autth_injustice_app/complementary_hours/domain/usecases/i_complementary_hours_usecases.dart';
import 'package:autth_injustice_app/complementary_hours/domain/services/complementary_hours_change_notifier.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/viewmodels/records/complementary_hours_records_viewmodel.dart';
import 'package:autth_injustice_app/complementary_hours/presentation/viewmodels/summary/complementary_hours_viewmodel.dart';
import 'package:autth_injustice_app/core/l10n/locale_controller.dart';
import 'package:autth_injustice_app/core/di/backend_dependency_bindings.dart';
import 'package:autth_injustice_app/core/theme/theme_controller.dart';
import 'package:autth_injustice_app/account/data/repositories/account_repository_impl.dart';
import 'package:autth_injustice_app/account/data/repositories/i_account_repository.dart';
import 'package:autth_injustice_app/account/domain/facades/account_facade_impl.dart';
import 'package:autth_injustice_app/account/domain/facades/i_account_facade.dart';
import 'package:autth_injustice_app/account/domain/usecases/account_usecases_impl.dart';
import 'package:autth_injustice_app/account/domain/usecases/i_account_usecases.dart';
import 'package:autth_injustice_app/events/data/repositories/events_repository_impl.dart';
import 'package:autth_injustice_app/events/data/repositories/i_events_repository.dart';
import 'package:autth_injustice_app/events/domain/facades/events_use_case_facade_impl.dart';
import 'package:autth_injustice_app/events/domain/facades/i_events_use_case_facade.dart';
import 'package:autth_injustice_app/events/domain/usecases/events_usecases_impl.dart';
import 'package:autth_injustice_app/events/domain/usecases/i_events_usecases.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_details/event_details_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_editor/event_editor_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_management/event_management_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/events_catalog/events_catalog_viewmodel.dart';
import 'package:autth_injustice_app/notifications/data/repositories/i_notifications_repository.dart';
import 'package:autth_injustice_app/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:autth_injustice_app/notifications/domain/facades/i_notifications_use_case_facade.dart';
import 'package:autth_injustice_app/notifications/domain/facades/notifications_use_case_facade_impl.dart';
import 'package:autth_injustice_app/notifications/domain/usecases/i_notifications_usecases.dart';
import 'package:autth_injustice_app/notifications/domain/usecases/notifications_usecases_impl.dart';
import 'package:autth_injustice_app/notifications/presentation/viewmodels/notifications/notifications_viewmodel.dart';
import 'package:autth_injustice_app/notifications/presentation/viewmodels/notification_editor/notification_editor_viewmodel.dart';
import 'package:autth_injustice_app/map/data/services/map_graphics_preferences.dart';
import 'package:autth_injustice_app/map/presentation/viewmodels/map_graphics_controller.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/change_email/change_email_viewmodel.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/change_name/change_name_viewmodel.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/change_password/change_password_viewmodel.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/settings/settings_viewmodel.dart';
import 'package:autth_injustice_app/settings/data/repositories/account_security_repository_impl.dart';
import 'package:autth_injustice_app/settings/data/repositories/i_account_security_repository.dart';
import 'package:autth_injustice_app/settings/domain/facades/account_security_facade_impl.dart';
import 'package:autth_injustice_app/settings/domain/facades/i_account_security_facade.dart';
import 'package:autth_injustice_app/settings/domain/usecases/account_security_usecases_impl.dart';
import 'package:autth_injustice_app/settings/domain/usecases/i_account_security_usecases.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/user_management/data/repositories/i_user_management_repository.dart';
import 'package:autth_injustice_app/user_management/data/repositories/user_management_repository_impl.dart';
import 'package:autth_injustice_app/user_management/domain/facades/i_user_management_use_case_facade.dart';
import 'package:autth_injustice_app/user_management/domain/facades/user_management_use_case_facade_impl.dart';
import 'package:autth_injustice_app/user_management/domain/usecases/i_user_management_usecases.dart';
import 'package:autth_injustice_app/user_management/domain/usecases/user_management_usecases_impl.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_management_viewmodel.dart';
import 'package:autth_injustice_app/user_management/presentation/viewmodels/user_details/user_details_viewmodel.dart';

final injector = AutoInjector();

void setupDependencies({
  required InstitutionPackage institutionPackage,
}) {
  injector.addInstance<InstitutionPackage>(institutionPackage);
  BackendDependencyBindings.register(
    injector,
    institutionPackage: institutionPackage,
  );
  injector.addSingleton<AuthorizationService>(AuthorizationService.new);
  injector.addSingleton<IAppEntryRepository>(AppEntryRepositoryImpl.new);
  injector.addSingleton<MapGraphicsPreferences>(MapGraphicsPreferences.new);
  injector.addSingleton<MapGraphicsController>(MapGraphicsController.new);
  _registerAuthentication();
  _registerStudentFeatures();
  _registerAccountManagement();
  _registerUserManagement();
  _registerSettings();
  injector.commit();
}

void _registerAuthentication() {
  injector.addSingleton<IAuthRepository>(AuthRepositoryImpl.new);
  injector.addSingleton<IEmailVerificationRepository>(
    EmailVerificationRepositoryImpl.new,
  );
  injector.addSingleton<IPasswordResetRepository>(
    PasswordResetRepositoryImpl.new,
  );

  injector.addSingleton<ISignInUseCase>(SignInUseCase.new);
  injector.addSingleton<ISignInWithGoogleUseCase>(SignInWithGoogleUseCase.new);
  injector.addSingleton<ISignOutUseCase>(SignOutUseCase.new);
  injector.addSingleton<ISignUpUseCase>(SignUpUseCase.new);
  injector.addSingleton<IGetEmailVerificationStatusUseCase>(
    GetEmailVerificationStatusUseCase.new,
  );
  injector.addSingleton<IResendEmailVerificationUseCase>(
    ResendEmailVerificationUseCase.new,
  );
  injector.addSingleton<IAuthUseCaseFacade>(AuthUseCaseFacadeImpl.new);
  injector.addSingleton<IEmailVerificationFacade>(
    EmailVerificationFacadeImpl.new,
  );
  injector.addSingleton<IResetPasswordUseCase>(ResetPasswordUseCase.new);
  injector.addSingleton<IPasswordResetFacade>(
    PasswordResetFacadeImpl.new,
  );

  injector.addSingleton<LoginViewModel>(LoginViewModel.new);
  injector.addSingleton<RegisterViewModel>(RegisterViewModel.new);
  injector.addSingleton<CheckEmailViewModel>(CheckEmailViewModel.new);
  injector.addSingleton<PasswordResetViewModel>(PasswordResetViewModel.new);
}

void _registerStudentFeatures() {
  injector.addSingleton<ComplementaryHoursChangeNotifier>(
    ComplementaryHoursChangeNotifier.new,
  );
  injector.addSingleton<IEventsRepository>(EventsRepositoryImpl.new);
  injector.addSingleton<IGetEventsCatalogUseCase>(GetEventsCatalogUseCase.new);
  injector.addSingleton<IGetManagementEventsCatalogUseCase>(
    GetManagementEventsCatalogUseCase.new,
  );
  injector.addSingleton<IGetEventDetailsUseCase>(GetEventDetailsUseCase.new);
  injector.addSingleton<ISetEventPersonalRecordUseCase>(
    SetEventPersonalRecordUseCase.new,
  );
  injector.addSingleton<IDeleteEventUseCase>(DeleteEventUseCase.new);
  injector.addSingleton<ICancelEventUseCase>(CancelEventUseCase.new);
  injector.addSingleton<IEndEventUseCase>(EndEventUseCase.new);
  injector.addSingleton<ICreateEventUseCase>(CreateEventUseCase.new);
  injector.addSingleton<IUpdateEventUseCase>(UpdateEventUseCase.new);
  injector.addSingleton<IEventsUseCaseFacade>(EventsUseCaseFacadeImpl.new);
  injector.addSingleton<EventsCatalogViewModel>(EventsCatalogViewModel.new);
  injector.addSingleton<EventDetailsViewModel>(EventDetailsViewModel.new);
  injector.addSingleton<EventManagementViewModel>(EventManagementViewModel.new);
  injector.addSingleton<EventEditorViewModel>(EventEditorViewModel.new);

  injector.addSingleton<INotificationsRepository>(
    NotificationsRepositoryImpl.new,
  );
  injector.addSingleton<IGetNotificationsUseCase>(GetNotificationsUseCase.new);
  injector.addSingleton<IMarkNotificationAsReadUseCase>(
    MarkNotificationAsReadUseCase.new,
  );
  injector.addSingleton<IMarkAllNotificationsAsReadUseCase>(
    MarkAllNotificationsAsReadUseCase.new,
  );
  injector.addSingleton<IPublishAnnouncementUseCase>(
    PublishAnnouncementUseCase.new,
  );
  injector.addSingleton<INotificationsUseCaseFacade>(
    NotificationsUseCaseFacadeImpl.new,
  );
  injector.addSingleton<NotificationsViewModel>(NotificationsViewModel.new);
  injector.addSingleton<NotificationEditorViewModel>(
    NotificationEditorViewModel.new,
  );

  injector.addSingleton<IComplementaryHoursRepository>(
    ComplementaryHoursRepositoryImpl.new,
  );
  injector.addSingleton<IGetComplementaryHoursSummaryUseCase>(
    GetComplementaryHoursSummaryUseCase.new,
  );
  injector.addSingleton<IGetComplementaryHoursRecordsUseCase>(
    GetComplementaryHoursRecordsUseCase.new,
  );
  injector.addSingleton<IDeleteComplementaryHoursRecordUseCase>(
    DeleteComplementaryHoursRecordUseCase.new,
  );
  injector.addSingleton<IComplementaryHoursUseCaseFacade>(
    ComplementaryHoursUseCaseFacadeImpl.new,
  );
  injector.addSingleton<ComplementaryHoursViewModel>(
    ComplementaryHoursViewModel.new,
  );
  injector.addSingleton<ComplementaryHoursRecordsViewModel>(
    ComplementaryHoursRecordsViewModel.new,
  );
}

void _registerAccountManagement() {
  injector.addSingleton<IAccountRepository>(AccountRepositoryImpl.new);
  injector.addSingleton<IGetAccountUseCase>(GetAccountUseCaseImpl.new);
  injector.addSingleton<ISaveAccountUseCase>(SaveAccountUseCaseImpl.new);
  injector.addSingleton<IUpdateAccountUseCase>(UpdateAccountUseCaseImpl.new);
  injector.addSingleton<IUpdateAccountNameUseCase>(
    UpdateAccountNameUseCaseImpl.new,
  );
  injector.addSingleton<IDeleteAccountUseCase>(DeleteAccountUseCaseImpl.new);
  injector.addSingleton<IAccountFacade>(AccountFacadeImpl.new);
}

void _registerUserManagement() {
  injector.addSingleton<IUserManagementRepository>(
    UserManagementRepositoryImpl.new,
  );
  injector.addSingleton<IGetManagedUsersUseCase>(
    GetManagedUsersUseCase.new,
  );
  injector.addSingleton<IGetManagedUserDetailsUseCase>(
    GetManagedUserDetailsUseCase.new,
  );
  injector.addSingleton<IUpdateManagedUserRoleUseCase>(
    UpdateManagedUserRoleUseCase.new,
  );
  injector.addSingleton<IUserManagementUseCaseFacade>(
    UserManagementUseCaseFacadeImpl.new,
  );
  injector.addSingleton<UserManagementViewModel>(
    UserManagementViewModel.new,
  );
  injector.addSingleton<UserDetailsViewModel>(
    UserDetailsViewModel.new,
  );
}

void _registerSettings() {
  injector.addSingleton<ThemeController>(ThemeController.new);
  injector.addSingleton<LocaleController>(LocaleController.new);
  injector.addSingleton<SettingsViewModel>(SettingsViewModel.new);

  injector.addSingleton<IAccountSecurityRepository>(
    AccountSecurityRepositoryImpl.new,
  );
  injector.addSingleton<IChangePasswordUseCase>(ChangePasswordUseCase.new);
  injector.addSingleton<IRequestEmailChangeUseCase>(
    RequestEmailChangeUseCase.new,
  );
  injector.addSingleton<IAccountSecurityFacade>(
    AccountSecurityFacadeImpl.new,
  );
  injector.addSingleton<ChangeEmailViewModel>(ChangeEmailViewModel.new);
  injector.addSingleton<ChangeNameViewModel>(ChangeNameViewModel.new);
  injector.addSingleton<ChangePasswordViewModel>(ChangePasswordViewModel.new);
}
