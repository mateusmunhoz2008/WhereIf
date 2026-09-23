// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get userManagementTitle => 'Usuarios';

  @override
  String get userManagementEmpty => 'No hay usuarios disponibles';

  @override
  String get userManagementSearchHint => 'Buscar por nombre o correo';

  @override
  String get userManagementSortNameAscending => 'Nombre de A a Z';

  @override
  String get userManagementSortNameDescending => 'Nombre de Z a A';

  @override
  String get userManagementSortHoursDescending => 'Más horas primero';

  @override
  String get userManagementSortHoursAscending => 'Menos horas primero';

  @override
  String get userManagementFilterAll => 'Todos';

  @override
  String get userManagementFilterStudents => 'Usuarios';

  @override
  String get userManagementFilterManagers => 'Gestores de eventos';

  @override
  String get userManagementRoleStudent => 'Usuario';

  @override
  String get userManagementRoleEventManager => 'Gestor de eventos';

  @override
  String get userManagementTotalHours => 'horas totales';

  @override
  String get userManagementNoResults => 'No se encontraron usuarios';

  @override
  String get userManagementLoadError => 'No se pudieron cargar los usuarios';

  @override
  String get userManagementUnauthorized =>
      'No tienes permiso para gestionar usuarios';

  @override
  String get userDetailsTitle => 'Detalles del usuario';

  @override
  String get userDetailsHoursProgress => 'Progreso de horas';

  @override
  String get userDetailsRecordsTitle => 'Registros';

  @override
  String get userDetailsRecordsEmpty => 'No se encontraron registros';

  @override
  String get userDetailsPromote => 'Promover';

  @override
  String get userDetailsDemote => 'Degradar';

  @override
  String get userDetailsPromoteTitle => '¿Promover usuario?';

  @override
  String userDetailsPromoteMessage(String name) {
    return '$name podrá crear y gestionar eventos. ¿Deseas continuar?';
  }

  @override
  String get userDetailsDemoteTitle => '¿Degradar usuario?';

  @override
  String userDetailsDemoteMessage(String name) {
    return '$name perderá los permisos de gestión de eventos. ¿Deseas continuar?';
  }

  @override
  String get userDetailsRoleUpdated => 'Rol actualizado correctamente.';

  @override
  String get userDetailsLoadError =>
      'No se pudieron cargar los detalles del usuario.';

  @override
  String get userDetailsNotFound => 'Usuario no encontrado.';

  @override
  String get userDetailsInvalidUser => 'Usuario no válido.';

  @override
  String get userDetailsInvalidRole => 'Rol no válido.';

  @override
  String get userDetailsRoleUnauthorized =>
      'No tienes permiso para cambiar roles.';

  @override
  String get userDetailsRoleChangeError => 'No se pudo cambiar el rol.';

  @override
  String get welcomeTo => 'Bienvenido a';

  @override
  String get whereIf => 'Where IF';

  @override
  String get continueButton => 'Continuar';

  @override
  String get joinThe => 'Únete al';

  @override
  String get team => 'Equipo';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get forgot => '¿Olvidaste tu contraseña?';

  @override
  String get loginButton => 'Entrar';

  @override
  String get dontHaveAccount => '¿No tienes una cuenta?';

  @override
  String get signupButton => 'Regístrarse';

  @override
  String get or => 'o';

  @override
  String get googleButton => 'Iniciar sesión con Google';

  @override
  String get whatYour => '¿Cuál es tu';

  @override
  String get createPassword => 'Crea una';

  @override
  String get registerNameTitle => '¿Cómo debemos\nllamarte?';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get invalidFirstName => 'Ingresa un nombre de al menos 2 caracteres.';

  @override
  String get invalidLastName => 'Ingresa un apellido de al menos 2 caracteres.';

  @override
  String get accountInvalidFullName => 'Ingresa tu nombre y apellido.';

  @override
  String get fieldsRequired => 'Por favor, complete los campos';

  @override
  String get invalidFields => 'Correo electrónico o contraseña incorrectos';

  @override
  String get authEmailAlreadyInUse =>
      'Este correo ya está vinculado a una cuenta.';

  @override
  String get authWeakPassword =>
      'La contraseña no cumple los requisitos de seguridad.';

  @override
  String get authNetworkError =>
      'Sin conexión. Comprueba tu internet e inténtalo de nuevo.';

  @override
  String get authTooManyRequests =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.';

  @override
  String get authAccountDisabled => 'Esta cuenta está desactivada.';

  @override
  String get authUnexpectedError => 'No se pudo completar la autenticación.';

  @override
  String get authBackendUnavailable =>
      'La autenticación aún no está conectada al servidor.';

  @override
  String get authUserNotFound => 'Cuenta no encontrada.';

  @override
  String get authGoogleCanceled => 'Se canceló el inicio de sesión con Google.';

  @override
  String get emailRequired => 'Introduce un correo electrónico';

  @override
  String get invalidEmail => 'Correo electrónico incorrecto';

  @override
  String get passwordRequired => 'Introduce una contraseña';

  @override
  String get passwordMinLength =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get passwordRequireLowercaseAndUppercase =>
      'Letras mayúsculas y minúsculas';

  @override
  String get passwordRequireNumber => 'Incluye al menos un número';

  @override
  String get passwordRequireSymbol => 'Incluye al menos un símbolo';

  @override
  String get passwordStrengthEmpty => 'Introduce una contraseña';

  @override
  String get passwordStrengthVeryWeak => 'Muy débil';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthFair => 'Aceptable';

  @override
  String get passwordStrengthGood => 'Buena';

  @override
  String get passwordStrengthExcellent => 'Excelente';

  @override
  String get checkEmailTitle => 'Verifica tu correo electrónico';

  @override
  String get checkEmailSentTo => 'Enviamos un enlace a:';

  @override
  String get checkEmailDescription => 'Haz clic en el enlace para continuar.';

  @override
  String get checkEmailResend => 'Reenviar enlace';

  @override
  String get checkEmailLinkResent => 'Enviamos un nuevo enlace a tu correo.';

  @override
  String get emailVerificationExpired =>
      'Este enlace venció. Solicita uno nuevo para continuar.';

  @override
  String get emailVerificationUnexpectedError =>
      'No pudimos verificar el correo ahora.';

  @override
  String get emailVerificationResendFailed => 'No pudimos reenviar el enlace.';

  @override
  String get emailConfirmedTitle => '¡Email confirmado!';

  @override
  String get emailConfirmedSubtitle =>
      'Todo listo. Ahora continuemos para crear tu nueva contraseña.';

  @override
  String get accountConfirmedSubtitle =>
      'Tu cuenta ha sido confirmada. Ahora puedes continuar.';

  @override
  String get passwordResetTitle => 'Crea tu\nnueva contraseña';

  @override
  String get passwordResetConfirmation => 'Confirma la nueva contraseña';

  @override
  String get passwordResetButton => 'Restablecer contraseña';

  @override
  String get passwordResetMismatch => 'Las contraseñas no coinciden.';

  @override
  String get passwordResetInvalidLink =>
      'Este enlace de restablecimiento no es válido o ya fue utilizado.';

  @override
  String get passwordResetFailed => 'No fue posible restablecer tu contraseña.';

  @override
  String get passwordResetChangedTitle => '¡Contraseña restablecida!';

  @override
  String get passwordResetChangedSubtitle =>
      'Todo listo. Ahora puedes iniciar sesión con tu nueva contraseña.';

  @override
  String get eventsTitle => 'Eventos';

  @override
  String get navigationMap => 'Mapa';

  @override
  String get navigationEvents => 'Eventos';

  @override
  String get navigationNotifications => 'Notificaciones';

  @override
  String get navigationHours => 'Horas';

  @override
  String get mapLoading => 'Cargando mapa...';

  @override
  String get mapComingSoon => 'Mapa próximamente';

  @override
  String get featuredEvents => 'Destacados';

  @override
  String get futureEvents => 'Próximos eventos';

  @override
  String get addToPersonalHistory => 'Añadir a mi historial';

  @override
  String get personalHistoryAdded => 'Guardado en mi historial';

  @override
  String get personalRecordUpdating => 'Actualizando mi historial...';

  @override
  String get personalRecordNotice =>
      'Registro personal. No acredita asistencia ni concede horas oficiales.';

  @override
  String get viewOnMap => 'Ver en el mapa';

  @override
  String get accessLink => 'Acceder al enlace';

  @override
  String get eventExternalLinkOpenError => 'No se pudo abrir este enlace.';

  @override
  String get eventsLoadError => 'No se pudieron cargar los eventos.';

  @override
  String get eventsEmpty => 'No hay eventos.';

  @override
  String get eventDetailsUnavailable => 'Evento no disponible.';

  @override
  String get eventEditorImageUploadUnavailable =>
      'La carga de imágenes desde el dispositivo aún no está disponible. Elige una imagen del catálogo.';

  @override
  String get notificationEvent => 'Evento';

  @override
  String get notificationReminder => 'Recordatorio';

  @override
  String get notificationUpdate => 'Actualización';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationManagementCreate => 'Nuevo aviso';

  @override
  String get notificationManagementCreateHint =>
      'Enviar una actualización para todos';

  @override
  String get notificationEditorContentTitle => 'Escribe el\naviso';

  @override
  String get notificationEditorContentSubtitle =>
      'Usa un título claro e incluye la información que todos necesitan.';

  @override
  String get notificationEditorTitleLabel => 'Título';

  @override
  String get notificationEditorDescriptionLabel => 'Descripción';

  @override
  String get notificationEditorLinkTitle => 'Añade un\nenlace útil';

  @override
  String get notificationEditorLinkSubtitle =>
      'Opcional. Incluye una página para obtener más información o realizar una acción.';

  @override
  String get notificationEditorLinkLabel => 'Enlace externo';

  @override
  String get notificationEditorLinkHint => 'ejemplo.edu/pagina';

  @override
  String get notificationEditorReview => 'Revisar aviso';

  @override
  String get notificationEditorReviewTitle => 'Revisa antes\nde publicar';

  @override
  String get notificationEditorReviewSubtitle =>
      'Esta actualización se publicará inmediatamente para todos en este campus.';

  @override
  String get notificationEditorPublish => 'Publicar aviso';

  @override
  String get notificationEditorAudience => 'Público';

  @override
  String get notificationEditorAudienceAll =>
      'Todos los usuarios de este campus';

  @override
  String get notificationEditorNotInformed => 'No informado';

  @override
  String get notificationEditorInvalidTitle =>
      'Introduce un título de entre 3 y 80 caracteres.';

  @override
  String get notificationEditorInvalidDescription =>
      'Introduce una descripción de entre 10 y 1000 caracteres.';

  @override
  String get notificationEditorInvalidExternalLink =>
      'Introduce un enlace HTTP o HTTPS válido.';

  @override
  String get notificationEditorRequiredFields =>
      'Completa los campos obligatorios del aviso.';

  @override
  String get notificationEditorPublishError => 'No se pudo publicar el aviso.';

  @override
  String get notificationManagementUnauthorized =>
      'No tienes permiso para publicar avisos.';

  @override
  String get notificationEditorDiscardTitle => '¿Descartar aviso?';

  @override
  String get notificationEditorDiscardMessage =>
      'La información introducida hasta ahora se perderá.';

  @override
  String get notificationEditorKeepEditing => 'Seguir editando';

  @override
  String get notificationEditorDiscard => 'Descartar';

  @override
  String get notificationEditorBackToReview => 'Volver a la revisión';

  @override
  String get notificationOpenLink => 'Abrir enlace';

  @override
  String get notificationOpenLinkError => 'No se pudo abrir el enlace.';

  @override
  String get notificationsLoadErrorTitle =>
      'No se pudieron cargar las notificaciones.';

  @override
  String get notificationsEmptyTitle => 'Aún no hay nada aquí.';

  @override
  String get notificationsLoadErrorMessage =>
      'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get notificationsEmptyMessage =>
      'Las novedades importantes aparecerán aquí.';

  @override
  String get notificationTimeNow => 'Ahora';

  @override
  String notificationTimeMinutesAgo(int count) {
    return 'Hace $count min';
  }

  @override
  String notificationTimeHoursAgo(int count) {
    return 'Hace $count h';
  }

  @override
  String get notificationTimeYesterday => 'Ayer';

  @override
  String notificationTimeDaysAgo(int count) {
    return 'Hace $count días';
  }

  @override
  String get notificationsFilterAll => 'Todas';

  @override
  String get notificationsFilterEvents => 'Eventos';

  @override
  String get notificationsFilterReminders => 'Recordatorios';

  @override
  String get notificationsFilterUpdates => 'Actualizaciones';

  @override
  String notificationEventCreatedTitle(String eventTitle) {
    return 'Nuevo evento: $eventTitle';
  }

  @override
  String notificationEventCancelledTitle(String eventTitle) {
    return 'Evento cancelado: $eventTitle';
  }

  @override
  String notificationEventEndedTitle(String eventTitle) {
    return 'Evento finalizado: $eventTitle';
  }

  @override
  String get notificationEventEndedMessage => 'El evento ha finalizado.';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsAccountSection => 'Cuenta';

  @override
  String get settingsEditProfile => 'Editar cuenta';

  @override
  String get settingsDarkMode => 'Modo oscuro';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSupportSection => 'Soporte y acerca de';

  @override
  String get settingsHelpSupport => 'Ayuda y soporte';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsComingSoon =>
      'Esta opción estará disponible próximamente.';

  @override
  String get settingsSignOutTitle => '¿Cerrar sesión?';

  @override
  String get settingsSignOutMessage =>
      'Tendrás que iniciar sesión nuevamente para acceder a la aplicación.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsConfirmSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutError => 'No se pudo cerrar la sesión.';

  @override
  String get aboutDescription =>
      'Eventos, orientación y un historial personal de tus actividades.';

  @override
  String get aboutVersion => 'Versión';

  @override
  String get aboutAcademicProject =>
      'Proyecto desarrollado como trabajo final de grado.';

  @override
  String get aboutTeam => 'Desarrollado por';

  @override
  String get aboutDeveloperRole => 'Desarrollador';

  @override
  String get aboutLegalInformation => 'Información legal';

  @override
  String get aboutPrivacyPolicy => 'Política de privacidad';

  @override
  String get aboutTermsOfUse => 'Términos de uso';

  @override
  String get helpIntroTitle => '¿Cómo podemos ayudarte?';

  @override
  String helpIntroDescription(String appName) {
    return 'Encuentra respuestas rápidas sobre las funciones principales de $appName.';
  }

  @override
  String get helpTopicsTitle => 'Temas de ayuda';

  @override
  String get helpPersonalHistoryTitle =>
      '¿Cómo registrar una actividad en mi historial?';

  @override
  String helpPersonalHistoryDescription(String institutionAcronym) {
    return 'Abre los detalles del evento y toca Añadir a mi historial. Este registro es una anotación personal y no acredita asistencia ni sustituye la validación del $institutionAcronym.';
  }

  @override
  String get helpHoursTitle => '¿Cómo se calculan las horas complementarias?';

  @override
  String helpHoursDescription(String institutionAcronym) {
    return 'El contador estima las horas informadas en los eventos añadidos a tu historial. Es una referencia personal y no sustituye los registros oficiales del $institutionAcronym.';
  }

  @override
  String get helpRecordsTitle => '¿Cómo eliminar un registro?';

  @override
  String get helpRecordsDescription =>
      'En la pantalla de horas, abre el panel de registros y desliza una tarjeta hacia un lado. Confirma la eliminación cuando aparezca el aviso.';

  @override
  String get helpNotificationsTitle => '¿Cómo funcionan las notificaciones?';

  @override
  String get helpNotificationsDescription =>
      'Usa los filtros para encontrar actualizaciones, eventos y recordatorios. Toca una notificación para expandir o contraer su contenido.';

  @override
  String get helpAccountTitle => '¿Cómo cambiar el correo o la contraseña?';

  @override
  String get helpAccountDescription =>
      'Abre Configuración, entra en Editar cuenta y elige la información que deseas cambiar. Algunos cambios requieren una confirmación de seguridad.';

  @override
  String get helpContactTitle => '¿Aún necesitas ayuda?';

  @override
  String get helpContactDescription =>
      'Ponte en contacto con el equipo. Toca la dirección para copiarla.';

  @override
  String get helpCopyEmail => 'Copiar correo';

  @override
  String get helpEmailCopied => 'Correo de soporte copiado.';

  @override
  String get accountTitle => 'Cuenta';

  @override
  String get accountProfileSection => 'Perfil';

  @override
  String get accountSecuritySection => 'Seguridad';

  @override
  String get accountChangeName => 'Cambiar nombre';

  @override
  String get accountChangeEmail => 'Cambiar correo electrónico';

  @override
  String get accountChangePassword => 'Cambiar contraseña';

  @override
  String get accountDelete => 'Eliminar cuenta';

  @override
  String get accountCurrentPasswordTitle => 'Confirma tu\ncontraseña actual';

  @override
  String get accountCurrentPassword => 'Contraseña actual';

  @override
  String get accountCurrentPasswordRequired => 'Ingresa tu contraseña actual';

  @override
  String get accountNewPasswordTitle => 'Crea una\nnueva contraseña';

  @override
  String get accountNewPassword => 'Nueva contraseña';

  @override
  String get accountPasswordMustDiffer =>
      'La nueva contraseña debe ser diferente de la actual';

  @override
  String get accountChangePasswordButton => 'Cambiar contraseña';

  @override
  String get accountPasswordChanged => 'Contraseña cambiada correctamente.';

  @override
  String get accountNewEmailTitle => 'Ingresa tu\nnuevo correo';

  @override
  String get accountNewEmail => 'Nuevo correo electrónico';

  @override
  String get accountEmailChangedTitle => '¡Correo confirmado!';

  @override
  String get accountEmailChangedSubtitle =>
      'Todo listo. Tu nuevo correo ya está vinculado a tu cuenta.';

  @override
  String get accountEmailChanged =>
      'Correo electrónico cambiado correctamente.';

  @override
  String get accountNewNameTitle => '¿Cómo debemos\nllamarte?';

  @override
  String get accountNameChanged => 'Nombre cambiado correctamente.';

  @override
  String get commonRetry => 'Intentar de nuevo';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get complementaryHoursTitle => 'Mi\nprogreso';

  @override
  String complementaryHoursInformalNotice(String institutionAcronym) {
    return 'Estimación personal. No acredita asistencia ni sustituye los registros del $institutionAcronym.';
  }

  @override
  String get complementaryHoursLoadError =>
      'No se pudo cargar el contador de horas.';

  @override
  String complementaryHoursProgressSemantics(String completed, String target) {
    return '$completed de $target';
  }

  @override
  String get complementaryHoursRecords => 'Mis registros';

  @override
  String get complementaryHoursRecordsLoadError =>
      'No se pudieron cargar los registros.';

  @override
  String get complementaryHoursRecordsEmpty => 'Aún no hay registros.';

  @override
  String get complementaryHoursNoWorkload => 'Sin carga horaria';

  @override
  String get complementaryHoursDeleteTitle => '¿Eliminar registro?';

  @override
  String complementaryHoursDeleteMessage(String eventName) {
    return '“$eventName” se eliminará de tu contador informal.';
  }

  @override
  String get complementaryHoursDeleteError =>
      'No se pudo eliminar el registro.';

  @override
  String get complementaryHoursDeleted => 'Registro eliminado.';

  @override
  String get navigationManageEvents => 'Gestión';

  @override
  String get eventManagementTitle => 'Gestionar eventos';

  @override
  String eventManagementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos en el catálogo',
      one: '1 evento en el catálogo',
      zero: 'No hay eventos en el catálogo',
    );
    return '$_temp0';
  }

  @override
  String get eventManagementCreate => 'Nuevo evento';

  @override
  String get eventManagementCreateHint => 'Añadir al catálogo';

  @override
  String get eventManagementScheduled => 'Programado';

  @override
  String get eventManagementPublished => 'Publicado';

  @override
  String get eventManagementOngoing => 'En curso';

  @override
  String get eventManagementEnded => 'Finalizado';

  @override
  String get eventManagementView => 'Ver';

  @override
  String get eventManagementEdit => 'Editar';

  @override
  String get eventManagementDelete => 'Eliminar';

  @override
  String get eventManagementDeleteTitle => '¿Eliminar evento?';

  @override
  String eventManagementDeleteMessage(String eventName) {
    return '“$eventName” se eliminará del catálogo.';
  }

  @override
  String get eventManagementDeleted => 'Evento eliminado.';

  @override
  String get eventManagementDeleteError => 'No se pudo eliminar el evento.';

  @override
  String get eventManagementCancelTitle => '¿Cancelar evento?';

  @override
  String eventManagementCancelMessage(String eventName) {
    return '“$eventName” ya está visible en la aplicación. Al cancelarlo, se eliminará del catálogo y todos recibirán una notificación.';
  }

  @override
  String get eventManagementCancelReasonLabel => 'Motivo de la cancelación';

  @override
  String get eventManagementCancelReasonHint =>
      'Explica claramente por qué el evento no se realizará.';

  @override
  String get eventManagementInvalidCancelReason =>
      'Introduce un motivo de al menos 10 caracteres.';

  @override
  String get eventManagementConfirmCancellation => 'Cancelar evento';

  @override
  String get eventManagementCampusNotification =>
      'NOTIFICACIÓN PARA TODO EL CAMPUS';

  @override
  String eventManagementCancellationNotificationTitle(String eventName) {
    return 'Evento cancelado: $eventName';
  }

  @override
  String get eventManagementCancelled =>
      'Evento cancelado y notificación enviada.';

  @override
  String get eventManagementCancelError => 'No se pudo cancelar el evento.';

  @override
  String get eventManagementEnd => 'Finalizar';

  @override
  String get eventManagementEndTitle => '¿Finalizar evento?';

  @override
  String eventManagementEndMessage(String eventName) {
    return '“$eventName” se eliminará del catálogo.';
  }

  @override
  String get eventManagementEndedMessage => 'Evento finalizado.';

  @override
  String get eventManagementEndError => 'No se pudo finalizar el evento.';

  @override
  String get eventManagementLoadError => 'No se pudieron cargar los eventos.';

  @override
  String get eventManagementEmptyTitle => 'Catálogo vacío';

  @override
  String get eventManagementEmptyMessage =>
      'Crea el primer evento para comenzar.';

  @override
  String get eventManagementCreateComingSoon =>
      'La creación de eventos se añadirá en la próxima etapa.';

  @override
  String get eventManagementUnauthorized =>
      'Tu cuenta no tiene permiso para gestionar eventos.';

  @override
  String eventEditorStep(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String editorStep(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String get eventEditorIdentityTitle => '¿Cuál es el evento?';

  @override
  String get eventEditorIdentitySubtitle =>
      'Comienza con el nombre y la categoría que mejor identifican la actividad.';

  @override
  String get eventEditorTitle => 'Título del evento';

  @override
  String get eventEditorCategory => 'Categoría';

  @override
  String get eventEditorDateTitle => '¿Cuándo será?';

  @override
  String get eventEditorDateSubtitle =>
      'Define la fecha y hora de inicio del evento.';

  @override
  String get eventEditorDate => 'Fecha';

  @override
  String get eventEditorTime => 'Hora';

  @override
  String get eventEditorChooseDate => 'Elegir fecha';

  @override
  String get eventEditorChooseTime => 'Elegir hora';

  @override
  String get eventEditorEndTitle => '¿Cómo termina el evento?';

  @override
  String get eventEditorEndSubtitle =>
      'Elige una hora de finalización o finaliza el evento manualmente cuando termine.';

  @override
  String get eventEditorAutomaticEnd => 'Hora de fin definida';

  @override
  String get eventEditorAutomaticEndDescription =>
      'El evento finaliza automáticamente en la fecha y hora seleccionadas.';

  @override
  String get eventEditorManualEnd => 'Finalización manual';

  @override
  String get eventEditorManualEndDescription =>
      'Úsala cuando la duración sea incierta. Un administrador deberá finalizar el evento.';

  @override
  String get eventEditorEndDate => 'Fecha de finalización';

  @override
  String get eventEditorEndTime => 'Hora de finalización';

  @override
  String get eventEditorLocationTitle => '¿Dónde será?';

  @override
  String get eventEditorLocationSubtitle =>
      'La ubicación es opcional y se puede añadir o cambiar después.';

  @override
  String get eventEditorLocation => 'Ubicación (opcional)';

  @override
  String get eventEditorDescriptionTitle => 'Describe el evento';

  @override
  String get eventEditorDescriptionSubtitle =>
      'Presenta el evento y, si existe, incluye una página oficial o un formulario de inscripción.';

  @override
  String get eventEditorDescription => 'Descripción';

  @override
  String get eventEditorExternalLink => 'Enlace externo (opcional)';

  @override
  String get eventEditorExternalLinkHint => 'ejemplo.com/registro';

  @override
  String get eventEditorHoursTitle => 'Carga horaria';

  @override
  String get eventEditorHoursSubtitle =>
      'Inclúyela solo cuando la actividad ofrezca horas complementarias.';

  @override
  String get eventEditorHasHours => 'Ofrece horas complementarias';

  @override
  String get eventEditorHours => 'Horas';

  @override
  String get eventEditorMinutes => 'Minutos';

  @override
  String get eventEditorImageTitle => 'Elige la imagen';

  @override
  String get eventEditorImageSubtitle =>
      'Revisa el recorte real en los dos formatos del catálogo.';

  @override
  String get eventEditorChooseImage => 'Seleccionar imagen';

  @override
  String get eventEditorChangeImage => 'Cambiar imagen';

  @override
  String get eventEditorImageGallery => 'Galería de la institución';

  @override
  String get eventEditorUseDeviceImage => 'Usar imagen del dispositivo';

  @override
  String get eventEditorExpandImage => 'Ampliar imagen';

  @override
  String get eventEditorExpandGallery => 'Mostrar todas las imágenes';

  @override
  String get eventEditorCollapseGallery => 'Contraer galería';

  @override
  String get eventEditorImageSelected => 'Imagen seleccionada';

  @override
  String eventEditorGalleryImage(int number) {
    return 'Imagen $number';
  }

  @override
  String get eventEditorReview => 'Revisar evento';

  @override
  String get eventEditorReviewTitle => 'Revisa y publica';

  @override
  String get eventEditorReviewSubtitle =>
      'Comprueba los datos y elige cuándo aparecerá el evento en la aplicación.';

  @override
  String get eventEditorPublishNow => 'Publicar ahora';

  @override
  String get eventEditorSchedule => 'Programar';

  @override
  String get eventEditorPublicationDate => 'Fecha de publicación';

  @override
  String get eventEditorPublicationTime => 'Hora de publicación';

  @override
  String get eventEditorPublish => 'Publicar evento';

  @override
  String get eventEditorScheduleEvent => 'Programar evento';

  @override
  String get eventEditorDateAndTime => 'Fecha y hora';

  @override
  String get eventEditorEnd => 'Finalización';

  @override
  String get eventEditorManualEndReview =>
      'Finalización manual por un administrador';

  @override
  String get eventEditorComplementaryHours => 'Carga horaria';

  @override
  String get eventEditorNotOffered => 'No ofrece';

  @override
  String eventEditorHoursAndMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get eventEditorInvalidTitle =>
      'Escribe un título de al menos 3 caracteres.';

  @override
  String get eventEditorInvalidCategory => 'Indica la categoría del evento.';

  @override
  String get eventEditorMissingDate => 'Elige la fecha y hora del evento.';

  @override
  String get eventEditorFutureDate =>
      'El evento debe comenzar en una fecha futura.';

  @override
  String get eventEditorMissingEndMode => 'Elige cómo finalizará el evento.';

  @override
  String get eventEditorEndAfterStart =>
      'El evento debe finalizar después de comenzar.';

  @override
  String get eventEditorInvalidLocation =>
      'Indica una ubicación de hasta 160 caracteres.';

  @override
  String get eventEditorInvalidDescription =>
      'Escribe una descripción de al menos 10 caracteres.';

  @override
  String get eventEditorInvalidExternalLink =>
      'Introduce un enlace válido, como ejemplo.com/registro.';

  @override
  String get eventEditorInvalidHours =>
      'Indica una carga horaria mayor que cero.';

  @override
  String get eventEditorMissingImage => 'Selecciona una imagen para el evento.';

  @override
  String get eventEditorImageError =>
      'No se pudo abrir la imagen seleccionada.';

  @override
  String get eventEditorFuturePublication =>
      'La publicación programada debe estar en el futuro.';

  @override
  String get eventEditorPublishBeforeEvent =>
      'La publicación debe ocurrir antes del inicio del evento.';

  @override
  String get eventEditorRequiredFields =>
      'Revisa los campos obligatorios del evento.';

  @override
  String get eventEditorCreateError => 'No se pudo crear el evento.';

  @override
  String get eventEditorCreated => 'Evento creado correctamente.';

  @override
  String get eventEditorDiscardTitle => '¿Descartar evento?';

  @override
  String get eventEditorDiscardMessage =>
      'La información ingresada se perderá.';

  @override
  String get eventEditorKeepEditing => 'Seguir editando';

  @override
  String get eventEditorDiscard => 'Descartar';

  @override
  String get eventEditorNotInformed => 'No informado';

  @override
  String get eventEditorBackToReview => 'Volver a la revisión';

  @override
  String get eventEditorEditReviewTitle => 'Editar evento';

  @override
  String get eventEditorEditReviewSubtitle =>
      'Revisa el evento y cambia solo lo necesario.';

  @override
  String get eventEditorSaveChanges => 'Guardar cambios';

  @override
  String get eventEditorUpdated => 'Evento actualizado correctamente.';

  @override
  String get eventEditorUpdateError => 'No se pudo actualizar el evento.';

  @override
  String get eventEditorLoadError =>
      'No se pudieron cargar los datos del evento.';

  @override
  String get eventEditorTryAgain => 'Intentar de nuevo';

  @override
  String get eventEditorDiscardChangesTitle => '¿Descartar cambios?';

  @override
  String get eventEditorDiscardChangesMessage =>
      'Los cambios realizados en este evento se perderán.';

  @override
  String get mapInteractionHint => 'Arrastra para explorar y toca un bloque';

  @override
  String get mapResetView => 'Volver al ángulo cero';

  @override
  String get mapInteriorComingSoon => 'Interior próximamente';

  @override
  String get mapSearch => 'Buscar en el mapa';

  @override
  String get mapSearchComingSoon =>
      'La búsqueda de aulas y bloques estará disponible próximamente.';

  @override
  String get mapRotate => 'Arrastra para girar el mapa';

  @override
  String get settingsMapGraphics => 'Gráficos del mapa';

  @override
  String get settingsMapGraphicsLight => 'Ligero';

  @override
  String get settingsMapGraphicsComplete => 'Completo';
}
