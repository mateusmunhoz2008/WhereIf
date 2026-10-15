# Otimização dos balões do mapa — 14/10/2026

Escopo: balões de eventos e pilhas, sem alterar mapa, iluminação, nitidez,
antisserrilhado, tamanho escolhido, conteúdo real ou regras de seleção.
Nenhuma prévia adicionada ou escrita no banco.

## Custo encontrado

A atualização anterior projetava todas as âncoras a cada quadro, inclusive
com câmera parada. O laço lia dimensões do documento, criava objetos e uma
assinatura de texto por quadro, escrevia estilos repetidos dos cards e das
pilhas fechadas e calculava seus limites de altura. O modo normal e o gesto
com lados travados ainda pontuavam colisões desnecessariamente. No modo
automático, candidatos laterais iguais eram avaliados várias vezes.

## Alterações

- Matrizes/viewport/estado em cache: câmera parada não reprojeta, não resolve
  layout e não escreve estilos. O contador de seleção animada não obriga os
  balões a refazer trabalho.
- Itens de projeção e arrays reutilizados, sem construir assinatura de texto.
  Dimensões vêm do viewport, não da leitura de layout do documento.
- Escritas de CSS somente quando o valor muda. No pan normal, só o transform
  da âncora muda; estilos do card, ponta e pilha permanecem intactos, exceto
  quando realmente necessário para acompanhar as bordas.
- Transform das âncoras preparado para composição e layout/estilo isolados,
  sem blur, filtros novos, redução de resolução ou clipping do conteúdo.
- Pilhas criam cards/fotos somente na primeira abertura. Altura e colunas da
  pilha só são atualizadas se estiver aberta. Imagens têm dimensões explícitas.
- Normal/exterior e movimentos com lados travados não calculam colisões.
  Candidatos duplicados são descartados no modo automático.
- Transições da câmera também mantêm lados estáveis; ao terminar, o modo
  automático volta a resolver a distribuição. Não foi limitado o FPS.
- Fade interrompido mantém sua continuidade; fades já estáveis não consultam
  estilo computado, e fades sem diferença/reduced-motion não criam animações.
  Fechar/trocar pilha toca somente a pilha aberta, sem duas passagens de layout.

## Validação

Testes matemáticos e DOM cobrem 70–160%, 320/412/768 px, ajuste às bordas,
retorno da ponta ao centro, ambos os modos, entrada/saída e reversão rápida
de fades, toque, pilhas, cores e descarte. Novas verificações: 1.000 chamadas
com câmera parada não projetam nem escrevem CSS; pan simples modifica apenas
os transforms (uma escrita por âncora); pilhas fechadas não criam cards ocultos.
Suíte WebGL com o GLB real valida navegação, pisos, seleção, qualidade e pinch.

Medição reversível no S24: seis balões reais no Piso 1 do Central, tamanho
105%, nitidez 70%, AA desligado, buffer 907 × 1965. Mesma trajetória de câmera,
mesmos efeitos e mesmo conteúdo. `tools/map/profile-event-markers.mjs` separa
atualização normal, DOM oculto, DOM congelado, composição e sombras de CSS.
Todas as variantes são temporárias e câmera/modo são restaurados.

Antes: mediana da atualização dos balões no automático ~0,3 ms; depois,
~0,1 ms. Nas passagens repetidas de câmera, contagens de layout caíram de
6–9 para 0–2. FPS oscilou entre passagens (antes ~98–103 no automático,
depois ~100–118); não é uma promessa de FPS fixo nem uma medida em A24.
Arquivos: `build/popup-before-auto-profile.json` e
`build/popup-after-auto-profile.json`. Qualidade e sombras do mapa preservadas.

## Entrega nativa final

APK final de 36.965.383 bytes instalado no S24, sem apagar dados
(`map-event-balloons-13`). Última repetição: `build/popup-final-auto-profile.json`;
passagens automáticas de ~112,8 e ~119,1 FPS, atualização mediana ~0,1–0,2 ms,
0–2 recálculos de layout. Variações de FPS não isolam todos os fatores do aparelho.
No teste com eventos reais, pilhas fechadas tinham zero cards internos alocados;
abrir uma delas criou dois cards e o toque fora fechou só a pilha, preservando
piso e câmera. Tamanho 105%, modo normal, nitidez 70%, AA desligado e buffer
907 × 1965 restaurados/preservados. Captura conferida em
`build/map-popups-optimized-s24.png`. Testes matemáticos, DOM e suíte completa
com o GLB real passaram. Conexão temporária de diagnóstico fechada.
