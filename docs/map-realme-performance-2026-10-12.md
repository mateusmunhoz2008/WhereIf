# Entrada e FPS do mapa no Realme — 12/10/2026

Dispositivo medido: RMX5020, Android 16, MT6769 / Mali-G52 MC2,
tela 720 × 1604 com modos de 50, 60, 90 e 120 Hz. APK release.

## O que foi encontrado

- A combinação visual aprovada era preparada em toda entrada. O botão Cru
  só a desligava depois; os controles não sobreviviam à recriação da WebView.
- A preparação de todos os contornos antes da primeira imagem levou cerca de
  13,4 segundos. O recarregamento completo da WebView levou 20,7 segundos.
- O aparelho anunciava 8 GB de RAM ao navegador e recebia DPR 3, apesar da
  GPU Mali-G52 e da tela com DPR nativo 2. RAM não identifica o custo da GPU.
- No cru, com todos os blurs desligados e framebuffer 540 × 1203, a medida
  inicial em movimento foi aproximadamente 54 FPS.

## Mudanças verificadas

- Contornos dos seis exteriores e três pisos são preparados durante a
  geração do app, usando o mesmo algoritmo. SHA-256 do GLB e layout dos pisos
  impedem o uso do cache com outro modelo. O importador reconstrói o cache.
- O cache é descompactado apenas se a seleção estiver habilitada. O cru não
  prepara contornos, materiais PBR, shaders, céu, janelas nem sombras.
- Combinação de efeitos, seleção, nitidez, antisserrilhado e controles de
  blur são guardados no armazenamento local da WebView.
- GPUs limitadas conhecidas deixam de receber supersampling em DPR 3.
  O S24 conserva seu orçamento anterior. No Realme foi preservado o
  framebuffer anterior de 540 × 1203: 75% do novo DPR nativo 2.
- O Android recebe uma solicitação para o maior modo da tela na mesma
  resolução enquanto a página do mapa está ativa. A solicitação anterior
  é restaurada ao sair/pausar. Nenhuma configuração global de tela foi
  alterada para tentar forçar o FPS.

## Medidas após a atualização

Recarregamentos da WebView, sem incluir a inicialização fria do app nem
as animações Flutter de entrada/saída:

| Caso | Tempo até o mapa pronto |
| --- | ---: |
| Versão anterior, combinação aprovada | 20,7 s |
| Versão corrigida, combinação aprovada | 5,8 s |
| Versão corrigida, cru | 3,3 s |

Com a combinação aprovada, a etapa de contornos caiu para aproximadamente
0,6 s. A transferência do mapa ainda ocupa cerca de 1,1–1,6 s.

No teste de movimento em 2D, o cru mediu cerca de 57 FPS no framebuffer
anterior e 58 FPS na resolução nativa. A WebView sem renderizar o mapa também
mediu aproximadamente 60 callbacks de animação por segundo. A tela chegou
a operar a 120 Hz, e o Android registrou o pedido de 120 Hz, mas isso não
liberou de forma sustentada 120 callbacks/FPS nesta WebView. Este limite
restante não foi resolvido; não atribuir essa medida a iluminação ou afirmar
que a versão passou a renderizar a 120 FPS.

O GLB continua byte a byte intacto (SHA-256
`522b9afda2b8cdbf1f8271786051f9047662672a65075a3007477d7a301566cd`).
O cache acrescentou aproximadamente 1,7 MB ao APK universal, em troca de
retirar a preparação pesada de geometria do celular.

Verificação: igualdade dos buffers, índices, bordas e esferas dos contornos;
invalidação do cache por modelo/layout; persistência e recuperação de
preferências; orçamento de GPU; ida e volta exata da transferência do GLB;
prévia WebGL com todos os efeitos, blocos, pisos, salas e reset cru;
dez testes Flutter de carregamento/seleção/blur; análise Flutter sem erros.

Essa primeira atualização foi instalada no Realme sem apagar dados. Modo cru
e blur desligado foram restaurados depois desses testes. Para repetir a entrada, usar
`tools/map/profile-map-loading.mjs` com a WebView exposta por ADB.

## Continuação: preservar o visual escolhido

Configuração capturada antes de atualizar novamente e conferida no APK novo:

- Luz simples, PBR, sombras, shaders, céu, seleção e janelas básicas ligados.
- Reflexos adicionais, texturas procedurais, tratamento de cor, bloom e luzes
  completas das janelas desligados.
- Nitidez 70%, antisserrilhado desligado, DPR 1,4 e framebuffer 503 × 1122.
- Blur da interface e da navegação desligados. Contorno, pulso, salas,
  fades, movimento de câmera e troca de pisos continuam disponíveis.
- Preferências salvas no aparelho têm prioridade sobre os padrões.

O GLB, os presets de clima e os limites de zoom continuam iguais. Nesta etapa
não houve nova redução de resolução, geometria, sombras ou efeitos aprovados.

Trabalho retirado sem alterar o resultado:

- Os oito raios usados nos limites da câmera e o polígono permitido são
  reutilizados durante deslocamentos que preservam a orientação/projeção.
  Rotação, zoom, altura, limites e enquadramento invalidam esse cache.
- Limites retangulares dos interiores não calculam raios que não utilizam.
- A transferência continua em blocos de 64 KB, mas cede a execução por
  pequenas fatias de trabalho em vez de aguardar 2 ms após cada mensagem.
- A leitura do cache de seleção evita uma chamada de função por byte.
- O shader não calcula halos de luar durante o dia nem transmissão da copa
  quando sua contribuição seria exatamente zero. As fórmulas ativas,
  intensidades e cores continuam iguais.

Validação: 240 estados de câmera em perspectiva/ortográfica contra o cálculo
sem cache, invalidação de zoom/rotação, transferência exata do GLB, cache de
seleção, orçamento de GPU, limites 2D, prévia WebGL completa, dez testes
Flutter e análise do componente sem erros.

APK release ARM64 atualizado instalado no Realme sem apagar os dados.
Um recarregamento da WebView com a combinação escolhida mediu 4,35 s.
É uma amostra, não uma garantia de tempo de abertura fria do app.

No mesmo piso `didatico-p2`, câmera e qualidade da captura, o teste de rotação
mediu 59,3–60 FPS, com 64 chamadas de desenho e mediana de envio CPU de
3,6–4,3 ms. Antes desta etapa o mesmo teste mediu 57,9–59,9 FPS e
4,3–5,1 ms. As faixas se sobrepõem: não interpretar como grande ganho de FPS
nem como liberação de 120 FPS. O contador visual conta uma renderização
completa; `renderer.info.render.frame` conta passes e não serve como FPS.

Também foi compilada e instalada uma comparação com Hybrid Composition
direta (`MAP_DIRECT_COMPOSITION=true`). Na rotação real, o relógio da WebView
ficou em 58,4 callbacks/s e o contador visual em 59 FPS, versus 57,3 callbacks/s
no caminho padrão. Com o mapa sem desenhar, a alternativa ainda mediu
59,96 callbacks/s, apesar do pedido de 120 Hz confirmado na janela Android.
Não houve ganho relevante nem liberação de 120 FPS; o APK padrão otimizado
foi reinstalado. A alternativa não está habilitada por padrão.

APK final ARM64: `build/app/outputs/flutter-apk/app-release.apk`, 36.948.171 bytes,
SHA-256 `719d73530b2f4f4773309ea369110f620a7f706d45e90c891a18e2a7032a82a0`.

## Correção posterior: contorno nas janelas

A grade colorida foi reproduzida no Central. A exclusão buscava apenas
objetos `janelas_preset_*` associados pelo nome ao bloco, embora o GLB
também tenha janelas em grupos compartilhados e em malhas com outros nomes.
Além disso, a máscara ignorava aberturas entre somente duas peças de fachada
ou em painéis pequenos. As arestas apareciam através dessas lacunas.

- Identificação das malhas de janela pelo material, incluindo grupos
  compartilhados. Seus triângulos são recortados à região do bloco antes de
  preencher a máscara; janelas de outro prédio não ampliam a seleção.
- Malhas exclusivamente de janela nunca fornecem linhas visíveis.
- Aberturas entre peças coplanares pequenas são fechadas somente na máscara.
  Uma fachada côncava única mantém seu recorte real.
- Cache e bundle regenerados. O trabalho continua pré-calculado, com uma
  máscara em stencil e um lote de linhas, sem blur ou passes de textura.
  O cache comprimido ficou em 1.506.192 bytes. GLB e presets não foram alterados.

Teste do mesmo GLB/ângulo usando o cache extraído do APK anterior: 1.043 pixels
coloridos nas duas faixas internas de janelas verificadas no Central, contra
zero na correção. Contorno externo visível, abertura pequena entre duas
peças sem grade e recorte côncavo preservado. Prévia dos cinco exteriores,
igualdade do cache/runtime, isolamento de janelas compartilhadas e suíte
WebGL de efeitos/seleção/pisos/salas passaram.

APK release corrigido instalado no S24 (`RQCX406HKYE`) sem apagar os dados.
O aparelho estava sendo usado para testar os modos básicos durante a
verificação final; as escolhas de efeitos do usuário não foram sobrescritas.
Nitidez capturada do S24: 80%, sem antisserrilhado e com blurs desligados.

## Preset salvo como modo desempenho

Captura posterior solicitada pelo usuário, não a combinação gráfica anterior:
nitidez 65%, antisserrilhado desligado; luz simples e seleção ligadas; PBR,
sombras, reflexos, texturas, shaders, céu, tratamento de cor, bloom, janelas
iluminadas e luzes adicionais desligados. Seleção mantém sala acesa, câmera
suave, nomes e pisos; contorno, pulso, fade de objetos, animação das pílulas e
todos os blurs desligados. Esse perfil está em `map_performance_preset.js`.

O interruptor **Modo desempenho** fica junto de Clima nas configurações.
A escolha usa SharedPreferences (`map.performanceMode`) e é aplicada antes
da preparação do modelo. Na primeira abertura, o estado anterior da WebView
é migrado sem substituir uma configuração diferente do perfil capturado.
Ao ativar, a configuração normal é guardada na WebView; ao desligar, ela é
restaurada. Sem backup, volta à combinação normal aprovada. Edições manuais
dos controles saem do preset nomeado; botões de diagnóstico continuam presentes.
Não há troca de GLB, limite de FPS nem alteração de clima, tema, idioma ou ângulos.

Correções adicionais pedidas no mesmo turno:

- Todo objeto exportado `janelas_preset_*` é ocultado imediatamente antes do
  trabalho de troca de piso, mesmo com o recurso de iluminação das janelas
  desligado. Janelas não participam do fade; ao voltar, restaura-se sua
  visibilidade anterior.
- Materiais-base preparados dos interiores são reaplicados após reconstruir
  os efeitos gráficos e ao reabrir o piso: azul nas salas, verde nos labs,
  bege nos banheiros. O destaque da sala selecionada continua separado.

Verificação: persistência e cliques rápidos do controlador; botão nas três
línguas e nos dois temas; modo exato, recarga persistente, prioridade da escolha
nativa na inicialização, restauração do normal, janelas ocultas antes do fade
completo e no modo leve, cores mantidas após refazer materiais; suíte WebGL
de efeitos/pisos/salas; análise Flutter sem erros.

APK release ARM64 instalado no S24 sem apagar dados. Conferência na WebView
do aparelho: modo desempenho ativo, nitidez 65%, antisserrilhado e blurs
desligados. No Didático P2, janelas exportadas já invisíveis imediatamente
após iniciar a troca; salas `4d596a`, labs `415e5a` e banheiros `5c574c`.
Captura de tela confirmou a distinção visual. Retorno ao exterior restaurou
as janelas e a câmera anterior, mantendo o preset ativo.

## Qualidade uniforme, sem perfil automático de aparelho fraco

A pedido do usuário, removidas as reduções automáticas baseadas em RAM,
número de núcleos, nome da GPU ou modelo de celular. Todos os aparelhos
usam a mesma escala de nitidez escolhida manualmente (base DPR 3), sem teto
especial de pixels, e sombras de 2048 quando habilitadas. Removidos também
o antigo teste de aparelho fraco, sua ponte Flutter e seu limite de 30 FPS.
O nome da GPU e os avisos de pouca memória continuam sendo apenas dados
de diagnóstico, sem alterar a renderização.

O modo desempenho manual nas configurações e seu preset de 65% permanecem
inalterados, assim como as preferências já salvas. Não foram removidas as
otimizações de carregamento, caches ou renderização sob demanda.

Verificação: qualidade idêntica para RAM/CPU ausentes ou diferentes, quatro
nitidezes e quatro resoluções/DPRs; ausência dos mecanismos antigos no bundle
e na ponte Flutter; suíte WebGL com modo desempenho, seleção, pisos e cores;
cache de contornos e análise Flutter sem erros.
