// Captured from the S24 on 2026-10-12. Percentage sharpness remains hardware
// relative; this is a graphics preset, not an FPS cap or a different GLB.
export const performanceMapPreset = Object.freeze({
  features: Object.freeze({
    lighting:true,pbr:false,shadows:false,reflections:false,textures:false,
    shaders:false,sky:false,grading:false,bloom:false,selection:true,
    windows:false,windowLighting:false,
  }),
  quality: Object.freeze({sharpness:65,antialias:'off'}),
  selectionOptions: Object.freeze({
    outline:false,outlineAnimation:false,pulse:false,roomGlow:true,
    objectFade:false,cameraAnimation:true,labels:true,floors:true,
    uiAnimation:false,glass:false,
  }),
  interfaceBlurEnabled:false,navBlurEnabled:false,
});

export function matchesPerformancePreset(settings) {
  return Object.entries(performanceMapPreset).every(([key,value]) =>
    typeof value==='object'
      ? Object.entries(value).every(([name,expected]) => settings?.[key]?.[name]===expected)
      : settings?.[key]===value);
}

const normalKey = 'whereif.map.normalRenderSettings.v1';
export function readNormalRenderPreferences(fallback) {
  try {
    const value=JSON.parse(localStorage.getItem(normalKey));
    return value&&value.features&&value.quality&&value.selectionOptions ? value : fallback;
  }catch{return fallback;}
}
export function saveNormalRenderPreferences(settings) {
  try{localStorage.setItem(normalKey,JSON.stringify(settings));}catch{}
}
