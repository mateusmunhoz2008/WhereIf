# Seleção e navegação do mapa — 12/10/2026

## Diagnóstico no S24

Condições: release, DPR 3 (1296 × 2808), nitidez 100%, antisserrilhado e
bloom desligados; luz simples, PBR, sombras, shaders, céu, seleção e janelas
básicas ligados. Câmera do Central repetida na mesma trajetória.

Dois custos independentes foram identificados:

- O contorno antigo refazia uma máscara e filtrava até 25 amostras por pixel.
  No Central, a região chegou a ocupar quase todo o framebuffer.
- As pílulas de identificação e pisos acrescentavam filtros de desfoque sobre
  o WebView. Escondê-las, mantendo a seleção 3D, também aumentou o FPS.

Na medição que isolou interface e contorno, seleção completa: 88–89 FPS;
sem interface de seleção: 97–101; sem interface e contorno: aproximadamente 119.
Esses últimos casos são controles diagnósticos, não os padrões do aplicativo.

## Implementação

- Contorno por stencil e faixas instanciadas nas bordas, sem máscaras/arestas
  em render targets de cor e sem filtro fullscreen de texturas.
- Uma máscara agrupada e uma chamada para as faixas, independentemente da
  quantidade de objetos do piso. A geometria auxiliar é preparada uma vez;
  movimentos de câmera não a recriam.
- Preenchimento de janelas e frestas de fachadas apenas no stencil, sem alterar
  o GLB, os materiais visíveis, o raycast ou a geometria de navegação.
- Transformação de câmera calculada uma vez por desenho. Shader sem discard
  para permitir rejeição antecipada pelo stencil.
- Desfoque adicional removido só das sobreposições de seleção e pisos.
  Cores, gradientes, bordas, sombras, dimensões e animações permanecem;
  os demais componentes de vidro do aplicativo não mudam.
- Seleções completamente fora do campo de visão são descartadas pelo frustum.

## Verificação final

Seleção completa: 95–101 FPS; referência sem interface/contorno: 101–105.
A diferença média entre os dois casos foi de aproximadamente 5 FPS, contra
aproximadamente 30 no teste anterior. As taxas absolutas variaram entre os
testes: não interpretar como garantia de 120 FPS, nem extrapolar ao A24.

Foi instalado o APK final no S24, preservando dados e preferências. Não houve
limite novo de FPS nem redução da resolução do mapa. Temporários da medição
foram removidos e o horário de calibração foi limpo.

Verificações automatizadas: cores/qualidade, janelas/grades sem contorno
interno, navegação de pisos/salas, picking do Central/Didático, shader sem
erros, estilos e animações das pílulas, análise dos arquivos Flutter alterados.

Ferramenta reversível: `tools/map/profile-selection-runtime.mjs`.
Opções: `--motion`, `--compare-outlines`, `--selection-ui` e `--edge-detail`.
Não tocar nos controles durante uma medição; mudanças invalidam o perfil.
O contador do mapa mede frames renderizados, enquanto os perfis usam uma
trajetória controlada com requestAnimationFrame. Temporizadores GPU não
estavam disponíveis no WebView do S24; não reportar tempo GPU baseado em FPS.

## Teste de blur da interface

O painel agora oferece dois interruptores: “Blur da interface inteira” e
“Blur só da barra inferior”. O primeiro remove os BackdropFilter das
superfícies do mapa e da barra, além das sombras desfocadas da interface;
o segundo permite isolar a barra. O controle individual de blur das pílulas
continua independente, subordinado ao interruptor geral. Ambos começam
ligados, não alteram os efeitos do GLB e não são salvos nas preferências.
Fora da rota do mapa, o visual da navegação continua normal. O ganho de FPS
da barra inferior deve ser medido no aparelho no mesmo ângulo e movimento.

## Seleção desmembrada para testes

O painel Testes agora possui “Seleção por partes”, independente das opções
de iluminação e nitidez. Dez interruptores: contorno, animação do contorno,
pulso de cor, degradê da sala selecionada, fades de pisos/janelas, animação
de foco da câmera, identificação, seletor de pisos, animação das pílulas e blur.

- Básico: toque, foco direto, identificação e acesso aos pisos. Sem contorno,
  materiais de seleção, fades, percurso da câmera ou animações das pílulas.
- Otimizado: a configuração anterior, com efeitos e sem blur extra. É o padrão.
- Completo: todos os itens, inclusive o blur opcional das pílulas.

Trocar um interruptor não reconstrói iluminação nem redefine câmera, clima,
piso ou sala. O contorno desligado deixa de renderizar; brilho e pulso
desligados restauram materiais reais; fade desligado não clona materiais
transparentes. Os controles nativos recebem as opções pelo MapBridge, somente
quando elas mudam, não a cada frame. As opções de teste não são persistidas.
Para medir, recolher o painel e repetir o mesmo movimento de câmera.

Testes: dez opções/presets e validação de entradas; toggles na interface com
o mapa real; preservação de sala/câmera/iluminação; contorno sem render calls;
brilho isolado; troca de pisos sem fades/foco animado; blur nativo opcional;
cancelamento da geleia no meio do slide. Dez testes Flutter passaram, junto
com análise estática e os testes reais do mapa e de picking.
