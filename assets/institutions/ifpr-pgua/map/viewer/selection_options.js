// Selection switches deliberately do not depend on lighting, PBR or resolution.
export const selectionOptionTopics = [
  ['outline', 'Contorno do bloco / sala', 'Desenho das bordas; duas chamadas de renderização.'],
  ['outlineAnimation', 'Animação do contorno', 'Entrada, saída e variação de cor / espessura.'],
  ['pulse', 'Pulso de cor ao tocar', 'Coloração temporária na superfície selecionada.'],
  ['roomGlow', 'Sala acesa em degradê', 'Coloração permanente apenas na sala selecionada.'],
  ['objectFade', 'Fade ao trocar de piso', 'Transparência do bloco, pisos e janelas na troca.'],
  ['cameraAnimation', 'Câmera suave ao selecionar', 'Desligado: vai direto ao destino, sem percurso.'],
  ['labels', 'Nome do bloco / sala', 'Pílula de identificação na parte inferior.'],
  ['floors', 'Seletor de pisos', 'Pílula lateral para acessar os interiores.'],
  ['uiAnimation', 'Slide / geleia das pílulas', 'Animações das pílulas, sem alterar o mapa.'],
  ['glass', 'Blur das pílulas', 'Desfoque sobre o mapa; pode pesar durante o arrasto.'],
];

export const optimizedSelectionOptions = Object.freeze(Object.fromEntries(
  selectionOptionTopics.map(([key]) => [key, key !== 'glass']),
));

export function normalizedSelectionOptions(requested = {}, current = optimizedSelectionOptions) {
  for (const [key, value] of Object.entries(requested)) {
    if (!selectionOptionTopics.some(([name]) => name === key) || typeof value !== 'boolean') {
      throw new Error('Opção de seleção inválida.');
    }
  }
  return Object.fromEntries(selectionOptionTopics.map(([key]) =>
    [key, requested[key] ?? current[key] ?? optimizedSelectionOptions[key]],
  ));
}

export function selectionOptionsPreset(name) {
  if (name === 'optimized') return { ...optimizedSelectionOptions };
  if (name !== 'basic' && name !== 'complete') throw new Error('Preset de seleção desconhecido.');
  return Object.fromEntries(selectionOptionTopics.map(([key]) =>
    [key, name === 'complete' || key === 'labels' || key === 'floors'],
  ));
}
