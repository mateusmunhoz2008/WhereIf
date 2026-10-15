import 'package:autth_injustice_app/complementary_hours/domain/models/complementary_hours_record.dart';
import 'package:autth_injustice_app/authorization/domain/models/account_role.dart';
import 'package:autth_injustice_app/dev/demo_backend/models/demo_event.dart';
import 'package:autth_injustice_app/account/domain/models/account.dart';
import 'package:autth_injustice_app/events/domain/models/event_preview.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/institution/domain/institution_package.dart';
import 'package:autth_injustice_app/notifications/domain/models/app_notification.dart';
import 'package:autth_injustice_app/user_management/domain/models/user_directory_entry.dart';

class DemoBackendSeed {
  DemoBackendSeed._();

  static final studentAccount = Account(
    uid: 'demo-user',
    email: 'student@example.com',
    displayName: 'Estudante de demonstração',
    createdAt: DateTime(2026, 2, 10),
    updatedAt: DateTime(2026, 7, 19),
    isProfileConfigured: true,
    role: AccountRole.student,
  );

  static final eventManagerAccount = studentAccount.copyWith(
    uid: 'demo-event-manager',
    email: 'events@example.com',
    displayName: 'Gestor de eventos',
    role: AccountRole.eventManager,
  );

  static final administratorAccount = studentAccount.copyWith(
    uid: 'demo-administrator',
    email: 'admin@example.com',
    displayName: 'Administrador',
    role: AccountRole.administrator,
  );

  static List<UserDirectoryEntry> buildManagedUsers() {
    return [
      UserDirectoryEntry(
        account: studentAccount,
        totalComplementaryMinutes: (50 * Duration.minutesPerHour) + 30,
      ),
      UserDirectoryEntry(
        account: Account(
          uid: 'demo-student-ana',
          email: 'ana.silva@example.com',
          displayName: 'Ana Silva',
          createdAt: DateTime(2025, 3, 12),
          updatedAt: DateTime(2026, 7, 20),
          isProfileConfigured: true,
          role: AccountRole.student,
        ),
        totalComplementaryMinutes: (32 * Duration.minutesPerHour) + 15,
      ),
      UserDirectoryEntry(
        account: Account(
          uid: 'demo-student-lucas',
          email: 'lucas.santos@example.com',
          displayName: 'Lucas Santos',
          createdAt: DateTime(2024, 2, 19),
          updatedAt: DateTime(2026, 7, 18),
          isProfileConfigured: true,
          role: AccountRole.student,
        ),
        totalComplementaryMinutes: 87 * Duration.minutesPerHour,
      ),
      UserDirectoryEntry(
        account: Account(
          uid: 'demo-student-mariana',
          email: 'mariana.costa@example.com',
          displayName: 'Mariana Costa',
          createdAt: DateTime(2026, 2, 9),
          updatedAt: DateTime(2026, 7, 22),
          isProfileConfigured: true,
          role: AccountRole.student,
        ),
        totalComplementaryMinutes: (18 * Duration.minutesPerHour) + 45,
      ),
      UserDirectoryEntry(
        account: eventManagerAccount,
        totalComplementaryMinutes: 0,
      ),
      UserDirectoryEntry(
        account: Account(
          uid: 'demo-event-manager-2',
          email: 'culture@example.com',
          displayName: 'Gestão cultural',
          createdAt: DateTime(2025, 8, 4),
          updatedAt: DateTime(2026, 7, 24),
          isProfileConfigured: true,
          role: AccountRole.eventManager,
        ),
        totalComplementaryMinutes: 0,
      ),
    ];
  }

  static List<DemoEvent> buildFeaturedEvents(InstitutionPackage package) => [
        DemoEvent(
          preview: EventPreview(
            id: 'neon-district',
            title: 'Festival de música',
            category: package.events.fallbackCategory,
            startsAt: DateTime(2026, 7, 28, 11),
            endMode: EventEndMode.automatic,
            endsAt: DateTime(2026, 8, 30, 12),
            location: 'Auditório',
            description:
                'Uma noite de música, luz e artistas locais ocupando o campus.',
            imageUrl: package.events.presetImages.firstOrNull?.location ?? '',
          ),
          complementaryMinutes: 4 * Duration.minutesPerHour,
        ),
        DemoEvent(
          preview: EventPreview(
            id: 'jazz-under-stars',
            title: 'Jazz Under Stars',
            category: package.events.fallbackCategory,
            startsAt: DateTime(2026, 7, 24, 20, 30),
            endMode: EventEndMode.automatic,
            endsAt: DateTime(2026, 7, 24, 23, 30),
            location: 'Praça das Artes',
            description:
                'Jazz ao vivo em uma noite aberta, com convidados e espaço para encontrar amigos.',
            imageUrl:
                'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=85',
          ),
        ),
      ];

  static List<DemoEvent> buildFutureEvents(InstitutionPackage package) => [
        DemoEvent(
          preview: EventPreview(
            id: 'art-after-dark',
            title: 'Exposição de artes visuais',
            category: package.events.fallbackCategory,
            startsAt: DateTime(2026, 8, 12, 18),
            endMode: EventEndMode.automatic,
            endsAt: DateTime(2026, 8, 12, 21),
            location: 'Galeria Central',
            description:
                'Uma seleção de artistas visuais, instalações e conversas durante a noite.',
            externalUrl: package.branding.websiteUrl,
            imageUrl:
                'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=900&q=85',
          ),
          complementaryMinutes: 6 * Duration.minutesPerHour,
        ),
        DemoEvent(
          preview: EventPreview(
            id: 'city-run',
            title: 'Encontro de bem-estar',
            category: package.events.fallbackCategory,
            startsAt: DateTime(2026, 8, 15, 14),
            endMode: EventEndMode.automatic,
            endsAt: DateTime(2026, 8, 15, 16),
            location: 'Sala de práticas',
            description:
                'Atividades de relaxamento e bem-estar para a comunidade.',
            imageUrl: package.events.presetImages.firstOrNull?.location ?? '',
          ),
          complementaryMinutes: 2 * Duration.minutesPerHour,
        ),
        DemoEvent(
          preview: EventPreview(
            id: 'open-air-cinema',
            title: 'Circo INFO23',
            category: package.events.fallbackCategory,
            startsAt: DateTime(2026, 8, 25, 19),
            endMode: EventEndMode.manual,
            location: 'Auditório',
            description: 'Apresentação teatral e musical da turma de INFO23.',
            imageUrl:
                'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=900&q=85',
          ),
          complementaryMinutes: (4 * Duration.minutesPerHour) + 30,
        ),
      ];

  static List<ComplementaryHoursRecord> buildComplementaryHoursRecords() {
    return [
      ComplementaryHoursRecord(
        id: 'academic-week',
        eventName: 'Semana Acadêmica',
        eventDate: DateTime(2026, 7, 10),
        durationMinutes: 12 * Duration.minutesPerHour,
      ),
      ComplementaryHoursRecord(
        id: 'technology-fair',
        eventName: 'Feira de Ciência e Tecnologia',
        eventDate: DateTime(2026, 6, 28),
        durationMinutes: 8 * Duration.minutesPerHour,
      ),
      ComplementaryHoursRecord(
        id: 'git-workshop',
        eventName: 'Oficina de Git e GitHub',
        eventDate: DateTime(2026, 6, 17),
        durationMinutes: 4 * Duration.minutesPerHour,
      ),
      ComplementaryHoursRecord(
        id: 'extension-journey',
        eventName: 'Jornada de Ensino e Extensão',
        eventDate: DateTime(2026, 5, 22),
        durationMinutes: 16 * Duration.minutesPerHour,
      ),
      ComplementaryHoursRecord(
        id: 'artificial-intelligence',
        eventName: 'Inteligência Artificial na Educação',
        eventDate: DateTime(2026, 5, 8),
        durationMinutes: 6 * Duration.minutesPerHour,
      ),
      ComplementaryHoursRecord(
        id: 'cultural-exhibition',
        eventName: 'Mostra Cultural',
        eventDate: DateTime(2026, 4, 25),
        durationMinutes: (4 * Duration.minutesPerHour) + 30,
      ),
    ];
  }

  static List<AppNotification> buildNotifications() {
    final now = DateTime.now();

    return [
      AppNotification(
        id: 'event-reminder',
        type: AppNotificationType.reminder,
        title: 'Festival de música começa hoje',
        message:
            'O evento no Auditório começa às 19:00. Chegue um pouco antes para aproveitar tudo.',
        createdAt: now.subtract(const Duration(minutes: 12)),
        isRead: false,
      ),
      AppNotification(
        id: 'event-update',
        type: AppNotificationType.update,
        title: 'Comunicado',
        message:
            'A biblioteca e os serviços gerais estarão indisponíveis por tempo indeterminado.',
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: false,
      ),
      AppNotification(
        id: 'new-event',
        type: AppNotificationType.event,
        title: 'Novo evento para você',
        message: 'O encontro de bem-estar foi adicionado ao catálogo.',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: false,
      ),
      AppNotification(
        id: 'catalog-update',
        type: AppNotificationType.update,
        title: 'Semana de arte e cultura adiada',
        message:
            'As atividades foram realocadas devido aos prejuízos causados pelo temporal.',
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: false,
      ),
    ];
  }
}
