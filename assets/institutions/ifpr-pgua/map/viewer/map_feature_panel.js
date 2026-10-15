import { selectionOptionTopics, selectionOptionsPreset } from './selection_options.js';

export const mapFeatureTopics = [
  ['lighting', '1. Luz simples'], ['pbr', '2. Materiais PBR'],
  ['shadows', '3. Sombras fixas'], ['reflections', '4. Reflexos'],
  ['textures', '5. Texturas extras'], ['shaders', '6. Shaders do app'],
  ['sky', '7. Céu e nuvens'], ['grading', '8. Cor e contraste'],
  ['bloom', '9. Bloom / brilho'], ['selection', '10. Seleção e fades'],
  ['windows', '11. Janelas básicas'], ['windowLighting', '12. Janelas completas'],
];
export function normalizedMapFeatures(requested = {}) {
  const state = Object.fromEntries(mapFeatureTopics.map(([key]) => [key, requested[key] === true]));
  if (state.windowLighting) state.windows = true;
  if (state.windows) state.pbr = true;
  if (state.reflections || state.textures || state.shaders) state.pbr = true;
  if (state.pbr || state.shadows) state.lighting = true;
  return state;
}

export function toggledMapFeatures(current, name, enabled) {
  if (!mapFeatureTopics.some(([key]) => key === name)) throw new Error('Opção desconhecida.');
  const next = { ...current, [name]: enabled === true };
  if (!enabled && name === 'windows') next.windowLighting = false;
  if (!enabled && (name === 'pbr' || name === 'lighting')) {
    next.reflections = false; next.textures = false; next.shaders = false;
    next.windows = false; next.windowLighting = false;
    if (name === 'lighting') { next.pbr = false; next.shadows = false; }
  }
  return normalizedMapFeatures(next);
}

export function createMapFeaturePanel({ state, quality, interiorEventSize=100, eventMarkerAutoLayout=true, selectionOptions, interfaceBlurEnabled, navBlurEnabled,
  onInterfaceBlurChange, onNavBlurChange, onSelectionChange,
  onQualityChange, onInteriorEventSizeChange, onEventMarkerAutoLayoutChange, onChange, onPreset, onClimate }) {
  const style = document.createElement('style');
  style.textContent = `
    #map-feature-panel{position:fixed;right:10px;top:128px;z-index:30;font:12px system-ui;color:#fff;max-width:calc(100vw - 20px)}
    #map-feature-panel button,#map-feature-panel select{font:inherit;color:inherit;background:#333;border:1px solid #666;border-radius:7px;padding:7px;cursor:pointer}
    #map-feature-panel button:disabled,#map-feature-panel select:disabled{opacity:.5;cursor:wait}
    #map-feature-panel .feature-body{width:228px;max-width:calc(100vw - 40px);max-height:min(65vh,calc(100dvh - 250px));overflow:auto;background:#171717f5;border:1px solid #555;border-radius:10px;padding:10px;margin-top:5px}
    #map-feature-panel .feature-row{display:flex;align-items:center;justify-content:space-between;padding:6px 0;gap:8px;border-bottom:1px solid #ffffff18}
    #map-feature-panel input{accent-color:#a889ff;width:17px;height:17px;margin:0;flex-shrink:0}
    #map-feature-panel .quality-section{margin-top:10px;padding-top:8px;border-top:1px solid #666}
    #map-feature-panel .quality-heading{display:flex;justify-content:space-between;align-items:center;margin:8px 0}
    #map-feature-panel input[type=range]{width:100%;height:24px}
    #map-feature-panel .quality-section select{width:100%}
    #map-feature-panel .feature-presets{display:flex;gap:5px;margin:6px 0}
    #map-feature-panel .feature-presets button{flex:1}
    #map-feature-panel .feature-note{font-size:11px;line-height:1.4;color:#ccc;margin:8px 0 0}
    #map-feature-panel .feature-status{min-height:16px;margin-top:6px;color:#d5c6ff}
    #map-feature-panel .selection-section{margin-top:10px;padding:8px;border:1px solid #817295;border-radius:9px;background:#25212c}
    #map-feature-panel .selection-detail{display:block;color:#bbb;font-size:10px;line-height:1.35;margin-top:3px}
    #map-feature-panel .selection-presets{flex-wrap:wrap}
    #map-feature-panel button[aria-pressed=true]{background:#57466e;border-color:#bc9ee7}
  `;
  document.head.appendChild(style);
  const root = document.createElement('section');
  root.id = 'map-feature-panel';
  const toggle = document.createElement('button');
  toggle.type = 'button'; toggle.textContent = 'Testes ▾'; toggle.setAttribute('aria-expanded', 'false');
  const body = document.createElement('div'); body.className = 'feature-body'; body.hidden = true;
  toggle.onclick = () => {
    body.hidden = !body.hidden;
    toggle.textContent = body.hidden ? 'Testes ▾' : 'Recolher ▴';
    toggle.setAttribute('aria-expanded', String(!body.hidden));
  };
  const heading = document.createElement('strong'); heading.textContent = 'Desempenho do mapa'; body.appendChild(heading);
  const presets = document.createElement('div'); presets.className = 'feature-presets';
  const controls = [];
  const status = document.createElement('div'); status.className = 'feature-status';
  let currentQuality = quality ?? { sharpness: 100, antialias: 'off' };
  let currentInterfaceBlur = interfaceBlurEnabled === true;
  let currentNavBlur = navBlurEnabled === true;
  let current = state;
  let disposed = false;
  async function run(operation) {
    controls.forEach(control => { control.disabled = true; });
    status.textContent = 'Preparando…';
    try {
      current = await operation();
      if (!disposed) { update(current); status.textContent = 'Pronto para medir'; }
    } catch (error) {
      if (!disposed) {
        update(current); updateSelection(currentSelection); updateQuality(currentQuality);
        updateInterfaceBlur(currentInterfaceBlur);
        updateNavBlur(currentNavBlur);
        status.textContent = `Falhou: ${error.message ?? error}`;
      }
    }
    finally { if (!disposed) controls.forEach(control => { control.disabled = false; }); }
  }
  for (const [key, label] of [['raw', 'Cru'], ['basic', 'Básico'], ['all', 'Tudo']]) {
    const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
    button.dataset.preset = key; button.onclick = () => run(() => onPreset(key));
    presets.appendChild(button); controls.push(button);
  }
  body.appendChild(presets);
  const popupSection=document.createElement('div');popupSection.className='quality-section';
  const popupLabel=document.createElement('label');popupLabel.className='quality-heading';popupLabel.htmlFor='map-interior-event-size';
  const popupName=document.createElement('span');popupName.textContent='Pop-ups internos';
  const popupValue=document.createElement('output');popupValue.htmlFor='map-interior-event-size';
  popupLabel.append(popupName,popupValue);
  const popupSize=document.createElement('input');popupSize.type='range';popupSize.id='map-interior-event-size';
  popupSize.min='70';popupSize.max='160';popupSize.step='5';popupSize.setAttribute('aria-label','Tamanho dos pop-ups internos');
  popupSize.oninput=()=>updateInteriorEventSize(onInteriorEventSizeChange?.(Number(popupSize.value))??Number(popupSize.value));
  const popupReset=document.createElement('button');popupReset.type='button';popupReset.dataset.interiorEventSizeReset='true';
  popupReset.textContent='Restaurar 100%';popupReset.onclick=()=>updateInteriorEventSize(onInteriorEventSizeChange?.(100)??100);
  const popupNote=document.createElement('p');popupNote.className='feature-note';
  popupNote.textContent='Ajuste ao vivo dos cards e pilhas dentro dos pisos. 100% é o tamanho anterior. Exterior e nitidez não mudam. Fica salvo neste aparelho.';
  const popupLayoutLabel=document.createElement('label');popupLayoutLabel.className='quality-heading';
  popupLayoutLabel.htmlFor='map-event-layout';popupLayoutLabel.textContent='Posição dos pop-ups';
  const popupLayout=document.createElement('select');popupLayout.id='map-event-layout';
  popupLayout.setAttribute('aria-label','Posição dos pop-ups');
  for(const [value,label] of [['auto','Reajuste automático'],['normal','Normal · com sobreposição']]){
    const option=document.createElement('option');option.value=value;option.textContent=label;popupLayout.appendChild(option);
  }
  popupLayout.onchange=()=>updateEventMarkerAutoLayout(onEventMarkerAutoLayoutChange?.(popupLayout.value==='auto')??popupLayout.value==='auto');
  const popupLayoutNote=document.createElement('p');popupLayoutNote.className='feature-note';
  popupLayoutNote.textContent='Automático alterna os cards internos para reduzir sobreposição. Normal mantém a posição original, mesmo sobrepostos. Ambos acompanham as bordas e ficam salvos neste aparelho.';
  popupSection.append(popupLabel,popupSize,popupReset,popupNote,popupLayoutLabel,popupLayout,popupLayoutNote);body.appendChild(popupSection);controls.push(popupSize,popupReset,popupLayout);
  const blurRow = document.createElement('label'); blurRow.className = 'feature-row';
  const blurText = document.createElement('span'); blurText.textContent = 'Blur da interface inteira';
  const blurDetail = document.createElement('small'); blurDetail.className = 'selection-detail';
  blurDetail.textContent = 'Barra inferior, botões do mapa, pílulas e sombras suaves. O blur individual das pílulas também precisa estar ligado para testá-lo.';
  blurText.appendChild(blurDetail);
  const blurInput = document.createElement('input'); blurInput.type = 'checkbox';
  blurInput.dataset.interfaceBlur = 'true';
  blurInput.onchange = () => run(async () => {
    currentInterfaceBlur = await onInterfaceBlurChange(blurInput.checked);
    return current;
  });
  blurRow.append(blurText, blurInput); body.appendChild(blurRow); controls.push(blurInput);
  const navBlurRow = document.createElement('label'); navBlurRow.className = 'feature-row';
  const navBlurText = document.createElement('span'); navBlurText.textContent = 'Blur só da barra inferior';
  const navBlurDetail = document.createElement('small'); navBlurDetail.className = 'selection-detail';
  navBlurDetail.textContent = 'Desliga apenas o filtro da navegação, para medir sua contribuição isolada.';
  navBlurText.appendChild(navBlurDetail);
  const navBlurInput = document.createElement('input'); navBlurInput.type = 'checkbox';
  navBlurInput.dataset.navBlur = 'true';
  navBlurInput.onchange = () => run(async () => {
    currentNavBlur = await onNavBlurChange(navBlurInput.checked);
    return current;
  });
  navBlurRow.append(navBlurText, navBlurInput); body.appendChild(navBlurRow); controls.push(navBlurInput);
  const selectionInputs = new Map();
  const selectionPresetButtons = new Map();
  const selectionNote = document.createElement('p'); selectionNote.className = 'feature-note';
  let currentSelection = selectionOptions;
  const selectionSection = document.createElement('div'); selectionSection.className = 'selection-section';
  const selectionHeading = document.createElement('strong'); selectionHeading.textContent = 'Seleção por partes';
  const selectionPresets = document.createElement('div'); selectionPresets.className = 'feature-presets selection-presets';
  const changeSelection = settings => run(async () => {
    currentSelection = await onSelectionChange(settings);
    if (!disposed) updateSelection(currentSelection);
    return current;
  });
  for (const [key, label] of [['basic', 'Básico'], ['optimized', 'Otimizado'], ['complete', 'Completo']]) {
    const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
    button.dataset.selectionPreset = key;
    button.onclick = () => changeSelection(selectionOptionsPreset(key));
    selectionPresets.appendChild(button); controls.push(button); selectionPresetButtons.set(key, button);
  }
  selectionSection.append(selectionHeading, selectionPresets);
  for (const [key, label, explanation] of selectionOptionTopics) {
    const row = document.createElement('label'); row.className = 'feature-row';
    const text = document.createElement('span'); text.textContent = label;
    const detail = document.createElement('small'); detail.className = 'selection-detail'; detail.textContent = explanation;
    text.appendChild(detail);
    const input = document.createElement('input'); input.type = 'checkbox'; input.dataset.selectionOption = key;
    input.onchange = () => changeSelection({ [key]: input.checked });
    row.append(text, input); selectionSection.appendChild(row); selectionInputs.set(key, input); controls.push(input);
  }
  selectionSection.appendChild(selectionNote); body.appendChild(selectionSection);
  const inputs = new Map();
  for (const [key, label] of mapFeatureTopics) {
    const row = document.createElement('label'); row.className = 'feature-row';
    const text = document.createElement('span'); text.textContent = label;
    const input = document.createElement('input'); input.type = 'checkbox'; input.dataset.feature = key;
    input.onchange = () => run(() => onChange(key, input.checked));
    row.append(text, input); body.appendChild(row); inputs.set(key, input); controls.push(input);
  }
  const qualitySection=document.createElement('div');qualitySection.className='quality-section';
  const sharpnessLabel=document.createElement('label');sharpnessLabel.className='quality-heading';
  sharpnessLabel.htmlFor='map-sharpness';
  const sharpnessName=document.createElement('span');sharpnessName.textContent='Nitidez';
  const sharpnessValue=document.createElement('output');sharpnessValue.htmlFor='map-sharpness';
  sharpnessLabel.append(sharpnessName,sharpnessValue);
  const sharpness=document.createElement('input');sharpness.type='range';sharpness.id='map-sharpness';
  sharpness.min='50';sharpness.max='125';sharpness.step='5';sharpness.setAttribute('aria-label','Nitidez do mapa');
  sharpness.oninput=()=>{sharpnessValue.textContent=`${sharpness.value}%`;};
  const changeQuality=settings=>run(async()=>{
    currentQuality=await onQualityChange(settings);
    if(!disposed)updateQuality(currentQuality);
    return current;
  });
  sharpness.onchange=()=>changeQuality({sharpness:Number(sharpness.value)});
  const antialiasLabel=document.createElement('label');antialiasLabel.className='quality-heading';
  antialiasLabel.htmlFor='map-antialias';antialiasLabel.textContent='Antisserrilhado';
  const antialias=document.createElement('select');antialias.id='map-antialias';
  antialias.setAttribute('aria-label','Antisserrilhado do mapa');
  for(const [key,label] of [['off','Desligado'],['light','Leve'],['strong','Forte']]) {
    const option=document.createElement('option');option.value=key;option.textContent=label;antialias.appendChild(option);
  }
  antialias.onchange=()=>changeQuality({antialias:antialias.value});
  const qualityNote=document.createElement('p');qualityNote.className='feature-note';
  qualityNote.textContent='100% mantém a nitidez anterior. Valores maiores renderizam mais pixels; menores aliviam a GPU. Aplicado ao soltar. Antisserrilhado suaviza as bordas e pode reduzir FPS. Nenhum deles limita FPS.';
  qualitySection.append(sharpnessLabel,sharpness,antialiasLabel,antialias,qualityNote);
  body.insertBefore(qualitySection,selectionSection.nextSibling);controls.push(sharpness,antialias);
  const climate = document.createElement('select'); climate.setAttribute('aria-label', 'Clima de teste');
  for (const [minute, label] of [[360, 'Manhã · 06h'], [720, 'Tarde · 12h'], [1050, 'Entardecer · 17h30'], [1320, 'Noite · 22h']]) {
    const option = document.createElement('option'); option.value = minute; option.textContent = label; climate.appendChild(option);
  }
  climate.value = '720'; climate.style.cssText = 'margin-top:8px;width:100%';
  climate.onchange = () => run(() => onClimate(Number(climate.value)));
  body.append(climate, status); controls.push(climate);
  const note = document.createElement('p'); note.className = 'feature-note';
  note.textContent = 'Janelas básicas: só emissão, sem luzes extras. Completas: emissão + até 4 luzes locais, sem novas sombras. A opção completa inclui a básica. Reflexos, texturas, shaders e janelas ativam PBR + luz. Após “Pronto”, mova a câmera por 15 s. Só o controle Nitidez altera a resolução.';
  body.appendChild(note); root.append(toggle, body); document.body.appendChild(root);
  function update(next) {
    current = next; for (const [key, input] of inputs) input.checked = next[key] === true;
    selectionNote.textContent = next.selection
      ? 'Básico mantém toque, nomes e acesso aos pisos, sem desenhos nem efeitos. Completo inclui blur. As opções não mudam luz, nitidez ou FPS máximo. Meça também com este painel recolhido.'
      : 'Ative “10. Seleção e fades” abaixo para testar estas partes. As escolhas ficam preservadas.';
  }
  function updateSelection(next) {
    currentSelection = next;
    for (const [key, input] of selectionInputs) input.checked = next[key] === true;
    for (const [key, button] of selectionPresetButtons) {
      const preset = selectionOptionsPreset(key);
      button.setAttribute('aria-pressed', String(selectionOptionTopics.every(([name]) => next[name] === preset[name])));
    }
  }
  function updateInterfaceBlur(next) {
    currentInterfaceBlur = next === true;
    blurInput.checked = currentInterfaceBlur;
  }
  function updateNavBlur(next) {
    currentNavBlur = next === true;
    navBlurInput.checked = currentNavBlur;
  }
  function updateQuality(next) {
    currentQuality=next;sharpness.value=next.sharpness;sharpnessValue.textContent=`${next.sharpness}%`;
    antialias.value=next.antialias;
  }
  function updateInteriorEventSize(next) {
    popupSize.value=next;popupValue.textContent=`${next}%`;
    popupSize.setAttribute('aria-valuetext',`${next}%`);
  }
  function updateEventMarkerAutoLayout(next) {
    popupLayout.value=next===false?'normal':'auto';
  }
  update(state);
  updateSelection(selectionOptions);
  updateInterfaceBlur(interfaceBlurEnabled);
  updateNavBlur(navBlurEnabled);
  updateQuality(currentQuality);
  updateInteriorEventSize(interiorEventSize);
  updateEventMarkerAutoLayout(eventMarkerAutoLayout);
  return { update, updateSelection, updateInterfaceBlur, updateNavBlur, updateQuality, updateInteriorEventSize, updateEventMarkerAutoLayout,
    dispose() { disposed = true; root.remove(); style.remove(); } };
}
