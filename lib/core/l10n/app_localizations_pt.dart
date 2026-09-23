// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get userManagementTitle => 'Usuários';

  @override
  String get userManagementEmpty => 'Nenhum usuário disponível';

  @override
  String get userManagementSearchHint => 'Buscar por nome ou e-mail';

  @override
  String get userManagementSortNameAscending => 'Nome de A a Z';

  @override
  String get userManagementSortNameDescending => 'Nome de Z a A';

  @override
  String get userManagementSortHoursDescending => 'Mais horas primeiro';

  @override
  String get userManagementSortHoursAscending => 'Menos horas primeiro';

  @override
  String get userManagementFilterAll => 'Todos';

  @override
  String get userManagementFilterStudents => 'Usuários';

  @override
  String get userManagementFilterManagers => 'Gerenciadores de eventos';

  @override
  String get userManagementRoleStudent => 'Usuário';

  @override
  String get userManagementRoleEventManager => 'Gerenciador de eventos';

  @override
  String get userManagementTotalHours => 'horas totais';

  @override
  String get userManagementNoResults => 'Nenhum usuário encontrado';

  @override
  String get userManagementLoadError => 'Não foi possível carregar os usuários';

  @override
  String get userManagementUnauthorized =>
      'Você não tem permissão para gerenciar usuários';

  @override
  String get userDetailsTitle => 'Detalhes do usuário';

  @override
  String get userDetailsHoursProgress => 'Progresso de horas';

  @override
  String get userDetailsRecordsTitle => 'Registros';

  @override
  String get userDetailsRecordsEmpty => 'Nenhum registro encontrado';

  @override
  String get userDetailsPromote => 'Promover';

  @override
  String get userDetailsDemote => 'Rebaixar';

  @override
  String get userDetailsPromoteTitle => 'Promover usuário?';

  @override
  String userDetailsPromoteMessage(String name) {
    return '$name poderá criar e gerenciar eventos. Deseja continuar?';
  }

  @override
  String get userDetailsDemoteTitle => 'Rebaixar usuário?';

  @override
  String userDetailsDemoteMessage(String name) {
    return '$name perderá as permissões de gerenciamento de eventos. Deseja continuar?';
  }

  @override
  String get userDetailsRoleUpdated => 'Cargo atualizado com sucesso.';

  @override
  String get userDetailsLoadError =>
      'Não foi possível carregar os detalhes do usuário.';

  @override
  String get userDetailsNotFound => 'Usuário não encontrado.';

  @override
  String get userDetailsInvalidUser => 'Usuário inválido.';

  @override
  String get userDetailsInvalidRole => 'Cargo inválido.';

  @override
  String get userDetailsRoleUnauthorized =>
      'Você não tem permissão para alterar cargos.';

  @override
  String get userDetailsRoleChangeError => 'Não foi possível alterar o cargo.';

  @override
  String get welcomeTo => 'Bem-vindo ao';

  @override
  String get whereIf => 'Where IF';

  @override
  String get continueButton => 'Continuar';

  @override
  String get joinThe => 'Junte-se ao';

  @override
  String get team => 'Time';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Senha';

  @override
  String get forgot => 'Esqueceu sua senha?';

  @override
  String get loginButton => 'Entrar';

  @override
  String get dontHaveAccount => 'Não tem uma conta?';

  @override
  String get signupButton => 'Cadastrar-se';

  @override
  String get or => 'ou';

  @override
  String get googleButton => 'Entrar com o Google';

  @override
  String get whatYour => 'Qual é o seu';

  @override
  String get createPassword => 'Crie uma';

  @override
  String get registerNameTitle => 'Como você se\nchama?';

  @override
  String get firstName => 'Nome';

  @override
  String get lastName => 'Sobrenome';

  @override
  String get invalidFirstName => 'Informe um nome com pelo menos 2 caracteres.';

  @override
  String get invalidLastName =>
      'Informe um sobrenome com pelo menos 2 caracteres.';

  @override
  String get accountInvalidFullName => 'Informe seu nome e sobrenome.';

  @override
  String get fieldsRequired => 'Por favor, preencha os campos';

  @override
  String get invalidFields => 'E-mail ou senha incorretos';

  @override
  String get authEmailAlreadyInUse =>
      'Este e-mail já está vinculado a uma conta.';

  @override
  String get authWeakPassword =>
      'A senha não atende aos requisitos de segurança.';

  @override
  String get authNetworkError =>
      'Sem conexão. Verifique sua internet e tente novamente.';

  @override
  String get authTooManyRequests =>
      'Muitas tentativas. Aguarde um pouco e tente novamente.';

  @override
  String get authAccountDisabled => 'Esta conta está desativada.';

  @override
  String get authUnexpectedError => 'Não foi possível concluir a autenticação.';

  @override
  String get authBackendUnavailable =>
      'A autenticação ainda não está conectada ao servidor.';

  @override
  String get authUserNotFound => 'Conta não encontrada.';

  @override
  String get authGoogleCanceled => 'Login com Google cancelado.';

  @override
  String get emailRequired => 'Informe um email';

  @override
  String get invalidEmail => 'E-mail incorreto';

  @override
  String get passwordRequired => 'Informe uma senha';

  @override
  String get passwordMinLength => 'A senha deve ter pelo menos 8 caracteres';

  @override
  String get passwordRequireLowercaseAndUppercase =>
      'Letras maiúsculas e minúsculas';

  @override
  String get passwordRequireNumber => 'Inclua pelo menos um número';

  @override
  String get passwordRequireSymbol => 'Inclua pelo menos um símbolo';

  @override
  String get passwordStrengthEmpty => 'Digite uma senha';

  @override
  String get passwordStrengthVeryWeak => 'Muito fraca';

  @override
  String get passwordStrengthWeak => 'Fraca';

  @override
  String get passwordStrengthFair => 'Razoável';

  @override
  String get passwordStrengthGood => 'Boa';

  @override
  String get passwordStrengthExcellent => 'Excelente';

  @override
  String get checkEmailTitle => 'Verifique seu e-mail';

  @override
  String get checkEmailSentTo => 'Enviamos um link para:';

  @override
  String get checkEmailDescription => 'Clique no link para continuar.';

  @override
  String get checkEmailResend => 'Reenviar link';

  @override
  String get checkEmailLinkResent => 'Enviamos um novo link para seu e-mail.';

  @override
  String get emailVerificationExpired =>
      'Este link expirou. Solicite um novo para continuar.';

  @override
  String get emailVerificationUnexpectedError =>
      'Não foi possível verificar o e-mail agora.';

  @override
  String get emailVerificationResendFailed =>
      'Não foi possível reenviar o link.';

  @override
  String get emailConfirmedTitle => 'Email confirmado!';

  @override
  String get emailConfirmedSubtitle =>
      'Tudo beleza. Agora vamos continuar para criar sua nova senha.';

  @override
  String get accountConfirmedSubtitle =>
      'Sua conta foi confirmada. Agora você já pode continuar.';

  @override
  String get passwordResetTitle => 'Crie sua\nnova senha';

  @override
  String get passwordResetConfirmation => 'Confirme a nova senha';

  @override
  String get passwordResetButton => 'Redefinir senha';

  @override
  String get passwordResetMismatch => 'As senhas não coincidem.';

  @override
  String get passwordResetInvalidLink =>
      'Este link de redefinição é inválido ou já foi utilizado.';

  @override
  String get passwordResetFailed => 'Não foi possível redefinir sua senha.';

  @override
  String get passwordResetChangedTitle => 'Senha redefinida!';

  @override
  String get passwordResetChangedSubtitle =>
      'Tudo certo. Agora você já pode entrar usando sua nova senha.';

  @override
  String get eventsTitle => 'Eventos';

  @override
  String get navigationMap => 'Mapa';

  @override
  String get navigationEvents => 'Eventos';

  @override
  String get navigationNotifications => 'Notificações';

  @override
  String get navigationHours => 'Horas';

  @override
  String get mapLoading => 'Carregando mapa...';

  @override
  String get mapComingSoon => 'Mapa em breve';

  @override
  String get featuredEvents => 'Em destaque';

  @override
  String get futureEvents => 'Eventos futuros';

  @override
  String get addToPersonalHistory => 'Adicionar ao meu histórico';

  @override
  String get personalHistoryAdded => 'Salvo no meu histórico';

  @override
  String get personalRecordUpdating => 'Atualizando meu histórico...';

  @override
  String get personalRecordNotice =>
      'Registro pessoal. Não comprova presença nem gera horas oficiais.';

  @override
  String get viewOnMap => 'Ver no mapa';

  @override
  String get accessLink => 'Acessar link';

  @override
  String get eventExternalLinkOpenError => 'Não foi possível abrir este link.';

  @override
  String get eventsLoadError => 'Não foi possível carregar os eventos.';

  @override
  String get eventsEmpty => 'Nenhum evento.';

  @override
  String get eventDetailsUnavailable => 'Evento indisponível.';

  @override
  String get eventEditorImageUploadUnavailable =>
      'Upload de imagem do dispositivo ainda não está disponível. Escolha uma imagem do catálogo.';

  @override
  String get notificationEvent => 'Evento';

  @override
  String get notificationReminder => 'Lembrete';

  @override
  String get notificationUpdate => 'Atualização';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get notificationManagementCreate => 'Novo aviso';

  @override
  String get notificationManagementCreateHint =>
      'Enviar uma atualização para todos';

  @override
  String get notificationEditorContentTitle => 'Escreva o\naviso';

  @override
  String get notificationEditorContentSubtitle =>
      'Use um título claro e inclua as informações que todos precisam saber.';

  @override
  String get notificationEditorTitleLabel => 'Título';

  @override
  String get notificationEditorDescriptionLabel => 'Descrição';

  @override
  String get notificationEditorLinkTitle => 'Adicione um\nlink útil';

  @override
  String get notificationEditorLinkSubtitle =>
      'Opcional. Inclua uma página para saber mais ou realizar alguma ação.';

  @override
  String get notificationEditorLinkLabel => 'Link externo';

  @override
  String get notificationEditorLinkHint => 'exemplo.edu.br/pagina';

  @override
  String get notificationEditorReview => 'Revisar aviso';

  @override
  String get notificationEditorReviewTitle => 'Revise antes\nde publicar';

  @override
  String get notificationEditorReviewSubtitle =>
      'Esta atualização será publicada imediatamente para todos deste campus.';

  @override
  String get notificationEditorPublish => 'Publicar aviso';

  @override
  String get notificationEditorAudience => 'Público';

  @override
  String get notificationEditorAudienceAll => 'Todos os usuários deste campus';

  @override
  String get notificationEditorNotInformed => 'Não informado';

  @override
  String get notificationEditorInvalidTitle =>
      'Informe um título entre 3 e 80 caracteres.';

  @override
  String get notificationEditorInvalidDescription =>
      'Informe uma descrição entre 10 e 1000 caracteres.';

  @override
  String get notificationEditorInvalidExternalLink =>
      'Informe um link HTTP ou HTTPS válido.';

  @override
  String get notificationEditorRequiredFields =>
      'Preencha os campos obrigatórios do aviso.';

  @override
  String get notificationEditorPublishError =>
      'Não foi possível publicar o aviso.';

  @override
  String get notificationManagementUnauthorized =>
      'Você não tem permissão para publicar avisos.';

  @override
  String get notificationEditorDiscardTitle => 'Descartar aviso?';

  @override
  String get notificationEditorDiscardMessage =>
      'As informações preenchidas até agora serão perdidas.';

  @override
  String get notificationEditorKeepEditing => 'Continuar editando';

  @override
  String get notificationEditorDiscard => 'Descartar';

  @override
  String get notificationEditorBackToReview => 'Voltar para revisão';

  @override
  String get notificationOpenLink => 'Acessar link';

  @override
  String get notificationOpenLinkError => 'Não foi possível abrir o link.';

  @override
  String get notificationsLoadErrorTitle =>
      'Não foi possível carregar as notificações.';

  @override
  String get notificationsEmptyTitle => 'Nada por aqui ainda.';

  @override
  String get notificationsLoadErrorMessage =>
      'Verifique sua conexão e tente novamente.';

  @override
  String get notificationsEmptyMessage =>
      'Quando algo importante acontecer, você verá aqui.';

  @override
  String get notificationTimeNow => 'Agora';

  @override
  String notificationTimeMinutesAgo(int count) {
    return 'Há $count min';
  }

  @override
  String notificationTimeHoursAgo(int count) {
    return 'Há $count h';
  }

  @override
  String get notificationTimeYesterday => 'Ontem';

  @override
  String notificationTimeDaysAgo(int count) {
    return 'Há $count dias';
  }

  @override
  String get notificationsFilterAll => 'Todas';

  @override
  String get notificationsFilterEvents => 'Eventos';

  @override
  String get notificationsFilterReminders => 'Lembretes';

  @override
  String get notificationsFilterUpdates => 'Atualizações';

  @override
  String notificationEventCreatedTitle(String eventTitle) {
    return 'Novo evento: $eventTitle';
  }

  @override
  String notificationEventCancelledTitle(String eventTitle) {
    return 'Evento cancelado: $eventTitle';
  }

  @override
  String notificationEventEndedTitle(String eventTitle) {
    return 'Evento encerrado: $eventTitle';
  }

  @override
  String get notificationEventEndedMessage => 'O evento chegou ao fim.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsAccountSection => 'Conta';

  @override
  String get settingsEditProfile => 'Editar conta';

  @override
  String get settingsDarkMode => 'Modo escuro';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsSignOut => 'Sair';

  @override
  String get settingsSupportSection => 'Suporte e sobre';

  @override
  String get settingsHelpSupport => 'Ajuda e suporte';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsComingSoon => 'Essa opção estará disponível em breve.';

  @override
  String get settingsSignOutTitle => 'Sair da conta?';

  @override
  String get settingsSignOutMessage =>
      'Você precisará entrar novamente para acessar o aplicativo.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsConfirmSignOut => 'Sair';

  @override
  String get settingsSignOutError => 'Não foi possível encerrar a sessão.';

  @override
  String get aboutDescription =>
      'Eventos, localização e um histórico pessoal das suas atividades.';

  @override
  String get aboutVersion => 'Versão';

  @override
  String get aboutAcademicProject =>
      'Projeto desenvolvido como Trabalho de Conclusão de Curso.';

  @override
  String get aboutTeam => 'Desenvolvido por';

  @override
  String get aboutDeveloperRole => 'Desenvolvedor';

  @override
  String get aboutLegalInformation => 'Informações legais';

  @override
  String get aboutPrivacyPolicy => 'Política de privacidade';

  @override
  String get aboutTermsOfUse => 'Termos de uso';

  @override
  String get helpIntroTitle => 'Como podemos ajudar?';

  @override
  String helpIntroDescription(String appName) {
    return 'Encontre respostas rápidas sobre os principais recursos do $appName.';
  }

  @override
  String get helpTopicsTitle => 'Tópicos de ajuda';

  @override
  String get helpPersonalHistoryTitle =>
      'Como registrar uma atividade no meu histórico?';

  @override
  String helpPersonalHistoryDescription(String institutionAcronym) {
    return 'Abra os detalhes do evento e toque em Adicionar ao meu histórico. Esse registro é uma anotação pessoal e não comprova presença nem substitui a validação do $institutionAcronym.';
  }

  @override
  String get helpHoursTitle => 'Como são calculadas as horas?';

  @override
  String helpHoursDescription(String institutionAcronym) {
    return 'O contador estima as cargas horárias informadas nos eventos adicionados ao seu histórico. Ele é uma referência pessoal e não substitui o registro oficial do $institutionAcronym.';
  }

  @override
  String get helpRecordsTitle => 'Como excluir um registro?';

  @override
  String get helpRecordsDescription =>
      'Na tela de horas, abra a gaveta de registros e arraste um cartão para o lado. Confirme a exclusão quando o aviso aparecer.';

  @override
  String get helpNotificationsTitle => 'Como usar as notificações?';

  @override
  String get helpNotificationsDescription =>
      'Use os filtros para encontrar atualizações, eventos e lembretes. Toque em uma notificação para expandir ou recolher seu conteúdo.';

  @override
  String get helpAccountTitle => 'Como alterar e-mail ou senha?';

  @override
  String get helpAccountDescription =>
      'Acesse Configurações, entre em Editar conta e escolha a informação que deseja alterar. Algumas mudanças exigem confirmação de segurança.';

  @override
  String get helpContactTitle => 'Ainda precisa de ajuda?';

  @override
  String get helpContactDescription =>
      'Entre em contato com a equipe. Toque no endereço abaixo para copiá-lo.';

  @override
  String get helpCopyEmail => 'Copiar e-mail';

  @override
  String get helpEmailCopied => 'E-mail de suporte copiado.';

  @override
  String get accountTitle => 'Conta';

  @override
  String get accountProfileSection => 'Perfil';

  @override
  String get accountSecuritySection => 'Segurança';

  @override
  String get accountChangeName => 'Alterar nome';

  @override
  String get accountChangeEmail => 'Alterar e-mail';

  @override
  String get accountChangePassword => 'Alterar senha';

  @override
  String get accountDelete => 'Excluir conta';

  @override
  String get accountCurrentPasswordTitle => 'Confirme sua\nsenha atual';

  @override
  String get accountCurrentPassword => 'Senha atual';

  @override
  String get accountCurrentPasswordRequired => 'Informe sua senha atual';

  @override
  String get accountNewPasswordTitle => 'Crie uma\nnova senha';

  @override
  String get accountNewPassword => 'Nova senha';

  @override
  String get accountPasswordMustDiffer =>
      'A nova senha deve ser diferente da atual';

  @override
  String get accountChangePasswordButton => 'Alterar senha';

  @override
  String get accountPasswordChanged => 'Senha alterada com sucesso.';

  @override
  String get accountNewEmailTitle => 'Digite seu\nnovo e-mail';

  @override
  String get accountNewEmail => 'Novo e-mail';

  @override
  String get accountEmailChangedTitle => 'E-mail confirmado!';

  @override
  String get accountEmailChangedSubtitle =>
      'Tudo certo. Seu novo e-mail já está vinculado à conta.';

  @override
  String get accountEmailChanged => 'E-mail alterado com sucesso.';

  @override
  String get accountNewNameTitle => 'Como devemos\nchamar você?';

  @override
  String get accountNameChanged => 'Nome alterado com sucesso.';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get complementaryHoursTitle => 'Meu\nprogresso';

  @override
  String complementaryHoursInformalNotice(String institutionAcronym) {
    return 'Estimativa pessoal. Não comprova presença nem substitui os registros do $institutionAcronym.';
  }

  @override
  String get complementaryHoursLoadError =>
      'Não foi possível carregar o contador.';

  @override
  String complementaryHoursProgressSemantics(String completed, String target) {
    return '$completed de $target';
  }

  @override
  String get complementaryHoursRecords => 'Meus registros';

  @override
  String get complementaryHoursRecordsLoadError =>
      'Não foi possível carregar os registros.';

  @override
  String get complementaryHoursRecordsEmpty => 'Nenhum registro por enquanto.';

  @override
  String get complementaryHoursNoWorkload => 'Sem carga horária';

  @override
  String get complementaryHoursDeleteTitle => 'Excluir registro?';

  @override
  String complementaryHoursDeleteMessage(String eventName) {
    return '“$eventName” será removido do seu contador informal.';
  }

  @override
  String get complementaryHoursDeleteError =>
      'Não foi possível excluir o registro.';

  @override
  String get complementaryHoursDeleted => 'Registro excluído.';

  @override
  String get navigationManageEvents => 'Gestão';

  @override
  String get eventManagementTitle => 'Gerenciar eventos';

  @override
  String eventManagementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos no catálogo',
      one: '1 evento no catálogo',
      zero: 'Nenhum evento no catálogo',
    );
    return '$_temp0';
  }

  @override
  String get eventManagementCreate => 'Novo evento';

  @override
  String get eventManagementCreateHint => 'Adicionar ao catálogo';

  @override
  String get eventManagementScheduled => 'Agendado';

  @override
  String get eventManagementPublished => 'Publicado';

  @override
  String get eventManagementOngoing => 'Em andamento';

  @override
  String get eventManagementEnded => 'Encerrado';

  @override
  String get eventManagementView => 'Ver';

  @override
  String get eventManagementEdit => 'Editar';

  @override
  String get eventManagementDelete => 'Excluir';

  @override
  String get eventManagementDeleteTitle => 'Excluir evento?';

  @override
  String eventManagementDeleteMessage(String eventName) {
    return '“$eventName” será removido do catálogo.';
  }

  @override
  String get eventManagementDeleted => 'Evento excluído.';

  @override
  String get eventManagementDeleteError => 'Não foi possível excluir o evento.';

  @override
  String get eventManagementCancelTitle => 'Cancelar evento?';

  @override
  String eventManagementCancelMessage(String eventName) {
    return '“$eventName” já está visível no app. Ao cancelar, ele sairá do catálogo e todos receberão uma notificação.';
  }

  @override
  String get eventManagementCancelReasonLabel => 'Motivo do cancelamento';

  @override
  String get eventManagementCancelReasonHint =>
      'Explique de forma clara por que o evento não acontecerá.';

  @override
  String get eventManagementInvalidCancelReason =>
      'Informe um motivo com pelo menos 10 caracteres.';

  @override
  String get eventManagementConfirmCancellation => 'Cancelar evento';

  @override
  String get eventManagementCampusNotification =>
      'NOTIFICAÇÃO PARA TODO O CAMPUS';

  @override
  String eventManagementCancellationNotificationTitle(String eventName) {
    return 'Evento cancelado: $eventName';
  }

  @override
  String get eventManagementCancelled =>
      'Evento cancelado e notificação enviada.';

  @override
  String get eventManagementCancelError =>
      'Não foi possível cancelar o evento.';

  @override
  String get eventManagementEnd => 'Encerrar';

  @override
  String get eventManagementEndTitle => 'Encerrar evento?';

  @override
  String eventManagementEndMessage(String eventName) {
    return '“$eventName” será removido do catálogo.';
  }

  @override
  String get eventManagementEndedMessage => 'Evento encerrado.';

  @override
  String get eventManagementEndError => 'Não foi possível encerrar o evento.';

  @override
  String get eventManagementLoadError =>
      'Não foi possível carregar os eventos.';

  @override
  String get eventManagementEmptyTitle => 'Catálogo vazio';

  @override
  String get eventManagementEmptyMessage =>
      'Crie o primeiro evento para começar.';

  @override
  String get eventManagementCreateComingSoon =>
      'A criação de eventos será adicionada na próxima etapa.';

  @override
  String get eventManagementUnauthorized =>
      'Sua conta não tem permissão para gerenciar eventos.';

  @override
  String eventEditorStep(int current, int total) {
    return 'Etapa $current de $total';
  }

  @override
  String editorStep(int current, int total) {
    return 'Etapa $current de $total';
  }

  @override
  String get eventEditorIdentityTitle => 'Qual é o evento?';

  @override
  String get eventEditorIdentitySubtitle =>
      'Informe o nome e a categoria que melhor representam a atividade.';

  @override
  String get eventEditorTitle => 'Título do evento';

  @override
  String get eventEditorCategory => 'Categoria';

  @override
  String get eventEditorDateTitle => 'Quando vai acontecer?';

  @override
  String get eventEditorDateSubtitle =>
      'Escolha a data e o horário em que o evento começará.';

  @override
  String get eventEditorDate => 'Data';

  @override
  String get eventEditorTime => 'Horário';

  @override
  String get eventEditorChooseDate => 'Escolher data';

  @override
  String get eventEditorChooseTime => 'Escolher horário';

  @override
  String get eventEditorEndTitle => 'Como o evento termina?';

  @override
  String get eventEditorEndSubtitle =>
      'Escolha um horário de término ou encerre o evento manualmente quando ele terminar.';

  @override
  String get eventEditorAutomaticEnd => 'Horário definido';

  @override
  String get eventEditorAutomaticEndDescription =>
      'O evento será encerrado automaticamente no dia e horário informados.';

  @override
  String get eventEditorManualEnd => 'Encerramento manual';

  @override
  String get eventEditorManualEndDescription =>
      'Use quando não houver duração previsível. Um administrador deverá encerrar o evento.';

  @override
  String get eventEditorEndDate => 'Data de término';

  @override
  String get eventEditorEndTime => 'Horário de término';

  @override
  String get eventEditorLocationTitle => 'Onde será?';

  @override
  String get eventEditorLocationSubtitle =>
      'Informe onde o evento será realizado, se houver um local definido.';

  @override
  String get eventEditorLocation => 'Localização (opcional)';

  @override
  String get eventEditorDescriptionTitle => 'Conte sobre o evento';

  @override
  String get eventEditorDescriptionSubtitle =>
      'Apresente o evento e, se houver, inclua uma página oficial ou formulário de inscrição.';

  @override
  String get eventEditorDescription => 'Descrição';

  @override
  String get eventEditorExternalLink => 'Link externo (opcional)';

  @override
  String get eventEditorExternalLinkHint => 'exemplo.com/inscricao';

  @override
  String get eventEditorHoursTitle => 'Carga horária';

  @override
  String get eventEditorHoursSubtitle =>
      'Informe a carga horária complementar oferecida pela atividade, se houver.';

  @override
  String get eventEditorHasHours => 'Oferece horas complementares';

  @override
  String get eventEditorHours => 'Horas';

  @override
  String get eventEditorMinutes => 'Minutos';

  @override
  String get eventEditorImageTitle => 'Escolha a imagem';

  @override
  String get eventEditorImageSubtitle =>
      'Escolha uma imagem e confira como ela aparecerá no catálogo.';

  @override
  String get eventEditorChooseImage => 'Selecionar imagem';

  @override
  String get eventEditorChangeImage => 'Trocar imagem';

  @override
  String get eventEditorImageGallery => 'Galeria da instituição';

  @override
  String get eventEditorUseDeviceImage => 'Usar imagem do dispositivo';

  @override
  String get eventEditorExpandImage => 'Ampliar imagem';

  @override
  String get eventEditorExpandGallery => 'Mostrar todas as imagens';

  @override
  String get eventEditorCollapseGallery => 'Recolher galeria';

  @override
  String get eventEditorImageSelected => 'Imagem selecionada';

  @override
  String eventEditorGalleryImage(int number) {
    return 'Imagem $number';
  }

  @override
  String get eventEditorReview => 'Revisar evento';

  @override
  String get eventEditorReviewTitle => 'Revise e publique';

  @override
  String get eventEditorReviewSubtitle =>
      'Confira todas as informações e defina quando o evento será publicado.';

  @override
  String get eventEditorPublishNow => 'Publicar agora';

  @override
  String get eventEditorSchedule => 'Agendar';

  @override
  String get eventEditorPublicationDate => 'Data da publicação';

  @override
  String get eventEditorPublicationTime => 'Horário da publicação';

  @override
  String get eventEditorPublish => 'Publicar evento';

  @override
  String get eventEditorScheduleEvent => 'Agendar evento';

  @override
  String get eventEditorDateAndTime => 'Data e horário';

  @override
  String get eventEditorEnd => 'Término';

  @override
  String get eventEditorManualEndReview =>
      'Encerramento manual pelo administrador';

  @override
  String get eventEditorComplementaryHours => 'Carga horária';

  @override
  String get eventEditorNotOffered => 'Não oferece';

  @override
  String eventEditorHoursAndMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get eventEditorInvalidTitle =>
      'Digite um título com pelo menos 3 caracteres.';

  @override
  String get eventEditorInvalidCategory => 'Informe a categoria do evento.';

  @override
  String get eventEditorMissingDate => 'Escolha a data e o horário do evento.';

  @override
  String get eventEditorFutureDate =>
      'O evento precisa começar em uma data futura.';

  @override
  String get eventEditorMissingEndMode =>
      'Escolha como o evento será encerrado.';

  @override
  String get eventEditorEndAfterStart =>
      'O término precisa acontecer depois do início do evento.';

  @override
  String get eventEditorInvalidLocation =>
      'Informe uma localização com até 160 caracteres.';

  @override
  String get eventEditorInvalidDescription =>
      'Escreva uma descrição com pelo menos 10 caracteres.';

  @override
  String get eventEditorInvalidExternalLink =>
      'Insira um link válido, como exemplo.com/inscricao.';

  @override
  String get eventEditorInvalidHours =>
      'Informe uma carga horária maior que zero.';

  @override
  String get eventEditorMissingImage => 'Selecione uma imagem para o evento.';

  @override
  String get eventEditorImageError =>
      'Não foi possível abrir a imagem selecionada.';

  @override
  String get eventEditorFuturePublication =>
      'O agendamento precisa estar no futuro.';

  @override
  String get eventEditorPublishBeforeEvent =>
      'A publicação deve ocorrer antes do início do evento.';

  @override
  String get eventEditorRequiredFields =>
      'Revise os campos obrigatórios do evento.';

  @override
  String get eventEditorCreateError => 'Não foi possível criar o evento.';

  @override
  String get eventEditorCreated => 'Evento criado com sucesso.';

  @override
  String get eventEditorDiscardTitle => 'Descartar evento?';

  @override
  String get eventEditorDiscardMessage =>
      'As informações preenchidas serão perdidas.';

  @override
  String get eventEditorKeepEditing => 'Continuar editando';

  @override
  String get eventEditorDiscard => 'Descartar';

  @override
  String get eventEditorNotInformed => 'Não informado';

  @override
  String get eventEditorBackToReview => 'Voltar à revisão';

  @override
  String get eventEditorEditReviewTitle => 'Edite o evento';

  @override
  String get eventEditorEditReviewSubtitle =>
      'Revise os dados e altere somente o que for necessário.';

  @override
  String get eventEditorSaveChanges => 'Salvar alterações';

  @override
  String get eventEditorUpdated => 'Evento atualizado com sucesso.';

  @override
  String get eventEditorUpdateError => 'Não foi possível atualizar o evento.';

  @override
  String get eventEditorLoadError =>
      'Não foi possível carregar os dados do evento.';

  @override
  String get eventEditorTryAgain => 'Tentar novamente';

  @override
  String get eventEditorDiscardChangesTitle => 'Descartar alterações?';

  @override
  String get eventEditorDiscardChangesMessage =>
      'As alterações feitas neste evento serão perdidas.';

  @override
  String get mapInteractionHint => 'Arraste para explorar e toque em um bloco';

  @override
  String get mapResetView => 'Voltar ao ângulo zero';

  @override
  String get mapInteriorComingSoon => 'Interior em breve';

  @override
  String get mapSearch => 'Pesquisar no mapa';

  @override
  String get mapSearchComingSoon =>
      'A pesquisa de salas e blocos estará disponível em breve.';

  @override
  String get mapRotate => 'Arraste para girar o mapa';

  @override
  String get settingsMapGraphics => 'Gráficos do mapa';

  @override
  String get settingsMapGraphicsLight => 'Leve';

  @override
  String get settingsMapGraphicsComplete => 'Completo';
}
