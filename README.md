# WhereIF

Aplicativo de eventos e navegação pelo campus, com mapa 3D, notificações e
registros pessoais para uma estimativa informal de horas complementares.

## Arquitetura

O aplicativo usa Firebase Auth para autenticação e Cloud Firestore para contas,
eventos, notificações, registros de horas e gestão de usuários. A composição das
dependências fica em `lib/core/di/`; os adaptadores são registrados em
`backend_dependency_bindings.dart`.

### Onde fica cada assunto

```text
lib/authentication/data/        login, sessão e verificação
lib/account/data/               perfil da conta
lib/events/data/                eventos e imagens
lib/notifications/data/         feed e comunicados
lib/complementary_hours/data/   registros pessoais e horas
lib/user_management/data/       usuários e cargos
lib/settings/data/              contratos de senha e e-mail
```

Dentro de cada `data`:

- `services/`: adapta os serviços externos aos contratos da funcionalidade.
- `repositories/`: fornece os dados à camada de aplicação/domínio.
- `mappers/`: converte documentos do banco em modelos Dart.

As telas e ViewModels consomem os contratos do aplicativo. O backend de
demonstração restante em `lib/dev/demo_backend/` é uma fixture local de testes;
não é registrado como backend real nem fornece um cargo fictício à sessão.

### Instituição

`lib/institution/domain/` define os contratos de marca, cores, idiomas,
categorias, política de horas, recursos do mapa e configuração do backend.
`lib/institution/packages/ifpr_pgua/` contém os dados concretos do IFPR.
Os registries selecionam o pacote e a configuração Firebase; as demais
funcionalidades dependem dos contratos, não dos dados concretos do IFPR.

O ponto de entrada passa a FirebaseApp selecionada à injeção de dependências,
que utiliza o `firestoreDatabaseId` do manifesto. A validação de projeto e
bucket evita uma composição incompatível. Isso não substitui as regras de
autorização no servidor.

## Configuração local

É necessário ter Flutter instalado e acesso autorizado ao projeto Firebase
indicado em `ifpr_pgua_package.dart`.

```powershell
flutter pub get
flutterfire configure --project=ID_DO_PROJETO --platforms=android --out=lib/institution/packages/ifpr_pgua/firebase_options.dart
```

Substitua `ID_DO_PROJETO` pelo projeto do manifesto. Para outro destino, gere
também a configuração da plataforma correspondente. Esse comando é uma etapa
de configuração local; não é uma instrução para publicar regras ou dados.

Quem já possui `lib/firebase_options.dart` na configuração anterior pode mover
seu arquivo local para `lib/institution/packages/ifpr_pgua/firebase_options.dart`,
sem regenerar nem sobrescrever uma configuração já existente nesse destino.

Os arquivos abaixo são locais e ignorados pelo Git:

- `lib/institution/packages/ifpr_pgua/firebase_options.dart`;
- `android/app/google-services.json`;
- `GoogleService-Info.plist`, quando aplicável;
- `firebase.json`, quando existente no ambiente local.

Um clone sem a configuração gerada não compila. Não versione chaves privadas,
credenciais de contas de serviço ou arquivos de assinatura. O manifesto deve
corresponder à configuração gerada.

## Validação e construção

Na raiz do projeto:

```powershell
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Para conferir apenas as fronteiras institucionais e os registros pessoais:

```powershell
flutter test test/institution test/dev test/events/data/services/events_firestore_service_test.dart
```

O APK é gerado em `build/app/outputs/flutter-apk/app-release.apk`. A construção
local não comprova permissões remotas, comportamento offline em aparelhos ou
adequação para publicação.

Ao modificar o JavaScript do mapa, regenere o bundle usado pelo aplicativo:

```powershell
npx --package=esbuild@0.28.2 esbuild assets/institutions/ifpr-pgua/map/viewer/viewer.js --bundle --format=iife --target=es2020 --minify --legal-comments=inline --outfile=assets/institutions/ifpr-pgua/map/viewer/viewer.bundle.js
node tools/map/check-viewer-lifecycle.mjs
node tools/map/check-model-transfer.mjs
node tools/map/check-event-marker-layout.mjs
```

O código de terceiros e suas licenças devem ser preservados. O bundle gerado
contém strings GLSL com espaços próprios; apenas esse arquivo está dispensado
da verificação de espaços pelo Git.

## Pendências de backend e segurança

Este é um fechamento de ciclo para continuidade por outro desenvolvedor, não
uma versão final. As pendências abaixo devem acompanhar a passagem de trabalho;
não precisam ser implementadas como parte desta limpeza.

Redefinição de senha e alteração de e-mail/senha ainda usam adaptadores
`Unconfigured...`, que retornam falha explícita. Upload de imagens locais de
eventos também não está implementado; o serviço aceita recursos já suportados,
como imagens de assets ou URLs remotas.

O arquivo local `firestore.rules` precisa de revisão antes de qualquer deploy:
há leitura pública irrestrita de eventos e faltam regras de notificações e
marcadores de leitura. As regras implantadas no projeto remoto não foram
verificadas nesta revisão. Consulte
[a revisão pré-commit](docs/precommit-review-2026-10-15.md) para os demais limites
e resultados de validação.

A variante Android `release` ainda usa a assinatura de debug e o identificador
`com.example.autth_injustice_app`. São configurações de teste; a publicação
exigirá assinatura e identidade definitivas, compatíveis com o Firebase.
