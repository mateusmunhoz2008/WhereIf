# Eventos vinculados ao mapa

O cadastro permite escolher vários destinos do catálogo local: bloco/quadra,
piso inteiro ou espaço específico. O catálogo é derivado de `campus_map.json`,
sem baixar/preparar o GLB no editor. Identidade: instituição, bloco, piso
opcional e nome do objeto da sala opcional. O texto exibido não é usado para
encontrar objetos 3D. Nomes como Sala de Música podem ser definidos no
`label` do espaço correspondente, sem renomear a geometria.

Os vínculos ficam em `events/{id}.mapLocations`. O campo antigo `location`
continua sendo salvo como descrição legível para compatibilidade. Documentos
antigos sem vínculos continuam legíveis, mas precisam de edição e associação
ao catálogo para ganhar cartão e navegação precisa. Locais externos ainda
podem ser informados como texto. O botão Mostrar no mapa requer vínculo.
Não foram alteradas regras, consultas públicas, permissões ou contas.

No mapa, eventos publicados, futuros ou em andamento, com destinos válidos
recebem balões pequenos com ponta inferior. No exterior, eventos são agrupados
por bloco e exibem Evento + número de eventos adicionais. No interior, cada
local tem um card vertical com foto circular e nome em até duas linhas;
só aparecem destinos relevantes ao piso atual. Vários destinos
no mesmo bloco não duplicam o evento no balão. Títulos usam `textContent`,
não HTML. Os rótulos não têm blur, luzes, meshes ou render targets e usam
o loop existente do mapa, sem timer de animação adicional.

O painel lateral da versão anterior foi excluído, junto com seu deslocamento
de projeção. Balões com vários eventos têm camadas deslocadas; ao tocar,
abrem cards lado a lado sobre o mesmo local. Cada card é clicável: no exterior
visita o destino; no interior abre a tela normal de detalhes do evento.
Toque fora fecha a pilha. Cards usam 88 px lógicos e escala limitada entre
0,72 e 1,08 conforme a distância da câmera. O grupo expandido é mantido
nos limites horizontais da tela; grupos grandes têm rolagem interna vertical.
Não há blur, novo loop de animação ou alteração de nitidez/qualidade.
Fotos vêm da imagem existente do evento; assets locais e HTTP(S) são aceitos,
sem caminhos arbitrários de arquivo. Sem foto válida, aparece a inicial.

Navegação é serializada e aceita só o último pedido pendente. O destino é
validado antes de mudar a cena; bloco usa exterior, piso não seleciona sala
arbitrária e sala reaproveita o foco/contorno existente. A troca do 2D para
o interior continua fluida. Clicar num local obsoleto não quebra o mapa.

Testes da nova versão: 40 testes Flutter de mapa e detalhes de eventos,
análise sem erros; suíte WebGL com modelo real, balões, fotos, pilhas,
escolha independente, múltiplos destinos, piso, sala, exterior, 2D,
referências obsoletas e cliques rápidos. Teste DOM específico em 320/412/768 px,
temas claro/escuro, ponta inferior, escala por zoom, fotos e descarte.
Qualidade uniforme, orçamento de renderização e cache de navegação preservados.

Builds com `MAP_CAMERA_CAPTURE=true` aceitam `eventPreview` pela ponte para conferir
eventos fictícios em memória; builds comuns ignoram essa mensagem. Essa
prévia não altera Firestore, SharedPreferences ou o catálogo compartilhado.

## Conferência dos balões no S24

APK ARM64 release de 36.844.031 bytes instalado, sem apagar dados, após
autorização específica do usuário. Dois eventos temporários foram enviados
apenas ao estado local da tela. A pilha exterior mostrou cards independentes,
inclusive o evento real já existente no mesmo bloco; fotos de assets carregaram
por `file:///android_asset/flutter_assets/`. Um toque físico no card Oficina
de desenho abriu `sala_1_did` em `didatico-p2`, com janelas ocultas. Na sala,
os dois eventos temporários ficaram agrupados em um balão com foto e +1.
O card é compacto, com ponta e camadas deslocadas; o grupo abre lado a lado.

Prévia removida, eventos reais preservados e piso/câmera registrados antes do
teste restaurados. Nitidez 70%, AA desligado, DPR 2,1 e framebuffer 907 × 1965
preservados. Conexão de diagnóstico local encerrada ao terminar. Capturas e
suíte DOM/WebGL em `build/event-balloon-preview` e `build/raw-map-preview`.
Nenhuma proteção do aparelho foi desabilitada ou alterada; o alerta antigo do
Avast permanece sem diagnóstico nesta tarefa.

## Fade, cores suaves e prévias permanentes de teste

Balões usam fade de opacidade de 180 ms, como os objetos dos pisos: entrada,
saída, abertura/fechamento dos cards e troca de piso. Animações interrompidas
partem da opacidade atual; nós antigos são descartados após o fade. Movimento
reduzido é respeitado. Não há blur nem um loop 3D adicional para esse efeito.
Seis cores suaves são sorteadas sem repetição inicial e guardadas por ID do
evento durante a sessão; não mudam ao arrastar/selecionar/trocar piso. Tema
escuro usa versões mais profundas da mesma paleta, com texto claro.

Exterior tem tamanho mínimo de 156 × 48 px lógicos, inclusive com nome curto.
Até grupos com um único evento abrem primeiro seu card no exterior. Cards
abertos mantêm cores individuais, fotos e acesso independente ao destino.
O corpo do balão é ocultado com fade antes de invadir a faixa do cabeçalho;
o grupo aberto mantém a margem superior e usa duas colunas em telas estreitas
quando três cards não cabem. Líderes dos grupos recebem a paleta primeiro,
evitando a repetição sistemática de cores provocada pelos pares de prévias.

`MAP_EVENT_PREVIEWS=true` habilita amostras locais, geradas uma vez por abertura
da tela: dois eventos por bloco e amostras nos outros pisos. Só usam destinos
reais do catálogo, sem gerar eventos em banheiros. Cards fictícios têm rótulo
Prévia; clicar dentro do piso informa que não foram publicados, em vez de
consultar um ID inexistente. As amostras não passam pelos controllers de
publicação e não alteram Firestore, preferências ou eventos reais. O APK de
teste mantém esse flag ativo até o usuário solicitar retirar as prévias;
builds normais sem o flag não recebem esses eventos.

Testes: 36 testes Flutter do mapa; DOM em 320/412/768 px com fade real,
interrupção/reversão rápida, descarte, largura mínima, cores estáveis,
fotos e cliques; suíte WebGL com navegação do modelo real aprovada.

APK final de 36.910.539 bytes instalado no S24. Conferência adicional:
13 prévias locais presentes em seis grupos exteriores; as seis cores suaves
apareceram nos líderes. A animação real do grupo visível registrou 180 ms;
movimento reduzido estava desligado. Cards continuaram no exterior, com
fotos, cores individuais e rótulo Prévia. Nitidez 70%, AA desligado e buffer
907 × 1965 preservados. As prévias foram mantidas após o teste, conforme pedido;
nenhum evento fictício foi publicado. Diagnóstico local encerrado.

## Entrada direta no piso e indicador de eventos

Exterior reduzido para 132 × 48 px lógicos: altura preservada, largura menor.
Paleta mais viva (vermelho, roxo, rosa, azul, verde e ocre), sem cores neon,
com versões para tema escuro e cores estáveis por evento na sessão.
O exterior não cria mais cards de foto/nome nem abre a lista de eventos.
O toque envia o bloco à tela Flutter, que abre o piso com mais eventos únicos.
Um evento em várias salas do mesmo piso conta uma única vez; pode contar
uma vez em cada piso quando tem múltiplos destinos. Empate segue a ordem dos
pisos no catálogo. Destino é o piso inteiro, sem escolher sala arbitrária.
Locais sem pisos e eventos vinculados apenas ao bloco continuam no exterior.
Cards empilhados e abertura lado a lado continuam disponíveis dentro do piso.

A pílula recebe as contagens locais dos mesmos eventos ativos/publicados usados
nos balões. Um evento histórico aberto pelo botão Mostrar no mapa não produz
contagens extras nem falsos indicadores. Pisos com eventos que não estão em
exibição mostram três pulsos suaves no número/fundo: 160 ms ligados,
190 ms entre os flashes e 4,2 s de pausa após a terceira rajada. Suavização
de cor em 80 ms, sem blur e sem ticker contínuo durante a pausa. O sinal é
um widget pequeno com repaint isolado; não altera nem pede frames à WebView.
O piso selecionado não pisca. Ocultar a tela, pôr o app em segundo plano,
carregar um piso, desativar animações ou usar movimento reduzido suspende
as rajadas. Timers são cancelados ao sair.
Contagens acessíveis/tooltip traduzidas em português, inglês e espanhol.

Validação: 41 testes Flutter de mapa, incluindo deduplicação por piso,
empate, destino inteiro, casos sem piso, três rajadas, pausa sem frames,
suspensão/retomada e descarte; análise sem avisos. Prévia DOM confirma
132 × 48, envio direto do bloco, nenhuma foto alocada no exterior e paleta
mais viva; suíte WebGL confirma navegação por piso e pilhas só no interior.

Conferência nativa no S24: cinco amostras adicionais temporárias no Piso 2
confirmaram que o toque exterior abre `didatico-p2` inteiro, sem sala
selecionada e sem abrir lista no exterior. Janelas ocultas; o Piso 1 sinalizou
seus eventos. A instalação seguinte reiniciou o estado local, descartando
essas cinco amostras e mantendo as 13 prévias geradas pedidas pelo usuário.
Nitidez 70%, AA desligado e buffer 907 × 1965 foram preservados no teste.

### Ajuste do toque e dos pulsos

Removido o destaque azul de toque nativo da WebView nos balões, incluindo
os cards internos; sem mudança da área de toque ou da escala. O fade existente
continua, mas não há efeito adicional de opacidade ao pressionar. Navegação
por teclado mantém um contorno `focus-visible` da própria cor do balão,
não o azul padrão. A pílula já usa toque sem splash/highlight.

Entre rajadas, o fundo do indicador fica totalmente transparente e o número
volta ao mesmo branco suave dos outros pisos. Removidos a borda e o ponto
no canto. Somente durante cada pulso o fundo e o número acendem; movimento
reduzido, tela oculta e carregamento deixam o piso com aparência normal.
Os testes de widgets verificam transparência zero na pausa, ausência de
borda/dot e nenhum ticker durante o intervalo. Testes DOM conferem
`-webkit-tap-highlight-color: transparent` também nos cards das salas.

APK final de 36.960.955 bytes instalado no S24 sem apagar dados. Conferência
da WebView visível confirmou `map-event-balloons-5`, destaque de toque
totalmente transparente nos seis balões e 16 eventos (13 prévias geradas
mais 3 reais), sem as cinco amostras extras. Nitidez 70%, AA desligado,
DPR 2,1 e framebuffer 907 × 1965 preservados. Os 14 testes focados passaram
e a análise Flutter terminou sem avisos. Diagnóstico local encerrado.

### Retorno de toque básico em todos os balões

A pedido do usuário, todos os botões de eventos agora comprimem levemente
para 96% ao tocar e voltam ao normal em 100 ms ao soltar. Inclui exterior,
balão do local e cada card aberto lado a lado, sem deslocar o ponto de
ancoragem do mapa. A resposta começa no `pointerdown`, sem esperar o
clique Android; `pointerup`, cancelamento, saída do ponteiro, perda de
captura e foco removem o estado. Ocultar o balão também limpa a pressão.
Teclado recebe a mesma resposta; movimento reduzido dispensa a transição.
Não há azul nativo, blur, filter, timer ou frames 3D adicionais.

Teste DOM com toques reais em 320/412/768 px confirma compressão, retorno,
cancelamento sem navegação, um único clique por toque e os três tipos de
botão, inclusive tema escuro. Fade, escala por zoom e navegação por piso
foram mantidos. Os pulsos da pílula continuam sem borda/dot permanente.

APK de 36.961.187 bytes instalado no S24, com a WebView confirmando
`map-event-balloons-6`. Eventos de ponteiro de diagnóstico confirmaram
escala 0,96 pressionado e 1,0 após cancelar, com destaque azul transparente.
As 13 prévias locais e os 3 eventos reais permaneceram; nitidez 70%, AA
desligado e framebuffer 907 × 1965 preservados. Sem alterações na pílula.

### Cor ao pressionar e saída do interior vindo do 2D

Contagem `Evento +N` mantida: N representa os eventos adicionais ao primeiro.
Todos os botões dos balões recebem uma variação leve da mesma cor ao pressionar
(mais escura no tema claro, mais clara no escuro), com retorno em 100 ms.
A cor é pré-calculada ao criar o balão; sem filter, blur ou trabalho por frame.
A ponta acompanha a cor. Testes de toque verificam retorno da cor após soltar
ou cancelar, também nos cards empilhados e no tema escuro.

A entrada no piso guardava os limites de órbita do exterior ainda em 2D
(inclinação 0..0,0001). Ao sair, esses limites eram reaplicados à câmera
perspectiva, que ficava quase vertical e não conseguia inclinar. Agora o
retorno guarda os limites 3D configurados, preservando o foco salvo do bloco.
Não foram alterados os ângulos padrão, qualidade, presets ou o 2D normal.

Um toque que não atinge sala e cujo raio fica fora dos limites dos pisos
visíveis sai do interior com o fade existente, desseleciona o bloco e avisa
a interface nativa para ocultar a pílula. Toques em corredores apenas limpam
a seleção da sala. A saída por toque fora não refoca a câmera.

Suíte WebGL com GLB real testou Didático e Central: 2D → piso por evento →
exterior, perspectiva com limites válidos e inclinação estável após novos
frames; 2D → piso → toque vazio real no canvas → desseleção completa.
Fluxos de sala, pisos, pilhas, cliques rápidos, seleção, fade, janelas e
qualidade anteriores também passaram. Suíte DOM e qualidade uniforme passaram.

APK de 36.961.531 bytes instalado no S24. Conferência nativa: o balão visível
em 2D abriu `central-p1` inteiro, sem sala selecionada; a cor ao pressionar
variou de RGB(118,156,200) para RGB(104,137,176). A saída pelo mesmo método
do botão Exterior recuperou perspectiva e limites [0,36; 1,25], mantendo o
ângulo ao rotacionar. Nova entrada 2D → piso seguida de toque real no canvas
fora dos limites deixou piso e bloco nulos, modo 3D e limites válidos.
Os 16 eventos (13 prévias e 3 reais), nitidez 70%, AA desligado e framebuffer
907 × 1965 permaneceram. Diagnóstico local encerrado após a conferência.

### Pilha de eventos tem prioridade no toque fora

Com dois ou mais cards abertos lado a lado, o primeiro toque fora fecha
somente a pilha com o fade existente. Bloco, piso, sala, contorno e câmera
permanecem selecionados/inalterados. Um novo toque fora, já com a pilha fechada,
volta a usar a desseleção normal. O gesto guarda no `pointerdown` que fechou
a pilha, para o `pointerup` não executar também a seleção de mapa por baixo.
Não há atraso, timer, nova renderização 3D ou bloqueio de arrasto/zoom.

Teste com GLB real: piso aberto por evento vindo do 2D, sala selecionada,
pilha aberta, toque real fora fecha somente os cards e preserva câmera e
seleção; segundo toque sai do piso. Escolher um card da pilha continua
funcionando independentemente. Suíte DOM confirma que toques dentro da pilha
não a fecham e que só o primeiro gesto externo é consumido.

APK de 36.961.611 bytes instalado no S24. Teste com toques reais abriu a
pilha de `sala_3_central`; primeiro toque vazio deixou `central-p1` e
`bloco-central` selecionados, cards fechados e posição/alvo da câmera
exatamente iguais. Segundo toque no mesmo ponto deixou piso/bloco nulos.
Nitidez 70%, AA desligado e buffer 907 × 1965 preservados. Sem novas amostras
ou publicações; diagnóstico temporário encerrado.

### Seletor de tamanho dos pop-ups internos

Painel Testes: controle Pop-ups internos de 70% a 160%, passos de 5%,
com valor atual e botão Restaurar 100%. Ajusta ao arrastar, sem carregamento.
100% mantém exatamente o tamanho anterior. Foto, texto, ponta, área de toque
e cards lado a lado escalam juntos; a escala existente por distância continua.
As colunas e os limites laterais se adaptam ao tamanho, inclusive em 320 px.

O exterior não muda. Tamanho não afeta nitidez, AA, câmera, clima ou modo
desempenho. A escolha fica em `interiorEventSize` nas preferências locais
de testes do mapa, separada dos presets gráficos. Ausente/inválida usa 100%.
Só o layout DOM é atualizado; o slider não pede novos frames do cenário 3D,
não reconstrói os balões e mantém a pilha aberta e as cores durante o ajuste.

Suítes DOM/WebGL passaram: 70/100/160%, pilha aberta, limites em telas
320/412/768 px, normalização, slider real, valor percentual, persistência,
reset e qualidade/câmera/modo desempenho inalterados. Fluxos de seleção e
prioridade de fechamento da pilha continuam aprovados.

APK de 36.962.143 bytes instalado no S24. Controle conferido no piso Central:
de 100% a 130%, o card passou de 63,36 para 82,37 px visíveis imediatamente;
o percentual foi salvo e Restaurar 100% recuperou exatamente o tamanho anterior.
Nitidez 70%, AA desligado e buffer 907 × 1965 inalterados. Painel Testes
deixado aberto com 100% para o usuário escolher; diagnóstico local encerrado.

### Redistribuição dos pop-ups sobrepostos

`event_marker_layout.js` distribui retângulos em pixels projetados, considerando
o tamanho escolhido, zoom, altura de cards/prévias e pilhas abertas. Pop-ups
isolados continuam acima. Quando a sobreposição supera aproximadamente 28%
do menor card, tenta alternar acima/abaixo; se ainda não houver espaço, usa
o afastamento lateral livre mais próximo e, por último, um nível vertical.
A ponta inverte com o lado. Uma linha fina liga deslocamentos ao ponto real
do mapa; não há mudança da localização nem redução automática de tamanho.
Não são descartados eventos por lotação: a posição menos conflitante é usada.

Pilha aberta tem prioridade, cabeçalho/rodapé e margens laterais são respeitados
e os cards abertos adaptam colunas/rolagem ao lado disponível. Abrir/fechar
recalcula o layout DOM sem pedir um frame 3D. Posições legíveis anteriores
são mantidas até existir conflito relevante, evitando piscar entre lados ao
rotacionar. Projeção arredondada/cache impede repetir cálculos e escritas DOM
quando a câmera/tamanho não mudam. Não há leitura de medidas DOM por frame,
blur, física, renderer adicional ou timer para essa distribuição.

Validação: teste matemático 70/100/130/160%, telas 320/412/768 px, três e seis
âncoras muito próximas, limites da tela, pequenas mudanças de câmera e
prioridade da pilha. Teste DOM mede cards renderizados, ausência de sobreposição
extrema, ponta superior/inferior, cliques corretos e estabilidade parada.
Captura visual: `build/event-balloon-preview/crowded-alternating-large.png`.
Suíte completa com GLB real e qualidade uniforme também passou, preservando
seleção, navegação 2D/3D, fade e primeiro toque que só fecha a pilha.

APK de 36.963.919 bytes instalado no S24. Tamanho escolhido de 160% mantido;
conferência nativa no Didático mostrou um card abaixo e outro acima, sem
interseção. Abrir os dois eventos do card inferior manteve a organização e
ampliou sua área de 101,38 para 222,34 px sem invadir o outro card. Fechar
apenas a pilha funcionou. Nitidez 70%, AA desligado e buffer 907 × 1965
preservados. Sem eventos novos no banco ou troca de preferências do usuário.

### Correção da regressão de ancoragem e pinch

A distribuição anterior foi simplificada após a conferência da tela do S24:
o balão da Portaria estava no centro útil da tela, mas guardava deslocamento
lateral de -73 px e uma linha. A causa era reutilizar `previous.dx/offset`
como nova posição preferida. Agora a posição sempre parte da âncora atual e
do clamp às margens, como antes da distribuição. Ir à borda e voltar recentra
automaticamente o balão e sua ponta. Não há linhas nem filas verticais soltas.
O exterior usa somente a adaptação normal às bordas. Interiores mantêm a
alternância simples acima/abaixo e só um pequeno ajuste dentro do alcance
da própria ponta; os deslocamentos não são memorizados.

Durante pan/pinch, os lados ficam estáveis e só se atualizam projeção, escala
e clamp. A resolução de colisões ocorre após o gesto. Cards ficam transparentes
ao hit-test enquanto a câmera é manipulada, para o segundo dedo não cair num
pop-up que se moveu. Se o primeiro dedo começou no card e surge um segundo,
os ponteiros ativos são transferidos ao OrbitControls sem emitir clique no
evento. Captura de ambos os ponteiros e contagem por IDs mantêm o gesto até
o último dedo sair. Cancelamento e suspensão limpam o estado. O retorno de
toque normal e a prioridade de fechar a pilha foram preservados.

Testes matemáticos/DOM cobrem esquerda → centro → direita → centro, 70–160%,
ponteiro recentrado, ausência de linhas, lados travados durante o gesto e
áreas clicáveis restauradas ao finalizar. O teste de pinch usa 5 pontos de
toque disponíveis e começa longe dos controles da interface para evitar o
retarget de toque do Chrome para o botão Testes.

Conferência nativa concluída em 14/10 no S24, com o APK de 36.964.335 bytes
instalado sem apagar dados (`map-event-balloons-11`). Na mesma câmera do bug,
a Portaria ficou com deslocamento zero e ponta centralizada; ao deslocar a
câmera até a borda, o clamp chegou a 74,28 px e voltou a zero ao retornar,
sem nenhum conector. Captura: `build/map-popup-corrected-s24.png`.
Gestos reais via entrada de toque do WebView, iniciados no canvas/pop-up e
no pop-up/pop-up, mantiveram os dois ponteiros ativos; levantar o primeiro
preservou o modo multitoque e levantar o último liberou o gesto. Nenhum
bloco/piso foi selecionado por acidente. Câmera restaurada após a medição;
tamanho 160%, nitidez 70%, AA desligado e buffer 907 × 1965 preservados.
Conexão temporária de diagnóstico fechada. Nenhuma escrita no banco.

### Opção de reajuste e remoção das prévias — 14/10

Em Testes → Posição dos pop-ups, há duas escolhas: Reajuste automático
(comportamento atual dos interiores, alternando acima/abaixo para reduzir
sobreposição) e Normal · com sobreposição (posição original, sem resolução
de colisões). Ambas mantêm o clamp às bordas, a ponta acompanhando a âncora,
os fades e a proteção do gesto com dois dedos. Exterior não muda.
A escolha fica em `eventMarkerAutoLayout` nas preferências locais, independente
de tamanho, modo desempenho e nitidez; o padrão continua automático.

Removidos a geração das amostras locais, o flag `MAP_EVENT_PREVIEWS`, o
receptor de injeção `eventPreview` e os rótulos de prévia dos balões. O mapa
recebe somente os eventos reais do catálogo. Não foram removidos documentos
no banco. O arquivo de geração das amostras e seu teste exclusivo também
foram retirados, pois não têm mais uso.

Testes matemáticos, DOM e WebGL com o modelo completo passaram nos dois
modos, incluindo mudança imediata, preferência preservada após recarregar,
bordas, toque, pinch, pilhas, navegação entre pisos e qualidade inalterada.
Análise Flutter sem problemas e os 39 testes de `test/map` passaram.
APK de 36.964.647 bytes instalado no S24 sem apagar dados; conferido
`map-event-balloons-12`, seletor com ambas as opções e gravação dos dois
valores. Modo escolhido no aparelho (normal) restaurado após o teste,
preservando piso, câmera, nitidez 70%, AA desligado e buffer 907 × 1965.
Nenhum rótulo de prévia no DOM; a geração e a injeção das amostras não
fazem mais parte do app. Conexão temporária de diagnóstico encerrada.

### Vários locais na tela do evento — 14/10

Verificado no S24: o gerenciamento de “Missa do Sétimo Dia” mostrava
Sala 9 · Piso 1 · Bloco Didático e Quadra, com publicação AGENDADA. O mapa
recebia seis eventos publicados, sem esse evento; a quadra existe no modelo.
Não houve alteração de publicação, locais, regras ou documentos no banco.

Na tela de detalhes, `displayLocation` juntava locais com quebra de linha,
mas o texto da pílula tinha `maxLines: 1`. Assim, só o primeiro aparecia.
Agora cada local tem sua própria pílula, com quebra de linha permitida e
largura limitada à tela; a área de metadados usa Wrap também nos aparelhos
pequenos, sem comprimir todos os locais numa única linha minúscula.
Localização legada continua funcionando. Descrição, animações e botões mantidos.

Análise sem erros e 15 testes passaram, cobrindo dois locais (Sala 9 + Quadra)
em 320 × 640 e 432 × 936, descrição longa, ações e resolução das localizações.
Atualização instalada no S24 sem apagar dados. Conferência nativa da tela
de detalhes mostrou as localizações como textos separados e legíveis, em vez
de um único texto multilinha cortado. Publicação e dados dos eventos intactos.

Refinamento solicitado em seguida: a página agora mostra apenas a pílula
“Locais do evento (N)”, com seta. O toque abre uma área expandida no mesmo
formato do “Ler mais” da descrição: animação de bottom sheet, arraste para
fechar, botão fechar e lista com rolagem interna. Assim, muitos locais não
esticam a página principal. O layout do modal foi compartilhado com a
descrição, mantendo seu comportamento anterior; textos PT/EN/ES já existentes
foram reaproveitados. Localização única/legada também funciona; sem localização,
o botão não aparece. Análise sem erros e nove testes de widgets passaram,
incluindo 14 locais, tema escuro, 320 × 640, abertura/fechamento sem mover a
página e descrição longa com leitura completa.
APK de 36.965.423 bytes instalado no S24 sem apagar dados; o app foi reaberto.

Refinamento seguinte: substituída a expansão dos locais por uma faixa
horizontal diretamente na página, com cards compactos de largura natural.
O texto de cada local é completo, sem reticências; o arrasto revela o restante.
`EventHorizontalRail` agora é compartilhado com `EventBannerRail`, mantendo
a mesma `ListView.separated`, `BouncingScrollPhysics` e espaçamento 12/16.
O catálogo conserva seus tamanhos, margens, toques e ausência de máscara.
Só o slide de locais tem fade de alfa nos últimos 22 px da direita, sem blur;
o fade some ao chegar ao fim e quando todo o conteúdo já cabe na tela.
A mesma subárvore é mantida para o fade não reiniciar a posição do slide.
Não há reconstrução por pixel: apenas quando muda a presença de conteúdo à
direita. A descrição mantém “Ler mais” e seu modal. Nove testes passaram em
telas pequenas/maiores, com muitos locais, última localização legível,
posição da página intacta e local legado/ausente. Análise sem avisos.
APK de 36.965.383 bytes instalado no S24 sem apagar dados. Conferência
nativa na tela de detalhes confirmou a faixa horizontal e o fade na borda;
captura `build/event-location-horizontal-s24.png`. Dados dos eventos intactos.
Adicionado também fade de 22 px na esquerda, ativo somente quando há conteúdo
antes da posição atual. No início não esconde o primeiro card; no meio há fade
nos dois lados; no final a direita fica livre. Ambos usam uma única máscara de
alfa, sem blur adicional e sem alterar a rolagem. Nove testes passaram cobrindo
essas posições e a ausência de fades quando todo o conteúdo cabe na tela.
Versão com fade bilateral instalada no S24 sem apagar dados; app reaberto.

### Sombras nos textos dos detalhes — 14/10

Adicionada sombra ao título e sombras menores aos textos de data, horas,
localizações, descrição e “Ler mais” sobre a imagem. A intensidade é reduzida
no tema claro; cores, dimensões, animações e fades da faixa de locais foram
preservados. São sombras do próprio texto, sem BackdropFilter adicional.
Onze testes passaram nos temas claro/escuro e telas pequenas/maiores; análise
sem problemas. APK instalado no S24 sem apagar os dados.

## Histórico da versão anterior: painel lateral (substituído)

O S24 desconectou após a instalação, antes da conferência visual do painel.
A tentativa de enviar as prévias locais falhou por falta de conexão; nenhum
evento fictício foi publicado ou inserido no aparelho. A validação do fluxo
com o modelo real foi concluída na prévia WebGL local. O teste de widgets
também foi repetido usando as fontes Inter/ArchivoBlack e os dois temas do app.

Os cartões foram testados no aparelho com duas prévias em memória, sem
publicação. O toque no cartão do Didático abriu o painel e selecionou
`sala_1_did` no `didatico-p2`; janelas ocultas. Tocar em Piso 1 deixou
`didatico-p1` ativo e nenhuma sala selecionada. Tocar em Quadra voltou
ao exterior e selecionou `quadra`. Nitidez 70%, AA desligado e framebuffer
907 × 1965 preservados durante as três visitas.

As prévias foram removidas, preservando o evento real que já existia no
catálogo. Ajustes encontrados na conferência: o cartão expandido não fica
duplicado sobre a sala e a lista de outros eventos acompanha o bloco do
destino escolhido. Suíte WebGL repetida com essa regra e análise sem erros.
APK final instalado novamente no S24, sem apagar dados.

Após a última instalação, Avast One exibiu alerta genérico de app suspeito
(ID de detecção `0c12a2cc84dc`). Não foi desabilitada proteção, criada exceção
ou dispensado o alerta. Não há diagnóstico de malware/falso positivo nesta
tarefa; a conferência visual adicional após essa instalação ficou interrompida.
