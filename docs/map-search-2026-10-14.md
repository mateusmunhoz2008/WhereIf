# Pesquisa do mapa — 14/10/2026

- A lupa antes mostrava apenas “em breve”. Agora consulta um índice local de
  blocos, pisos, salas e eventos publicados, não encerrados e com localização
  válida, usando o mesmo catálogo dos balões. Não há buscas novas no Firestore
  nem leitura do GLB durante a digitação.
- Botão sólido preto/branco conforme o tema. O campo se revela para a esquerda
  em 290 ms e pede foco no primeiro frame, junto à abertura do teclado. Fecha em
  210 ms; resultados usam fade/slide de 180 ms e saída de 120 ms. Movimento
  reduzido do sistema é respeitado.
- Eventos mostram só o título, com a paleta dos balões. Lugares mostram o nome
  e, quando há, a origem (piso/bloco) menor abaixo. Cores de eventos são estáveis
  durante a busca. Nomes sem acentos também encontram os locais.
- Selecionar fecha a pesquisa e usa `navigateToMapLocation`, inclusive para
  pisos/salas. Evento com vários locais leva ao primeiro local válido salvo.
  Nenhum dado do evento é alterado. Fechar/cancelar invalida seleções pendentes;
  toques repetidos não disparam duas navegações.
- Digitação agrupada em 90 ms, índice normalizado reutilizado, resultados
  grandes com criação sob demanda, sem blur ou animações contínuas. Listas de
  até quatro resultados encolhem com animação de altura; a área disponível
  considera teclado e também hosts que já redimensionam o conteúdo.

Validação: suíte do mapa com 52 testes passou; depois do ajuste de altura,
os 13 testes específicos da pesquisa passaram novamente. Cobertura de temas
claro/escuro, 320 × 568, 432 × 936, tablet, paisagem, teclado, filtros,
cancelamento, toques rápidos, movimento reduzido e destinos estáveis.
Primeira versão instalada no S24 sem apagar dados; confirmado teclado
automático, busca por Quadra e navegação real para ela. Presets do mapa,
nitidez, efeitos e dados remotos preservados.

Versão final com painel compacto instalada no S24 sem apagar dados; análise
sem problemas. Teclado automático e painel de um único resultado conferidos
no aparelho (`build/map-search-final-s24.png`). Não foram criadas prévias nem
publicados eventos durante a validação.

## Refinamento de tamanho e entrada

A pedido do usuário, a entrada passou a 520 ms com `easeInOutCubic` (saída
permanece em 210 ms). Campo sem borda em todos os estados, com altura mínima
de 54 pixels lógicos. Cards com mínimo de 84, padding vertical 20/horizontal
16 e título de 15. Eventos agora mostram o primeiro local válido como
subtítulo de 12, com 55% da opacidade do texto principal; é o mesmo destino
usado ao selecionar. Pisos e salas conservam sua origem abaixo do nome.
Painel compacto, lista sob demanda e adaptações ao teclado preservados.
Quatorze testes específicos passaram, incluindo abertura ainda em andamento
aos 200 ms com campo já focado, ausência de borda e hierarquia dos subtítulos.
Análise sem problemas. Refinamento instalado no S24 sem apagar dados e sem
trazer o app para frente, pois outro aplicativo estava em uso.

Nos cards coloridos de eventos, título, subtítulo e ícone agora permanecem
brancos nos dois temas. Mantidos os níveis de opacidade: título 100%, ícone
85% e subtítulo 55%. Cards de lugares e campo continuam seguindo o tema.
Quatorze testes passaram com verificações explícitas dessas cores; análise
sem problemas.

Textos dos cards de eventos receberam sombra difusa estática, com raio de
10 no título e 7 no subtítulo, deslocamento de apenas 1 pixel e preto
translúcido. Constantes reutilizadas, sem filtro de fundo. Cores, tamanhos e
estilos dos lugares preservados; os 14 testes específicos passaram.
