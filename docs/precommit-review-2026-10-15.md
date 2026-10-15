# Revisão pré-commit — 15/10/2026

## Escopo e estado

Fechamento de ciclo para outro desenvolvedor continuar o projeto, ainda em
desenvolvimento. Revisão local de organização, fronteiras institucionais,
composição do backend e estabilidade. Não houve commit, instalação em aparelho,
deploy de regras ou alteração de dados remotos nesta revisão. Este relatório
não certifica o aplicativo como seguro ou pronto para publicação.

## Sessão, estabilidade e higiene

- Os ViewModels privados invalidam respostas antigas ao trocar UID/cargo,
  reiniciar a operação ou encerrar a tela. Isso evita que resultados da conta
  anterior repovoem listas e liberem flags da operação seguinte.
- Comandos com parâmetros distintos não compartilham mais indevidamente o
  mesmo Future em andamento. As telas de detalhe, edição e gestão de eventos
  recebem ViewModels próprios, com descarte de efeitos e callbacks.
- A criação de perfil é transacional e não sobrescreve um documento existente.
  A autenticação relê o perfil persistido após criar e confere o UID nativo
  antes de aceitar o resultado. Um evento inicial nulo atrasado não cancela
  sozinho um login válido. Atualização e exclusão de perfil têm prazo para
  resposta; isso não cancela eventual escrita remota tardia.
- Registros pessoais e o total de horas são alterados na mesma transação;
  repetição de adição/remoção não duplica o total. Exclusão de registro também
  ajusta o total. As respostas das consultas privadas são revalidadas por UID.
- A Splash permite repetir falhas de inicialização sem assumir que uma falha
  de perfil significa logout. Fluxos revisados liberam loading em exceções.
- O WebView só admite navegação para o documento local do viewer, rejeitando
  traversal e URLs externas. File/content access amplo e debugging padrão
  foram desativados; a captura continua sendo uma opção explícita de build.
- O viewer descarta listeners, texturas e recursos WebGL, ignora callbacks
  tardios e rejeita transferências parciais ou excessivas do modelo. O bundle
  foi regenerado preservando licenças.
- Removidos logs temporários de teclado, wrappers obsoletos do mapa, adaptadores
  demo sem uso e comentários redundantes. Não foram removidas licenças nem
  explicações de invariantes importantes.
- Capturas, recuperações, credenciais e arquivos de assinatura locais estão
  protegidos por regras de ignore. Os 1.399 artefatos antigos de `.dart_appdata`
  (25.555.059 bytes) foram movidos, sem perda, para
  `.tool_state/review-backups/dart-appdata-2026-10-15/`. As exclusões desse cache
  aparecerão no diff, mas o backup local é recuperável. O histórico Git não
  foi reescrito; ignore não remove dados de commits antigos.

## Fronteiras institucionais e composição

- `EventCategory` passou ao domínio institucional. As categorias concretas do
  IFPR não dependem do domínio de eventos do aplicativo.
- Os dados do IFPR ficam em `lib/institution/packages/ifpr_pgua/`. Os contratos
  em `lib/institution/domain/` são consumidos pelas funcionalidades. Os
  registries são os pontos de seleção do pacote concreto.
- Foram adicionados testes de fronteira para detectar imports do aplicativo
  dentro do módulo institucional e imports concretos de IFPR nas
  funcionalidades genéricas.
- O backend declarado corresponde aos adaptadores Firebase realmente usados.
  Foram removidos os runtimes de demonstração não implementados, o registro
  indevido do store demo e a substituição de identidade por `DEMO_ROLE` em
  serviços reais.
- A FirebaseApp criada no bootstrap é passada explicitamente à composição.
  Auth e Firestore usam essa aplicação; Firestore considera o
  `firestoreDatabaseId` do manifesto. Projeto e bucket são validados.
- O seed de demonstração recebe o contrato institucional, usa endereços
  `example.com` e não importa os dados concretos do IFPR. Cinco adaptadores demo
  sem consumidores foram removidos; o store local foi preservado para testes.
- A configuração Firebase local foi movida para
  `lib/institution/packages/ifpr_pgua/firebase_options.dart`. O novo caminho
  continua coberto pelo `.gitignore`.
- O validador passou a rejeitar identificador de banco vazio, labels vazios e
  recursos locais que escapem do diretório institucional por segmentos de
  caminho. Ausência de `InstitutionScope` produz erro explícito também em
  release.
- O bootstrap apresenta uma mensagem de falha controlada se a inicialização
  falhar, sem mostrar ao usuário o conteúdo bruto da exceção.

Trata-se de isolamento lógico dentro do repositório Flutter atual, não da
extração para um pacote Dart publicado ou um serviço remoto independente.

## Registros pessoais e testes de regressão

Foram adicionados testes locais de `EventsFirestoreService.setPersonalRecord`
com doubles de Firestore/Transaction, sem rede real ou novas dependências.
Cobrem adição e remoção repetidas sem duplicar o total, clamp em zero, total
prévio inválido, ausência de conta/evento, duração negativa, falha de commit,
rollback, nova tentativa, evento sem horas e remoção após exclusão do evento.

Esses testes verificam o fluxo do cliente. Não substituem testes de regras no
emulador nem comprovam o comportamento transacional de uma implantação real.

## Pendências críticas de autorização

O arquivo **local** `firestore.rules` não é uma representação confirmada das
regras implantadas. Sua leitura identificou:

- `allow read: if true` em eventos: qualquer cliente pode ler todos os campos
  do documento, incluindo eventos agendados. Filtrar pelo `publishAt` no app
  não impede leitura direta por outro cliente.
- Atualizações de conta pelo titular preservam o cargo, mas não restringem
  todos os demais campos. A integridade de totais de horas e outros campos
  confiáveis exige regras específicas ou um backend confiável.
- Não há regras para `notifications` ou
  `accounts/{uid}/readNotifications`; no arquivo local essas operações caem na
  negação geral. Isso pode impedir leitura, publicação de notificações e
  operações em lote que também criem uma notificação.

**As regras remotas não foram consultadas, verificadas nem alteradas.** Antes
de qualquer deploy, comparar a política pretendida com a implantação real e
testar cenários de visitante, estudante, gestor e administrador. Não publicar
o arquivo local automaticamente como parte da limpeza do código.

## Limites de operações assíncronas e offline

- Timeout de um Future no cliente não cancela uma escrita nativa Firebase já
  iniciada. Uma operação pode concluir mais tarde, inclusive após reconectar.
  O aplicativo diferencia confirmação, sincronização pendente e resultado
  não confirmado, mas isso não fornece cancelamento remoto.
- `createEvent` e `publishAnnouncement` geram um novo documento por chamada.
  Repetir manualmente uma criação cujo resultado ficou incerto pode duplicar
  dados. Falta um identificador de operação idempotente persistido entre
  tentativas ou deduplicação em backend confiável.
- A revogação de cargo não é instantânea quando o aparelho está offline.
  Dados já presentes no cache não podem ser retirados imediatamente. Controles
  de sessão e UI não substituem autorização de cada operação pelo servidor.
- O SDK local aceita o filtro OR do catálogo para `publishAt == null` ou
  `publishAt <= agora`. Isso não valida índices/permissões remotos nem garante
  inclusão de documentos legados sem o campo `publishAt`.

## Recursos ainda não implementados

Confirmado nos adaptadores registrados em `backend_dependency_bindings.dart`:

- `UnconfiguredPasswordResetService`: redefinição de senha retorna falha
  explícita.
- `UnconfiguredAccountSecurityService`: alteração de senha e solicitação de
  troca de e-mail retornam falha explícita.
- Upload de arquivos locais de imagem de eventos não está implementado no
  serviço; a operação é recusada com erro específico.
- Um clone limpo depende da geração autorizada dos arquivos Firebase locais
  ignorados. Sem `firebase_options.dart`, o import estático não compila. O
  tratamento de falha no bootstrap não corrige ausência de arquivo na compilação.
- A assinatura Android de release ainda é a de debug, e o applicationId é o
  identificador de exemplo. Antes de publicação, o proprietário precisa definir
  identidade/assinatura definitivas e alinhar as configurações Firebase. Não
  foram inventadas chaves ou alterados esses identificadores nesta revisão.

Esses itens são limitações conhecidas para continuidade/publicação, não uma
solicitação para expandir este fechamento de ciclo e implementar tudo agora.

## Resultados de validação

Resultados locais; testes com doubles não acessam o banco de produção:

| Verificação | Resultado |
| --- | --- |
| `flutter analyze --no-pub` | Aprovado; nenhum erro ou aviso |
| `flutter test --reporter compact` | 303 testes aprovados |
| Prazos de escrita de perfil (`account_write_deadline_test.dart`) | 2 testes adicionais aprovados |
| Testes de fronteira institucional | Aprovados na suíte completa |
| Testes transacionais de registros pessoais | 11 testes aprovados na suíte completa |
| `flutter build apk --release --target-platform android-arm64` | Aprovado; APK local de 35,3 MB, ainda com assinatura de teste |
| Verificações do viewer/mapa | 8 scripts Node aprovados; lista abaixo |
| `git diff --check` final | Aprovado; whitespace de strings GLSL do bundle gerado tratado por atributo específico |
| Validação manual em aparelho | Não realizada neste fechamento |
| Regras Firebase implantadas e testes de autorização | Não verificados nesta revisão |

Scripts executados em `tools/map/`: `check-viewer-lifecycle.mjs`,
`check-model-transfer.mjs`, `check-event-marker-layout.mjs`,
`check-map-feature-state.mjs`, `check-navigation-cache.mjs`,
`check-selection-cache.mjs`, `check-top-view-zoom.mjs` e
`check-uniform-device-quality.mjs`. Verificam lógica local e descarte de
recursos; não são medições de FPS/memória em aparelho real.

A primeira execução detectou um escape de navegação com `../`, normalizado
antes da checagem. A validação da URL bruta foi corrigida, incluindo variantes
codificadas; a segunda suíte completa passou. Nos testes de widgets existe
um aviso do renderizador SVG sobre `<filter>` não suportado. A compilação
também informou ausência da fonte CupertinoIcons; não há uso direto desses
ícones no código do aplicativo, mas a aparência de componentes adaptativos em
iOS deve ser conferida nessa plataforma.

O código passou nas verificações locais deste ciclo. A continuidade por outro
desenvolvedor pode partir deste estado, acompanhada das configurações locais
descritas no README e das limitações acima. Isso não equivale a uma homologação
em aparelho, revisão das regras remotas ou conclusão do produto.

## Antes do commit

Revisar o diff completo e incluir apenas arquivos intencionais; preservar as
licenças e comentários técnicos necessários. Não incluir capturas locais,
configurações privadas, binários de diagnóstico ou recuperações de arquivos
por engano. Qualquer falha crítica de teste, compilação ou autorização deve ser
registrada antes de declarar o conjunto pronto para commit.
