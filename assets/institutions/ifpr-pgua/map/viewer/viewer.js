import * as THREE from './vendor/three.module.min.js';
import { OrbitControls } from './vendor/controls/OrbitControls.js';
import { GLTFLoader } from './vendor/loaders/GLTFLoader.js';
import { EffectComposer } from './vendor/postprocessing/EffectComposer.js';
import { OutputPass } from './vendor/postprocessing/OutputPass.js';
import { RenderPass } from './vendor/postprocessing/RenderPass.js';
import { ShaderPass } from './vendor/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from './vendor/postprocessing/UnrealBloomPass.js';
import { createNightCinema } from './night_cinema.js';
import { createInteriorNavigation } from './interior_navigation.js';
import { createFpsCounter } from './fps_counter.js';
import { createSelectionOutline, createTextureSelectionOutline } from './selection_outline.js';
import { createMobileBloom } from './mobile_bloom.js';
import { createMapAntialias, normalizedMapQuality } from './map_antialias.js';
import { createMapFeaturePanel, normalizedMapFeatures, toggledMapFeatures, mapFeatureTopics } from './map_feature_panel.js';
import { normalizedSelectionOptions, optimizedSelectionOptions } from './selection_options.js';
import { readRenderPreferences, saveRenderPreferences } from './render_preferences.js';
import { loadSelectionCache } from './selection_cache.js';
import { createNavigationOffsetCache } from './navigation_cache.js';
import { collectSelectionWindowMeshes } from './selection_geometry_outline.js';
import { performanceMapPreset, matchesPerformancePreset, readNormalRenderPreferences, saveNormalRenderPreferences } from './map_performance_preset.js';
import { createMapEventMarkers, normalizedInteriorEventSize } from './map_event_markers.js';

const viewerEvents = new AbortController();
const tuning = window.WHEREIF_MAP_TUNING ?? {};
const geometryOnly = window.WHEREIF_GEOMETRY_ONLY === true;
let basicLightingTest = geometryOnly && window.WHEREIF_BASIC_LIGHTING === true;
const featurePanelEnabled = geometryOnly && window.WHEREIF_FEATURE_PANEL === true;
const savedRenderPreferences = readRenderPreferences();
let interiorEventSize = normalizedInteriorEventSize(savedRenderPreferences.interiorEventSize);
let eventMarkerAutoLayout = savedRenderPreferences.eventMarkerAutoLayout !== false;
let performanceModeEnabled = typeof savedRenderPreferences.performanceModeEnabled==='boolean'
  ? savedRenderPreferences.performanceModeEnabled : matchesPerformancePreset(savedRenderPreferences);
const initialRenderPreferences = performanceModeEnabled ? performanceMapPreset : savedRenderPreferences;
let performanceModeApplying = false;
let performanceModeQueue = Promise.resolve();
let testFeatures = normalizedMapFeatures(featurePanelEnabled
  ? initialRenderPreferences.features ?? tuning.renderer?.approvedMapFeatures ?? { lighting: basicLightingTest }
  : { lighting: basicLightingTest });
let featurePanel = null;
let featureApplyQueue = Promise.resolve();
let featureBusy = false;
const testMaterialSources = new Map();
const testOwnedMaterials = new Set();
const testGrassColors = new Map();
const testInteriorParents = new Map();
const testInteriorNodes = new Map();
const rendererTuning = tuning.renderer ?? {};
const approvedFeatureAppearance = rendererTuning.approvedFeatureAppearance ?? {};
const cameraTuning = tuning.camera ?? {};
const controlsTuning = tuning.controls ?? {};
const lightingTuning = tuning.lighting ?? {};
const nightSkyTuning = lightingTuning.nightSky ?? {};
const selectionTuning = tuning.selection ?? {};
let selectionOptions;
try { selectionOptions = normalizedSelectionOptions(initialRenderPreferences.selectionOptions); }
catch { selectionOptions = normalizedSelectionOptions(); }
let interfaceBlurEnabled = initialRenderPreferences.interfaceBlurEnabled ?? tuning.renderer?.approvedInterfaceBlur ?? true;
let navBlurEnabled = initialRenderPreferences.navBlurEnabled ?? tuning.renderer?.approvedNavBlur ?? true;
let selectionPreparedCache = null;
let selectionCacheLoader = null;
const postProcessingTuning = rendererTuning.postProcessing ?? {};
const nightLook = lightingTuning.nightLook ?? {};
const defaultNightLook = { ...nightLook };
const defaultToneMapping = rendererTuning.toneMapping ?? 'aces';
const defaultBloom = { ...postProcessingTuning.bloom };
const materialTextureStates = new WeakMap();
let texturesEnabled = nightLook.textures !== false;
let nightCinema = null;

const graphicsProfileStorageKey = 'whereif.map.graphicsProfile';
// One map profile for every device, including devices with an old saved choice.
const savedGraphicsProfile = 'basic';
let graphicsProfile = 'basic';
// Quality is selected by the user, never inferred from RAM, GPU or phone model.
// Keep the same approved resolution and shadow budget on every device.
const renderBudget = {
  pixels: Infinity,
  maxRatio: 3,
  shadowSize: 2048,
};
let mapQuality;
try { mapQuality = normalizedMapQuality(initialRenderPreferences.quality ?? rendererTuning.approvedMapQuality); }
catch { mapQuality = normalizedMapQuality(); }
let initialAntialias = mapQuality.antialias;
mapQuality.antialias = 'off';
let mapAntialias = null;
let qualityApplyQueue = Promise.resolve();

function hardwarePixelRatio() {
  return renderBudget.maxRatio;
}

function budgetPixelRatio() {
  return THREE.MathUtils.clamp(hardwarePixelRatio() * mapQuality.sharpness / 100, .5, 4);
}

function applyBasicGraphicsTuning() {
  rendererTuning.maxPixelRatio = budgetPixelRatio();
  rendererTuning.interactionPixelRatio = rendererTuning.maxPixelRatio;
  rendererTuning.environmentIntensity = Math.min(
    rendererTuning.environmentIntensity ?? 0.42,
    0.42,
  );
  const atmosphere = lightingTuning.atmosphere ??= {};
  atmosphere.enabled = true;
  atmosphere.resolution = 560;
  const shadows = lightingTuning.shadows ??= {};
  shadows.enabled = true;
  shadows.mapSize = renderBudget.shadowSize;
  (lightingTuning.groundRays ??= {}).enabled = false;
  (lightingTuning.sunProjection ??= {}).enabled = false;
}

function applyCinematicGraphicsTuning() {
  rendererTuning.maxPixelRatio = 4;
  rendererTuning.interactionPixelRatio = 1.6;
  const atmosphere = lightingTuning.atmosphere ??= {};
  atmosphere.enabled = true;
  atmosphere.resolution = 720;
  const shadows = lightingTuning.shadows ??= {};
  shadows.enabled = true;
  shadows.mapSize = 4096;
}

function applyBalancedGraphicsTuning() {
  rendererTuning.maxPixelRatio = Math.min(
    rendererTuning.maxPixelRatio ?? 1.35,
    1.6,
  );
  rendererTuning.interactionPixelRatio = Math.min(
    rendererTuning.interactionPixelRatio ?? 0.75,
    0.75,
  );
  const atmosphere = lightingTuning.atmosphere ??= {};
  atmosphere.enabled = true;
  atmosphere.resolution = Math.min(atmosphere.resolution ?? 720, 720);
}

if (graphicsProfile === 'basic') applyBasicGraphicsTuning();
if (graphicsProfile === 'balanced') applyBalancedGraphicsTuning();
if (graphicsProfile === 'cinematic') applyCinematicGraphicsTuning();

const scene = new THREE.Scene();
const perspectiveCamera = new THREE.PerspectiveCamera(cameraTuning.fov ?? 42, 1, 0.1, 5000);
const topCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 5000);
let camera = perspectiveCamera;
let mapViewMode = '3d';
let topViewHalfHeight = 1;
let mapEventNavigationRequest = 0;
let mapEventNavigationQueue = Promise.resolve();

function updatePerspectiveProjection(viewCamera) {
  viewCamera.updateProjectionMatrix();
  const verticalShift = cameraTuning.verticalLensShift ?? 0;
  if (!viewCamera.isPerspectiveCamera || !Number.isFinite(verticalShift)) return;
  viewCamera.projectionMatrix.elements[9] += verticalShift;
  viewCamera.projectionMatrixInverse.copy(viewCamera.projectionMatrix).invert();
}
const renderer = new THREE.WebGLRenderer({
  antialias: graphicsProfile === 'cinematic',
  alpha: false,
  stencil: true,
  precision: 'highp',
  powerPreference: 'high-performance',
});
const gpuInfo = renderer.getContext().getExtension('WEBGL_debug_renderer_info');
const gpuName = gpuInfo ? String(renderer.getContext().getParameter(gpuInfo.UNMASKED_RENDERER_WEBGL)) : '';
applyBasicGraphicsTuning();

const toneMappings = {
  aces: THREE.ACESFilmicToneMapping,
  agx: THREE.AgXToneMapping,
  cineon: THREE.CineonToneMapping,
  linear: THREE.LinearToneMapping,
  neutral: THREE.NeutralToneMapping,
  reinhard: THREE.ReinhardToneMapping,
};

function applyToneMapping(name) {
  const normalizedName = String(name ?? 'aces').toLowerCase();
  renderer.toneMapping = toneMappings[normalizedName] ?? toneMappings.aces;
  rendererTuning.toneMapping = toneMappings[normalizedName]
    ? normalizedName
    : 'aces';
}

function setToneMapping(name) {
  applyToneMapping(name);
  requestRender();
}

renderer.setPixelRatio(
  Math.min(
    window.devicePixelRatio || 1,
    rendererTuning.maxPixelRatio ?? 1.5,
  ),
);
renderer.outputColorSpace = THREE.SRGBColorSpace;
applyToneMapping(rendererTuning.toneMapping);
renderer.toneMappingExposure = rendererTuning.exposure ?? 0.88;
renderer.shadowMap.enabled = !geometryOnly && (lightingTuning.shadows?.enabled ?? true);
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.shadowMap.autoUpdate = false;
document.body.appendChild(renderer.domElement);
const fpsCounter = createFpsCounter(window.WHEREIF_SHOW_FPS === true);
const eventAnchorCache = new Map();
let mapEvents = [];
let pendingMarkerPointer = null;
function forwardMapPointer(event,target) {
  const forwarded=new PointerEvent('pointerdown',{bubbles:false,cancelable:true,
    pointerId:event.pointerId,pointerType:event.pointerType,isPrimary:event.isPrimary,
    clientX:event.clientX,clientY:event.clientY,button:event.button,buttons:event.buttons,
    pressure:event.pressure});
  forwarded.mapMarkerTarget=target;
  renderer.domElement.dispatchEvent(forwarded);
  renderer.domElement.setPointerCapture(event.pointerId);
}
function forwardPendingMarkerPointer() {
  const pending=pendingMarkerPointer;pendingMarkerPointer=null;
  if(pending)forwardMapPointer(pending.event,pending.target);
}
const eventMarkers = createMapEventMarkers({
  onPointerDown(event,target) {
    if(event.pointerType!=='touch'||viewTransition)return;
    if(event.isPrimary){pendingMarkerPointer={event,target};return;}
    if(pendingMarkerPointer){forwardPendingMarkerPointer();forwardMapPointer(event,target);}
    else if(cameraPointerIds.size>0)forwardMapPointer(event,target);
  },
  onPointerEnd(event) {
    if(pendingMarkerPointer?.event.pointerId===event.pointerId)pendingMarkerPointer=null;
  },
  interiorSize: interiorEventSize,
  autoLayout: eventMarkerAutoLayout,
  anchorFor(location,floor) {
    const key=floor ? `${floor.id}/${location.spaceNodeName??''}` : location.zoneId;
    if(eventAnchorCache.has(key))return eventAnchorCache.get(key);
    const space=floor?.spaces.find(entry=>entry.nodeName===location.spaceNodeName);
    const bounds=space?.bounds??floor?.bounds;
    const zone=config?.zones.find(entry=>entry.id===location.zoneId);
    const node=zone?zoneNodes.get(zone.nodeName):null;
    const box=bounds??(node?new THREE.Box3().setFromObject(node):null);
    if(!box || box.isEmpty())return null;
    const anchor=box.getCenter(new THREE.Vector3());anchor.y=box.max.y+1.5;
    eventAnchorCache.set(key,anchor);return anchor;
  },
  onSelected:payload=>send('eventSelected',payload),
});

const objectFades = new Set();
function prepareObjectFade(objects, from) {
  // The basic selection path must not allocate transparent material copies.
  if (!selectionOptions.objectFade) return { cleanup() {}, start: () => Promise.resolve() };
  const copies = new Map();
  const meshes = [];
  const visited = new Set();
  const copyFor = source => {
    if (!copies.has(source)) {
      const material = source.clone();
      material.onBeforeCompile = source.onBeforeCompile.bind(source);
      material.customProgramCacheKey = source.customProgramCacheKey.bind(source);
      material.transparent = true;
      material.depthWrite = false;
      material.forceSinglePass = true;
      copies.set(source, { material, opacity: source.opacity });
    }
    return copies.get(source).material;
  };
  for (const object of objects) object.traverse(mesh => {
    if (!mesh.isMesh || mesh.userData.interiorSpace?.marker === mesh) return;
    if (visited.has(mesh)) return;
    visited.add(mesh);
    meshes.push({ mesh, material: mesh.material });
    mesh.material = Array.isArray(mesh.material) ? mesh.material.map(copyFor) : copyFor(mesh.material);
  });
  const setOpacity = amount => {
    for (const state of copies.values()) state.material.opacity = state.opacity * amount;
  };
  setOpacity(from);
  const fade = { startedAt: Infinity, from, to: from, duration: 180, setOpacity, cleaned: false,
    resolve: null, cleanup() {
      if (fade.cleaned) return;
      fade.cleaned = true;
      for (const state of meshes) state.mesh.material = state.material;
      for (const state of copies.values()) state.material.dispose();
      objectFades.delete(fade);
      fade.resolve?.();
    }, start(to) {
      fade.to = to;
      fade.startedAt = performance.now();
      requestRender();
      return new Promise(resolve => { fade.resolve = resolve; });
    } };
  objectFades.add(fade);
  return fade;
}

function updateObjectFades(time) {
  let animating = false;
  for (const fade of objectFades) {
    if (!Number.isFinite(fade.startedAt)) continue;
    const progress = Math.min(1, (time - fade.startedAt) / fade.duration);
    const eased = progress * progress * (3 - 2 * progress);
    fade.setOpacity(fade.from + (fade.to - fade.from) * eased);
    if (progress < 1) animating = true;
    else {
      fade.startedAt = Infinity;
      fade.resolve?.();
      fade.resolve = null;
    }
  }
  return animating;
}

let effectComposer = null;
let mobileBloom = null;
let sceneRenderPass = null;
let bloomPass = null;
let cinematicGradePass = null;
const materialEnvironmentIntensities = new WeakMap();
const materialNightFinishes = new WeakMap();
const balancedMaterialCache = new WeakMap();

const cinematicGradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    warmColor: { value: new THREE.Color('#ff9d37') },
    warmStrength: { value: 0 },
    warmStart: { value: 0.08 },
    warmEnd: { value: 0.72 },
    neutralWarmResponse: { value: 0.22 },
    contrast: { value: 1 },
    saturation: { value: 1 },
    temperature: { value: 0 },
    atmosphereTexture: { value: null },
    atmosphereBaseColor: { value: new THREE.Color('#090a0d') },
    surfaceRayStrength: { value: 0 },
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;

    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: /* glsl */`
    uniform sampler2D tDiffuse;
    uniform vec3 warmColor;
    uniform float warmStrength;
    uniform float warmStart;
    uniform float warmEnd;
    uniform float neutralWarmResponse;
    uniform float contrast;
    uniform float saturation;
    uniform float temperature;
    uniform sampler2D atmosphereTexture;
    uniform vec3 atmosphereBaseColor;
    uniform float surfaceRayStrength;
    varying vec2 vUv;

    float gradeLuminance(vec3 color) {
      return dot(color, vec3(0.2126, 0.7152, 0.0722));
    }

    void main() {
      vec4 sampleColor = texture2D(tDiffuse, vUv);
      vec3 color = sampleColor.rgb;
      float originalLuminance = gradeLuminance(color);

      // The same world-projected rays used by the sky are applied very lightly
      // to visible surfaces. This keeps the shafts anchored to the sun instead
      // of turning them into a camera-facing reflection.
      vec3 atmosphere = texture2D(atmosphereTexture, vUv).rgb;
      vec3 surfaceRays = max(atmosphere - atmosphereBaseColor, vec3(0.0));
      float surfaceMask = smoothstep(0.015, 0.18, originalLuminance);
      float highlightGuard = 1.0 - smoothstep(0.72, 1.45, originalLuminance);
      color += surfaceRays * surfaceRayStrength * surfaceMask * highlightGuard;

      float warmMask = smoothstep(warmStart, warmEnd, originalLuminance);
      float greenDominance = smoothstep(
        0.0,
        0.16,
        color.g - max(color.r, color.b)
      );
      float surfaceResponse = mix(
        neutralWarmResponse,
        1.0,
        greenDominance
      );
      float warmLuminance = max(gradeLuminance(warmColor), 0.001);
      vec3 warmTarget = warmColor * (originalLuminance / warmLuminance) * 1.04;
      color = mix(
        color,
        warmTarget,
        warmMask * warmStrength * surfaceResponse
      );

      float filterLuminance = gradeLuminance(color);
      vec3 temperatureGain = mix(vec3(0.68, 1.0, 1.35),
        vec3(1.35, 1.0, 0.68), temperature * 0.5 + 0.5);
      temperatureGain = mix(vec3(1.0), temperatureGain, abs(temperature));
      color *= temperatureGain;
      color *= filterLuminance / max(gradeLuminance(color), 0.00001);
      float gradedLuminance = gradeLuminance(color);
      color = mix(vec3(gradedLuminance), color, saturation);
      color = (color - vec3(0.18)) * contrast + vec3(0.18);
      gl_FragColor = vec4(max(color, vec3(0.0)), sampleColor.a);
    }
  `,
};

function installPostProcessing({ debug = false } = {}) {
  if (geometryOnly && !debug) return;
  const bloom = postProcessingTuning.bloom ?? {};
  if (effectComposer || mobileBloom) return;
  if (debug && testFeatures.bloom && !testFeatures.grading) {
    mobileBloom = createMobileBloom(renderer, bloom);
    bloomPass = mobileBloom;
    return;
  }

  effectComposer = new EffectComposer(renderer);
  if (renderer.capabilities.isWebGL2) {
    const context = renderer.getContext();
    const supportedSamples = context.getParameter(context.MAX_SAMPLES) ?? 0;
    // HDR + four MSAA samples duplicated across ping-pong targets was the
    // largest allocation. Pixel coverage provides smoothing at a fixed budget.
    const requestedSamples = 0;
    const samples = Math.min(requestedSamples, supportedSamples);
    effectComposer.renderTarget1.samples = samples;
    effectComposer.renderTarget2.samples = samples;
  }
  sceneRenderPass = new RenderPass(scene, camera);
  effectComposer.addPass(sceneRenderPass);
  if (!debug || testFeatures.bloom) {
    bloomPass = new UnrealBloomPass(
      new THREE.Vector2(1, 1),
      bloom.strength ?? 0.72,
      bloom.radius ?? 0.46,
      bloom.threshold ?? 0.72,
    );
    // Bloom only processes color; depth attachments serve no purpose here.
    for (const target of [bloomPass.renderTargetBright,
      ...bloomPass.renderTargetsHorizontal, ...bloomPass.renderTargetsVertical]) {
      target.depthBuffer = false;
      target.stencilBuffer = false;
    }
    const sizeBloom = bloomPass.setSize.bind(bloomPass);
    bloomPass.setSize = (width, height) => sizeBloom(
      Math.max(1, Math.round(width * 0.5)), Math.max(1, Math.round(height * 0.5)));
    effectComposer.addPass(bloomPass);
  }
  if (!debug || testFeatures.grading) {
    cinematicGradePass = new ShaderPass(cinematicGradeShader);
    cinematicGradePass.uniforms.atmosphereTexture.value = atmosphereTexture;
    effectComposer.addPass(cinematicGradePass);
  }
  effectComposer.addPass(new OutputPass());
}

function configureBloom(settings = {}) {
  const bloom = postProcessingTuning.bloom ??= {};
  Object.assign(bloom, settings);
  if (!bloomPass && bloom.enabled !== false) {
    installPostProcessing();
    resize();
    applyDaylightProfile();
  }
  if (!bloomPass) return;
  bloomPass.enabled = bloom.enabled !== false;
  bloomPass.strength = bloom.strength ?? 0.72;
  bloomPass.radius = bloom.radius ?? 0.46;
  bloomPass.threshold = bloom.threshold ?? 0.72;
  requestRender();
}

function updateDaylightBloom(profile) {
  if (!bloomPass || !profile) return;
  const settings = postProcessingTuning.bloom ?? {};
  const sunlightAmount = THREE.MathUtils.smoothstep(
    profile.rays?.opacity ?? 0,
    0.012,
    0.10,
  );
  bloomPass.enabled = settings.enabled !== false &&
    (!settings.nightOnly || nightSkyAmount() > 0.001);
  const baseStrength = THREE.MathUtils.lerp(
    settings.strength ?? 0.25,
    settings.sunlightStrength ?? 0.56,
    sunlightAmount,
  );
  const baseRadius = THREE.MathUtils.lerp(
    settings.radius ?? 0.24,
    settings.sunlightRadius ?? 0.34,
    sunlightAmount,
  );
  const baseThreshold = THREE.MathUtils.lerp(
    settings.threshold ?? 0.93,
    settings.sunlightThreshold ?? 0.72,
    sunlightAmount,
  );
  const directViewSettings = settings.directSunView ?? {};
  const directViewAmount = (profile.rays?.opacity ?? 0) > 0.001 ? directSunViewAmount(
    projectedSunPosition(),
    directViewSettings,
  ) : 0;
  bloomPass.strength = baseStrength * THREE.MathUtils.lerp(
    1,
    directViewSettings.strengthScale ?? 0.76,
    directViewAmount,
  );
  bloomPass.radius = baseRadius * THREE.MathUtils.lerp(
    1,
    directViewSettings.radiusScale ?? 0.80,
    directViewAmount,
  );
  bloomPass.threshold = THREE.MathUtils.lerp(
    baseThreshold,
    directViewSettings.threshold ?? baseThreshold,
    directViewAmount,
  );
}

function updateDirectSunExposure(profile) {
  if (!profile) return;
  const directViewSettings =
    postProcessingTuning.bloom?.directSunView ?? {};
  const directViewAmount = (profile.rays?.opacity ?? 0) > 0.001 ? directSunViewAmount(
    projectedSunPosition(),
    directViewSettings,
  ) : 0;
  renderer.toneMappingExposure = profile.exposure * THREE.MathUtils.lerp(
    1,
    directViewSettings.exposureScale ?? 0.78,
    directViewAmount,
  );
}

const selectionOutline = createSelectionOutline(renderer,{preparedFor:node=>selectionPreparedCache?.[node.name],windowNodesFor:node=>{
  const zone=config?.zones.find(zone=>zoneNodes.get(zone.nodeName)===node);
  return zone ? selectionWindowMeshes : [];
}});
const pickingTarget = new THREE.WebGLRenderTarget(1, 1, {
  minFilter: THREE.NearestFilter,
  magFilter: THREE.NearestFilter,
  format: THREE.RGBAFormat,
  depthBuffer: true,
  stencilBuffer: false,
});
const pickingColors = [0xff0000, 0x00ff00, 0x0000ff];
const pickingMaterials = pickingColors.map(
  (color) =>
    new THREE.MeshBasicMaterial({
      color,
      side: THREE.DoubleSide,
      toneMapped: false,
    }),
);
const outlineMaterial = selectionOutline.material;
const outlineScene = selectionOutline.scene;
const outlineCamera = selectionOutline.camera;

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = false;
controls.rotateSpeed = controlsTuning.rotateSpeed ?? 0.62;
controls.zoomSpeed = controlsTuning.zoomSpeed ?? 0.82;
controls.panSpeed = controlsTuning.panSpeed ?? 0.58;
controls.minPolarAngle = controlsTuning.minPolarAngle ?? 0.2;
controls.maxPolarAngle = controlsTuning.maxPolarAngle ?? Math.PI * 0.48;
controls.screenSpacePanning = false;
controls.touches.ONE =
  controlsTuning.oneFingerAction === 'pan'
    ? THREE.TOUCH.PAN
    : THREE.TOUCH.ROTATE;
controls.touches.TWO =
  controlsTuning.twoFingerAction === 'rotate'
    ? THREE.TOUCH.DOLLY_ROTATE
    : THREE.TOUCH.DOLLY_PAN;

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const zoneNodes = new Map();

let config = null;
let previewLocalTimeMinutes = null;
let daylightPreviewOverrides = null;
let morningLook = {};
const defaultMiddayLook = { ...rendererTuning.approvedMiddayLook };
let middayLook = { ...defaultMiddayLook };
const defaultSunsetLook = { ...rendererTuning.approvedSunsetLook };
let sunsetLook = { ...defaultSunsetLook };
const savedSkySettings = {
  midday: { ...rendererTuning.middaySky },
  sunset: { ...rendererTuning.sunsetSky },
  morning: { ...rendererTuning.morningSky },
};
function isSunset() { const m = localTimeMinutes(); return m >= 990 && m < 1140; }
function isMidday() { const m = localTimeMinutes(); return m >= 660 && m < 990; }
function isDayCustomization() { return isMorning() || isMidday() || isSunset(); }
// Sample the approved lighting once per period; clock time only selects a period.
function presetTimeMinutes() {
  if (isMorning()) return 360;
  if (isMidday()) return 720;
  if (isSunset()) return 1080;
  return 1260;
}
function activeColorTemperature() {
  const look = isSunset() ? sunsetLook : isMidday() ? middayLook : isMorning() ? morningLook : nightLook;
  return THREE.MathUtils.clamp(look.temperature ?? 0, -1, 1);
}
function effectiveMorningLook() {
  if (isSunset()) return { reflections: rendererTuning.sunsetEnvironmentScale ?? 4.5,
    wetness: 0, floorRoughness: 0.82, textureDetail: 1,
    sunHighlights: 1, textures: true, ...sunsetLook };
  if (isMidday()) return { reflections: 1, wetness: 0,
    floorRoughness: 0.82, textureDetail: 1, sunHighlights: 1,
    textures: true, ...middayLook };
  const preset = rendererTuning.approvedDawnSurface;
  const amount = phaseEnvelope(presetTimeMinutes(), preset ?? {});
  const defaults = { reflections: rendererTuning.dawnSurface?.environmentScale ?? 8,
    wetness: rendererTuning.dawnSurface?.pavement?.clearcoat ?? 0.65,
    floorRoughness: rendererTuning.dawnSurface?.pavement?.roughness ?? 0.27,
    textureDetail: 1.65, sunHighlights: 1, textures: true };
  for (const [key, value] of Object.entries(preset?.values ?? {})) {
    if (typeof value === 'number') defaults[key] = THREE.MathUtils.lerp(defaults[key], value, amount);
  }
  return { ...defaults, ...morningLook };
}
function isMorning() { const m = localTimeMinutes(); return m >= 330 && m < 660; }
let model = null;
let interiors = null;
let interiorLoading = false;
let interiorRequest = 0;
let exteriorNavigation = null;
let rawModeEnabled = false;
const rawMaterialStates = [];
const rawMaterials = new Set();
const rawBackground = new THREE.Color('#303030');
let pointerStart = null;
const cameraPointerIds = new Set();
let initialCameraPosition = null;
let initialTarget = null;
let initialAzimuth = null;
let lastSentBearing = null;
let lastCameraStateSentAt = 0;
let resettingCamera = null;
let viewTransition = null;
let hemisphereLight = null;
let ambientLight = null;
let keyLight = null;
let fillLight = null;
const sunProjectionLights = [];
const groundSunRayMeshes = [];
let groundSunRayMaterial = null;
let reflectionEnvironment = null;
let reflectionEnvironmentFaces = [];
let lightingFrame = null;
let activeDaylightProfile = null;
let shadowViewSignature = '';
let lastShadowViewUpdateAt = 0;
let atmosphereCanvas = null;
let atmosphereContext = null;
let atmosphereTexture = null;
let atmospherePaintSignature = null;
let nightSkyPoints = null;
let nightSkyMaterial = null;
let middaySkyMesh = null;
let sunsetSkyMesh = null;
let morningSkyMesh = null;
const materialBaseFinishes = new WeakMap();
const windowPresetGroups = new Map();
let selectionWindowMeshes = [];
const windowGlowLights = [];
const windowOwnedMaterials = new Set();
let animationFrame = null;
let viewerDisposed = false;
let viewerSuspended = false;
let diagnosticsEnabled = false;
let diagnosticsTimer = null;
let diagnosticsGpuExtension = null;
let diagnosticsGpuQuery = null;
let diagnosticsGpuMs = null;
let diagnosticsRenderMaxMs = 0;
let diagnosticsStage = 'Criando renderizador';
let diagnosticsStageStartedAt = performance.now();
const loadingStages = [];

function configureDiagnostics(enabled) {
  diagnosticsEnabled = enabled;
  if (!enabled || diagnosticsTimer !== null) return;
  const gl = renderer.getContext();
  diagnosticsGpuExtension = gl.getExtension('EXT_disjoint_timer_query_webgl2');
  renderer.info.autoReset = false;
  diagnosticsTimer = setInterval(() => {
    if (viewerDisposed) return;
    send('diagnostics', diagnosticsSnapshot());
    diagnosticsRenderMaxMs = 0;
  }, 2000);
}

function diagnosticsSnapshot() {
  const gl = renderer.getContext();
  if (diagnosticsGpuQuery && diagnosticsGpuExtension) {
    const disjoint = gl.getParameter(diagnosticsGpuExtension.GPU_DISJOINT_EXT);
    const available = gl.getQueryParameter(diagnosticsGpuQuery, gl.QUERY_RESULT_AVAILABLE);
    if (available || disjoint) {
      if (!disjoint) diagnosticsGpuMs = gl.getQueryParameter(diagnosticsGpuQuery, gl.QUERY_RESULT) / 1e6;
      else diagnosticsGpuMs = null;
      gl.deleteQuery(diagnosticsGpuQuery);
      diagnosticsGpuQuery = null;
    }
  }
  return { stage: diagnosticsStage, renderCpuMaxMs: diagnosticsRenderMaxMs,
    framesRendered: renderer.info.render.frame,
    gpuAvailable: diagnosticsGpuExtension !== null, gpuMaxMs: diagnosticsGpuMs,
    drawCalls: renderer.info.render.calls, triangles: renderer.info.render.triangles,
    textures: renderer.info.memory.textures, geometries: renderer.info.memory.geometries,
    pixelRatio: renderer.getPixelRatio(), shadowMapSize: renderer.shadowMap.enabled ? keyLight?.shadow.mapSize.x ?? 0 : 0,
    pixelBudget: renderBudget.pixels,
    gpuName, geometryOnly, basicLightingTest,
    loadingStages: [...loadingStages],
    testStage: geometryOnly ? (basicLightingTest ? 'basic-lighting' : 'raw') : 'full',
    rawMode: rawModeEnabled,
    msaaSamples: rawModeEnabled ? 0 : effectComposer?.renderTarget1.samples ?? 0 };
}

function recordLoadingStage(stage) {
  const now = performance.now();
  const previousStageMs = now - diagnosticsStageStartedAt;
  loadingStages.push({ stage: diagnosticsStage, ms: Math.round(previousStageMs) });
  diagnosticsStage = stage;
  diagnosticsStageStartedAt = now;
  if (diagnosticsEnabled) send('diagnostics', { ...diagnosticsSnapshot(), previousStageMs });
}
let selectedMeshes = [];
let selectedMaterialStates = [];
let selectedMaterialCache = new WeakMap();
const selectionVariantMaterials = new Set();
let selectionState = null;
let selectedZoneId = null;
let lastFocusedZoneId = null;
let cameraMovedSinceFocus = true;
let multiTouchGesture = false;
let navigationBounds = null;
let navigationTargetHeight = null;
let navigationHull = [];
let navigationEdges = [];
let navigationInset = 0;
const navigationOffsetCache = createNavigationOffsetCache();
const navigationPolygonCache = new WeakMap();
const emptyNavigationOffsets = [];
let navigationSpring = null;
let cameraFocus = null;
let controlsInteractionActive = false;
let resolutionRestoreTimer = null;
let shadowUpdateResumeAt = 0;
let interactionStartedAt = 0;
let interactionFrameCount = 0;
let lastPerformanceReportAt = 0;
let lastPerformanceFrameCount = 0;
let suppressNextControlsEnd = false;
let navigationConstraintSuspended = false;
let baseMinDistance = 0;
let baseMaxDistance = Infinity;

function send(type, payload = {}) {
  if (!window.MapBridge?.postMessage) return;
  window.MapBridge.postMessage(JSON.stringify({ type, ...payload }));
}

function normalizedBearingDegrees(value) {
  return ((value + 180) % 360 + 360) % 360 - 180;
}

function currentBearingDegrees() {
  if (initialAzimuth === null) return 0;
  const azimuth = Math.atan2(camera.position.x - controls.target.x,
    camera.position.z - controls.target.z);
  return normalizedBearingDegrees(
    THREE.MathUtils.radToDeg(azimuth - initialAzimuth),
  );
}

function sendCameraState({ force = false } = {}) {
  if (initialAzimuth === null) return;
  const now = performance.now();
  if (!force && now - lastCameraStateSentAt < 48) return;
  const bearing = currentBearingDegrees();
  const change = lastSentBearing === null
    ? Infinity
    : Math.abs(normalizedBearingDegrees(bearing - lastSentBearing));
  if (!force && change < 0.08) return;
  lastSentBearing = bearing;
  lastCameraStateSentAt = now;
  send('camera', { bearing });
}

function beginManualCameraGesture() {
  if (viewTransition) return;
  resettingCamera = null;
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  cameraMovedSinceFocus = true;
  enableElasticDistanceBounds();
}

function clearControlsMomentum() {
  const dampingEnabled = controls.enableDamping;
  controls.enableDamping = false;
  controls.update();
  controls.enableDamping = dampingEnabled;
}

function cssColor(value, fallback) {
  return typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value)
    ? value
    : fallback;
}

function findModelNode(root, nodeName) {
  const namedNode = root.getObjectByName(nodeName);
  if (namedNode) return namedNode;

  let originalNameNode = null;
  root.traverse((object) => {
    if (!originalNameNode && object.userData?.name === nodeName) {
      originalNameNode = object;
    }
  });
  return originalNameNode;
}

function releaseSelectedMaterials() {
  for (const state of selectedMaterialStates) {
    state.mesh.material = state.originalMaterial;
    for (const entry of state.materials) {
      if (entry.owned) entry.material.dispose();
    }
  }
  selectedMaterialStates = [];
}

function releaseSelectedMeshes() {
  selectionOutline.clear();
  for (const mesh of selectedMeshes) mesh.layers.disable(1);
  releaseSelectedMaterials();
  selectedMeshes = [];
}

function disposeSelectionVariants() {
  for (const material of selectionVariantMaterials) material.dispose();
  selectionVariantMaterials.clear();
  selectedMaterialCache = new WeakMap();
}

function isWindowSelectionPart(mesh, material) {
  const name = `${mesh?.name ?? ''} ${material?.name ?? ''}`.toLowerCase();
  return /window|janela/.test(name);
}

function prepareSelectedMaterial(mesh) {
  const originalMaterial = mesh.material;
  const sourceMaterials = Array.isArray(originalMaterial)
    ? originalMaterial
    : [originalMaterial];
  const materials = sourceMaterials.map((source) => {
    if (isWindowSelectionPart(mesh, source)) {
      return { material: source, effectUniforms: null, owned: false };
    }
    const cached = selectedMaterialCache.get(source);
    if (cached) {
      const uniforms = cached.effectUniforms;
      uniforms.colorA.value.copy(selectionState.accentColor);
      uniforms.colorB.value.copy(selectionState.flashColor);
      uniforms.roomColorA.value.copy(selectionState.accentColor);
      uniforms.roomColorB.value.copy(selectionState.accentColor).multiplyScalar(0.42);
      uniforms.roomMin.value.copy(selectionState.roomBounds?.min ?? new THREE.Vector3());
      if (selectionState.roomBounds) selectionState.roomBounds.getSize(uniforms.roomSize.value);
      else uniforms.roomSize.value.set(1, 1, 1);
      uniforms.intensity.value = uniforms.light.value = 0;
      return cached;
    }
    const material = source.clone();
    // Three.js does not clone shader callbacks. Preserve surface lighting
    // and its original baselines before adding the selection animation.
    if (materialEnvironmentIntensities.has(source)) {
      materialEnvironmentIntensities.set(material, materialEnvironmentIntensities.get(source));
    }
    if (materialNightFinishes.has(source)) {
      materialNightFinishes.set(material, materialNightFinishes.get(source));
    }
    const effectUniforms = {
      colorA: { value: selectionState.accentColor.clone() },
      colorB: { value: selectionState.flashColor.clone() },
      intensity: { value: 0 },
      light: { value: 0 },
      lightBrightness: { value: 0.78 },
      roomColorA: { value: selectionState.accentColor.clone() },
      roomColorB: { value: selectionState.accentColor.clone().multiplyScalar(0.42) },
      roomMin: { value: selectionState.roomBounds?.min.clone() ?? new THREE.Vector3() },
      roomSize: { value: selectionState.roomBounds?.getSize(new THREE.Vector3()) ?? new THREE.Vector3(1, 1, 1) },
      phase: { value: 0 },
      frequency: {
        value: selectionTuning.flashSpatialFrequency ?? 0.075,
      },
    };
    const sourceOnBeforeCompile = source.onBeforeCompile.bind(source);
    const sourceProgramCacheKey = source.customProgramCacheKey.bind(source);
    material.onBeforeCompile = (shader, webGlRenderer) => {
      sourceOnBeforeCompile(shader, webGlRenderer);
      shader.uniforms.whereIfSelectionColorA = effectUniforms.colorA;
      shader.uniforms.whereIfSelectionColorB = effectUniforms.colorB;
      shader.uniforms.whereIfSelectionIntensity = effectUniforms.intensity;
      shader.uniforms.whereIfSelectionLight = effectUniforms.light;
      shader.uniforms.whereIfSelectionLightBrightness = effectUniforms.lightBrightness;
      shader.uniforms.whereIfRoomColorA = effectUniforms.roomColorA;
      shader.uniforms.whereIfRoomColorB = effectUniforms.roomColorB;
      shader.uniforms.whereIfRoomMin = effectUniforms.roomMin;
      shader.uniforms.whereIfRoomSize = effectUniforms.roomSize;
      shader.uniforms.whereIfSelectionPhase = effectUniforms.phase;
      shader.uniforms.whereIfSelectionFrequency = effectUniforms.frequency;
      shader.vertexShader = `
        varying vec3 vWhereIfSelectionWorldPosition;
        ${shader.vertexShader}
      `.replace(
        '#include <worldpos_vertex>',
        `
          #include <worldpos_vertex>
          vWhereIfSelectionWorldPosition =
            (modelMatrix * vec4(transformed, 1.0)).xyz;
        `,
      );
      shader.fragmentShader = `
        uniform vec3 whereIfSelectionColorA;
        uniform vec3 whereIfSelectionColorB;
        uniform float whereIfSelectionIntensity;
        uniform float whereIfSelectionLight;
        uniform float whereIfSelectionLightBrightness;
        uniform vec3 whereIfRoomColorA;
        uniform vec3 whereIfRoomColorB;
        uniform vec3 whereIfRoomMin;
        uniform vec3 whereIfRoomSize;
        uniform float whereIfSelectionPhase;
        uniform float whereIfSelectionFrequency;
        varying vec3 vWhereIfSelectionWorldPosition;
        ${shader.fragmentShader}
      `.replace(
        '#include <dithering_fragment>',
        `
          if (whereIfSelectionIntensity > 0.0001) {
          float whereIfSelectionWave = 0.5 + 0.5 * sin(
            (vWhereIfSelectionWorldPosition.x +
              vWhereIfSelectionWorldPosition.z * 0.72) *
              whereIfSelectionFrequency -
              whereIfSelectionPhase
          );
          float whereIfSelectionBlend = smoothstep(
            0.08,
            0.92,
            whereIfSelectionWave
          );
          vec3 whereIfSelectionColor = mix(
            whereIfSelectionColorA,
            whereIfSelectionColorB,
            whereIfSelectionBlend
          );
          gl_FragColor.rgb = mix(
            gl_FragColor.rgb,
            whereIfSelectionColor,
            whereIfSelectionIntensity
          );
          }
          if (whereIfSelectionLight > 0.0001) {
          vec3 whereIfRoomPosition = (vWhereIfSelectionWorldPosition - whereIfRoomMin)
            / max(whereIfRoomSize, vec3(0.01));
          float whereIfRoomGradient = smoothstep(0.0, 1.0,
            whereIfRoomPosition.x * 0.55 + whereIfRoomPosition.z * 0.45);
          vec3 whereIfRoomLight = mix(whereIfRoomColorA, whereIfRoomColorB,
            whereIfRoomGradient) * whereIfSelectionLightBrightness;
          gl_FragColor.rgb = mix(gl_FragColor.rgb, whereIfRoomLight, whereIfSelectionLight);
          }
          #include <dithering_fragment>
        `,
      );
    };
    material.customProgramCacheKey = () =>
      `${sourceProgramCacheKey()}-whereif-selection-gradient-v3`;
    material.needsUpdate = true;
    const entry = {
      material,
      effectUniforms,
      owned: false,
    };
    selectedMaterialCache.set(source, entry);
    selectionVariantMaterials.add(material);
    return entry;
  });
  mesh.material = Array.isArray(originalMaterial)
    ? materials.map((entry) => entry.material)
    : materials[0].material;
  selectedMaterialStates.push({ mesh, originalMaterial, materials });
}

function updateSelectedMaterialGradient(intensity, phase, light = 0) {
  const useComposer = effectComposer &&
    (bloomPass?.enabled || isDayCustomization() || activeColorTemperature() !== 0);
  for (const state of selectedMaterialStates) {
    for (const entry of state.materials) {
      if (!entry.effectUniforms) continue;
      entry.effectUniforms.intensity.value = intensity;
      entry.effectUniforms.phase.value = phase;
      entry.effectUniforms.light.value = light;
      entry.effectUniforms.lightBrightness.value = 0.78 /
        (useComposer ? Math.max(0.1, renderer.toneMappingExposure) : 1);
    }
  }
}

function clearSelection({ animate = true } = {}) {
  selectedZoneId = null;
  if (!selectionState) return;
  if (animate && selectionOptions.outlineAnimation) {
    selectionState.leavingAt ??= performance.now();
  } else {
    releaseSelectedMeshes();
    selectionState = null;
    outlineMaterial.uniforms.outlineOpacity.value = 0;
  }
  requestRender();
}

function startSelectionEffect(node, { lit = false } = {}) {
  clearSelection({ animate: false });
  selectionState = {
    node,
    effectsSettled: false,
    startedAt: performance.now(),
    restingLight: lit && selectionOptions.roomGlow ? 0.68 : 0,
    room: lit,
    roomBounds: lit ? new THREE.Box3().setFromObject(node) : null,
    leavingAt: null,
    startColor: new THREE.Color(
      cssColor(selectionTuning.startColor, '#ffffff'),
    ),
    accentColor: new THREE.Color(
      cssColor(config.accentColor, '#a64cff'),
    ),
    flashColor: new THREE.Color(
      cssColor(config.selectionFlashColor, '#ff435f'),
    ),
    effectColor: new THREE.Color(),
  };
  node.traverse((object) => {
    if (!object.isMesh || !object.geometry) return;
    if (object.userData.interiorSpace?.marker === object) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    if (materials.every((material) => isWindowSelectionPart(object, material))) {
      return;
    }
    if ((lit && selectionOptions.roomGlow) ||
        (selectionOptions.pulse && (selectionTuning.flashIntensity ?? 0) > 0)) {
      prepareSelectedMaterial(object);
    }
    if (selectionOptions.outline) object.layers.enable(1);
    selectedMeshes.push(object);
  });
  if (selectionOptions.outline) selectionOutline.select(node);
  updateSelectionEffects(performance.now());
  requestRender();
}

function selectZone(zoneId) {
  if (rawModeEnabled && !(featurePanelEnabled && testFeatures.selection)) return false;
  const zone = config.zones.find((entry) => entry.id === zoneId);
  const node = zone ? zoneNodes.get(zone.nodeName) : null;
  if (!zone || !node) {
    clearSelection();
    send('selected');
    return true;
  }
  if (selectedZoneId === zone.id && selectionState?.leavingAt === null) {
    clearSelection();
    send('selected');
    return true;
  }

  const shouldFocus =
    lastFocusedZoneId !== zone.id || cameraMovedSinceFocus;

  startSelectionEffect(node);
  selectedZoneId = zone.id;

  if (shouldFocus) {
    focusNode(node, zone.focus);
    lastFocusedZoneId = zone.id;
    cameraMovedSinceFocus = false;
  }
  requestRender();
  send('selected', { zoneId: zone.id });
  return !shouldFocus;
}

function findZoneForObject(object) {
  let current = object;
  while (current) {
    for (const zone of config.zones) {
      if (zoneNodes.get(zone.nodeName) === current) return zone;
    }

    current = current.parent;
  }
  return null;
}

function interiorDirection(zoneId) {
  const focus = config?.zones.find((zone) => zone.id === zoneId)?.focus;
  if (Array.isArray(focus?.position) && Array.isArray(focus?.target)) {
    const direction = new THREE.Vector3().fromArray(focus.position)
      .sub(new THREE.Vector3().fromArray(focus.target));
    if (direction.lengthSq() > 1e-6) return direction.normalize();
  }
  if (Array.isArray(focus?.direction)) {
    const direction = new THREE.Vector3().fromArray(focus.direction);
    if (direction.lengthSq() > 1e-6) return direction.normalize();
  }
  return camera.position.clone().sub(controls.target).normalize();
}

function interiorRoomDirection(zoneId) {
  const direction = interiorDirection(zoneId);
  const minimum = cameraTuning.interiorRoomMinElevationDegrees?.[zoneId];
  if (!Number.isFinite(minimum)) return direction;
  const horizontal = Math.hypot(direction.x, direction.z);
  if (horizontal < 1e-6) return direction;
  const elevation = THREE.MathUtils.degToRad(THREE.MathUtils.clamp(minimum, 0, 85));
  // Preserve the saved azimuth, and raise only views below the room minimum.
  direction.y = Math.max(direction.y, Math.tan(elevation) * horizontal);
  return direction.normalize();
}

function selectInteriorSpace(space) {
  if(!interiors?.current)return;
  interiors.select(space);
  if(space){
    startSelectionEffect(space.node,{lit:true});
    focusNode(space.node,{useVisualCenter:true,
      direction:interiorRoomDirection(interiors.current.zoneId).toArray(),
      distanceScale:cameraTuning.interiorRoomDistanceScales?.[interiors.current.zoneId]??1.25});
  }else clearSelection();
  sendInteriorState();requestRender();
}

function navigateToMapLocation(location) {
  const request=++mapEventNavigationRequest;
  const run=mapEventNavigationQueue.catch(()=>{}).then(async()=>{
    while(!viewerDisposed && (modelLoading || interiorLoading || featureBusy))await yieldLoadingWork();
    if(viewerDisposed || request!==mapEventNavigationRequest)return false;
    const zone=config?.zones.find(entry=>entry.id===location?.zoneId);
    const node=zone?zoneNodes.get(zone.nodeName):null;
    const floor=location?.floorId?interiors?.floors.get(location.floorId):null;
    const space=location?.spaceNodeName?floor?.spaces.find(entry=>entry.nodeName===location.spaceNodeName):null;
    if(!node || (location.floorId && (!floor || floor.zoneId!==zone.id)) ||
       (location.spaceNodeName && !space))return false;
    if(interiors?.current && interiors.current.zoneId!==zone.id)exitInterior({focus:false});
    selectedZoneId=zone.id;send('selected',{zoneId:zone.id});
    if(floor){
      await setInteriorFloor(zone.id,floor.id);
      if(viewerDisposed || request!==mapEventNavigationRequest)return false;
      if(interiors?.current?.id!==floor.id)return false;
      if(space)selectInteriorSpace(space);
      selectedZoneId=zone.id;send('selected',{zoneId:zone.id});
    }else{
      if(interiors?.current)await exitInteriorWithFade();
      if(viewerDisposed || request!==mapEventNavigationRequest)return false;
      startSelectionEffect(node);focusNode(node,zone.focus);
      selectedZoneId=zone.id;lastFocusedZoneId=zone.id;cameraMovedSinceFocus=false;
      send('selected',{zoneId:zone.id});
    }
    requestRender();return true;
  });
  mapEventNavigationQueue=run;return run;
}

function setEventMarkers(events) {
  mapEvents=Array.isArray(events)?events:[];
  eventAnchorCache.clear();eventMarkers.setEvents(mapEvents);requestRender();
}

function selectAt(clientX, clientY) {
  if (geometryOnly && !(featurePanelEnabled && testFeatures.selection)) return true;
  if (featureBusy) return true;
  if (!model || !config) return false;
  if (interiorLoading) return true;

  const viewportBounds = renderer.domElement.getBoundingClientRect();
  pointer.x = ((clientX - viewportBounds.left) / viewportBounds.width) * 2 - 1;
  pointer.y = -((clientY - viewportBounds.top) / viewportBounds.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);

  if (interiors?.current) {
    const space = interiors.pick(raycaster);
    if (!space && !interiors.activeFloors.some(floor =>
        raycaster.ray.intersectsBox(floor.bounds))) {
      // A tap on the campus outside this building leaves the interior too.
      // Empty corridors inside the floor only clear the room selection.
      void exitInteriorWithFade({ focus: false });
      return true;
    }
    selectInteriorSpace(space);
    return !space;
  }

  const pickedZone = pickZoneAt(clientX, clientY, viewportBounds);
  const intersections = raycaster.intersectObjects(
    [...zoneNodes.values()],
    true,
  );
  const hit = intersections[0];
  const zone = pickedZone ?? (hit ? findZoneForObject(hit.object) : null);
  return selectZone(zone?.id);
}

function preserveCameraAfterTap(snapshot) {
  queueMicrotask(() => {
    cameraFocus = null;
    navigationSpring = null;
    navigationConstraintSuspended = false;
    clearControlsMomentum();
    camera.position.copy(snapshot.position);
    controls.target.copy(snapshot.target);
    camera.lookAt(controls.target);
    applyNavigationConstraint();
    applyDistanceConstraint();
    requestRender();
  });
}

function pickZoneAt(clientX, clientY, viewportBounds) {
  if (config.zones.length > pickingMaterials.length) return null;

  const drawingSize = renderer.getDrawingBufferSize(new THREE.Vector2());
  const pixelX = THREE.MathUtils.clamp(
    Math.floor(
      ((clientX - viewportBounds.left) / viewportBounds.width) * drawingSize.x,
    ),
    0,
    drawingSize.x - 1,
  );
  const pixelY = THREE.MathUtils.clamp(
    Math.floor(
      ((clientY - viewportBounds.top) / viewportBounds.height) * drawingSize.y,
    ),
    0,
    drawingSize.y - 1,
  );
  const originalBackground = scene.background;
  const originalLayerMask = camera.layers.mask;
  const originalRenderTarget = renderer.getRenderTarget();
  const originalAutoClear = renderer.autoClear;
  const originalClearColor = renderer.getClearColor(new THREE.Color()).clone();
  const originalClearAlpha = renderer.getClearAlpha();
  const meshStates = [];

  model.traverse((object) => {
    if (!object.isMesh) return;
    meshStates.push({
      object,
      visible: object.visible,
      material: object.material,
    });
    const zone = findZoneForObject(object);
    const zoneIndex = zone
      ? config.zones.findIndex((candidate) => candidate.id === zone.id)
      : -1;
    if (zoneIndex < 0) {
      object.visible = false;
      return;
    }
    object.visible = true;
    object.material = pickingMaterials[zoneIndex];
  });

  scene.background = null;
  // O ceu e decorativo: nao pode ser confundido com um bloco ao tocar no vazio.
  const middaySkyWasVisible = middaySkyMesh?.visible;
  if (middaySkyMesh) middaySkyMesh.visible = false;
  const sunsetSkyWasVisible = sunsetSkyMesh?.visible;
  if (sunsetSkyMesh) sunsetSkyMesh.visible = false;
  const morningSkyWasVisible = morningSkyMesh?.visible;
  if (morningSkyMesh) morningSkyMesh.visible = false;
  camera.layers.set(0);
  camera.setViewOffset(
    drawingSize.x,
    drawingSize.y,
    pixelX,
    pixelY,
    1,
    1,
  );
  renderer.setRenderTarget(pickingTarget);
  renderer.setClearColor(0x000000, 1);
  renderer.autoClear = true;
  renderer.render(scene, camera);

  const pixel = new Uint8Array(4);
  renderer.readRenderTargetPixels(pickingTarget, 0, 0, 1, 1, pixel);

  for (const state of meshStates) {
    state.object.visible = state.visible;
    state.object.material = state.material;
  }
  camera.clearViewOffset();
  camera.layers.mask = originalLayerMask;
  scene.background = originalBackground;
  if (middaySkyMesh) middaySkyMesh.visible = middaySkyWasVisible;
  if (sunsetSkyMesh) sunsetSkyMesh.visible = sunsetSkyWasVisible;
  if (morningSkyMesh) morningSkyMesh.visible = morningSkyWasVisible;
  renderer.setRenderTarget(originalRenderTarget);
  renderer.setClearColor(originalClearColor, originalClearAlpha);
  renderer.autoClear = originalAutoClear;

  const strongestChannel = Math.max(pixel[0], pixel[1], pixel[2]);
  if (strongestChannel < 128) return null;
  const zoneIndex =
    pixel[0] === strongestChannel ? 0 : pixel[1] === strongestChannel ? 1 : 2;
  return config.zones[zoneIndex] ?? null;
}

function boundsForNodes(object, nodeNames) {
  const bounds = new THREE.Box3();
  if (!Array.isArray(nodeNames)) return bounds;

  for (const nodeName of nodeNames) {
    const node = findModelNode(object, nodeName);
    if (node) bounds.expandByObject(node);
  }
  return bounds;
}

function navigationPointsForNodes(object, nodeNames) {
  const points = [];
  if (!Array.isArray(nodeNames)) return points;
  object.updateWorldMatrix(true, true);

  for (const nodeName of nodeNames) {
    const node = findModelNode(object, nodeName);
    node?.traverse((child) => {
      const positions = child.geometry?.attributes?.position;
      if (!child.isMesh || child.userData.isGroundSunRay || !positions) return;
      for (let index = 0; index < positions.count; index++) {
        const world = new THREE.Vector3()
          .fromBufferAttribute(positions, index)
          .applyMatrix4(child.matrixWorld);
        points.push(new THREE.Vector2(world.x, world.z));
      }
    });
  }
  return points;
}

function convexHull(points) {
  if (points.length < 3) return [];
  const sorted = [...points].sort((a, b) => a.x - b.x || a.y - b.y);
  const cross = (origin, a, b) =>
    (a.x - origin.x) * (b.y - origin.y) -
    (a.y - origin.y) * (b.x - origin.x);
  const lower = [];
  const upper = [];

  for (const point of sorted) {
    while (
      lower.length >= 2 &&
      cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0
    ) {
      lower.pop();
    }
    lower.push(point);
  }
  for (let index = sorted.length - 1; index >= 0; index--) {
    const point = sorted[index];
    while (
      upper.length >= 2 &&
      cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0
    ) {
      upper.pop();
    }
    upper.push(point);
  }
  lower.pop();
  upper.pop();
  return lower.concat(upper);
}

function configureNavigationBounds(object, fallbackBounds) {
  const navigation = cameraTuning.navigation ?? {};
  const groundBounds = boundsForNodes(object, navigation.groundNodes);
  const hull = convexHull(
    navigationPointsForNodes(object, navigation.groundNodes),
  );
  const requestedBounds = boundsForNodes(object, navigation.boundsNodes);
  navigationBounds = groundBounds.isEmpty()
    ? requestedBounds.isEmpty()
      ? fallbackBounds.clone()
      : requestedBounds
    : groundBounds.clone();
  navigationHull = hull;
  navigationEdges = [];
  if (hull.length >= 3) {
    for (let index = 0; index < hull.length; index++) {
      const origin = hull[index];
      const destination = hull[(index + 1) % hull.length];
      const edge = destination.clone().sub(origin);
      navigationEdges.push({
        origin,
        inward: new THREE.Vector2(-edge.y, edge.x).normalize(),
      });
    }
  }
  const size = navigationBounds.getSize(new THREE.Vector3());
  navigationInset =
    Math.max(size.x, size.z) *
    THREE.MathUtils.clamp(navigation.boundaryInset ?? 0.01, 0, 0.12);
  const groundTop = groundBounds.isEmpty()
    ? fallbackBounds.min.y
    : groundBounds.max.y;
  navigationTargetHeight =
    groundTop + (navigation.targetHeightOffset ?? 0);
}

function clipNavigationPolygon(polygon, edge, requiredDistance) {
  if (polygon.length === 0) return [];
  const result = [];
  const signedDistance = (point) =>
    (point.x - edge.origin.x) * edge.inward.x +
    (point.y - edge.origin.y) * edge.inward.y - requiredDistance;

  for (let index = 0; index < polygon.length; index++) {
    const current = polygon[index];
    const next = polygon[(index + 1) % polygon.length];
    const currentDistance = signedDistance(current);
    const nextDistance = signedDistance(next);
    const currentInside = currentDistance >= -1e-6;
    const nextInside = nextDistance >= -1e-6;

    if (currentInside && nextInside) {
      result.push(next.clone());
      continue;
    }
    if (currentInside === nextInside) continue;

    const denominator = currentDistance - nextDistance;
    const amount = Math.abs(denominator) <= 1e-8
      ? 0
      : currentDistance / denominator;
    const intersection = current.clone().lerp(next, amount);
    result.push(intersection);
    if (!currentInside && nextInside) result.push(next.clone());
  }
  return result;
}

function navigationPolygonForOffsets(offsets, offsetScale) {
  let polygon = navigationHull.map((point) => point.clone());
  for (const edge of navigationEdges) {
    let requiredDistance = navigationInset;
    for (const offset of offsets) {
      requiredDistance = Math.max(
        requiredDistance,
        navigationInset - edge.inward.dot(offset) * offsetScale,
      );
    }
    polygon = clipNavigationPolygon(polygon, edge, requiredDistance);
    if (polygon.length === 0) break;
  }
  return polygon;
}

function feasibleNavigationPolygon(offsets) {
  let polygon = navigationPolygonForOffsets(offsets, 1);
  if (polygon.length > 0) return polygon;

  let low = 0;
  let high = 1;
  let best = navigationPolygonForOffsets(offsets, 0);
  for (let index = 0; index < 20; index++) {
    const middle = (low + high) / 2;
    const candidate = navigationPolygonForOffsets(offsets, middle);
    if (candidate.length > 0) {
      low = middle;
      best = candidate;
    } else {
      high = middle;
    }
  }
  return best;
}

function closestPointInPolygon(point, polygon) {
  if (polygon.length === 0) return point.clone();
  const inside = polygon.every((start, index) => {
    const end = polygon[(index + 1) % polygon.length];
    const edge = end.clone().sub(start);
    const relative = point.clone().sub(start);
    return edge.x * relative.y - edge.y * relative.x >= -1e-6;
  });
  if (inside) return point.clone();

  let closest = polygon[0].clone();
  let closestDistance = Infinity;
  for (let index = 0; index < polygon.length; index++) {
    const start = polygon[index];
    const end = polygon[(index + 1) % polygon.length];
    const segment = end.clone().sub(start);
    const lengthSquared = segment.lengthSq();
    const amount = lengthSquared <= 1e-8
      ? 0
      : THREE.MathUtils.clamp(
          point.clone().sub(start).dot(segment) / lengthSquared,
          0,
          1,
        );
    const candidate = start.clone().addScaledVector(segment, amount);
    const distance = candidate.distanceToSquared(point);
    if (distance < closestDistance) {
      closestDistance = distance;
      closest = candidate;
    }
  }
  return closest;
}

function constrainNavigationPoint(point, offsets = []) {
  const constrained = point.clone();
  if (!navigationBounds) return constrained;

  if (navigationEdges.length > 0) {
    const position = new THREE.Vector2(constrained.x, constrained.z);
    const anchor = camera.isOrthographicCamera ? cameraTuning.topView?.initialTarget : null;
    let cached = navigationPolygonCache.get(offsets);
    if (!cached || cached.hull !== navigationHull || cached.edges !== navigationEdges ||
        cached.inset !== navigationInset || cached.anchorX !== anchor?.[0] || cached.anchorZ !== anchor?.[2]) {
      let polygon = feasibleNavigationPolygon(offsets);
      if (anchor) {
        // Keep the approved framing reachable while constraining the visible
        // area at every other edge. The anchor itself must stay on the terrain.
        const savedAnchor = closestPointInPolygon(new THREE.Vector2(anchor[0], anchor[2]), navigationHull);
        polygon = convexHull([...polygon, savedAnchor]);
      }
      cached = { hull: navigationHull, edges: navigationEdges, inset: navigationInset,
        anchorX: anchor?.[0], anchorZ: anchor?.[2], polygon };
      navigationPolygonCache.set(offsets, cached);
    }
    const closest = closestPointInPolygon(position, cached.polygon);
    constrained.x = closest.x;
    constrained.z = closest.y;
  } else {
    constrained.x = THREE.MathUtils.clamp(
      constrained.x,
      navigationBounds.min.x,
      navigationBounds.max.x,
    );
    constrained.z = THREE.MathUtils.clamp(
      constrained.z,
      navigationBounds.min.z,
      navigationBounds.max.z,
    );
  }
  if (
    !interiors?.current &&
    cameraTuning.navigation?.lockTargetToGround !== false &&
    navigationTargetHeight !== null
  ) {
    constrained.y = navigationTargetHeight;
  }
  return constrained;
}

function viewportNavigationOffsets(
  viewCamera = camera,
  viewTarget = controls.target,
) {
  if (!navigationBounds || navigationTargetHeight === null) return null;

  const viewport = viewCamera.isOrthographicCamera
    ? { left: 0.90, right: 0.90, top: 0.72, bottom: 0.80 }
    : cameraTuning.navigation?.viewport ?? {};
  const cached = navigationOffsetCache.get(viewCamera, viewTarget, navigationTargetHeight, viewport);
  if (cached) return cached.offsets;
  const left = -(viewport.left ?? 0.58);
  const right = viewport.right ?? 0.58;
  const top = viewport.top ?? 0.42;
  const bottom = -(viewport.bottom ?? 0.58);
  const samples = [
    [left, top],
    [0, top],
    [right, top],
    [left, 0],
    [right, 0],
    [left, bottom],
    [0, bottom],
    [right, bottom],
  ];
  const plane = new THREE.Plane(
    new THREE.Vector3(0, 1, 0),
    -navigationTargetHeight,
  );
  const viewRaycaster = new THREE.Raycaster();
  const offsets = [];
  viewCamera.updateMatrixWorld();

  for (const [x, y] of samples) {
    viewRaycaster.setFromCamera(new THREE.Vector2(x, y), viewCamera);
    if (viewRaycaster.ray.direction.y >= -0.015) continue;
    const groundPoint = viewRaycaster.ray.intersectPlane(
      plane,
      new THREE.Vector3(),
    );
    if (!groundPoint) continue;
    offsets.push(groundPoint.sub(viewTarget));
  }
  return navigationOffsetCache.set(viewCamera, viewTarget, navigationTargetHeight, viewport,
    offsets.length ? offsets.map((offset) => new THREE.Vector2(offset.x, offset.z)) : null);
}

function constrainedNavigationTarget(
  viewCamera = camera,
  viewTarget = controls.target,
) {
  // Interior bounds are axis-aligned; this path never consumes ground rays.
  if (!navigationEdges.length) return constrainNavigationPoint(viewTarget);
  const offsets = viewportNavigationOffsets(viewCamera, viewTarget);
  return constrainNavigationPoint(viewTarget, offsets ?? emptyNavigationOffsets);
}

function applyNavigationConstraint({ elastic = false } = {}) {
  if (cameraFocus?.interiorTravel) return;
  if (viewTransition) return;
  if (!navigationBounds || navigationConstraintSuspended) return;

  const rigidTarget = constrainedNavigationTarget();
  const desiredTarget = rigidTarget;
  if (elastic) {
    const size = navigationBounds.getSize(new THREE.Vector3());
    const overshootRatio = cameraTuning.navigation?.maxOvershootRatio ?? 0.035;
    const overshoot = controls.target.clone().sub(rigidTarget);
    overshoot.y = 0;
    overshoot.multiplyScalar(mapViewMode === '2d' ? 1 :
      THREE.MathUtils.clamp(
        cameraTuning.navigation?.elasticResistance ?? 0.18,
        0.05,
        0.5,
      ),
    );
    const maxOvershoot = Math.max(size.x, size.z) * overshootRatio;
    if (overshoot.length() > maxOvershoot) {
      overshoot.setLength(maxOvershoot);
    }
    desiredTarget.add(overshoot);
  }

  const correction = desiredTarget.sub(controls.target);
  if (correction.lengthSq() <= 1e-8) return;
  controls.target.add(correction);
  camera.position.add(correction);
}

function enableElasticDistanceBounds() {
  if (mapViewMode === '2d') {
    const limits = topViewZoomLimits();
    controls.minZoom = limits.min * 0.86;
    controls.maxZoom = limits.max * 1.14;
    return;
  }
  if (!(baseMinDistance > 0) || !Number.isFinite(baseMaxDistance)) return;
  const ratio = THREE.MathUtils.clamp(
    cameraTuning.navigation?.maxZoomOvershootRatio ?? 0.10,
    0.02,
    0.24,
  );
  controls.minDistance = baseMinDistance * (1 - ratio);
  controls.maxDistance = baseMaxDistance * (1 + ratio);
}

function applyDistanceConstraint({ elastic = false } = {}) {
  if (cameraFocus?.interiorTravel) return;
  if (mapViewMode === '2d') return;
  if (!(baseMinDistance > 0) || !Number.isFinite(baseMaxDistance)) return;
  const offset = camera.position.clone().sub(controls.target);
  const distance = offset.length();
  if (distance <= 1e-6) return;

  const rigidDistance = THREE.MathUtils.clamp(
    distance,
    baseMinDistance,
    baseMaxDistance,
  );
  let desiredDistance = rigidDistance;
  if (elastic && distance !== rigidDistance) {
    const resistance = THREE.MathUtils.clamp(
      cameraTuning.navigation?.zoomElasticResistance ?? 0.16,
      0.05,
      0.45,
    );
    const ratio = THREE.MathUtils.clamp(
      cameraTuning.navigation?.maxZoomOvershootRatio ?? 0.10,
      0.02,
      0.24,
    );
    const referenceDistance = distance < baseMinDistance
      ? baseMinDistance
      : baseMaxDistance;
    const maxOvershoot = referenceDistance * ratio;
    const overshoot = THREE.MathUtils.clamp(
      (distance - rigidDistance) * resistance,
      -maxOvershoot,
      maxOvershoot,
    );
    desiredDistance += overshoot;
  }

  if (Math.abs(desiredDistance - distance) <= 1e-6) return;
  camera.position
    .copy(controls.target)
    .addScaledVector(offset.normalize(), desiredDistance);
}

function startNavigationReturn() {
  if (viewTransition) return;
  if (mapViewMode === '2d') {
    const limits = topViewZoomLimits();
    const zoom = THREE.MathUtils.clamp(camera.zoom, limits.min, limits.max);
    const preview = camera.clone();
    preview.zoom = zoom;
    preview.updateProjectionMatrix();
    const target = constrainedNavigationTarget(preview, controls.target);
    const correction = target.clone().sub(controls.target);
    if (correction.lengthSq() < 0.000001 && Math.abs(camera.zoom - zoom) < 0.000001) {
      controls.minZoom = limits.min;
      controls.maxZoom = limits.max;
      return;
    }
    navigationSpring = {
      startedAt: performance.now(), duration: 650, bounce: 0.5,
      fromPosition: camera.position.clone(), fromTarget: controls.target.clone(),
      toPosition: camera.position.clone().add(correction), toTarget: target,
      fromZoom: camera.zoom, toZoom: zoom,
    };
    beginCameraTransitionResolution();
    requestRender();
    return;
  }
  if (!navigationBounds || navigationConstraintSuspended) return;
  const offset = camera.position.clone().sub(controls.target);
  const distance = offset.length();
  const targetDistance = THREE.MathUtils.clamp(
    distance,
    baseMinDistance,
    baseMaxDistance,
  );
  const distanceNeedsReturn = Math.abs(targetDistance - distance) > 0.0001;

  const direction = distance > 1e-6
    ? offset.multiplyScalar(1 / distance)
    : new THREE.Vector3(0, 0, 1);
  const targetCamera = camera.clone();
  targetCamera.position
    .copy(controls.target)
    .addScaledVector(direction, targetDistance);
  targetCamera.lookAt(controls.target);
  targetCamera.updateMatrixWorld();
  const target = constrainedNavigationTarget(targetCamera, controls.target);
  const correction = target.clone().sub(controls.target);
  if (correction.lengthSq() <= 0.0001 && !distanceNeedsReturn) return;
  const destination = target
    .clone()
    .addScaledVector(direction, targetDistance);

  navigationSpring = {
    startedAt: performance.now(),
    duration: cameraTuning.navigation?.returnDuration ?? 180,
    fromPosition: camera.position.clone(),
    fromTarget: controls.target.clone(),
    toPosition: destination,
    toTarget: target,
    bounce: THREE.MathUtils.clamp(
      cameraTuning.navigation?.returnBounce ?? 0.55,
      0,
      1.4,
    ),
  };
  beginCameraTransitionResolution();
  requestRender();
}

const focusPointCache = new WeakMap();
function focusPointsForNode(node) {
  node.updateWorldMatrix(true, false);
  const cached = focusPointCache.get(node);
  const transformKey = node.matrixWorld.elements.join(',');
  if (cached?.transformKey === transformKey) return cached.points;
  const meshes = [];
  let vertexCount = 0;
  node.updateWorldMatrix(true, true);
  node.traverse((object) => {
    const positions = object.geometry?.attributes?.position;
    if (!object.isMesh || !object.visible || !positions || object.userData.interiorSpace?.marker === object) return;
    meshes.push({ object, positions });
    vertexCount += positions.count;
  });

  const maxPoints = selectionTuning.focusMaxSamplePoints ?? 20000;
  const stride = Math.max(1, Math.ceil(vertexCount / maxPoints));
  const points = [];
  let globalIndex = 0;
  for (const { object, positions } of meshes) {
    const first = (stride - globalIndex % stride) % stride;
    for (let index = first; index < positions.count; index += stride) {
      points.push(
        new THREE.Vector3()
          .fromBufferAttribute(positions, index)
          .applyMatrix4(object.matrixWorld),
      );
    }
    globalIndex += positions.count;
  }
  focusPointCache.set(node, { transformKey, points });
  return points;
}

function focusDistanceForPoints(points, target, direction, options = {}) {
  const safeWidth = options.safeWidth ?? selectionTuning.focusSafeWidth ?? 0.84;
  const safeHeight = options.safeHeight ?? selectionTuning.focusSafeHeight ?? 0.58;
  const padding = options.padding ?? selectionTuning.focusPadding ?? 1.08;
  const testCamera = perspectiveCamera.clone();
  const projected = new THREE.Vector3();

  function fits(distance) {
    testCamera.position.copy(target).addScaledVector(direction, distance);
    testCamera.lookAt(target);
    testCamera.updateMatrixWorld();
    updatePerspectiveProjection(testCamera);
    for (const point of points) {
      projected.copy(point).project(testCamera);
      if (
        projected.z < -1 ||
        projected.z > 1 ||
    Math.abs(projected.x) > safeWidth ||
        Math.abs(projected.y) > safeHeight
      ) {
        return false;
      }
    }
    return true;
  }

  let low = 2;
  let high = Math.max(baseMaxDistance, 32);
  while (!fits(high) && high < 4000) high *= 1.5;
  for (let index = 0; index < 24; index++) {
    const middle = (low + high) / 2;
    if (fits(middle)) high = middle;
    else low = middle;
  }
  return high * padding;
}

function constrainedFocusTarget(target, direction, distance) {
  const testCamera = perspectiveCamera.clone();
  testCamera.position.copy(target).addScaledVector(direction, distance);
  testCamera.lookAt(target);
  testCamera.updateMatrixWorld();
  updatePerspectiveProjection(testCamera);
  return constrainedNavigationTarget(testCamera, target);
}

function localTimeMinutes() {
  if (Number.isFinite(previewLocalTimeMinutes)) {
    return ((previewLocalTimeMinutes % 1440) + 1440) % 1440;
  }
  if (Number.isFinite(config?.localTimeMinutes)) {
    return ((config.localTimeMinutes % 1440) + 1440) % 1440;
  }
  const now = new Date();
  return now.getHours() * 60 + now.getMinutes();
}

function previewColor(value, fallback) {
  if (value?.isColor) return value.clone();
  if (typeof value === 'string' || Number.isFinite(value)) {
    return new THREE.Color(value);
  }
  return fallback.clone();
}

function daylightProfileWithPreview(profile) {
  if (isDayCustomization()) {
    const morningLook = isMidday() ? middayLook : effectiveMorningLook();
    profile = { ...profile, rays: { ...profile.rays }, key: { ...profile.key },
      ambient: { ...profile.ambient }, hemisphere: { ...profile.hemisphere },
      fill: { ...profile.fill }, grading: { ...profile.grading } };
    if (isMidday()) {
      // Nao herda a cor/posicao do entardecer pela interpolacao das horas.
      const midday = rendererTuning.middayLighting ?? {};
      profile.key.color = previewColor(midday.sunColor, profile.key.color);
      profile.key.positionOffset = midday.sunPosition ?? profile.key.positionOffset;
      profile.ambient.color = previewColor(midday.ambientColor, profile.ambient.color);
      profile.hemisphere.skyColor = previewColor(midday.skyColor, profile.hemisphere.skyColor);
      profile.hemisphere.groundColor = previewColor(midday.groundColor, profile.hemisphere.groundColor);
      profile.fill.color = previewColor(midday.fillColor, profile.fill.color);
      profile.fill.positionOffset = midday.fillPosition ?? profile.fill.positionOffset;
      profile.grading.warmStrength = 0;
      profile.grading.neutralWarmResponse = 0;
      profile.shadowIntensity = 0.95;
    }
    for (const key of ['exposure', 'shadowRadius']) {
      if (Number.isFinite(morningLook[key])) profile[key] = morningLook[key];
    }
    for (const key of ['key', 'ambient', 'hemisphere', 'fill']) {
      if (Number.isFinite(morningLook[key])) profile[key].intensity = morningLook[key];
    }
    if (Number.isFinite(morningLook.rays)) profile.rays.opacity = morningLook.rays;
    for (const key of ['contrast', 'saturation']) {
      if (Number.isFinite(morningLook[key])) profile.grading[key] = morningLook[key];
    }
  }
  const preview = daylightPreviewOverrides;
  if (!preview) return profile;

  return {
    ...profile,
    exposure: Number.isFinite(preview.exposure)
      ? preview.exposure
      : profile.exposure,
    rays: {
      ...profile.rays,
      color: previewColor(preview.rays?.color, profile.rays.color),
      opacity: Number.isFinite(preview.rays?.opacity)
        ? preview.rays.opacity
        : profile.rays.opacity,
    },
    ambient: {
      ...profile.ambient,
      color: previewColor(preview.ambient?.color, profile.ambient.color),
      intensity: Number.isFinite(preview.ambient?.intensity)
        ? preview.ambient.intensity
        : profile.ambient.intensity,
    },
    hemisphere: {
      ...profile.hemisphere,
      skyColor: previewColor(
        preview.hemisphere?.skyColor,
        profile.hemisphere.skyColor,
      ),
      groundColor: previewColor(
        preview.hemisphere?.groundColor,
        profile.hemisphere.groundColor,
      ),
      intensity: Number.isFinite(preview.hemisphere?.intensity)
        ? preview.hemisphere.intensity
        : profile.hemisphere.intensity,
    },
    key: {
      ...profile.key,
      color: previewColor(preview.key?.color, profile.key.color),
      intensity: Number.isFinite(preview.key?.intensity)
        ? preview.key.intensity
        : profile.key.intensity,
      positionOffset: preview.key?.positionOffset ?? profile.key.positionOffset,
    },
    fill: {
      ...profile.fill,
      color: previewColor(preview.fill?.color, profile.fill.color),
      intensity: Number.isFinite(preview.fill?.intensity)
        ? preview.fill.intensity
        : profile.fill.intensity,
      positionOffset: preview.fill?.positionOffset ?? profile.fill.positionOffset,
    },
    grading: {
      ...profile.grading,
      warmColor: previewColor(
        preview.grading?.warmColor,
        profile.grading.warmColor,
      ),
      warmStrength: Number.isFinite(preview.grading?.warmStrength)
        ? preview.grading.warmStrength
        : profile.grading.warmStrength,
      warmStart: Number.isFinite(preview.grading?.warmStart)
        ? preview.grading.warmStart
        : profile.grading.warmStart,
      warmEnd: Number.isFinite(preview.grading?.warmEnd)
        ? preview.grading.warmEnd
        : profile.grading.warmEnd,
      neutralWarmResponse: Number.isFinite(
        preview.grading?.neutralWarmResponse
      )
        ? preview.grading.neutralWarmResponse
        : profile.grading.neutralWarmResponse,
      contrast: Number.isFinite(preview.grading?.contrast)
        ? preview.grading.contrast
        : profile.grading.contrast,
      saturation: Number.isFinite(preview.grading?.saturation)
        ? preview.grading.saturation
        : profile.grading.saturation,
    },
    shadowIntensity: Number.isFinite(preview.shadowIntensity)
      ? preview.shadowIntensity
      : profile.shadowIntensity,
    shadowRadius: Number.isFinite(preview.shadowRadius)
      ? preview.shadowRadius
      : profile.shadowRadius,
  };
}

function interpolateNumber(from, to, amount) {
  return THREE.MathUtils.lerp(from ?? 0, to ?? from ?? 0, amount);
}

function interpolateColor(from, to, amount, fallback) {
  return new THREE.Color(from ?? fallback).lerp(
    new THREE.Color(to ?? from ?? fallback),
    amount,
  );
}

function interpolateOffset(from, to, amount) {
  const start = from ?? { x: 0, y: 1, z: 0 };
  const end = to ?? start;
  return {
    x: interpolateNumber(start.x, end.x, amount),
    y: interpolateNumber(start.y, end.y, amount),
    z: interpolateNumber(start.z, end.z, amount),
  };
}

function gradeFrame(frame = {}) {
  const defaults = postProcessingTuning.grading ?? {};
  const grading = frame.grading ?? {};
  return {
    warmColor: grading.warmColor ?? defaults.warmColor ?? '#ff9d37',
    warmStrength: grading.warmStrength ?? defaults.warmStrength ?? 0,
    warmStart: grading.warmStart ?? defaults.warmStart ?? 0.08,
    warmEnd: grading.warmEnd ?? defaults.warmEnd ?? 0.72,
    neutralWarmResponse:
      grading.neutralWarmResponse ?? defaults.neutralWarmResponse ?? 0.22,
    contrast: grading.contrast ?? defaults.contrast ?? 1,
    saturation: grading.saturation ?? defaults.saturation ?? 1,
  };
}

function interpolateGrade(from, to, amount) {
  const start = gradeFrame(from);
  const end = gradeFrame(to);
  return {
    warmColor: interpolateColor(
      start.warmColor,
      end.warmColor,
      amount,
      '#ff9d37',
    ),
    warmStrength: interpolateNumber(
      start.warmStrength,
      end.warmStrength,
      amount,
    ),
    warmStart: interpolateNumber(start.warmStart, end.warmStart, amount),
    warmEnd: interpolateNumber(start.warmEnd, end.warmEnd, amount),
    neutralWarmResponse: interpolateNumber(
      start.neutralWarmResponse,
      end.neutralWarmResponse,
      amount,
    ),
    contrast: interpolateNumber(start.contrast, end.contrast, amount),
    saturation: interpolateNumber(start.saturation, end.saturation, amount),
  };
}

function cyclicScheduleAmount(schedule, minute) {
  const frames = Array.isArray(schedule)
    ? [...schedule].sort((a, b) => a.minute - b.minute)
    : [];
  if (frames.length === 0) return 0;
  if (frames.length === 1) return frames[0].amount ?? 0;

  let fromIndex = frames.length - 1;
  for (let index = 0; index < frames.length; index++) {
    if (frames[index].minute <= minute) fromIndex = index;
  }
  const from = frames[fromIndex];
  const to = frames[(fromIndex + 1) % frames.length];
  const fromMinute = from.minute;
  const toMinute = to.minute <= fromMinute ? to.minute + 1440 : to.minute;
  const currentMinute = minute < fromMinute ? minute + 1440 : minute;
  const linearAmount = THREE.MathUtils.clamp(
    (currentMinute - fromMinute) / Math.max(1, toMinute - fromMinute),
    0,
    1,
  );
  const amount = linearAmount * linearAmount * (3 - 2 * linearAmount);
  return interpolateNumber(from.amount, to.amount, amount);
}

function stableDailyScore(name) {
  const now = new Date();
  const dayKey = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
  const source = `${dayKey}:${name}`;
  let hash = 2166136261;
  for (let index = 0; index < source.length; index++) {
    hash ^= source.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967295;
}

function windowPresetGroupName(nodeName, prefix) {
  return nodeName
    .slice(prefix.length)
    .replace('didatido', 'didatico')
    .replace(/_\d+$/, '');
}

function clearWindowPresets() {
  windowPresetGroups.clear();
  for (const light of windowGlowLights) {
    scene.remove(light);
    light.dispose?.();
  }
  windowGlowLights.length = 0;
  for (const material of windowOwnedMaterials) material.dispose();
  windowOwnedMaterials.clear();
}

function prepareWindowPresets(root, { glowEnabled, glowMaxLights = Infinity, preserveSurface = false } = {}) {
  const settings = lightingTuning.dayCycle?.windows;
  const prefix = settings?.nodePrefix ?? 'janelas_preset_';
  const surfaceMaterialName = (
    settings?.surfaceMaterialName ?? 'whereif_ultra_concrete'
  ).toLowerCase();
  let surfaceMaterial = null;

  root.traverse((object) => {
    if (preserveSurface || surfaceMaterial || !object.isMesh) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    surfaceMaterial = materials.find((material) =>
      material?.name?.toLowerCase().includes(surfaceMaterialName)
    ) ?? null;
  });

  clearWindowPresets();

  root.traverse((object) => {
    if (!object.name?.startsWith(prefix)) return;
    const groupName = windowPresetGroupName(object.name, prefix);
    const group = windowPresetGroups.get(groupName) ?? [];
    const materialStates = [];
    object.traverse((child) => {
      if (!child.isMesh) return;
      const sourceMaterials = Array.isArray(child.material)
        ? child.material
        : [child.material];
      const materials = sourceMaterials.map((source) => {
        const material = (surfaceMaterial ?? source).clone();
        const hasUv = child.geometry?.getAttribute('uv') != null;
        if (surfaceMaterial && !hasUv) {
          material.map = null;
          material.normalMap = null;
          material.roughnessMap = null;
          material.metalnessMap = null;
          material.aoMap = null;
          material.color.set(settings?.fallbackSurfaceColor ?? '#85898d');
        }
        material.name = `${source.name || 'window'}_surface`;
        windowOwnedMaterials.add(material);
        // Windows must behave like the facade while the sun is present:
        // no environment reflection and full participation in cast shadows.
        if (!preserveSurface) {
          if ('envMapIntensity' in material) material.envMapIntensity = 0;
          if ('roughness' in material) material.roughness = 1;
          if ('clearcoat' in material) material.clearcoat = 0;
        }
        material.needsUpdate = true;
        const supportsEmission = material.emissive?.isColor === true;
        materialStates.push({
          material,
          supportsColor: material.color?.isColor === true,
          baseColor: material.color?.isColor === true
            ? material.color.clone()
            : null,
          supportsEmission,
          baseEmissive: supportsEmission
            ? material.emissive.clone()
            : null,
          baseEmissiveIntensity: material.emissiveIntensity ?? 0,
        });
        return material;
      });
      child.material = Array.isArray(child.material)
        ? materials
        : materials[0];
      child.castShadow = false;
      child.receiveShadow = true;
    });
    group.push({
      node: object,
      score: stableDailyScore(object.name),
      materialStates,
    });
    windowPresetGroups.set(groupName, group);
    object.visible = true;
  });

  for (const group of windowPresetGroups.values()) {
    group.sort((a, b) => a.score - b.score);
  }
  if (glowEnabled ?? settings?.glowEnabled === true) {
    // Give each building one light before allocating more to the same facade.
    // The complete test stays bounded, never one light per individual window.
    const groups = [...windowPresetGroups.values()];
    const candidates = [...groups.map(group => group[0]), ...groups.flatMap(group => group.slice(1))];
    for (const preset of candidates.slice(0, glowMaxLights)) {
      const bounds = new THREE.Box3().setFromObject(preset.node);
      if (bounds.isEmpty()) continue;
      const size = bounds.getSize(new THREE.Vector3());
      const center = bounds.getCenter(new THREE.Vector3());
      center.y = bounds.min.y + size.y * 0.46;
      // A preset can contain windows on several facades. Its bounding-box
      // center may be inside the building, far from every pane. Anchor the
      // optional light to an actual vertical pane, slightly outside its face.
      const panePosition = new THREE.Vector3();
      const paneNormal = new THREE.Vector3();
      const bestPosition = new THREE.Vector3();
      const bestNormal = new THREE.Vector3();
      const normalMatrix = new THREE.Matrix3();
      let nearestPane = Infinity;
      preset.node.traverse(mesh => {
        if (!mesh.isMesh) return;
        const positions = mesh.geometry.getAttribute('position');
        const normals = mesh.geometry.getAttribute('normal');
        if (!positions || !normals) return;
        normalMatrix.getNormalMatrix(mesh.matrixWorld);
        const stride = Math.max(1, Math.floor(positions.count / 256));
        for (let index = 0; index < positions.count; index += stride) {
          paneNormal.fromBufferAttribute(normals, index).applyNormalMatrix(normalMatrix);
          if (Math.abs(paneNormal.y) > 0.4) continue;
          panePosition.fromBufferAttribute(positions, index).applyMatrix4(mesh.matrixWorld);
          const distance = panePosition.distanceToSquared(center);
          if (distance < nearestPane) {
            nearestPane = distance;
            bestPosition.copy(panePosition); bestNormal.copy(paneNormal);
          }
        }
      });
      if (Number.isFinite(nearestPane)) center.copy(bestPosition).addScaledVector(bestNormal, 1.2);
      const glow = new THREE.PointLight(
        settings?.color ?? '#fff4cf',
        0,
        Math.min(28, Math.max(16, Math.max(size.x, size.y, size.z) *
          (settings?.glowDistanceRatio ?? 0.72))),
        settings?.glowDecay ?? 2,
      );
      glow.position.copy(center);
      glow.castShadow = false;
      preset.glowLight = glow;
      windowGlowLights.push(glow);
      scene.add(glow);
    }
  }
}

function applyWindowPresetLighting() {
  if (windowPresetGroups.size === 0) return;
  const settings = lightingTuning.dayCycle?.windows ?? {};
  const lightColor = new THREE.Color(settings.color ?? '#ffdca0');
  const amount = THREE.MathUtils.clamp(
    cyclicScheduleAmount(settings.schedule, presetTimeMinutes()),
    0,
    1,
  );
  const enabled = amount > 0.015;
  const activeRatio = THREE.MathUtils.lerp(
    settings.duskActiveRatio ?? 0.34,
    settings.nightActiveRatio ?? 0.67,
    amount,
  );

  const lightIntensity = enabled
    ? THREE.MathUtils.lerp(
        settings.duskIntensity ?? 0.045,
        (settings.nightIntensity ?? 0.28) * (nightLook.windows ?? 1),
        amount,
      )
    : 0;
  for (const group of windowPresetGroups.values()) {
    const activeCount = enabled
      ? Math.max(1, Math.round(group.length * activeRatio))
      : 0;
    for (let index = 0; index < group.length; index++) {
      const preset = group[index];
      const active = index < activeCount;
      preset.node.visible = !interiors?.current && hiddenInteriorWindows.size===0;
      if (preset.glowLight) {
        preset.glowLight.visible = active && enabled && !interiors?.current && hiddenInteriorWindows.size===0;
        preset.glowLight.color.copy(lightColor);
        preset.glowLight.intensity = active
          ? THREE.MathUtils.lerp(
              settings.glowDuskIntensity ?? 8,
              settings.glowNightIntensity ?? 92,
              amount,
            )
          : 0;
      }
      for (const state of preset.materialStates) {
        if (state.supportsColor) {
          state.material.color.copy(state.baseColor);
        }
        if (!state.supportsEmission) continue;
        state.material.emissive.copy(state.baseEmissive);
        state.material.emissiveIntensity = state.baseEmissiveIntensity;
        if (active) {
          state.material.emissive.copy(lightColor);
          state.material.emissiveIntensity = lightIntensity;
        }
      }
    }
  }
}

function daylightProfile() {
  const cycle = lightingTuning.dayCycle;
  const frames = Array.isArray(cycle?.keyframes)
    ? [...cycle.keyframes].sort((a, b) => a.minute - b.minute)
    : [];
  if (cycle?.enabled === false || frames.length < 2) {
    const hemisphere = lightingTuning.hemisphere ?? {};
    const key = lightingTuning.key ?? {};
    const fill = lightingTuning.fill ?? {};
    return {
      exposure: rendererTuning.exposure ?? 0.88,
      rays: {
        color: new THREE.Color('#ffb35c'),
        opacity: 0,
      },
      ambient: {
        color: new THREE.Color(hemisphere.skyColor ?? '#ffffff'),
        intensity: hemisphere.ambientIntensity ?? 0.10,
      },
      hemisphere: {
        skyColor: new THREE.Color(hemisphere.skyColor ?? '#ffffff'),
        groundColor: new THREE.Color(hemisphere.groundColor ?? '#303746'),
        intensity: hemisphere.intensity ?? 0.78,
      },
      key: {
        color: new THREE.Color(key.color ?? '#fff4e8'),
        intensity: key.intensity ?? 1.35,
        positionOffset: key.positionOffset ?? { x: 0.8, y: 1.35, z: 0.65 },
      },
      fill: {
        color: new THREE.Color(fill.color ?? '#9db7ff'),
        intensity: fill.intensity ?? 0.32,
        positionOffset: fill.positionOffset ?? { x: -0.8, y: 0.7, z: -0.65 },
      },
      grading: {
        ...gradeFrame(),
        warmColor: new THREE.Color(gradeFrame().warmColor),
      },
      shadowIntensity: lightingTuning.shadows?.intensity ?? 1,
      shadowRadius: lightingTuning.shadows?.radius ?? 1,
    };
  }

  const minute = presetTimeMinutes();
  let fromIndex = frames.length - 1;
  for (let index = 0; index < frames.length; index++) {
    if (frames[index].minute <= minute) fromIndex = index;
  }
  const from = frames[fromIndex];
  const to = frames[(fromIndex + 1) % frames.length];
  const fromMinute = from.minute;
  const toMinute = to.minute <= fromMinute ? to.minute + 1440 : to.minute;
  const currentMinute = minute < fromMinute ? minute + 1440 : minute;
  const linearAmount = THREE.MathUtils.clamp(
    (currentMinute - fromMinute) / Math.max(1, toMinute - fromMinute),
    0,
    1,
  );
  const amount = linearAmount * linearAmount * (3 - 2 * linearAmount);

  const profile = {
    exposure: interpolateNumber(from.exposure, to.exposure, amount),
    rays: {
      color: interpolateColor(
        from.rays?.color,
        to.rays?.color,
        amount,
        '#ffb35c',
      ),
      opacity: interpolateNumber(
        from.rays?.opacity,
        to.rays?.opacity,
        amount,
      ),
    },
    ambient: {
      color: interpolateColor(
        from.ambient?.color,
        to.ambient?.color,
        amount,
        '#ffffff',
      ),
      intensity: interpolateNumber(
        from.ambient?.intensity,
        to.ambient?.intensity,
        amount,
      ),
    },
    hemisphere: {
      skyColor: interpolateColor(
        from.hemisphere?.skyColor,
        to.hemisphere?.skyColor,
        amount,
        '#ffffff',
      ),
      groundColor: interpolateColor(
        from.hemisphere?.groundColor,
        to.hemisphere?.groundColor,
        amount,
        '#303746',
      ),
      intensity: interpolateNumber(
        from.hemisphere?.intensity,
        to.hemisphere?.intensity,
        amount,
      ),
    },
    key: {
      color: interpolateColor(
        from.key?.color,
        to.key?.color,
        amount,
        '#fff4e8',
      ),
      intensity: interpolateNumber(
        from.key?.intensity,
        to.key?.intensity,
        amount,
      ),
      positionOffset: interpolateOffset(
        from.key?.positionOffset,
        to.key?.positionOffset,
        amount,
      ),
    },
    fill: {
      color: interpolateColor(
        from.fill?.color,
        to.fill?.color,
        amount,
        '#9db7ff',
      ),
      intensity: interpolateNumber(
        from.fill?.intensity,
        to.fill?.intensity,
        amount,
      ),
      positionOffset: interpolateOffset(
        from.fill?.positionOffset,
        to.fill?.positionOffset,
        amount,
      ),
    },
    grading: interpolateGrade(from, to, amount),
    shadowIntensity: interpolateNumber(
      from.shadowIntensity,
      to.shadowIntensity,
      amount,
    ),
    shadowRadius: interpolateNumber(
      from.shadowRadius,
      to.shadowRadius,
      amount,
    ),
  };
  return applyIsolatedDaylightPhases(profile, minute, cycle.isolatedPhases);
}

function phaseEnvelope(minute, phase) {
  const start = ((phase.startMinute ?? 0) % 1440 + 1440) % 1440;
  const end = ((phase.endMinute ?? start) % 1440 + 1440) % 1440;
  const duration = (end - start + 1440) % 1440;
  if (duration <= 0) return 0;

  const elapsed = (minute - start + 1440) % 1440;
  if (elapsed > duration) return 0;

  const fade = Math.min(
    Math.max(0, phase.fadeMinutes ?? 0),
    duration * 0.5,
  );
  if (fade <= 0) return 1;
  const fadeIn = THREE.MathUtils.smoothstep(elapsed, 0, fade);
  const fadeOut = THREE.MathUtils.smoothstep(duration - elapsed, 0, fade);
  return Math.min(fadeIn, fadeOut);
}

function blendPhaseColor(current, next, amount) {
  return next == null
    ? current.clone()
    : current.clone().lerp(new THREE.Color(next), amount);
}

function blendPhaseOffset(current, next, amount) {
  if (!next) return { ...current };
  return {
    x: THREE.MathUtils.lerp(current.x, next.x ?? current.x, amount),
    y: THREE.MathUtils.lerp(current.y, next.y ?? current.y, amount),
    z: THREE.MathUtils.lerp(current.z, next.z ?? current.z, amount),
  };
}

function applyIsolatedDaylightPhases(base, minute, phases) {
  if (!Array.isArray(phases) || phases.length === 0) return base;
  let profile = base;

  for (const phase of phases) {
    const amount = phaseEnvelope(minute, phase);
    const next = phase.profile;
    if (amount <= 0 || !next) continue;

    profile = {
      exposure: interpolateNumber(profile.exposure, next.exposure, amount),
      rays: {
        color: blendPhaseColor(profile.rays.color, next.rays?.color, amount),
        opacity: interpolateNumber(
          profile.rays.opacity,
          next.rays?.opacity,
          amount,
        ),
      },
      ambient: {
        color: blendPhaseColor(
          profile.ambient.color,
          next.ambient?.color,
          amount,
        ),
        intensity: interpolateNumber(
          profile.ambient.intensity,
          next.ambient?.intensity,
          amount,
        ),
      },
      hemisphere: {
        skyColor: blendPhaseColor(
          profile.hemisphere.skyColor,
          next.hemisphere?.skyColor,
          amount,
        ),
        groundColor: blendPhaseColor(
          profile.hemisphere.groundColor,
          next.hemisphere?.groundColor,
          amount,
        ),
        intensity: interpolateNumber(
          profile.hemisphere.intensity,
          next.hemisphere?.intensity,
          amount,
        ),
      },
      key: {
        color: blendPhaseColor(profile.key.color, next.key?.color, amount),
        intensity: interpolateNumber(
          profile.key.intensity,
          next.key?.intensity,
          amount,
        ),
        positionOffset: blendPhaseOffset(
          profile.key.positionOffset,
          next.key?.positionOffset,
          amount,
        ),
      },
      fill: {
        color: blendPhaseColor(profile.fill.color, next.fill?.color, amount),
        intensity: interpolateNumber(
          profile.fill.intensity,
          next.fill?.intensity,
          amount,
        ),
        positionOffset: blendPhaseOffset(
          profile.fill.positionOffset,
          next.fill?.positionOffset,
          amount,
        ),
      },
      grading: {
        warmColor: blendPhaseColor(
          profile.grading.warmColor,
          next.grading?.warmColor,
          amount,
        ),
        warmStrength: interpolateNumber(
          profile.grading.warmStrength,
          next.grading?.warmStrength,
          amount,
        ),
        warmStart: interpolateNumber(
          profile.grading.warmStart,
          next.grading?.warmStart,
          amount,
        ),
        warmEnd: interpolateNumber(
          profile.grading.warmEnd,
          next.grading?.warmEnd,
          amount,
        ),
        neutralWarmResponse: interpolateNumber(
          profile.grading.neutralWarmResponse,
          next.grading?.neutralWarmResponse,
          amount,
        ),
        contrast: interpolateNumber(
          profile.grading.contrast,
          next.grading?.contrast,
          amount,
        ),
        saturation: interpolateNumber(
          profile.grading.saturation,
          next.grading?.saturation,
          amount,
        ),
      },
      shadowIntensity: interpolateNumber(
        profile.shadowIntensity,
        next.shadowIntensity,
        amount,
      ),
      shadowRadius: interpolateNumber(
        profile.shadowRadius,
        next.shadowRadius,
        amount,
      ),
    };
  }
  return profile;
}

function applyDaylightProfile() {
  if (featurePanelEnabled) { applyTestFeatureProfile(); return; }
  if (geometryOnly || rawModeEnabled) return;
  const morningLook = effectiveMorningLook();
  if (
    !ambientLight ||
    !hemisphereLight ||
    !keyLight ||
    !fillLight ||
    !lightingFrame
  ) return;
  if (activeColorTemperature() !== 0 && !effectComposer) {
    installPostProcessing();
    resize();
  }
  const profile = daylightProfileWithPreview(daylightProfile());
  const night = nightSkyAmount();
  profile.exposure = THREE.MathUtils.lerp(profile.exposure, nightLook.exposure ?? 0.56, night);
  for (const [section, setting] of [
    ['ambient', 'ambient'], ['hemisphere', 'hemisphere'],
    ['key', 'moonlight'], ['fill', 'fill'],
  ]) {
    profile[section].intensity = THREE.MathUtils.lerp(
      profile[section].intensity,
      nightLook[setting] ?? profile[section].intensity,
      night,
    );
  }
  profile.shadowIntensity = THREE.MathUtils.lerp(profile.shadowIntensity, 1.0, night);
  profile.key.color.lerp(new THREE.Color('#c3d5ff'), night);
  profile.fill.color.lerp(new THREE.Color('#899fc8'), night);
  activeDaylightProfile = profile;

  renderer.toneMappingExposure = profile.exposure;
  const shadowContrast = lightingTuning.shadowContrast ?? {};
  const contrastAmount = shadowContrast.enabled === false || isMidday()
    ? 0
    : THREE.MathUtils.smoothstep(
        profile.key.intensity,
        shadowContrast.startKeyIntensity ?? 0.75,
        shadowContrast.fullKeyIntensity ?? 3.0,
      );
  ambientLight.color.copy(profile.ambient.color);
  const ambientIntensity = profile.ambient.intensity * THREE.MathUtils.lerp(
    1,
    shadowContrast.ambientScale ?? 0.62,
    contrastAmount,
  );
  ambientLight.intensity = ambientIntensity +
    (rendererTuning.visibilityLift?.ambient ?? 0);
  hemisphereLight.color.copy(profile.hemisphere.skyColor);
  hemisphereLight.groundColor.copy(profile.hemisphere.groundColor);
  const hemisphereIntensity = profile.hemisphere.intensity *
    THREE.MathUtils.lerp(
      1,
      shadowContrast.hemisphereScale ?? 0.62,
      contrastAmount,
    );
  hemisphereLight.intensity = hemisphereIntensity +
    (rendererTuning.visibilityLift?.hemisphere ?? 0);
  keyLight.color.copy(profile.key.color);
  keyLight.intensity = profile.key.intensity;
  fillLight.color.copy(profile.fill.color);
  const fillIntensity = profile.fill.intensity * THREE.MathUtils.lerp(
    1,
    shadowContrast.fillScale ?? 0.64,
    contrastAmount,
  );
  fillLight.intensity = fillIntensity;
  updateDaylightBloom(profile);
  if (cinematicGradePass) {
    const uniforms = cinematicGradePass.uniforms;
    uniforms.warmColor.value.copy(profile.grading.warmColor);
    uniforms.warmStrength.value = profile.grading.warmStrength;
    uniforms.warmStart.value = profile.grading.warmStart;
    uniforms.warmEnd.value = Math.max(
      profile.grading.warmStart + 0.001,
      profile.grading.warmEnd,
    );
    uniforms.neutralWarmResponse.value = profile.grading.neutralWarmResponse;
    uniforms.contrast.value = profile.grading.contrast;
    uniforms.saturation.value = profile.grading.saturation;
    uniforms.temperature.value = activeColorTemperature();
  }
  updateReflectionEnvironment(profile);

  configureDirectionalLight(
    keyLight,
    profile.key,
    lightingFrame.center,
    lightingFrame.dimension,
  );
  configureDirectionalLight(
    fillLight,
    profile.fill,
    lightingFrame.center,
    lightingFrame.dimension,
  );
  updateSunRays(profile);
  updateGroundSunRays(profile);
  updateAtmosphericBackground(profile, { force: true });
  updateAtmosphericPostProcessing(profile);
  updateNightSky();

  if (keyLight.castShadow) {
    keyLight.shadow.intensity = profile.shadowIntensity;
    keyLight.shadow.radius = profile.shadowRadius;
    if (lightingTuning.shadows?.dynamicFit && model) {
      updateDirectionalShadowForView({ force: true });
    } else if (lightingTuning.shadows?.tightFit !== false) {
      fitShadowCameraToBounds(
        keyLight,
        lightingFrame.bounds,
        lightingFrame.dimension,
      );
    }
    refreshDirectionalShadow({ recreate: model !== null });
  }
  applyWindowPresetLighting();
  nightCinema?.update(night, isDayCustomization() ? morningLook.textures !== false : texturesEnabled,
    keyLight, lightingFrame,
  isDayCustomization() ? 1 : phaseEnvelope(presetTimeMinutes(), rendererTuning.dawnSurface ?? {}),
  isDayCustomization() ? morningLook.textureDetail ?? 1.65 : undefined,
  isDayCustomization() ? morningLook.sunHighlights ?? 1 : 1,
  isDayCustomization() ? (morningLook.reflections ?? 8) / 8 : 1,
  morningLook.foliageStrength ?? 0);
}

function focusNode(node, options = {}) {
  const box = new THREE.Box3().setFromObject(node);
  if (box.isEmpty()) return;

  // Keep the actual top-view pose and projection until the transition starts.
  const source = mapViewMode === '2d' || viewTransition
    ? { camera: camera.clone(), target: controls.target.clone() }
    : null;

  // Clear any damped orbit delta before capturing the focus route.
  const visiblePosition = camera.position.clone();
  const visibleTarget = controls.target.clone();
  clearControlsMomentum();
  camera.position.copy(visiblePosition);
  controls.target.copy(visibleTarget);
  camera.lookAt(visibleTarget);

  const hasFixedView =
    Array.isArray(options.position) && options.position.length === 3 &&
    Array.isArray(options.target) && options.target.length === 3;
  const requestedTarget = hasFixedView
    ? new THREE.Vector3().fromArray(options.target)
    : box.getCenter(new THREE.Vector3());
  if (Array.isArray(options.targetOffset) && options.targetOffset.length === 3) {
    requestedTarget.add(new THREE.Vector3().fromArray(options.targetOffset));
  }
  if (!options.useVisualCenter && navigationTargetHeight !== null) {
    requestedTarget.y = navigationTargetHeight;
  }
  const direction = hasFixedView
    ? new THREE.Vector3().fromArray(options.position).sub(requestedTarget).normalize()
    : Array.isArray(options.direction) &&
      options.direction.length === 3
    ? new THREE.Vector3().fromArray(options.direction).normalize()
    : camera.position.clone().sub(controls.target).normalize();
  const focusPoints = focusPointsForNode(node);
  const points = focusPoints.length > 0 ? focusPoints : [box.min, box.max];
  const requestedDistance = focusDistanceForPoints(
    points,
    requestedTarget,
    direction,
    options,
  );
  const distance = THREE.MathUtils.clamp(
    requestedDistance * (options.distanceScale ?? 1),
    baseMinDistance,
    baseMaxDistance,
  );
  const target = interiors?.current
    ? constrainNavigationPoint(requestedTarget)
    : hasFixedView || options.constrainToNavigation === false
    ? requestedTarget.clone()
    : constrainedFocusTarget(requestedTarget, direction, distance);
  const destination = hasFixedView
    ? new THREE.Vector3().fromArray(options.position)
    : target.clone().addScaledVector(direction, distance);
  const finalMinDistance = baseMinDistance;
  const finalMaxDistance = baseMaxDistance;

  if (options.immediate === true || !selectionOptions.cameraAnimation) {
    if (source) {
      viewTransition = null;
      activateMapCamera('3d');
    }
    navigationSpring = null;
    cameraFocus = null;
    navigationConstraintSuspended = false;
    controls.minDistance = finalMinDistance;
    controls.maxDistance = finalMaxDistance;
    controls.target.copy(target);
    camera.position.copy(destination);
    camera.lookAt(target);
    clearControlsMomentum();
    requestRender();
    return;
  }

  if (source) {
    const destinationCamera = perspectiveCamera.clone();
    destinationCamera.position.copy(destination);
    destinationCamera.lookAt(target);
    updatePerspectiveProjection(destinationCamera);
    navigationConstraintSuspended = false;
    beginViewTransition('3d', destinationCamera, target, source);
    return;
  }

  navigationSpring = null;
  navigationConstraintSuspended = false;
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  cameraFocus = {
    interiorTravel: !!interiors?.current || options.interiorTravel === true,
    startedAt: performance.now(),
    duration: selectionTuning.focusDuration ?? 650,
    fromPosition: camera.position.clone(),
    fromTarget: controls.target.clone(),
    toPosition: destination,
    toTarget: target,
    finalMinDistance,
    finalMaxDistance,
  };
  beginCameraTransitionResolution();
  requestRender();
}

function focusZone(zoneId, overrides = {}) {
  if (interiors?.current) exitInterior({ focus: false });
  if (!config) return false;
  const zone = config.zones.find((entry) => entry.id === zoneId);
  const node = zone ? zoneNodes.get(zone.nodeName) : null;
  if (!zone || !node) return false;
  focusNode(node, { ...zone.focus, ...overrides });
  return true;
}

function frameModel(object) {
  const framingNodes = cameraTuning.framingNodes;
  const bounds = new THREE.Box3();
  if (Array.isArray(framingNodes) && framingNodes.length > 0) {
    for (const nodeName of framingNodes) {
      const node = findModelNode(object, nodeName);
      if (node) bounds.expandByObject(node);
    }
  }
  if (bounds.isEmpty()) bounds.setFromObject(object);
  configureNavigationBounds(object, bounds);
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const maxDimension = Math.max(size.x, size.y, size.z);
  const sphere = bounds.getBoundingSphere(new THREE.Sphere());

  const cameraOffset = cameraTuning.positionOffset ?? {
    x: 0.55,
    y: 0.62,
    z: 0.78,
  };
  const direction = new THREE.Vector3(
    cameraOffset.x,
    cameraOffset.y,
    cameraOffset.z,
  ).normalize();
  const verticalFov = THREE.MathUtils.degToRad(camera.fov);
  const horizontalFov = 2 * Math.atan(Math.tan(verticalFov / 2) * camera.aspect);
  const fitFov = cameraTuning.framing === 'cover'
    ? Math.max(verticalFov, horizontalFov)
    : Math.min(verticalFov, horizontalFov);
  const fitPadding = cameraTuning.fitPadding ?? 1.12;
  const fitDistance =
    (sphere.radius / Math.sin(fitFov / 2)) * fitPadding;

  const configuredPosition = cameraTuning.initialPosition;
  const configuredTarget = cameraTuning.initialTarget;
  const hasConfiguredView =
    Array.isArray(configuredPosition) && configuredPosition.length === 3 &&
    Array.isArray(configuredTarget) && configuredTarget.length === 3;
  const target = hasConfiguredView
    ? new THREE.Vector3().fromArray(configuredTarget)
    : center;

  const targetHeightCorrection =
    cameraTuning.navigation?.lockTargetToGround !== false &&
    navigationTargetHeight !== null
      ? navigationTargetHeight - target.y
      : 0;
  target.y += targetHeightCorrection;

  if (hasConfiguredView) {
    camera.position.fromArray(configuredPosition);
    camera.position.y += targetHeightCorrection;
  } else {
    camera.position.copy(center).addScaledVector(direction, fitDistance);
  }
  camera.lookAt(target);
  controls.target.copy(target);
  baseMinDistance =
    maxDimension * (cameraTuning.minDistanceMultiplier ?? 0.24);
  baseMaxDistance =
    maxDimension * (cameraTuning.maxDistanceMultiplier ?? 2.35);
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  controls.update();
  applyNavigationConstraint();

  const initialZone = config?.zones?.find(
    (zone) => zone.id === cameraTuning.initialZoneId,
  );
  const initialZoneNode = initialZone
    ? zoneNodes.get(initialZone.nodeName)
    : null;
  if (initialZone && initialZoneNode) {
    focusNode(initialZoneNode, { ...initialZone.focus, immediate: true });
  }

  lightingFrame = {
    center: center.clone(),
    bounds: bounds.clone(),
    dimension: maxDimension,
  };
  applyDaylightProfile();

  if (keyLight?.castShadow) {
    const shadow = keyLight.shadow;
    const requestedMapSize = lightingTuning.shadows?.mapSize ?? 1024;
    const supportedMapSize = renderer.capabilities.maxTextureSize;
    shadow.mapSize.setScalar(Math.min(requestedMapSize, supportedMapSize));

    if (lightingTuning.shadows?.tightFit !== false) {
      fitShadowCameraToBounds(keyLight, bounds, maxDimension);
    } else {
      const coverage =
        maxDimension * (lightingTuning.shadows?.coverageMultiplier ?? 0.72);
      shadow.camera.left = -coverage;
      shadow.camera.right = coverage;
      shadow.camera.top = coverage;
      shadow.camera.bottom = -coverage;
      shadow.camera.near = 0.1;
      shadow.camera.far = maxDimension * 4;
    }
    shadow.bias = lightingTuning.shadows?.bias ?? -0.00035;
    shadow.normalBias = lightingTuning.shadows?.normalBias ?? 0.025;
    shadow.camera.updateProjectionMatrix();
    renderer.shadowMap.needsUpdate = true;
  }

  initialCameraPosition = camera.position.clone();
  initialTarget = controls.target.clone();
  const initialOffset = initialCameraPosition.clone().sub(initialTarget);
  const configuredZeroBearing = cameraTuning.zeroBearingDegrees == null
    ? NaN : Number(cameraTuning.zeroBearingDegrees);
  initialAzimuth = Number.isFinite(configuredZeroBearing)
    ? THREE.MathUtils.degToRad(configuredZeroBearing)
    : Math.atan2(initialOffset.x, initialOffset.z);
  lastSentBearing = null;
  sendCameraState({ force: true });
  requestRender();
}

function fitShadowCameraToBounds(light, bounds, dimension) {
  const shadowCamera = light.shadow.camera;
  shadowCamera.position.copy(light.position);
  shadowCamera.lookAt(light.target.position);
  shadowCamera.updateMatrixWorld(true);

  const min = bounds.min;
  const max = bounds.max;
  const corners = [
    new THREE.Vector3(min.x, min.y, min.z),
    new THREE.Vector3(min.x, min.y, max.z),
    new THREE.Vector3(min.x, max.y, min.z),
    new THREE.Vector3(min.x, max.y, max.z),
    new THREE.Vector3(max.x, min.y, min.z),
    new THREE.Vector3(max.x, min.y, max.z),
    new THREE.Vector3(max.x, max.y, min.z),
    new THREE.Vector3(max.x, max.y, max.z),
  ];
  const lightSpaceBounds = new THREE.Box3();
  for (const corner of corners) {
    lightSpaceBounds.expandByPoint(
      corner.applyMatrix4(shadowCamera.matrixWorldInverse),
    );
  }

  const padding = dimension * (lightingTuning.shadows?.fitPadding ?? 0.04);
  shadowCamera.left = lightSpaceBounds.min.x - padding;
  shadowCamera.right = lightSpaceBounds.max.x + padding;
  shadowCamera.bottom = lightSpaceBounds.min.y - padding;
  shadowCamera.top = lightSpaceBounds.max.y + padding;
  shadowCamera.near = Math.max(0.1, -lightSpaceBounds.max.z - padding);
  shadowCamera.far = Math.max(
    shadowCamera.near + 1,
    -lightSpaceBounds.min.z + padding,
  );
  shadowCamera.updateProjectionMatrix();
}

function visibleShadowBounds() {
  if (!lightingFrame || !model) return null;
  camera.updateMatrixWorld(true);

  const sceneBounds = lightingFrame.bounds;
  const groundY = navigationTargetHeight ?? sceneBounds.min.y;
  const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -groundY);
  const raycaster = new THREE.Raycaster();
  const point = new THREE.Vector3();
  const bounds = new THREE.Box3();
  const cameraDistance = camera.position.distanceTo(controls.target);
  const maxRayDistance = Math.min(
    lightingFrame.dimension * 0.78,
    cameraDistance *
      (lightingTuning.shadows?.viewRayDistanceMultiplier ?? 1.75),
  );

  // The topmost strip is normally sky. Sampling until 0.72 avoids wasting
  // shadow resolution behind the campus while still covering tall buildings.
  const samplesX = [-1, -0.5, 0, 0.5, 1];
  const samplesY = [-1, -0.5, 0, 0.36, 0.72];
  for (const x of samplesX) {
    for (const y of samplesY) {
      raycaster.setFromCamera({ x, y }, camera);
      const hit = raycaster.ray.intersectPlane(groundPlane, point);
      if (!hit || hit.distanceTo(camera.position) > maxRayDistance) {
        raycaster.ray.at(maxRayDistance, point);
      }
      point.x = THREE.MathUtils.clamp(
        point.x,
        sceneBounds.min.x,
        sceneBounds.max.x,
      );
      point.z = THREE.MathUtils.clamp(
        point.z,
        sceneBounds.min.z,
        sceneBounds.max.z,
      );
      bounds.expandByPoint(point);
    }
  }

  point.copy(controls.target);
  point.x = THREE.MathUtils.clamp(
    point.x,
    sceneBounds.min.x,
    sceneBounds.max.x,
  );
  point.z = THREE.MathUtils.clamp(
    point.z,
    sceneBounds.min.z,
    sceneBounds.max.z,
  );
  bounds.expandByPoint(point);
  if (bounds.isEmpty()) return sceneBounds.clone();

  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const sceneSize = sceneBounds.getSize(new THREE.Vector3());
  const minimumSpan = lightingFrame.dimension *
    (lightingTuning.shadows?.minimumViewSpanRatio ?? 0.18);
  const maximumSpan = lightingFrame.dimension *
    (lightingTuning.shadows?.maximumViewSpanRatio ?? 0.60);
  const padding = Math.max(size.x, size.z, minimumSpan) *
    (lightingTuning.shadows?.viewPadding ?? 0.065);
  const spanX = THREE.MathUtils.clamp(
    size.x + padding * 2,
    Math.min(minimumSpan, sceneSize.x),
    Math.min(maximumSpan, sceneSize.x),
  );
  const spanZ = THREE.MathUtils.clamp(
    size.z + padding * 2,
    Math.min(minimumSpan, sceneSize.z),
    Math.min(maximumSpan, sceneSize.z),
  );

  center.x = THREE.MathUtils.clamp(
    center.x,
    sceneBounds.min.x + spanX / 2,
    sceneBounds.max.x - spanX / 2,
  );
  center.z = THREE.MathUtils.clamp(
    center.z,
    sceneBounds.min.z + spanZ / 2,
    sceneBounds.max.z - spanZ / 2,
  );
  return new THREE.Box3(
    new THREE.Vector3(
      center.x - spanX / 2,
      sceneBounds.min.y,
      center.z - spanZ / 2,
    ),
    new THREE.Vector3(
      center.x + spanX / 2,
      sceneBounds.max.y,
      center.z + spanZ / 2,
    ),
  );
}

function updateDirectionalShadowForView({ force = false } = {}) {
  if (
    !keyLight?.castShadow ||
    !lightingTuning.shadows?.dynamicFit ||
    !lightingFrame ||
    !model
  ) return;
  const now = performance.now();
  if (!force && (controlsInteractionActive || now < shadowUpdateResumeAt)) {
    return;
  }
  const interactionUpdateInterval =
    lightingTuning.shadows?.interactionUpdateInterval ?? 0;
  if (
    !force &&
    controlsInteractionActive &&
    now - lastShadowViewUpdateAt < interactionUpdateInterval
  ) return;
  const values = [
    ...camera.position.toArray(),
    ...controls.target.toArray(),
    ...keyLight.position.toArray(),
  ];
  const signature = values.map((value) => value.toFixed(2)).join(':');
  if (!force && signature === shadowViewSignature) return;

  const bounds = visibleShadowBounds();
  if (!bounds) return;
  const size = bounds.getSize(new THREE.Vector3());
  fitShadowCameraToBounds(
    keyLight,
    bounds,
    Math.max(size.x, size.y, size.z),
  );
  keyLight.shadow.needsUpdate = true;
  renderer.shadowMap.needsUpdate = true;
  shadowViewSignature = signature;
  lastShadowViewUpdateAt = now;
}

function refreshDirectionalShadow({ recreate = false } = {}) {
  if (!keyLight?.castShadow) return;
  const shadow = keyLight.shadow;
  if (recreate && shadow.map) {
    shadow.map.dispose();
    shadow.map = null;
  }
  shadow.needsUpdate = true;
  renderer.shadowMap.needsUpdate = true;
}

function installLighting() {
  if (geometryOnly) {
    if (basicLightingTest || featurePanelEnabled) {
      // Fixed diffuse-only test. Do not install the normal environment,
      // climate shaders, shadow maps, extra fills or atmosphere resources.
      hemisphereLight = new THREE.HemisphereLight('#ffffff', '#60666f', 1);
      keyLight = new THREE.DirectionalLight('#ffffff', 2);
      keyLight.position.set(120, 240, -120);
      keyLight.castShadow = false;
      scene.add(hemisphereLight, keyLight, keyLight.target);
    }
    return;
  }
  const hemisphere = lightingTuning.hemisphere ?? {};
  ambientLight = new THREE.AmbientLight(
    hemisphere.skyColor ?? '#ffffff',
    hemisphere.ambientIntensity ?? 0.10,
  );
  scene.add(ambientLight);

  hemisphereLight = new THREE.HemisphereLight(
    hemisphere.skyColor ?? '#ffffff',
    hemisphere.groundColor ?? '#303746',
    hemisphere.intensity ?? 0.78,
  );
  scene.add(hemisphereLight);

  const key = lightingTuning.key ?? {};
  keyLight = new THREE.DirectionalLight(
    key.color ?? '#fff4e8',
    key.intensity ?? 1.35,
  );
  keyLight.castShadow = lightingTuning.shadows?.enabled ?? true;
  keyLight.shadow.mapSize.setScalar(
    Math.min(
      lightingTuning.shadows?.mapSize ?? 1024,
      renderer.capabilities.maxTextureSize,
    ),
  );
  scene.add(keyLight);
  scene.add(keyLight.target);

  const fill = lightingTuning.fill ?? {};
  fillLight = new THREE.DirectionalLight(
    fill.color ?? '#9db7ff',
    fill.intensity ?? 0.32,
  );
  scene.add(fillLight);
  scene.add(fillLight.target);
  if (graphicsProfile !== 'basic') installSunRays();
  installReflectionEnvironment();
  installAtmosphericBackground();
}

function installGroundSunRays(root) {
  const settings = lightingTuning.groundRays ?? {};
  if (settings.enabled === false) return;

  groundSunRayMaterial = new THREE.ShaderMaterial({
    uniforms: {
      rayColor: { value: new THREE.Color(settings.color ?? '#ffb24d') },
      rayOpacity: { value: 0 },
      rayCenter: { value: new THREE.Vector2() },
      rayDirection: { value: new THREE.Vector2(0, 1) },
      rayPerpendicular: { value: new THREE.Vector2(1, 0) },
      rayDimension: { value: 1 },
      rayLengthRatio: { value: settings.lengthRatio ?? 1.45 },
      rayWidths: { value: new THREE.Vector3(0.065, 0.038, 0.024) },
      rayOffsets: { value: new THREE.Vector3(-0.24, 0.015, 0.27) },
      rayStrengths: { value: new THREE.Vector3(0.72, 1.0, 0.58) },
    },
    vertexShader: /* glsl */`
      varying vec3 vRayWorldPosition;
      varying vec3 vRayWorldNormal;

      void main() {
        vec4 worldPosition = modelMatrix * vec4(position, 1.0);
        vRayWorldPosition = worldPosition.xyz;
        vRayWorldNormal = normalize(mat3(modelMatrix) * normal);
        gl_Position = projectionMatrix * viewMatrix * worldPosition;
      }
    `,
    fragmentShader: /* glsl */`
      uniform vec3 rayColor;
      uniform float rayOpacity;
      uniform vec2 rayCenter;
      uniform vec2 rayDirection;
      uniform vec2 rayPerpendicular;
      uniform float rayDimension;
      uniform float rayLengthRatio;
      uniform vec3 rayWidths;
      uniform vec3 rayOffsets;
      uniform vec3 rayStrengths;
      varying vec3 vRayWorldPosition;
      varying vec3 vRayWorldNormal;

      float softBand(float coordinate, float offset, float width) {
        float distanceFromCenter = abs(coordinate - offset);
        return 1.0 - smoothstep(width * 0.22, width, distanceFromCenter);
      }

      void main() {
        vec2 worldOffset = (vRayWorldPosition.xz - rayCenter) / rayDimension;
        float across = dot(worldOffset, rayPerpendicular);
        float along = dot(worldOffset, rayDirection);
        float halfLength = rayLengthRatio * 0.5;
        float edgeSoftness = min(0.18, halfLength * 0.34);
        float alongMask = smoothstep(
          -halfLength,
          -halfLength + edgeSoftness,
          along
        ) * (1.0 - smoothstep(
          halfLength - edgeSoftness,
          halfLength,
          along
        ));
        float bands = softBand(across, rayOffsets.x, rayWidths.x) *
          rayStrengths.x;
        bands += softBand(across, rayOffsets.y, rayWidths.y) *
          rayStrengths.y;
        bands += softBand(across, rayOffsets.z, rayWidths.z) *
          rayStrengths.z;
        float upwardSurface = smoothstep(0.34, 0.82, vRayWorldNormal.y);
        float alpha = min(bands, 1.0) * alongMask * upwardSurface * rayOpacity;
        if (alpha <= 0.001) discard;
        gl_FragColor = vec4(rayColor, alpha);
      }
    `,
    transparent: true,
    // Normal blending transfers the warm hue to the surface instead of only
    // adding luminance until the ray looks pale or white.
    blending: THREE.NormalBlending,
    depthTest: true,
    depthWrite: false,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2,
    side: THREE.DoubleSide,
    toneMapped: true,
  });

  const nodeNames = settings.nodes ??
    cameraTuning.navigation?.groundNodes ??
    [];
  const sourceMeshes = [];
  for (const nodeName of nodeNames) {
    const node = findModelNode(root, nodeName);
    node?.traverse((child) => {
      if (child.isMesh && !child.userData.isGroundSunRay) {
        sourceMeshes.push(child);
      }
    });
  }
  for (const source of new Set(sourceMeshes)) {
    const overlay = new THREE.Mesh(source.geometry, groundSunRayMaterial);
    overlay.name = `${source.name || 'ground'}_sun_rays`;
    overlay.userData.isGroundSunRay = true;
    overlay.castShadow = false;
    overlay.receiveShadow = false;
    overlay.renderOrder = (source.renderOrder ?? 0) + 1;
    overlay.raycast = () => {};
    groundSunRayMeshes.push(overlay);
    source.add(overlay);
  }
}

function updateGroundSunRays(profile) {
  const settings = lightingTuning.groundRays ?? {};
  if (
    settings.enabled === false ||
    !lightingFrame ||
    !keyLight ||
    groundSunRayMeshes.length === 0
  ) {
    for (const mesh of groundSunRayMeshes) mesh.visible = false;
    return;
  }

  const amount = THREE.MathUtils.clamp(
    (profile.rays?.opacity ?? 0) / 0.12,
    0,
    1,
  );
  if (amount <= 0.001) {
    for (const mesh of groundSunRayMeshes) mesh.visible = false;
    return;
  }

  const center = lightingFrame.center;
  const dimension = lightingFrame.dimension;
  const direction = keyLight.target.position
    .clone()
    .sub(keyLight.position)
    .setY(0);
  if (direction.lengthSq() < 0.0001) return;
  direction.normalize();
  const perpendicular = new THREE.Vector3(-direction.z, 0, direction.x);
  const widths = settings.widths ?? [0.065, 0.038, 0.024];
  const offsets = settings.offsets ?? [-0.24, 0.015, 0.27];
  const strengths = settings.strengths ?? [0.72, 1.0, 0.58];
  const baseColor = new THREE.Color(settings.color ?? '#ffb24d').lerp(
    profile.rays.color,
    settings.profileColorMix ?? 0.42,
  );
  const uniforms = groundSunRayMaterial.uniforms;
  uniforms.rayColor.value.copy(baseColor);
  uniforms.rayOpacity.value = amount * (settings.opacity ?? 0.18);
  uniforms.rayCenter.value.set(center.x, center.z);
  uniforms.rayDirection.value.set(direction.x, direction.z);
  uniforms.rayPerpendicular.value.set(perpendicular.x, perpendicular.z);
  uniforms.rayDimension.value = dimension;
  uniforms.rayLengthRatio.value = settings.lengthRatio ?? 1.45;
  uniforms.rayWidths.value.fromArray([
    widths[0] ?? 0.065,
    widths[1] ?? 0.038,
    widths[2] ?? 0.024,
  ]);
  uniforms.rayOffsets.value.fromArray([
    offsets[0] ?? -0.24,
    offsets[1] ?? 0.015,
    offsets[2] ?? 0.27,
  ]);
  uniforms.rayStrengths.value.fromArray([
    strengths[0] ?? 0.72,
    strengths[1] ?? 1.0,
    strengths[2] ?? 0.58,
  ]);
  for (const mesh of groundSunRayMeshes) mesh.visible = true;
}

function installSunRays() {
  const intensityFactors = [1, 0.72, 0.48];
  for (let index = 0; index < intensityFactors.length; index++) {
    const light = new THREE.SpotLight(
      '#ffb35c',
      0,
      0,
      0.20 + index * 0.035,
      0.90,
      2,
    );
    light.castShadow = false;
    light.userData.intensityFactor = intensityFactors[index];
    sunProjectionLights.push(light);
    scene.add(light);
    scene.add(light.target);
  }
}

function updateSunRays(profile) {
  if (sunProjectionLights.length === 0 || !keyLight || !lightingFrame) return;
  const projection = lightingTuning.sunProjection ?? {};
  if (projection.enabled === false) {
    for (const light of sunProjectionLights) light.intensity = 0;
    return;
  }
  const opacity = THREE.MathUtils.clamp(profile.rays?.opacity ?? 0, 0, 0.12);
  const dimension = lightingFrame.dimension;
  const center = lightingFrame.center;
  const origin = keyLight.position.clone();
  const targetOffsets = [
    [-0.10, 0.01, 0.07],
    [0.08, 0.015, -0.08],
    [0.20, 0.008, 0.12],
  ];

  for (let index = 0; index < sunProjectionLights.length; index++) {
    const light = sunProjectionLights[index];
    const offset = targetOffsets[index];
    const target = center.clone().add(new THREE.Vector3(
      dimension * offset[0],
      dimension * offset[1],
      dimension * offset[2],
    ));
    light.position.copy(origin);
    light.target.position.copy(target);
    light.target.updateMatrixWorld();
    light.color.copy(profile.rays.color);
    light.distance = dimension * 2.4;
    light.intensity = opacity *
      (projection.intensityMultiplier ?? 500000) *
      light.userData.intensityFactor;
  }
}

function atmosphereColor(color, alpha) {
  const srgb = color.clone().convertLinearToSRGB();
  return `rgba(${Math.round(srgb.r * 255)}, ${Math.round(srgb.g * 255)}, ${
    Math.round(srgb.b * 255)
  }, ${THREE.MathUtils.clamp(alpha, 0, 1)})`;
}

function installAtmosphericBackground() {
  const settings = lightingTuning.atmosphere ?? {};
  if (settings.enabled === false) return;
  atmosphereCanvas = document.createElement('canvas');
  atmosphereContext = atmosphereCanvas.getContext('2d');
  if (!atmosphereContext) {
    atmosphereCanvas = null;
    return;
  }
  atmosphereTexture = new THREE.CanvasTexture(atmosphereCanvas);
  atmosphereTexture.colorSpace = THREE.SRGBColorSpace;
  atmosphereTexture.generateMipmaps = false;
  atmosphereTexture.minFilter = THREE.LinearFilter;
  atmosphereTexture.magFilter = THREE.LinearFilter;
  applyConfiguredBackground();
}

function nightSkyAmount() {
  if (nightSkyTuning.enabled === false) return 0;
  return isDayCustomization() ? 0 : 1;
}

function updateNightSky() {
  if (middaySkyMesh) middaySkyMesh.visible = isMidday();
  if (sunsetSkyMesh) sunsetSkyMesh.visible = isSunset();
  if (morningSkyMesh) morningSkyMesh.visible = isMorning();
  if (!nightSkyPoints || !nightSkyMaterial) return;
  const amount = nightSkyAmount();
  nightSkyPoints.visible = amount > 0.001;
  nightSkyMaterial.uniforms.skyOpacity.value = amount;
  if (amount > 0.001) {
    const daytimeColor = new THREE.Color(
      cssColor(config?.backgroundColor, '#090a0d'),
    );
    const nightColor = new THREE.Color(
      nightSkyTuning.backgroundColor ?? '#02050c',
    );
    scene.background = daytimeColor.lerp(nightColor, amount);
  } else if (atmosphereTexture) {
    scene.background = atmosphereTexture;
  } else {
    scene.background = new THREE.Color(
      cssColor(config?.backgroundColor, '#090a0d'),
    );
  }
}

function updateNightSkyRenderScale() {
  if (!nightSkyMaterial) return;
  // gl_PointSize usa pixels do buffer. Acompanhar o pixel ratio faz cada
  // estrela conservar o mesmo tamanho visual durante e depois dos gestos.
  nightSkyMaterial.uniforms.pixelRatio.value = renderer.getPixelRatio();
}

function installNightSky() {
  if (nightSkyTuning.enabled === false || nightSkyPoints) return;
  const counts = nightSkyTuning.counts ?? {};
  const count = Math.max(1, Math.round(
    counts[graphicsProfile] ?? counts.balanced ?? 2600,
  ));
  const radius = 1900;
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  const sizes = new Float32Array(count);
  const brightness = new Float32Array(count);
  const sparkle = new Float32Array(count);
  const minSize = nightSkyTuning.minSize ?? 0.75;
  const maxSize = nightSkyTuning.maxSize ?? 2.1;
  const brightChance = nightSkyTuning.brightStarChance ?? 0.025;
  const brightMaxSize = nightSkyTuning.brightStarMaxSize ?? 4.8;

  for (let index = 0; index < count; index++) {
    const azimuth = Math.random() * Math.PI * 2;
    // Distribuicao uniforme em toda a esfera. Assim qualquer trecho de ceu
    // revelado pela camera tem estrelas, e o terreno recorta o horizonte.
    const vertical = Math.random() * 2 - 1;
    const horizontal = Math.sqrt(1 - vertical * vertical);
    positions[index * 3] = Math.cos(azimuth) * horizontal * radius;
    positions[index * 3 + 1] = vertical * radius;
    positions[index * 3 + 2] = Math.sin(azimuth) * horizontal * radius;

    const temperature = Math.random();
    const color = temperature < 0.16
      ? new THREE.Color('#b9d7ff')
      : temperature > 0.88
        ? new THREE.Color('#ffe0b2')
        : new THREE.Color('#f4f7ff');
    const colorVariation = 0.82 + Math.random() * 0.18;
    colors[index * 3] = color.r * colorVariation;
    colors[index * 3 + 1] = color.g * colorVariation;
    colors[index * 3 + 2] = color.b * colorVariation;

    const isBright = Math.random() < brightChance;
    sizes[index] = isBright
      ? maxSize + Math.random() * (brightMaxSize - maxSize)
      : minSize + Math.pow(Math.random(), 2.4) * (maxSize - minSize);
    brightness[index] = isBright
      ? 0.82 + Math.random() * 0.18
      : 0.42 + Math.pow(Math.random(), 1.6) * 0.58;
    sparkle[index] = isBright ? 0.45 + Math.random() * 0.55 : 0;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('starColor', new THREE.BufferAttribute(colors, 3));
  geometry.setAttribute('starSize', new THREE.BufferAttribute(sizes, 1));
  geometry.setAttribute(
    'starBrightness',
    new THREE.BufferAttribute(brightness, 1),
  );
  geometry.setAttribute('starSparkle', new THREE.BufferAttribute(sparkle, 1));

  nightSkyMaterial = new THREE.ShaderMaterial({
    uniforms: {
      skyOpacity: { value: 0 },
      pixelRatio: { value: renderer.getPixelRatio() },
    },
    vertexShader: /* glsl */`
      attribute vec3 starColor;
      attribute float starSize;
      attribute float starBrightness;
      attribute float starSparkle;
      uniform float pixelRatio;
      varying vec3 vStarColor;
      varying float vBrightness;
      varying float vSparkle;

      void main() {
        vStarColor = starColor;
        vBrightness = starBrightness;
        vSparkle = starSparkle;
        vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
        gl_Position = projectionMatrix * viewPosition;
        gl_PointSize = starSize * pixelRatio;
      }
    `,
    fragmentShader: /* glsl */`
      uniform float skyOpacity;
      varying vec3 vStarColor;
      varying float vBrightness;
      varying float vSparkle;

      void main() {
        vec2 point = gl_PointCoord - vec2(0.5);
        float distanceFromCenter = length(point);
        float disc = 1.0 - smoothstep(0.18, 0.50, distanceFromCenter);
        float core = 1.0 - smoothstep(0.0, 0.16, distanceFromCenter);
        float verticalRay = (1.0 - smoothstep(0.0, 0.055, abs(point.x))) *
          (1.0 - smoothstep(0.12, 0.50, abs(point.y)));
        float horizontalRay = (1.0 - smoothstep(0.0, 0.055, abs(point.y))) *
          (1.0 - smoothstep(0.12, 0.50, abs(point.x)));
        float rays = (verticalRay + horizontalRay) * vSparkle;
        float alpha = (disc * vBrightness + core * 0.42 + rays * 0.46) *
          skyOpacity;
        if (alpha < 0.01) discard;
        gl_FragColor = vec4(vStarColor * (0.72 + core * 0.62), alpha);
      }
    `,
    transparent: true,
    depthWrite: false,
    depthTest: true,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
    fog: false,
  });
  nightSkyPoints = new THREE.Points(geometry, nightSkyMaterial);
  nightSkyPoints.frustumCulled = false;
  scene.add(nightSkyPoints);
  updateNightSkyRenderScale();
  updateNightSky();
}

function resizeAtmosphericBackground(width, height) {
  if (!atmosphereCanvas) return;
  const resolution = lightingTuning.atmosphere?.resolution ?? 768;
  const scale = resolution / Math.max(width, height);
  const canvasWidth = Math.max(1, Math.round(width * scale));
  const canvasHeight = Math.max(1, Math.round(height * scale));
  if (
    atmosphereCanvas.width === canvasWidth &&
    atmosphereCanvas.height === canvasHeight
  ) return;
  atmosphereCanvas.width = canvasWidth;
  atmosphereCanvas.height = canvasHeight;
  atmospherePaintSignature = null;
  updateAtmosphericBackground(activeDaylightProfile, { force: true });
}

function projectedSunPosition() {
  if (!keyLight) return null;
  const settings = lightingTuning.atmosphere ?? {};
  const toSun = keyLight.position
    .clone()
    .sub(keyLight.target.position)
    .normalize();
  if (Number.isFinite(settings.visualSunElevation)) {
    toSun.y = settings.visualSunElevation;
    toSun.normalize();
  }
  const cameraDirection = camera.getWorldDirection(new THREE.Vector3());
  const facing = cameraDirection.dot(toSun);
  if (facing <= 0.015) return null;

  const visualDistance = Math.max(
    1,
    (lightingFrame?.dimension ?? 500) *
      (settings.visualSunDistanceMultiplier ?? 1.25),
  );
  const projected = keyLight.target.position
    .clone()
    .addScaledVector(toSun, visualDistance)
    .project(camera);
  const horizontalOverflow = settings.horizontalOverflow ?? 0.40;
  return {
    x: THREE.MathUtils.clamp(
      projected.x * 0.5 + 0.5,
      -horizontalOverflow,
      1 + horizontalOverflow,
    ),
    y: THREE.MathUtils.clamp(-projected.y * 0.5 + 0.5, -0.35, 1.35),
    facing,
  };
}

function directSunViewAmount(source, settings = {}) {
  if (!source) return 0;
  return THREE.MathUtils.smoothstep(
    source.facing,
    settings.startFacing ?? 0.70,
    settings.fullFacing ?? 0.94,
  );
}

function paintAtmosphericRay(context, source, angle, width, length, color) {
  const directionX = Math.cos(angle);
  const directionY = Math.sin(angle);
  const normalX = -directionY;
  const normalY = directionX;
  const endX = source.x + directionX * length;
  const endY = source.y + directionY * length;
  const gradient = context.createLinearGradient(
    source.x,
    source.y,
    endX,
    endY,
  );
  gradient.addColorStop(0, atmosphereColor(color, 0.88));
  gradient.addColorStop(0.24, atmosphereColor(color, 0.48));
  gradient.addColorStop(0.72, atmosphereColor(color, 0.10));
  gradient.addColorStop(1, atmosphereColor(color, 0));

  context.fillStyle = gradient;
  context.beginPath();
  context.moveTo(source.x, source.y);
  context.lineTo(endX + normalX * width, endY + normalY * width);
  context.lineTo(endX - normalX * width, endY - normalY * width);
  context.closePath();
  context.fill();
}

function installMiddaySky({ sunset = false, morning = false } = {}) {
  if (morning ? morningSkyMesh : sunset ? sunsetSkyMesh : middaySkyMesh) return;
  const warm = sunset || morning;
  const settings = (morning ? rendererTuning.morningSky : sunset ? rendererTuning.sunsetSky : rendererTuning.middaySky) ?? {};
  const canvas = document.createElement('canvas');
  canvas.width = settings.resolution ?? 1024;
  canvas.height = Math.round(canvas.width / 2);
  const context = canvas.getContext('2d');
  if (!context) return;
  const { width, height } = canvas;
  // Panorama gerado uma vez; a orientacao permanece fixa, como as estrelas.
  const zenith = new THREE.Color(settings.zenithColor ?? '#2e7ccb');
  const horizon = new THREE.Color(settings.horizonColor ?? '#83bee6');
  // O mapa e visto de cima: o fundo tambem precisa preencher os raios que
  // apontam abaixo do horizonte. Como as estrelas, cobre a esfera inteira.
  // Espelha o degrade para nao deixar essa metade como uma cor lisa.
  for (let row = 0; row < height; row++) {
    const elevation = Math.abs(Math.cos(row / (height - 1) * Math.PI));
    const blend = Math.exp(-elevation * (settings.horizonHaze ?? 5));
    context.fillStyle = `#${zenith.clone().lerp(horizon, blend).getHexString()}`;
    context.fillRect(0, row, width, 1);
  }

  let seed = settings.seed ?? 260926;
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  // Manchas de cor largas e suaves, independentes das nuvens. A repeticao
  // lateral fecha o panorama sem costura; nao ha ruido recalculado por frame.
  const patchColors = warm
    ? ['67,61,111', '131,103,155', '222,137,139', '241,182,149']
    : ['49,105,186', '113,174,218', '192,211,225', '222,231,236'];
  for (let index = 0; index < 48; index++) {
    const x = random() * width;
    const y = random() * height;
    const radius = width * (0.07 + random() * 0.11);
    const stretch = 0.7 + random() * 0.8;
    const color = patchColors[index % patchColors.length];
    const alpha = (0.22 + random() * 0.28) * (settings.patchStrength ?? 1);
    for (const wrap of [-width, 0, width]) {
      context.save();
      context.translate(x + wrap, y);
      context.scale(stretch, 0.65);
      const gradient = context.createRadialGradient(0, 0, 0, 0, 0, radius);
      gradient.addColorStop(0, `rgba(${color},${alpha})`);
      gradient.addColorStop(0.45, `rgba(${color},${alpha * 0.6})`);
      gradient.addColorStop(1, `rgba(${color},0)`);
      context.fillStyle = gradient;
      context.fillRect(-radius, -radius, radius * 2, radius * 2);
      context.restore();
    }
  }
  const sunDirection = new THREE.Vector3().fromArray(
    settings.sunDirection ?? [-0.78, 0.17, 0.62],
  ).normalize();
  if (warm) {
    const sunX = ((Math.atan2(sunDirection.z, -sunDirection.x) / (Math.PI * 2)) + 1) % 1;
    const sunY = Math.acos(sunDirection.y) / Math.PI;
    for (const wrap of [-width, 0, width]) {
      context.save();
      context.translate(sunX * width + wrap, sunY * height);
      context.scale(1, 0.55);
      const radius = width * (settings.glowSize ?? 0.22);
      context.globalAlpha = Math.min(settings.glowStrength ?? 1, 1);
      const glow = context.createRadialGradient(0, 0, 0, 0, 0, radius);
      glow.addColorStop(0, 'rgba(255,223,158,0.96)');
      glow.addColorStop(0.18, 'rgba(255,182,101,0.87)');
      glow.addColorStop(0.48, 'rgba(243,135,99,0.62)');
      glow.addColorStop(1, 'rgba(243,135,99,0)');
      context.fillStyle = glow;
      context.fillRect(-radius, -radius, radius * 2, radius * 2);
      context.restore();
    }
  }
  const cloudDirections = [];
  const cloudSizes = [];
  const cloudCount = settings.cloudCount ?? 96;
  const sectors = Math.ceil(cloudCount / 3);
  for (let index = 0; index < cloudCount; index++) {
    // Distribuicao estratificada: cada faixa cobre todos os lados, com
    // deslocamentos aleatorios para nao formar fileiras regulares.
    const x = (Math.floor(index / 3) + 0.15 + random() * 0.7) / sectors;
    // Massas acima, perto e abaixo do horizonte: a camera inclinada tambem
    // revela nuvens, sem mudar seu angulo aprovado nem prender o ceu a tela.
    const band = index % 3;
    const y = band === 0 ? 0.18 + random() * 0.28
      : band === 1 ? 0.55 + random() * 0.29
        : 0.49 + random() * 0.055;
    const widthMin = settings.cloudWidthMin ?? 0.075;
    const widthMax = Math.max(widthMin, settings.cloudWidthMax ?? 0.155);
    const cloudWidth = width * THREE.MathUtils.lerp(widthMin, widthMax, random());
    const cloudHeight = cloudWidth * THREE.MathUtils.lerp(
      settings.cloudHeightMin ?? 0.14, settings.cloudHeightMax ?? 0.26, random(),
    );
    const opacity = (0.42 + random() * 0.22) * (settings.cloudOpacity ?? 1);
    const slope = (random() - 0.5) * 0.45;
    const puffs = Array.from({ length: 16 + Math.floor(random() * 13) }, () => {
      const along = random() - 0.5;
      const fullness = Math.sqrt(Math.max(0, 1 - 4 * along * along));
      return {
        x: along * cloudWidth,
        y: ((random() - 0.5) * fullness + along * slope) * cloudHeight,
        radius: cloudHeight * (0.22 + random() * 0.52),
        stretch: 0.80 + random() * 0.80,
      };
    });
    cloudSizes.push([cloudWidth / width, cloudHeight / height]);
    const direction = new THREE.Vector3(
      -Math.cos(x * Math.PI * 2) * Math.sin(y * Math.PI),
      Math.cos(y * Math.PI),
      Math.sin(x * Math.PI * 2) * Math.sin(y * Math.PI),
    );
    cloudDirections.push(direction);
    const sunFacing = THREE.MathUtils.smoothstep(direction.dot(sunDirection), -0.1, 0.95);
    const cloudLight = new THREE.Color('#d897ad').lerp(new THREE.Color('#ffdaa3'), sunFacing);
    const cloudShade = new THREE.Color('#665b80').lerp(new THREE.Color('#b77881'), sunFacing);
    // Uma cor coesa por volume evita aneis escuros na sobreposicao dos puffs.
    const cloudBody = cloudLight.clone().lerp(cloudShade, 0.26);
    const rgba = (color, alpha) => {
      const hex = color.getHexString();
      return `rgba(${[0, 2, 4].map(offset => parseInt(hex.slice(offset, offset + 2), 16)).join(',')},${alpha})`;
    };
    // Repete somente a borda do panorama para fechar a volta sem emenda.
    for (const wrap of [-width, 0, width]) {
      for (const puff of puffs) {
        const px = x * width + puff.x + wrap;
        const py = y * height + puff.y;
        context.save();
        context.translate(px, py);
        context.scale(puff.stretch, 1);
        const gradient = context.createRadialGradient(
          0, -puff.radius * 0.22, 0, 0, 0, puff.radius,
        );
        gradient.addColorStop(0, warm ? rgba(cloudBody, opacity) : `rgba(255,255,255,${opacity})`);
        gradient.addColorStop(0.62, warm ? rgba(cloudBody, opacity * 0.88) : `rgba(251,253,255,${opacity * 0.96})`);
        gradient.addColorStop(0.84, warm ? rgba(cloudBody, opacity * 0.42) : `rgba(227,237,248,${opacity * 0.74})`);
        gradient.addColorStop(0.94, warm ? rgba(cloudBody, opacity * 0.12) : `rgba(227,237,248,${opacity * 0.26})`);
        gradient.addColorStop(1, warm ? rgba(cloudBody, 0) : 'rgba(227,237,248,0)');
        context.fillStyle = gradient;
        context.fillRect(-puff.radius, -puff.radius, puff.radius * 2, puff.radius * 2);
        context.restore();
      }
    }
  }
  // O enquadramento do mapa aponta para baixo: ilumina a regiao solar do
  // horizonte, inclusive sua continuacao inferior, e nao um ponto fora da tela.
  // Desenha depois das nuvens para o reforco nao desaparecer sob os puffs.
  const coreStrength = settings.sunCoreStrength ?? 0;
  if (warm && coreStrength > 0) {
    const sunX = ((Math.atan2(sunDirection.z, -sunDirection.x) / (Math.PI * 2)) + 1) % 1;
    const alpha = 1 - Math.exp(-coreStrength * 0.85);
    const radius = width * 0.12;
    for (const wrap of [-width, 0, width]) {
      context.save();
      context.globalCompositeOperation = 'screen';
      context.translate(sunX * width + wrap, height * 0.5);
      context.scale(1, 0.9);
      const core = context.createRadialGradient(0, 0, 0, 0, 0, radius);
      core.addColorStop(0, `rgba(255,248,218,${alpha})`);
      core.addColorStop(0.3, `rgba(255,232,174,${alpha * 0.9})`);
      core.addColorStop(0.65, `rgba(255,206,143,${alpha * 0.45})`);
      core.addColorStop(1, 'rgba(255,206,143,0)');
      context.fillStyle = core;
      context.fillRect(-radius, -radius, radius * 2, radius * 2);
      context.restore();
    }
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.generateMipmaps = false;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.wrapS = THREE.RepeatWrapping;
  const skyMesh = new THREE.Mesh(
    new THREE.SphereGeometry(1900, 40, 24),
    new THREE.MeshBasicMaterial({
      map: texture, side: THREE.BackSide, depthWrite: false,
      toneMapped: false, fog: false,
    }),
  );
  skyMesh.name = morning ? 'MorningSky' : sunset ? 'SunsetSky' : 'MiddaySky';
  skyMesh.material.color.setScalar(settings.brightness ?? 1);
  skyMesh.renderOrder = -1000;
  skyMesh.frustumCulled = false;
  skyMesh.visible = morning ? isMorning() : sunset ? isSunset() : isMidday();
  skyMesh.position.copy(camera.position);
  skyMesh.userData.cloudDirections = cloudDirections;
  skyMesh.userData.cloudSizes = cloudSizes;
  scene.add(skyMesh);
  if (morning) morningSkyMesh = skyMesh;
  else if (sunset) sunsetSkyMesh = skyMesh;
  else middaySkyMesh = skyMesh;
}

function updateAtmosphericBackground(profile, { force = false } = {}) {
  if (!atmosphereCanvas || !atmosphereContext || !atmosphereTexture) return;
  if (
    (graphicsProfile === 'basic' || graphicsProfile === 'balanced') &&
    controlsInteractionActive &&
    !force
  ) {
    return;
  }
  const settings = lightingTuning.atmosphere ?? {};
  const source = profile ? projectedSunPosition() : null;
  const directViewSettings = settings.directSunView ?? {};
  const directViewAmount = directSunViewAmount(source, directViewSettings);
  const intensity = source
    ? THREE.MathUtils.clamp((profile.rays?.opacity ?? 0) / 0.12, 0, 1) *
      (settings.opacityMultiplier ?? 1)
    : 0;
  const signature = [
    atmosphereCanvas.width,
    atmosphereCanvas.height,
    isMidday() ? 'midday' : source?.x.toFixed(3) ?? 'none',
    isMidday() ? 'fixed' : source?.y.toFixed(3) ?? 'none',
    isMidday() ? 'fixed' : directViewAmount.toFixed(3),
    isMidday() ? 'fixed' : intensity.toFixed(3),
    profile?.rays?.color.getHexString() ?? 'none',
    config?.backgroundColor ?? 'none',
  ].join(':');
  if (!force && signature === atmospherePaintSignature) return;
  atmospherePaintSignature = signature;

  const context = atmosphereContext;
  const width = atmosphereCanvas.width;
  const height = atmosphereCanvas.height;
  context.save();
  context.filter = 'none';
  context.globalCompositeOperation = 'source-over';
  if (isMidday()) {
    context.fillStyle = rendererTuning.middaySky?.horizonColor ?? '#d2e4ef';
    context.fillRect(0, 0, width, height);
    context.restore();
    atmosphereTexture.needsUpdate = true;
    return;
  }
  context.fillStyle = cssColor(config?.backgroundColor, '#090a0d');
  context.fillRect(0, 0, width, height);

  if (source && intensity > 0.001) {
    const sourcePoint = {
      x: source.x * width,
      y: (source.y + (settings.sourceYOffset ?? 0)) * height,
    };
    const color = profile.rays.color;
    const glowColor = settings.glowColor
      ? new THREE.Color(settings.glowColor)
      : color;
    const maxDimension = Math.max(width, height);
    const glowRadius = maxDimension * (settings.glowRadiusRatio ?? 0.54) *
      THREE.MathUtils.lerp(
        1,
        directViewSettings.glowRadiusScale ?? 0.84,
        directViewAmount,
      );
    const glow = context.createRadialGradient(
      sourcePoint.x,
      sourcePoint.y,
      0,
      sourcePoint.x,
      sourcePoint.y,
      glowRadius,
    );
    glow.addColorStop(
      0,
      atmosphereColor(
        glowColor,
        intensity * (settings.glowOpacity ?? 0.24),
      ),
    );
    glow.addColorStop(
      0.34,
      atmosphereColor(
        glowColor,
        intensity * (settings.glowOpacity ?? 0.24) * 0.34,
      ),
    );
    glow.addColorStop(1, atmosphereColor(color, 0));
    context.globalCompositeOperation = 'lighter';
    context.fillStyle = glow;
    context.fillRect(0, 0, width, height);

    const destination = {
      x: width * (settings.destination?.x ?? 0.56),
      y: height * (settings.destination?.y ?? 0.60),
    };
    const baseAngle = Math.atan2(
      destination.y - sourcePoint.y,
      destination.x - sourcePoint.x,
    );
    const rayOffsets = settings.rayOffsets ?? [-0.12, 0.025, 0.15];
    const rayWidths = settings.rayWidths ?? [0.085, 0.052, 0.034];
    const rayOpacity = intensity * (settings.rayOpacity ?? 0.34);
    context.globalAlpha = rayOpacity;
    context.filter = `blur(${settings.rayBlur ?? 12}px)`;
    for (let index = 0; index < rayWidths.length; index++) {
      paintAtmosphericRay(
        context,
        sourcePoint,
        baseAngle + (rayOffsets[index] ?? 0),
        maxDimension * rayWidths[index],
        maxDimension * (settings.rayLengthRatio ?? 2.2) *
          THREE.MathUtils.lerp(
            1,
            directViewSettings.rayLengthScale ?? 0.90,
            directViewAmount,
          ),
        color,
      );
    }
  }
  context.restore();
  atmosphereTexture.needsUpdate = true;
}

function applyConfiguredBackground() {
  if (geometryOnly) {
    document.body.style.background = '#303030';
    scene.background = rawBackground;
    scene.environment = null;
    scene.fog = null;
    return;
  }
  const backgroundColor = cssColor(config?.backgroundColor, '#090a0d');
  document.body.style.background = backgroundColor;
  if (atmosphereTexture) {
    scene.background = atmosphereTexture;
    updateAtmosphericBackground(activeDaylightProfile, { force: true });
  } else {
    scene.background = new THREE.Color(backgroundColor);
  }
  updateAtmosphericPostProcessing(activeDaylightProfile);
}

function updateAtmosphericPostProcessing(profile) {
  if (!cinematicGradePass) return;
  const uniforms = cinematicGradePass.uniforms;
  const settings = lightingTuning.atmosphere ?? {};
  uniforms.atmosphereTexture.value = atmosphereTexture;
  uniforms.atmosphereBaseColor.value.set(
    cssColor(config?.backgroundColor, '#090a0d'),
  );
  const daylightAmount = THREE.MathUtils.clamp(
    (profile?.rays?.opacity ?? 0) / 0.12,
    0,
    1,
  );
  uniforms.surfaceRayStrength.value = settings.enabled === false || isMidday()
    ? 0
    : daylightAmount * (settings.surfaceRayStrength ?? 0);
}

function environmentCanvas() {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  return canvas;
}

function paintEnvironmentFace(canvas, top, bottom) {
  const context = canvas.getContext('2d');
  if (!context) return;
  const gradient = context.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, `#${top.getHexString()}`);
  gradient.addColorStop(1, `#${bottom.getHexString()}`);
  context.fillStyle = gradient;
  context.fillRect(0, 0, canvas.width, canvas.height);
}

function installReflectionEnvironment() {
  reflectionEnvironmentFaces = Array.from({ length: 6 }, environmentCanvas);
  reflectionEnvironment = new THREE.CubeTexture(reflectionEnvironmentFaces);
  reflectionEnvironment.colorSpace = THREE.SRGBColorSpace;
  reflectionEnvironment.generateMipmaps = true;
  reflectionEnvironment.minFilter = THREE.LinearMipmapLinearFilter;
  reflectionEnvironment.needsUpdate = true;
  scene.environment = reflectionEnvironment;
}

function updateReflectionEnvironment(profile) {
  if (!reflectionEnvironment) return;
  const sky = profile.hemisphere.skyColor.clone().lerp(profile.key.color, 0.12);
  const horizon = profile.hemisphere.skyColor.clone().lerp(
    profile.hemisphere.groundColor,
    0.52,
  );
  const ground = profile.hemisphere.groundColor.clone().multiplyScalar(0.72);
  for (const index of [0, 1, 4, 5]) {
    paintEnvironmentFace(reflectionEnvironmentFaces[index], sky, ground);
  }
  paintEnvironmentFace(reflectionEnvironmentFaces[2], sky, horizon);
  paintEnvironmentFace(reflectionEnvironmentFaces[3], horizon, ground);
  // Fontes amplas no ambiente produzem reflexos direcionais suaves, presos
  // ao mundo. Nao sao reflexos em tempo real da geometria dos edificios.
  const night = nightSkyAmount();
  if (night > 0) {
    for (const [face, x, y, color, strength] of [
      [2, 0.32, 0.42, '192,215,255', 0.80],
      [0, 0.55, 0.64, '255,205,141', 0.42],
      [5, 0.40, 0.55, '147,188,255', 0.55],
    ]) {
      const canvas = reflectionEnvironmentFaces[face];
      const context = canvas.getContext('2d');
      const glow = context.createRadialGradient(x * 256, y * 256, 0, x * 256, y * 256, 85);
      glow.addColorStop(0, `rgba(${color},${strength * night})`);
      glow.addColorStop(1, `rgba(${color},0)`);
      context.fillStyle = glow;
      context.fillRect(0, 0, 256, 256);
    }
  }
  reflectionEnvironment.needsUpdate = true;
  updateMaterialEnvironmentResponse(profile);

  const density = rendererTuning.atmosphereDensity ?? 0;
  if (density > 0) {
    const fogColor = profile.hemisphere.groundColor.clone().lerp(sky, 0.28);
    if (!scene.fog?.isFogExp2) scene.fog = new THREE.FogExp2(fogColor, density);
    scene.fog.color.copy(fogColor);
    scene.fog.density = density;
  }
}

function updateMaterialEnvironmentResponse(profile) {
  const morningLook = effectiveMorningLook();
  if (!model || !profile) return;
  const nightAmount = nightSkyAmount();
  const nightScale = (rendererTuning.nightEnvironmentScale ?? 2.4) *
    (nightLook.reflections ?? 1);
  const sunsetAmount = THREE.MathUtils.smoothstep(
    profile.rays?.opacity ?? 0,
    0.025,
    0.09,
  );
  const dawnAmount = isDayCustomization() ? 1 : phaseEnvelope(presetTimeMinutes(), rendererTuning.dawnSurface ?? {});
  const sunsetScale = THREE.MathUtils.lerp(
    1,
    THREE.MathUtils.lerp(rendererTuning.sunsetEnvironmentScale ?? 2.2,
      morningLook.reflections ?? rendererTuning.dawnSurface?.environmentScale ?? 8, dawnAmount),
    sunsetAmount,
  );
  const visited = new Set();

  model.traverse((object) => {
    if (!object.isMesh) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    for (const material of materials) {
      if (!material || visited.has(material.uuid)) continue;
      visited.add(material.uuid);
      const name = `${object.name ?? ''} ${material.name ?? ''}`.toLowerCase();
      if (name.includes('windows')) continue;
      if (!materialEnvironmentIntensities.has(material)) {
        materialEnvironmentIntensities.set(
          material,
          material.envMapIntensity ?? rendererTuning.environmentIntensity ?? 0,
        );
      }
      if (!materialNightFinishes.has(material)) {
        materialNightFinishes.set(material, {
          color: material.color?.isColor ? material.color.clone() : null,
          roughness: material.roughness,
          clearcoat: material.clearcoat,
          clearcoatRoughness: material.clearcoatRoughness,
        });
      }
      const baseFinish = materialNightFinishes.get(material);
      // Sempre parte da cor original, para o ajuste diurno nao vazar a noite.
      if (baseFinish.color && material.color?.isColor) material.color.copy(baseFinish.color);
      const isGroundSurface =
        name.includes('grass') ||
        name.includes('street') ||
        name.includes('asphalt') ||
        name.includes('ground') ||
        name.includes('pavement') ||
        name.includes('chao') ||
        name.includes('rua') ||
        name.includes('calcada') ||
        name.includes('calçada');
      const isGrass = name.includes('grass') || name.includes('grama');
      const finishType = isGroundSurface
        ? isGrass ? null : 'pavement'
        : name.includes('concrete') ||
            name.includes('bloco') ||
            name.includes('portaria')
          ? 'concrete'
          : 'generic';
      material.envMapIntensity = isGrass
        ? materialEnvironmentIntensities.get(material) * (1 - nightAmount * 0.99)
        : isGroundSurface
          ? THREE.MathUtils.lerp(THREE.MathUtils.lerp(materialEnvironmentIntensities.get(material),
              materialEnvironmentIntensities.get(material) * sunsetScale, dawnAmount),
              (nightLook.floorReflection ?? 1.6) * (nightLook.reflections ?? 3), nightAmount)
          : materialEnvironmentIntensities.get(material) * THREE.MathUtils.lerp(sunsetScale, nightScale, nightAmount);
      const nightFinish = finishType
        ? rendererTuning.nightReflectionFinish?.[finishType]
        : null;
      const sunsetFinish = finishType === 'pavement' && dawnAmount > 0
        ? { ...rendererTuning.dawnSurface?.pavement,
            roughness: morningLook.floorRoughness ?? rendererTuning.dawnSurface?.pavement?.roughness,
            clearcoat: morningLook.wetness ?? rendererTuning.dawnSurface?.pavement?.clearcoat } : finishType
        ? rendererTuning.sunsetReflectionFinish?.[finishType]
        : null;
      const finishAmount = THREE.MathUtils.smoothstep(nightAmount, 0.10, 0.92) *
        (finishType === 'pavement' ? nightLook.wetness ?? 0.75 : 1);

      if (baseFinish.color && material.color?.isColor && isGroundSurface) {
        material.color.copy(baseFinish.color).multiplyScalar(THREE.MathUtils.lerp(
          1, isGrass ? nightLook.grassBrightness ?? 0.045 : 0.48, nightAmount,
        ));
      }

      if (baseFinish.color && material.color?.isColor && finishType === 'concrete') {
        material.color.copy(baseFinish.color).multiplyScalar(
          THREE.MathUtils.lerp(
            1,
            rendererTuning.nightBuildingBrightness ?? 0.72,
            finishAmount,
          ),
        );
      }

      if (Number.isFinite(baseFinish.roughness)) {
        const sunsetRoughness = Number.isFinite(sunsetFinish?.roughness)
          ? THREE.MathUtils.lerp(
              baseFinish.roughness,
              sunsetFinish.roughness,
              finishType === 'pavement' ? dawnAmount : sunsetAmount,
            )
          : baseFinish.roughness;
        material.roughness = Number.isFinite(nightFinish?.roughness)
          ? THREE.MathUtils.lerp(
              sunsetRoughness,
              nightFinish.roughness,
              finishAmount,
            )
          : sunsetRoughness;
      }
      if (Number.isFinite(baseFinish.clearcoat)) {
        const sunsetClearcoat = Number.isFinite(sunsetFinish?.clearcoat)
          ? THREE.MathUtils.lerp(
              baseFinish.clearcoat,
              sunsetFinish.clearcoat,
              finishType === 'pavement' ? dawnAmount : sunsetAmount,
            )
          : baseFinish.clearcoat;
        material.clearcoat = Number.isFinite(nightFinish?.clearcoat)
          ? THREE.MathUtils.lerp(
              sunsetClearcoat,
              nightFinish.clearcoat,
              finishAmount,
            )
          : sunsetClearcoat;
      }
      if (Number.isFinite(baseFinish.clearcoatRoughness)) {
        const sunsetClearcoatRoughness = Number.isFinite(
          sunsetFinish?.clearcoatRoughness,
        )
          ? THREE.MathUtils.lerp(
              baseFinish.clearcoatRoughness,
              sunsetFinish.clearcoatRoughness,
              finishType === 'pavement' ? dawnAmount : sunsetAmount,
            )
          : baseFinish.clearcoatRoughness;
        material.clearcoatRoughness = Number.isFinite(
          nightFinish?.clearcoatRoughness,
        )
          ? THREE.MathUtils.lerp(
              sunsetClearcoatRoughness,
              nightFinish.clearcoatRoughness,
              finishAmount,
            )
          : sunsetClearcoatRoughness;
      }
      if (finishType === 'pavement' && nightAmount > 0) {
        material.roughness = THREE.MathUtils.lerp(material.roughness,
          (nightLook.floorRoughness ?? 0.24) * (1 - (nightLook.wetness ?? 0) * 0.6), nightAmount);
        if ('clearcoat' in material) {
          material.clearcoat = THREE.MathUtils.lerp(material.clearcoat ?? 0,
            0.35 + (nightLook.wetness ?? 0) * 0.6, nightAmount);
          material.clearcoatRoughness = THREE.MathUtils.lerp(material.clearcoatRoughness ?? 0.15, 0.13, nightAmount);
        }
      }
      if (isMidday()) {
        const finish = rendererTuning.middayMaterials ?? {};
        const isFoliage = (rendererTuning.foliageMaterials ?? []).includes(material.name);
        const isTrunk = material.name === 'Material.002';
        if (material.color?.isColor) {
          if (isFoliage) {
            material.color.lerp(new THREE.Color(finish.foliageColor ?? '#6b9637'), finish.foliageBlend ?? 0.20);
          } else if (isGrass) {
            material.color.lerp(new THREE.Color(finish.grassColor ?? '#5c9638'), finish.grassBlend ?? 0.30);
          } else if (finishType === 'concrete') {
            material.color.multiplyScalar(finish.concreteBrightness ?? 1.16);
          } else if (/street|asphalt|rua/.test(name)) {
            material.color.multiplyScalar(finish.roadBrightness ?? 1.45);
          }
        }
        // Superficies secas; conserva os controles de reflexo/molhado do piso.
        if (isFoliage || isTrunk || isGrass) {
          material.roughness = 0.95;
          material.envMapIntensity = 0.025;
          if ('clearcoat' in material) material.clearcoat = 0;
        } else if (finishType !== 'pavement') {
          material.roughness = 0.62;
          material.envMapIntensity = (materialEnvironmentIntensities.get(material) ?? 0.05) * (morningLook.reflections ?? 1);
          if ('clearcoat' in material) material.clearcoat = 0.04;
        }
      }
      material.needsUpdate = true;
    }
  });
}

function configureDirectionalLight(light, settings, center, dimension) {
  if (!light) return;
  const offset = settings?.positionOffset ?? { x: 0.8, y: 1.35, z: 0.65 };
  light.position.set(
    center.x + dimension * offset.x,
    center.y + dimension * offset.y,
    center.z + dimension * offset.z,
  );
  light.target.position.copy(center);
  light.target.updateMatrixWorld();
}

function materialFinishForName(name) {
  const finishes = rendererTuning.materialFinish ?? {};
  if (name.includes('grass')) return finishes.grass;
  if (name.includes('street')) return finishes.street;
  if (name.includes('ground') || name.includes('pavement')) {
    return finishes.ground;
  }
  if (name.includes('concrete')) return finishes.concrete;
  return null;
}

function applyMaterialFinish(material) {
  if (!material) return;
  let base = materialBaseFinishes.get(material);
  if (!base) {
    base = {
      color: material.color?.isColor ? material.color.clone() : null,
      roughness: material.roughness,
      clearcoat: material.clearcoat,
      clearcoatRoughness: material.clearcoatRoughness,
      envMapIntensity: material.envMapIntensity,
    };
    materialBaseFinishes.set(material, base);
  }

  const name = material.name?.toLowerCase() ?? '';
  if (base.color && material.color?.isColor) {
    material.color.copy(base.color);
    if (name.includes('concrete')) {
      material.color.multiplyScalar(rendererTuning.concreteBrightness ?? 0.84);
    }
  }

  const finish = materialFinishForName(name);
  if (
    base.color &&
    material.color?.isColor &&
    Number.isFinite(finish?.brightness)
  ) {
    material.color.multiplyScalar(finish.brightness);
  }
  if (Number.isFinite(base.roughness)) {
    material.roughness = Math.max(
      base.roughness,
      finish?.roughnessMin ?? base.roughness,
    );
    if (Number.isFinite(finish?.roughnessMax)) {
      material.roughness = Math.min(
        material.roughness,
        finish.roughnessMax,
      );
    }
  }
  if (Number.isFinite(base.clearcoat)) {
    material.clearcoat = THREE.MathUtils.clamp(
      base.clearcoat,
      finish?.clearcoatMin ?? base.clearcoat,
      finish?.clearcoatMax ?? base.clearcoat,
    );
  }
  if (Number.isFinite(base.clearcoatRoughness)) {
    material.clearcoatRoughness = Math.max(
      base.clearcoatRoughness,
      finish?.clearcoatRoughnessMin ?? base.clearcoatRoughness,
    );
  }
  material.envMapIntensity = finish?.envMapIntensity ??
    rendererTuning.environmentIntensity ?? base.envMapIntensity ?? 0.42;
  material.needsUpdate = true;
}

function balancedMaterialFor(material) {
  if (
    !material ||
    (graphicsProfile !== 'basic' && graphicsProfile !== 'balanced')
  ) return material;
  const cached = balancedMaterialCache.get(material);
  if (cached) return cached;

  const simplified = new THREE.MeshStandardMaterial({
    name: material.name,
    color: material.color?.isColor ? material.color.clone() : 0xffffff,
    map: material.map ?? null,
    normalMap: material.normalMap ?? null,
    normalScale: material.normalScale?.clone(),
    roughness: material.roughness ?? 1,
    roughnessMap: material.roughnessMap ?? null,
    metalness: material.metalness ?? 0,
    metalnessMap: material.metalnessMap ?? null,
    lightMap: material.lightMap ?? null,
    lightMapIntensity: material.lightMapIntensity ?? 1,
    aoMap: material.aoMap ?? null,
    aoMapIntensity: material.aoMapIntensity ?? 1,
    emissive: material.emissive?.isColor
      ? material.emissive.clone()
      : 0x000000,
    emissiveMap: material.emissiveMap ?? null,
    emissiveIntensity: material.emissiveIntensity ?? 1,
    transparent: material.transparent === true,
    opacity: material.opacity ?? 1,
    alphaTest: material.alphaTest ?? 0,
    depthTest: material.depthTest !== false,
    depthWrite: material.depthWrite !== false,
    side: THREE.DoubleSide,
    vertexColors: material.vertexColors === true,
  });
  balancedMaterialCache.set(material, simplified);
  return simplified;
}

async function prepareModelMaterials(object) {
  const receiverNodes = lightingTuning.shadows?.receiverNodes;
  const casterExclusions = lightingTuning.shadows?.casterExclusions;
  const receivesEverywhere = !Array.isArray(receiverNodes);
  const maxAnisotropy = graphicsProfile === 'basic'
    ? 2
    : graphicsProfile === 'balanced'
      ? Math.min(4, renderer.capabilities.getMaxAnisotropy())
      : renderer.capabilities.getMaxAnisotropy();

  function belongsToNamedNode(child, nodeNames) {
    if (!Array.isArray(nodeNames)) return false;
    let current = child;
    while (current && current !== object) {
      if (nodeNames.includes(current.name)) return true;
      current = current.parent;
    }
    return false;
  }

  const meshes = [];
  object.traverse(child => { if (child.isMesh) meshes.push(child); });
  const preparedMaterials = new Set();
  const preparedTextures = new Set();
  let sliceStarted = performance.now();
  for (const child of meshes) {
    if (viewerDisposed) return;
    if (performance.now() - sliceStarted > 6) {
      await yieldLoadingWork();
      sliceStarted = performance.now();
    }

    if (graphicsProfile === 'basic' || graphicsProfile === 'balanced') {
      child.material = Array.isArray(child.material)
        ? child.material.map(balancedMaterialFor)
        : balancedMaterialFor(child.material);
    }

    child.castShadow = !belongsToNamedNode(child, casterExclusions);
    child.receiveShadow = receivesEverywhere ||
      belongsToNamedNode(child, receiverNodes);
    const materials = Array.isArray(child.material)
      ? child.material
      : [child.material];
    for (const material of materials) {
      if (!material || preparedMaterials.has(material)) continue;
      preparedMaterials.add(material);
      material.side = THREE.DoubleSide;
      applyMaterialFinish(material);
      for (const texture of [
        material.map,
        material.normalMap,
        material.roughnessMap,
        material.metalnessMap,
        material.aoMap,
      ]) {
        if (!texture || preparedTextures.has(texture)) continue;
        preparedTextures.add(texture);
        texture.anisotropy = maxAnisotropy;
        texture.needsUpdate = true;
      }
      material.needsUpdate = true;
    }
  }
}

function yieldLoadingWork() {
  return new Promise(resolve => setTimeout(resolve, 16));
}

async function prepareGpuTextures(root) {
  const textures = new Set();
  root.traverse(node => {
    for (const material of (Array.isArray(node.material) ? node.material : [node.material])) {
      if (!material) continue;
      for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
    }
  });
  for (const texture of textures) {
    if (viewerDisposed) return;
    renderer.initTexture(texture);
    await yieldLoadingWork();
  }
}

async function waitForGpu() {
  const gl = renderer.getContext();
  const fence = gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
  if (!fence) return;
  gl.flush();
  const started = performance.now();
  try {
    while (!viewerDisposed && !gl.isContextLost()) {
      const status = gl.clientWaitSync(fence, 0, 0);
      if (status === gl.ALREADY_SIGNALED || status === gl.CONDITION_SATISFIED) return;
      if (status === gl.WAIT_FAILED || performance.now() - started > 20000) {
        throw new Error('A GPU não concluiu a preparação do mapa. Tente abrir novamente.');
      }
      await yieldLoadingWork();
    }
  } finally {
    if (!gl.isContextLost()) gl.deleteSync(fence);
  }
}

let geometryWarmupTarget = null;
async function prepareGpuGeometry(root, renderScene = scene, { isolate = false } = {}) {
  const meshes = [];
  root.traverse(node => {
    if (node.isMesh) meshes.push({ node, visible: node.visible, culled: node.frustumCulled });
  });
  // Upload-only work does not need HDR or a new framebuffer for each floor.
  const target = geometryWarmupTarget ??= new THREE.WebGLRenderTarget(64, 64);
  const oldTarget = renderer.getRenderTarget();
  const shadowUpdate = renderer.shadowMap.needsUpdate;
  const hiddenChildren = [];
  if (isolate) {
    for (const child of renderScene.children) {
      if (child !== root && !child.isLight && child.visible) {
        hiddenChildren.push(child);
        child.visible = false;
      }
    }
  }
  renderer.shadowMap.needsUpdate = false;
  for (const { node } of meshes) node.visible = false;
  try {
    // Upload a few meshes at a time, before the first full-resolution image.
    // No geometry is simplified or removed; this only spreads GPU allocation.
    for (let i = 0; i < meshes.length; i += 4) {
      if (viewerDisposed) return;
      const batch = meshes.slice(i, i + 4);
      for (const state of batch) {
        state.node.visible = state.visible;
        state.node.frustumCulled = false;
      }
      renderer.setRenderTarget(target);
      const started = performance.now();
      renderer.render(renderScene, camera);
      diagnosticsRenderMaxMs = Math.max(diagnosticsRenderMaxMs, performance.now() - started);
      for (const { node } of batch) node.visible = false;
      await yieldLoadingWork();
    }
  } finally {
    for (const state of meshes) {
      state.node.visible = state.visible;
      state.node.frustumCulled = state.culled;
    }
    for (const child of hiddenChildren) child.visible = true;
    renderer.shadowMap.needsUpdate = shadowUpdate;
    if (!viewerDisposed) renderer.setRenderTarget(oldTarget);
  }
}

let modelTransfer = null;
let modelLoading = false;
let modelGpuReady = false;

function beginModelTransfer(compression, expectedLength) {
  if (viewerDisposed) return;
  if (!['gzip', 'glb'].includes(compression) ||
      !Number.isSafeInteger(expectedLength) || expectedLength <= 0 || expectedLength > 128 * 1024 * 1024) {
    throw new Error('Invalid map transfer.');
  }
  recordLoadingStage('Transferindo mapa');
  modelTransfer = { compression, expectedLength, received: 0, chunks: [] };
}

function appendModelChunk(encoded) {
  if (viewerDisposed) return;
  if (!modelTransfer) throw new Error('Map transfer was not initialized.');
  if (typeof encoded !== 'string' || encoded.length > 64 * 1024 ||
      modelTransfer.received + encoded.length > modelTransfer.expectedLength) {
    modelTransfer = null;
    throw new Error('Invalid map transfer chunk.');
  }
  let binary;
  try { binary = atob(encoded); }
  catch (error) { modelTransfer = null; throw error; }
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  modelTransfer.chunks.push(bytes);
  modelTransfer.received += encoded.length;
}

async function loadConfiguredModel() {
  if (!config || model || modelLoading || viewerDisposed) return;
  modelLoading = true;
  const modelUrl = config.modelUrl;

  applyConfiguredBackground();

  try {
    const loader = new GLTFLoader();
    let gltf;
    recordLoadingStage('Descompactando mapa');
    if (config.modelCompression === 'gzip') {
      const response = await fetch(modelUrl);
      const stream = response.body.pipeThrough(new DecompressionStream('gzip'));
      const bytes = await new Response(stream).arrayBuffer();
      if (viewerDisposed) return;
      recordLoadingStage('Lendo geometria');
      gltf = await loader.parseAsync(bytes, '');
      selectionCacheLoader = await loadSelectionCache(bytes, config.zones);
    } else {
      gltf = await loader.loadAsync(modelUrl);
    }
    if (viewerDisposed) return;
    recordLoadingStage(geometryOnly ? 'Preparando GLB cru' : 'Preparando materiais');
    model = gltf.scene;
    selectionWindowMeshes = collectSelectionWindowMeshes(model);
    exportedWindowPresetObjects = [];
    const presetPrefix=lightingTuning.dayCycle?.windows?.nodePrefix??'janelas_preset_';
    model.traverse(node=>{if(node.name?.startsWith(presetPrefix)&&!node.parent?.name?.startsWith(presetPrefix))exportedWindowPresetObjects.push(node);});
    if (featurePanelEnabled) model.traverse(node => {
      if (node.isMesh) testMaterialSources.set(node, node.material);
    });
    if (geometryOnly) {
      // Start from the loader's materials, before any app shader/color edits.
      // Only the tested material/light stage changes; keep the same geometry.
      // All GLB objects, including interiors, remain in their original hierarchy.
      scene.add(model);
      setRawMode(true);
    } else {
      interiors = createInteriorNavigation(model, config.zones, findModelNode, scene, config.accentColor);
      await yieldLoadingWork();
      if (viewerDisposed) return;
      await prepareModelMaterials(model);
      if (viewerDisposed) return;
      await yieldLoadingWork();
      if (viewerDisposed) return;
      prepareWindowPresets(model);
      scene.add(model);
      nightCinema = createNightCinema(model, scene, nightLook);
      if (graphicsProfile !== 'basic') installGroundSunRays(model);
    }

    for (const zone of config.zones) {
      const node = findModelNode(model, zone.nodeName);
      if (node) {
        zoneNodes.set(zone.nodeName, node);
      }
    }

    await yieldLoadingWork();
    if (viewerDisposed) return;
    eventAnchorCache.clear();eventMarkers.setEvents(mapEvents);
    frameModel(model);
    if (featurePanelEnabled) await applyMapTestFeatures(testFeatures, { warm: false });
    if (viewerDisposed) return;
    // Campus geometry is static; keep transforms without rebuilding matrices
    // for every frame of a camera animation.
    model.updateMatrixWorld(true);
    model.traverse(node => { node.matrixAutoUpdate = false; });
    recordLoadingStage('Preparando GPU e sombras');
    // Keep Flutter's curtain up through shader preparation and the first
    // shadow refresh, not merely until the GLB has been parsed.
    await yieldLoadingWork();
    if (!geometryOnly) await prepareGpuTextures(model);
    if (viewerDisposed) return;
    await renderer.compileAsync(scene, camera);
    if (viewerDisposed) return;
    if (selectionOutline.warmup && selectionOptions.outline && (!geometryOnly || testFeatures.selection)) {
      recordLoadingStage('Preparando seleção');
      await selectionOutline.warmup([...zoneNodes.values()],camera,yieldLoadingWork);
      if (viewerDisposed) return;
    }
    recordLoadingStage('Enviando geometria à GPU');
    // Upload geometry in small batches so the first camera movement does not
    // suffer from large, synchronous GPU allocations.
    if (!geometryOnly) await prepareGpuGeometry(model);
    if (viewerDisposed) return;
    if (initialAntialias !== 'off') await applyMapQuality({ antialias: initialAntialias });
    await yieldLoadingWork();
    if (viewerDisposed) return;
    modelGpuReady = true;
    fpsCounter.setReady();
    requestRender();
    await new Promise(resolve => requestAnimationFrame(resolve));
    if (viewerDisposed) return;
    // ANGLE/Vulkan can initially allocate an empty depth texture.
    if (!geometryOnly) refreshDirectionalShadow({ recreate: true });
    requestRender();
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    await waitForGpu();
    if (viewerDisposed) return;
    renderer.domElement.classList.add('is-ready');
    recordLoadingStage('Pronto');
    if (featurePanelEnabled && !featurePanel) {
      featurePanel = createMapFeaturePanel({
        state: testFeatures,
        quality: mapQuality,
        interiorEventSize,
        eventMarkerAutoLayout,
        selectionOptions,
        interfaceBlurEnabled,
        navBlurEnabled,
        onInterfaceBlurChange: enabled => setInterfaceBlur(enabled),
        onNavBlurChange: enabled => setNavBlur(enabled),
        onSelectionChange: settings => setSelectionOptions(settings),
        onQualityChange: settings => setMapQuality(settings),
        onInteriorEventSizeChange: percent => setInteriorEventSize(percent),
        onEventMarkerAutoLayoutChange: enabled => setEventMarkerAutoLayout(enabled),
        onChange: (name, enabled) => setMapTestFeature(name, enabled),
        onPreset: preset => setMapTestFeatures(preset === 'all'
          ? Object.fromEntries(mapFeatureTopics.map(([key]) => [key, true]))
          : preset === 'basic' ? { lighting: true } : {}),
        onClimate: async minutes => {
          setPreviewTimeMinutes(minutes);
          return setMapTestFeatures(testFeatures);
        },
      });
    }
    send('selectionOptions', { options: { ...selectionOptions } });
    send('interfaceBlur', { enabled: interfaceBlurEnabled });
    send('navBlur', { enabled: navBlurEnabled });
    persistRenderPreferences();
    send('performanceMode', { enabled: performanceModeEnabled, source:'initial' });
    send('ready', {
        resolvedZones: zoneNodes.size,
        graphicsProfile,
        graphicsProfilePreference: savedGraphicsProfile,
        restingPixelRatio: rendererTuning.maxPixelRatio,
        interactionPixelRatio: rendererTuning.interactionPixelRatio,
        shadowMapSize: renderer.shadowMap.enabled
          ? keyLight?.shadow?.mapSize?.x ?? 0
          : 0,
        atmosphereResolution: lightingTuning.atmosphere?.enabled === false
          ? 0
          : lightingTuning.atmosphere?.resolution ?? 0,
    });
  } catch (error) {
    send('error', {
      message: error instanceof Error ? error.message : String(error),
    });
  } finally {
    modelLoading = false;
    if (modelUrl?.startsWith('blob:')) URL.revokeObjectURL(modelUrl);
  }
}

function configure(nextConfig) {
  if (viewerDisposed) return;
  configureDiagnostics(nextConfig.diagnosticsEnabled === true);
  if (modelTransfer) {
    if (modelTransfer.received !== modelTransfer.expectedLength) {
      send('error', { message: 'Incomplete map transfer.' });
      return;
    }
    const blob = new Blob(modelTransfer.chunks, { type: 'application/octet-stream' });
    nextConfig = { ...nextConfig, modelUrl: URL.createObjectURL(blob),
      modelCompression: modelTransfer.compression };
    modelTransfer = null;
  }
  config = nextConfig;
  if(typeof nextConfig.performanceMode==='boolean'&&nextConfig.performanceMode!==performanceModeEnabled) {
    if(!model&&!modelLoading) {
      const preset=renderPresetForMode(nextConfig.performanceMode);
      performanceModeEnabled=nextConfig.performanceMode;
      testFeatures=normalizedMapFeatures(preset.features);
      selectionOptions=normalizedSelectionOptions(preset.selectionOptions);
      mapQuality=normalizedMapQuality(preset.quality);
      initialAntialias=mapQuality.antialias;mapQuality.antialias='off';
      interfaceBlurEnabled=preset.interfaceBlurEnabled;navBlurEnabled=preset.navBlurEnabled;
    }else setMapPerformanceMode(nextConfig.performanceMode).catch(error=>send('error',{message:String(error.message??error)}));
  }
  if (!geometryOnly) {
    installMiddaySky();
    installMiddaySky({ sunset: true });
    installMiddaySky({ morning: true });
    installNightSky();
  }
  if (model) {
    applyConfiguredBackground();
    applyDaylightProfile();
    requestRender();
    return;
  }
  loadConfiguredModel();
}

function restoreRawMaterials() {
  for (const { mesh, material } of rawMaterialStates) mesh.material = material;
  rawMaterialStates.length = 0;
  for (const material of rawMaterials) material.dispose();
  rawMaterials.clear();
}

function disposeTestComposer() {
  mobileBloom?.dispose(); mobileBloom = null;
  for (const pass of effectComposer?.passes ?? []) pass.dispose?.();
  effectComposer?.dispose();
  effectComposer = null; sceneRenderPass = null; bloomPass = null; cinematicGradePass = null;
}

function removeTestSky() {
  for (const object of [middaySkyMesh, sunsetSkyMesh, morningSkyMesh, nightSkyPoints]) {
    if (!object) continue;
    object.removeFromParent(); object.geometry.dispose();
    object.material.map?.dispose(); object.material.dispose();
  }
  middaySkyMesh = null; sunsetSkyMesh = null; morningSkyMesh = null;
  nightSkyPoints = null; nightSkyMaterial = null;
  scene.background = rawBackground;
}

function configureTestInteriors(enabled) {
  if (!interiors && enabled) {
    for (const zone of config.zones) for (const floor of zone.floors ?? []) {
      for (const name of [...floor.nodeNames, ...floor.spaces.map(space => space.nodeName)]) {
        const node = findModelNode(model, name);
        if (node) testInteriorParents.set(node, node.parent);
      }
    }
    interiors = createInteriorNavigation(model, config.zones, findModelNode, scene, config.accentColor);
    for (const floor of interiors.floors.values()) testInteriorNodes.set(floor.id, [...floor.group.children]);
  }
  if (!interiors) return;
  if (interiors.current) exitInterior({ focus: false });
  interiors.leave();
  for (const floor of interiors.floors.values()) {
    for (const node of testInteriorNodes.get(floor.id) ?? []) {
      const parent = enabled ? floor.group : testInteriorParents.get(node);
      parent?.attach(node);
    }
    floor.group.updateMatrixWorld(true);
  }
}

function applyTestFeatureProfile() {
  if (!featurePanelEnabled || !model || !lightingFrame) return;
  const profile = daylightProfileWithPreview(daylightProfile());
  activeDaylightProfile = profile;
  // Same two diffuse lights for every material test: no hidden extra fills.
  keyLight.visible = testFeatures.lighting;
  hemisphereLight.visible = testFeatures.lighting;
  keyLight.intensity = 2; hemisphereLight.intensity = 1;
  keyLight.color.copy(profile.key.color);
  configureDirectionalLight(keyLight, profile.key, lightingFrame.center, lightingFrame.dimension);
  keyLight.castShadow = testFeatures.shadows;
  renderer.shadowMap.enabled = testFeatures.shadows;
  renderer.shadowMap.autoUpdate = false;
  if (testFeatures.shadows) {
    keyLight.shadow.mapSize.setScalar(renderBudget.shadowSize);
    fitShadowCameraToBounds(keyLight, lightingFrame.bounds, lightingFrame.dimension);
    keyLight.shadow.bias = lightingTuning.shadows?.bias ?? -0.00035;
    keyLight.shadow.normalBias = lightingTuning.shadows?.normalBias ?? 0.025;
    keyLight.shadow.intensity = profile.shadowIntensity;
    refreshDirectionalShadow();
  } else {
    keyLight.shadow.map?.dispose(); keyLight.shadow.map = null;
    keyLight.shadow.mapPass?.dispose(); keyLight.shadow.mapPass = null;
  }
  renderer.toneMapping = testFeatures.grading
    ? toneMappings[defaultToneMapping] ?? THREE.ACESFilmicToneMapping : THREE.NoToneMapping;
  renderer.toneMappingExposure = testFeatures.grading ? profile.exposure : 1;
  scene.fog = null;
  if (testFeatures.reflections) {
    if (!reflectionEnvironment) installReflectionEnvironment();
    scene.environment = reflectionEnvironment;
    updateReflectionEnvironment(profile);
    // Fog is not part of the reflection test.
    scene.fog = null;
  } else {
    scene.environment = null;
    reflectionEnvironment?.dispose(); reflectionEnvironment = null; reflectionEnvironmentFaces = [];
  }
  if (testFeatures.sky) {
    if (isMorning()) installMiddaySky({ morning: true });
    else if (isSunset()) installMiddaySky({ sunset: true });
    else if (isMidday()) installMiddaySky();
    else installNightSky();
    updateNightSky();
  } else removeTestSky();
  if (cinematicGradePass) {
    const uniforms = cinematicGradePass.uniforms;
    uniforms.warmColor.value.copy(profile.grading.warmColor);
    uniforms.warmStrength.value = profile.grading.warmStrength;
    uniforms.warmStart.value = profile.grading.warmStart;
    uniforms.warmEnd.value = Math.max(profile.grading.warmStart + 0.001, profile.grading.warmEnd);
    uniforms.neutralWarmResponse.value = profile.grading.neutralWarmResponse;
    uniforms.contrast.value = profile.grading.contrast;
    uniforms.saturation.value = profile.grading.saturation;
    uniforms.temperature.value = activeColorTemperature();
    uniforms.surfaceRayStrength.value = 0;
  }
  if (bloomPass) { updateDaylightBloom(profile); bloomPass.enabled = testFeatures.bloom; }
  mobileBloom?.invalidate();
  const look = effectiveMorningLook();
  const shaderGain = isMorning() ? approvedFeatureAppearance.morningShaderGain ?? 1
    : isSunset() ? approvedFeatureAppearance.sunsetShaderGain ?? 1 : 1;
  const grassBrightness = testFeatures.shaders && nightSkyAmount() > 0.5
    ? approvedFeatureAppearance.nightGrassBrightness ?? 1 : 1;
  // Always start from the captured material color: repeated clock updates and
  // returning from night must not progressively darken the campus.
  for (const [material, color] of testGrassColors) {
    material.color.copy(color).multiplyScalar(grassBrightness);
  }
  nightCinema?.update(nightSkyAmount(), testFeatures.textures, keyLight, lightingFrame,
    isDayCustomization() ? 1 : 0, look.textureDetail,
    testFeatures.shaders ? (look.sunHighlights ?? 1) * shaderGain : 1,
    testFeatures.shaders ? (look.reflections ?? 8) / 8 : 1,
    testFeatures.shaders ? look.foliageStrength ?? 0 : 0);
  applyWindowPresetLighting();
}

async function applyMapTestFeatures(requested, { warm = true } = {}) {
  if (!featurePanelEnabled || !model || viewerDisposed) return { ...testFeatures };
  if (interiorLoading) throw new Error('Aguarde a troca de piso terminar.');
  featureBusy = true;
  try {
    for (const fade of [...objectFades]) fade.cleanup();
    clearSelection({ animate: false }); send('selected');
    disposeSelectionVariants();
    clearWindowPresets();
    testFeatures = normalizedMapFeatures(requested);
    if (testFeatures.selection && selectionCacheLoader && !selectionPreparedCache) {
      selectionPreparedCache = await selectionCacheLoader();
      if (viewerDisposed) return { ...testFeatures };
    }
    if (!testFeatures.selection) {
      pickingTarget.setSize(1, 1); selectionOutline.clear({ release: true });
    }
    basicLightingTest = testFeatures.lighting;
    configureTestInteriors(testFeatures.selection);
    restoreRawMaterials();
    nightCinema?.dispose(); nightCinema = null;
    for (const material of testOwnedMaterials) material.dispose();
    testOwnedMaterials.clear();
    testGrassColors.clear();
    const cache = new Map();
    const materialFor = source => {
      if (cache.has(source)) return cache.get(source);
      let material;
      if (testFeatures.pbr) {
        material = source.clone();
        if (testFeatures.textures || testFeatures.shaders) applyMaterialFinish(material);
      } else {
        const Type = testFeatures.lighting ? THREE.MeshLambertMaterial : THREE.MeshBasicMaterial;
        material = new Type({ name: source.name, color: source.color?.clone() ?? new THREE.Color('white'),
          map: source.map ?? null, vertexColors: source.vertexColors === true,
          transparent: source.transparent === true, opacity: source.opacity ?? 1,
          alphaTest: source.alphaTest ?? 0, side: source.side,
          depthTest: source.depthTest !== false, depthWrite: source.depthWrite !== false });
      }
      material.toneMapped = testFeatures.grading; material.fog = false;
      if (/grass|grama/i.test(material.name)) testGrassColors.set(material, material.color.clone());
      cache.set(source, material); testOwnedMaterials.add(material); return material;
    };
    const excluded = lightingTuning.shadows?.casterExclusions ?? [];
    for (const [mesh, source] of testMaterialSources) {
      mesh.material = Array.isArray(source) ? source.map(materialFor) : materialFor(source);
      let parent = mesh; let casts = true;
      while (parent) { if (excluded.includes(parent.name)) casts = false; parent = parent.parent; }
      mesh.castShadow = testFeatures.shadows && casts;
      mesh.receiveShadow = testFeatures.shadows;
    }
    if (testFeatures.textures || testFeatures.shaders) {
      nightCinema = createNightCinema(model, scene, nightLook,
        { textures: testFeatures.textures, shaders: testFeatures.shaders });
    }
    if (testFeatures.windows) prepareWindowPresets(model,
      { glowEnabled: testFeatures.windowLighting, glowMaxLights: 4, preserveSurface: true });
    if(testFeatures.selection)interiors?.restorePreparedMaterials();
    disposeTestComposer();
    if (testFeatures.grading || testFeatures.bloom) { installPostProcessing({ debug: true }); resize(); }
    applyTestFeatureProfile();
    model.updateMatrixWorld(true);
    rawModeEnabled = true; // Diagnostic scene; never re-enable the normal pipeline implicitly.
    if (warm) {
      await yieldLoadingWork();
      if (viewerDisposed) return { ...testFeatures };
      await renderer.compileAsync(scene, camera);
      if (viewerDisposed) return { ...testFeatures };
      await mobileBloom?.warmup(scene, camera);
      if (viewerDisposed) return { ...testFeatures };
      requestRender();
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    }
    featurePanel?.update(testFeatures);
    if (warm) persistRenderPreferences();
    requestRender();
    return { ...testFeatures };
  } finally { featureBusy = false; }
}

function setMapTestFeatures(requested) {
  const next = { ...requested };
  const run = featureApplyQueue.catch(() => {}).then(() => applyMapTestFeatures(next));
  featureApplyQueue = run;
  return run;
}

function setMapTestFeature(name, enabled) {
  try { return setMapTestFeatures(toggledMapFeatures(testFeatures, name, enabled)); }
  catch (error) { return Promise.reject(error); }
}

function setSelectionOptions(settings) {
  if (interiorLoading || featureBusy) throw new Error('Aguarde a troca de piso / efeitos terminar.');
  const next = normalizedSelectionOptions(settings, selectionOptions);
  const effectChanged = ['outline', 'outlineAnimation', 'pulse', 'roomGlow']
    .some(key => next[key] !== selectionOptions[key]);
  const state = selectionState;
  const zoneId = selectedZoneId;
  selectionOptions = next;
  persistRenderPreferences();
  // Do not rebuild the lighting/material pipeline, change floors, or refocus
  // the camera just to change one piece of selection decoration.
  if (effectChanged && state) {
    if (state.leavingAt !== null) clearSelection({ animate: false });
    else {
      startSelectionEffect(state.node, { lit: state.room });
      selectedZoneId = zoneId;
    }
  }
  featurePanel?.updateSelection(selectionOptions);
  send('selectionOptions', { options: { ...selectionOptions } });
  requestRender();
  return { ...selectionOptions };
}

function setInterfaceBlur(enabled) {
  if (typeof enabled !== 'boolean') throw new Error('Valor de blur inválido.');
  interfaceBlurEnabled = enabled;
  persistRenderPreferences();
  featurePanel?.updateInterfaceBlur(enabled);
  send('interfaceBlur', { enabled });
  return enabled;
}

function setNavBlur(enabled) {
  if (typeof enabled !== 'boolean') throw new Error('Valor de blur inválido.');
  navBlurEnabled = enabled;
  persistRenderPreferences();
  featurePanel?.updateNavBlur(enabled);
  send('navBlur', { enabled });
  return enabled;
}

function sendInteriorState(message = null) {
  send('interior', { zoneId: interiors?.current?.zoneId ?? null,
    floorId: interiors?.current?.id ?? null, spaceLabel: interiors?.selected?.label ?? null,
    busy: interiorLoading, message });
}

let hiddenInteriorExterior = null;
let exportedWindowPresetObjects = [];
const hiddenInteriorWindows = new Map();

function hideInteriorWindows() {
  const nodes=new Set([...exportedWindowPresetObjects,...interiorWindowObjects()]);
  for(const node of nodes) {
    if(!hiddenInteriorWindows.has(node))hiddenInteriorWindows.set(node,node.visible);
    node.visible=false;
  }
  for(const group of windowPresetGroups.values())for(const preset of group)
    if(preset.glowLight)preset.glowLight.visible=false;
  requestRender();
}

function showInteriorExterior() {
  if (hiddenInteriorExterior) {
    hiddenInteriorExterior.node.visible = hiddenInteriorExterior.visible;
    hiddenInteriorExterior = null;
  }
  for(const [node,visible] of hiddenInteriorWindows)node.visible=visible;
  hiddenInteriorWindows.clear();
  for (const group of windowPresetGroups.values()) {
    for (const preset of group) {
      if (preset.glowLight) preset.glowLight.visible = preset.glowLight.intensity > 0;
    }
  }
}

function interiorWindowObjects() {
  return [...windowPresetGroups.values()].flatMap(group => group.map(preset => preset.node));
}

function hideInteriorExterior(zoneId) {
  if (hiddenInteriorExterior?.zoneId !== zoneId) {
    showInteriorExterior();
    const zone = config?.zones.find((entry) => entry.id === zoneId);
    const node = zoneNodes.get(zone?.nodeName);
    if (node) {
      hiddenInteriorExterior = { zoneId, node, visible: node.visible };
      node.visible = false;
    }
  }
  hideInteriorWindows();
}

function exitInterior({ focus = true } = {}) {
  ++interiorRequest;
  const zoneId = interiors?.current?.zoneId;
  for (const fade of [...objectFades]) fade.cleanup();
  interiors?.leave();
  showInteriorExterior();
  interiorLoading = false;
  controls.enabled = true;
  if (exteriorNavigation) {
    ({ navigationBounds, navigationHull, navigationEdges, navigationInset,
      navigationTargetHeight, baseMinDistance, baseMaxDistance } = exteriorNavigation);
    controls.minPolarAngle = exteriorNavigation.minPolarAngle;
    controls.maxPolarAngle = exteriorNavigation.maxPolarAngle;
    exteriorNavigation = null;
  }
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  cameraFocus = null;
  viewTransition = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  clearSelection({ animate: false });
  send('selected');
  sendInteriorState();
  if (focus && zoneId) focusZone(zoneId, { interiorTravel: true });
  requestRender();
}

async function exitInteriorWithFade({ focus = true } = {}) {
  if (!interiors?.current || interiorLoading || viewerDisposed) return;
  let request = ++interiorRequest;
  const zone = config.zones.find(entry => entry.id === interiors.current.zoneId);
  const exterior = zoneNodes.get(zone?.nodeName);
  let fade;
  interiorLoading = true;
  controls.enabled = false;
  clearSelection({ animate: false });
  sendInteriorState();
  try {
    fade = prepareObjectFade(interiors.activeFloors.map(entry => entry.group), 1);
    await fade.start(0);
    if (viewerDisposed || request !== interiorRequest) return;
    exitInterior({ focus });
    request = interiorRequest;
    interiorLoading = true;
    controls.enabled = false;
    if (exterior) {
      fade = prepareObjectFade([exterior], 0);
      await fade.start(1);
    }
  } finally {
    fade?.cleanup();
    if (!viewerDisposed && request === interiorRequest) {
      interiorLoading = false;
      controls.enabled = true;
      sendInteriorState();
      requestRender();
    }
  }
}

async function setInteriorFloor(zoneId, floorId) {
  if (featureBusy) return;
  if (geometryOnly && !(featurePanelEnabled && testFeatures.selection)) return;
  if (!floorId) { await exitInteriorWithFade(); return; }
  const floor = interiors?.floors.get(floorId);
  if (!floor || floor.zoneId !== zoneId || interiorLoading || viewerDisposed) return;
  hideInteriorWindows();
  const request = ++interiorRequest;
  if (rawModeEnabled && !featurePanelEnabled) { setRawMode(false); send('rawMode', { enabled: false }); }
  if (!exteriorNavigation) exteriorNavigation = {
    navigationBounds, navigationHull, navigationEdges, navigationInset,
    navigationTargetHeight, baseMinDistance, baseMaxDistance,
    // Interior travel always ends in 3D. Do not save the temporary top-view
    // polar lock (0..0.0001) as the exterior's orbit limits.
    minPolarAngle: controlsTuning.minPolarAngle ?? 0.2,
    maxPolarAngle: controlsTuning.maxPolarAngle ?? Math.PI * 0.48,
  };
  clearSelection({ animate: false });
  interiorLoading = true;
  controls.enabled = false;
  const previousFloors = interiors.activeFloors;
  const baseFloor = [...interiors.floors.values()].find(entry => entry.zoneId === zoneId);
  const desiredFloors = new Set([baseFloor, floor]);
  const outgoingObjects = previousFloors.filter(entry => !desiredFloors.has(entry))
    .map(entry => entry.group);
  if (!interiors.current) {
    const zone = config.zones.find(entry => entry.id === zoneId);
    const exterior = zoneNodes.get(zone?.nodeName);
    if (exterior) outgoingObjects.push(exterior);
  }
  let outgoingFade;
  let incomingFade;
  sendInteriorState();
  try {
    if (outgoingObjects.length) {
      outgoingFade = prepareObjectFade(outgoingObjects, 1);
      await outgoingFade.start(0);
      if (viewerDisposed || request !== interiorRequest) return;
    }
    interiors.enter(floorId);
    hideInteriorExterior(zoneId);
    outgoingFade?.cleanup();
    const incomingObjects = interiors.activeFloors.filter(entry => !previousFloors.includes(entry))
      .map(entry => entry.group);
    sendInteriorState();
    navigationBounds = floor.bounds.clone();
    navigationHull = [];
    navigationEdges = [];
    navigationInset = 0;
    navigationTargetHeight = floor.floorY + 0.6;
    const size = floor.bounds.getSize(new THREE.Vector3());
    const span = Math.max(size.x, size.z);
    navigationBounds.expandByScalar(span * 0.035);
    baseMinDistance = Math.max(5, span * (cameraTuning.minDistanceMultiplier ?? 0.22));
    const floorDirection = interiorDirection(zoneId);
    baseMaxDistance = span * 6;
    const fittedDistance = focusDistanceForPoints(focusPointsForNode(floor.group),
      floor.bounds.getCenter(new THREE.Vector3()), floorDirection, {}) * 1.1;
    baseMaxDistance = Math.max(span * (cameraTuning.maxDistanceMultiplier ?? 0.42),
      fittedDistance * 1.2);
    controls.minPolarAngle = 0.05;
    controls.maxPolarAngle = Math.PI * 0.43;
    resettingCamera = null;
    navigationSpring = null;
    focusNode(floor.group, { useVisualCenter: true, direction: floorDirection.toArray(),
      distanceScale: 1.1, constrainToNavigation: false });
    const pendingFloors = interiors.activeFloors.filter(entry => !entry.gpuReady);
    if (pendingFloors.length > 0) {
      await yieldLoadingWork();
      for (const entry of pendingFloors) {
        // Compile the actual opaque interior too: previously only the fade
        // copies were warmed, and restoring the real material caused a hitch.
        await renderer.compileAsync(entry.group, camera, scene);
        if (viewerDisposed || request !== interiorRequest) return;
        startSelectionEffect(entry.group);
        await renderer.compileAsync(entry.group, camera, scene);
        clearSelection({ animate: false });
        if (viewerDisposed || request !== interiorRequest) return;
      }
    }
    if (incomingObjects.length) {
      incomingFade = prepareObjectFade(incomingObjects, 0);
      for (const object of incomingObjects) await renderer.compileAsync(object, camera, scene);
      if (viewerDisposed || request !== interiorRequest) return;
    }
    if (pendingFloors.length > 0) {
      for (const entry of pendingFloors) {
        await prepareGpuGeometry(entry.group, scene, { isolate: true });
        if (viewerDisposed || request !== interiorRequest) return;
      }
      await waitForGpu();
      if (viewerDisposed || request !== interiorRequest) return;
      for (const entry of pendingFloors) entry.gpuReady = true;
    }
    if (cameraFocus) cameraFocus.startedAt = performance.now();
    if (viewTransition) viewTransition.startedAt = performance.now();
    if (incomingFade) {
      await incomingFade.start(1);
      if (viewerDisposed || request !== interiorRequest) return;
      incomingFade.cleanup();
    }
    startSelectionEffect(floor.group);
  } catch (error) {
    if (request !== interiorRequest || viewerDisposed) return;
    exitInterior();
    sendInteriorState(String(error.message ?? error));
  } finally {
    outgoingFade?.cleanup();
    incomingFade?.cleanup();
    if (request === interiorRequest && !viewerDisposed) {
      interiorLoading = false;
      controls.enabled = true;
      sendInteriorState();
      requestRender();
    }
  }
}

function setRawMode(enabled) {
  if (geometryOnly && enabled !== true) return rawModeEnabled;
  if (interiors?.current) exitInterior();
  const next = enabled === true;
  if (rawModeEnabled === next || !model) return rawModeEnabled;
  clearSelection({ animate: false });
  send('selected');
  if (next) {
    const cache = new Map();
    const basicFor = (source) => {
      if (cache.has(source)) return cache.get(source);
      const Material = basicLightingTest ? THREE.MeshLambertMaterial : THREE.MeshBasicMaterial;
      const basic = new Material({
        color: source.color?.clone() ?? new THREE.Color('#ffffff'),
        map: source.map ?? null,
        vertexColors: source.vertexColors === true,
        transparent: source.transparent === true,
        opacity: source.opacity ?? 1,
        alphaTest: source.alphaTest ?? 0,
        side: source.side ?? THREE.FrontSide,
        depthTest: source.depthTest !== false,
        depthWrite: source.depthWrite !== false,
        toneMapped: false,
        fog: false,
      });
      cache.set(source, basic);
      rawMaterials.add(basic);
      return basic;
    };
    model.traverse((node) => {
      if (!node.isMesh || !node.material) return;
      rawMaterialStates.push({ mesh: node, material: node.material });
      node.material = Array.isArray(node.material)
        ? node.material.map(basicFor)
        : basicFor(node.material);
    });
    rawModeEnabled = true;
  } else {
    restoreRawMaterials();
    rawModeEnabled = false;
    applyDaylightProfile();
  }
  requestRender();
  if (diagnosticsEnabled) send('diagnostics', diagnosticsSnapshot());
  return rawModeEnabled;
}

function disposeViewer() {
  if (viewerDisposed) return;
  viewerDisposed = true;
  viewerEvents.abort();
  mapEventNavigationRequest++;
  eventMarkers.dispose();eventAnchorCache.clear();
  fpsCounter.dispose();
  featurePanel?.dispose();
  nightCinema?.dispose();
  clearWindowPresets();
  for (const material of testOwnedMaterials) material.dispose();
  testOwnedMaterials.clear(); testMaterialSources.clear(); testGrassColors.clear();
  for (const fade of [...objectFades]) fade.cleanup();
  releaseSelectedMeshes();
  disposeSelectionVariants();
  geometryWarmupTarget?.dispose(); geometryWarmupTarget = null;
  if (diagnosticsTimer !== null) clearInterval(diagnosticsTimer);
  if (diagnosticsGpuQuery) renderer.getContext().deleteQuery(diagnosticsGpuQuery);
  if (animationFrame !== null) cancelAnimationFrame(animationFrame);
  if (bearingResetFrame !== null) cancelAnimationFrame(bearingResetFrame);
  bearingResetFrame = null;
  animationFrame = null;
  cancelRestingResolutionRestore();
  controls.dispose();
  interiors?.dispose();
  restoreRawMaterials();
  modelTransfer = null;
  mobileBloom?.dispose(); mobileBloom = null;
  mapAntialias?.dispose(); mapAntialias = null;
  for (const pass of effectComposer?.passes ?? []) pass.dispose?.();
  effectComposer?.dispose();
  selectionOutline.dispose();
  pickingTarget.dispose();
  const resources = new Set();
  for (const texture of [scene.background, scene.environment, atmosphereTexture, reflectionEnvironment]) {
    if (texture?.isTexture) resources.add(texture);
  }
  scene.traverse(node => {
    if (node.geometry) resources.add(node.geometry);
    for (const material of (Array.isArray(node.material) ? node.material : [node.material])) {
      if (!material) continue;
      resources.add(material);
      for (const value of Object.values(material)) if (value?.isTexture) resources.add(value);
    }
    node.shadow?.dispose();
  });
  for (const resource of resources) resource.dispose();
  scene.clear();
  scene.background = null;
  scene.environment = null;
  atmosphereTexture = null;
  atmosphereCanvas = null;
  atmosphereContext = null;
  reflectionEnvironment = null;
  reflectionEnvironmentFaces = [];
  model = null;
  selectionWindowMeshes = [];
  exportedWindowPresetObjects = [];hiddenInteriorWindows.clear();
  zoneNodes.clear();
  renderer.dispose();
  renderer.forceContextLoss();
}

function setVisible(visible) {
  if (viewerDisposed) return;
  viewerSuspended = !visible;
  if (viewerSuspended) {
    cameraPointerIds.clear();pointerStart=null;multiTouchGesture=false;pendingMarkerPointer=null;
    eventMarkers.setCameraGestureActive(false);
    if (animationFrame !== null) cancelAnimationFrame(animationFrame);
    animationFrame = null;
    cancelRestingResolutionRestore();
  } else requestRender();
}

function resetCamera() {
  if (interiors?.current) exitInterior({ focus: false });
  if (!initialCameraPosition || !initialTarget) return;
  if (mapViewMode === '2d' || viewTransition) {
    const destination = perspectiveCamera.clone();
    destination.position.copy(initialCameraPosition);
    destination.lookAt(initialTarget);
    beginViewTransition('3d', destination, initialTarget);
    return;
  }
  activateMapCamera('3d');
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  resettingCamera = {
    startedAt: performance.now(),
    duration: 650,
    fromPosition: camera.position.clone(),
    fromTarget: controls.target.clone(),
  };
  beginCameraTransitionResolution();
  requestRender();
}

function setLocalTimeMinutes(minutes) {
  if (!config || !Number.isFinite(minutes)) return;
  const previousPeriod = presetTimeMinutes();
  config.localTimeMinutes = ((minutes % 1440) + 1440) % 1440;
  if (model && previousPeriod !== presetTimeMinutes()) {
    applyDaylightProfile();
    requestRender();
  }
}

function setPreviewTimeMinutes(minutes) {
  if (!Number.isFinite(minutes)) return;
  previewLocalTimeMinutes = ((minutes % 1440) + 1440) % 1440;
  if (model) {
    applyDaylightProfile();
    requestRender();
  }
}

function clearPreviewTime() {
  previewLocalTimeMinutes = null;
  if (model) {
    applyDaylightProfile();
    requestRender();
  }
}

function setDaylightPreview(overrides) {
  daylightPreviewOverrides = overrides && typeof overrides === 'object'
    ? overrides
    : null;
  if (model) {
    applyDaylightProfile();
    requestRender();
  }
}

function clearDaylightPreview() {
  daylightPreviewOverrides = null;
  if (model) {
    applyDaylightProfile();
    requestRender();
  }
}

function configureAtmosphere(settings = {}) {
  if (!settings || typeof settings !== 'object') return;
  const atmosphere = lightingTuning.atmosphere ??= {};
  Object.assign(atmosphere, settings);
  resizeAtmosphericBackground(
    Math.max(1, document.documentElement.clientWidth),
    Math.max(1, document.documentElement.clientHeight),
  );
  updateAtmosphericBackground(activeDaylightProfile, { force: true });
  updateAtmosphericPostProcessing(activeDaylightProfile);
  requestRender();
}

function configureGroundRays(settings = {}) {
  if (!settings || typeof settings !== 'object') return;
  const groundRays = lightingTuning.groundRays ??= {};
  Object.assign(groundRays, settings);
  updateGroundSunRays(activeDaylightProfile);
  requestRender();
}

function setPreviewCamera(view = {}) {
  if (!Array.isArray(view.position) || !Array.isArray(view.target)) return;
  resettingCamera = null;
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  camera.position.fromArray(view.position);
  controls.target.fromArray(view.target);
  camera.lookAt(controls.target);
  controls.update();
  if (view.constrain !== false) {
    applyNavigationConstraint({ elastic: false });
    applyDistanceConstraint({ elastic: false });
  }
  sendCameraState({ force: true });
  requestRender();
}

function rotateCameraBy(degrees) {
  if (viewTransition) return;
  if (!Number.isFinite(degrees) || Math.abs(degrees) < 0.001) return;
  resettingCamera = null;
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  const offset = camera.position.clone().sub(controls.target);
  offset.applyAxisAngle(
    new THREE.Vector3(0, 1, 0),
    THREE.MathUtils.degToRad(-degrees),
  );
  camera.position.copy(controls.target).add(offset);
  camera.lookAt(controls.target);
  applyNavigationConstraint({ elastic: true });
  sendCameraState();
  requestRender();
}

let externalRotationActive = false;
let bearingResetFrame = null;

function beginExternalRotation() {
  if (viewTransition) return;
  if (bearingResetFrame !== null) {
    cancelAnimationFrame(bearingResetFrame);
    bearingResetFrame = null;
  }
  if (externalRotationActive) return;
  externalRotationActive = true;
  beginManualCameraGesture();
  controlsInteractionActive = true;
  interactionStartedAt = performance.now();
  interactionFrameCount = 0;
  lastPerformanceReportAt = interactionStartedAt;
  lastPerformanceFrameCount = 0;
  shadowUpdateResumeAt = Infinity;
  cancelRestingResolutionRestore();
  useInteractionResolution(true);
  requestRender();
}

function resetBearing() {
  resetCamera();
}

function topViewZoomLimits() {
  const settings = cameraTuning.topView ?? {};
  const baseline = Math.max(0.01, Number(settings.zoom) || 1);
  const closer = Math.max(0, Math.min(0.5, settings.zoomInLimit ?? 0.20));
  const farther = Math.max(0, Math.min(0.5, settings.zoomOutLimit ?? 0.18));
  // Orthographic zoom is inverse to the visible width/height.
  return { min: baseline / (1 + farther), max: baseline * (1 + closer) };
}

function activateMapCamera(mode) {
  const topView = mode === '2d';
  mapViewMode = topView ? '2d' : '3d';
  camera = topView ? topCamera : perspectiveCamera;
  controls.object = camera;
  controls.enabled = true;
  controls.enableRotate = !topView;
  controls.minPolarAngle = topView ? 0 : interiors?.current ? 0.05 : controlsTuning.minPolarAngle ?? 0.2;
  controls.maxPolarAngle = topView ? 0.0001 : interiors?.current ? Math.PI * 0.43 : controlsTuning.maxPolarAngle ?? Math.PI * 0.48;
  controls.mouseButtons.LEFT = topView ? THREE.MOUSE.PAN : THREE.MOUSE.ROTATE;
  controls.touches.ONE = topView || controlsTuning.oneFingerAction === 'pan'
    ? THREE.TOUCH.PAN : THREE.TOUCH.ROTATE;
  controls.touches.TWO = !topView && controlsTuning.twoFingerAction === 'rotate'
    ? THREE.TOUCH.DOLLY_ROTATE : THREE.TOUCH.DOLLY_PAN;
  const zoomLimits = topViewZoomLimits();
  controls.minZoom = topView ? zoomLimits.min : 0;
  controls.maxZoom = topView ? zoomLimits.max : Infinity;
  controls.minDistance = baseMinDistance;
  controls.maxDistance = topView ? Infinity : baseMaxDistance;
  if (sceneRenderPass) sceneRenderPass.camera = camera;
  resize();
  send('viewMode', { mode: mapViewMode });
}

function setMapViewMode(mode) {
  if (interiors?.current) exitInterior({ focus: false });
  if (!model || !lightingFrame || !initialTarget) return false;
  if (mode !== '2d') {
    resetCamera();
    return true;
  }
  const source = { camera: camera.clone(), target: controls.target.clone() };
  clearSelection({ animate: false });
  send('selected');
  resettingCamera = null;
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  const bounds = navigationBounds ?? lightingFrame.bounds;
  const size = bounds.getSize(new THREE.Vector3());
  const settings = cameraTuning.topView ?? {};
  const hasSavedView = Array.isArray(settings.initialPosition) &&
    settings.initialPosition.length === 3 && Array.isArray(settings.initialTarget) &&
    settings.initialTarget.length === 3;
  const target = hasSavedView
    ? new THREE.Vector3().fromArray(settings.initialTarget)
    : bounds.getCenter(new THREE.Vector3());
  if (!hasSavedView) target.y = navigationTargetHeight ?? initialTarget.y;
  const aspect = Math.max(1, document.documentElement.clientWidth) /
    Math.max(1, document.documentElement.clientHeight);
  topViewHalfHeight = Math.max(size.z / 2, size.x / (2 * aspect)) * 1.08;
  const height = Math.max(size.x, size.z, 100) * 2;
  const azimuth = initialAzimuth ?? 0;
  const zoomLimits = topViewZoomLimits();
  topCamera.zoom = THREE.MathUtils.clamp(settings.zoom ?? 1,
    zoomLimits.min, zoomLimits.max);
  if (hasSavedView) {
    topCamera.position.fromArray(settings.initialPosition);
  } else {
    topCamera.position.copy(target).add(new THREE.Vector3(
      Math.sin(azimuth) * height * 0.00001, height,
      Math.cos(azimuth) * height * 0.00001,
    ));
  }
  topCamera.lookAt(target);
  topCamera.left = -topViewHalfHeight * aspect;
  topCamera.right = topViewHalfHeight * aspect;
  topCamera.top = topViewHalfHeight;
  topCamera.bottom = -topViewHalfHeight;
  topCamera.updateProjectionMatrix();
  beginViewTransition('2d', topCamera, target, source);
  cameraMovedSinceFocus = true;
  sendCameraState({ force: true });
  requestRender();
  return true;
}

function beginViewTransition(mode, destination, target, source = null) {
  const start = source?.camera ?? camera.clone();
  const startTarget = source?.target ?? controls.target.clone();
  const fromProjection = start.projectionMatrix.clone();
  // Homogeneous normalization preserves the first frame while letting the
  // vanishing point move continuously toward an orthographic projection.
  if (start.isPerspectiveCamera && !viewTransition) {
    fromProjection.multiplyScalar(1 / Math.max(1, start.position.distanceTo(startTarget)));
  }
  const toProjection = destination.projectionMatrix.clone();
  if (destination.isPerspectiveCamera) {
    toProjection.multiplyScalar(1 / Math.max(1, destination.position.distanceTo(target)));
  }
  viewTransition = {
    startedAt: performance.now(), duration: 650, mode,
    fromPosition: start.position.clone(), toPosition: destination.position.clone(),
    fromQuaternion: start.quaternion.clone(), toQuaternion: destination.quaternion.clone(),
    fromTarget: startTarget, toTarget: target.clone(),
    fromProjection, toProjection, zoom: destination.zoom,
  };
  resettingCamera = null;
  cameraFocus = null;
  navigationSpring = null;
  camera = start;
  controls.object = camera;
  controls.enabled = false;
  if (sceneRenderPass) sceneRenderPass.camera = camera;
  beginCameraTransitionResolution();
  camera.projectionMatrix.copy(fromProjection);
  camera.projectionMatrixInverse.copy(fromProjection).invert();
  send('viewMode', { mode });
  requestRender();
}

function endExternalRotation() {
  if (!externalRotationActive) return;
  externalRotationActive = false;
  sendPerformanceSample(performance.now(), { force: true });
  controlsInteractionActive = false;
  shadowUpdateResumeAt = performance.now() + 140;
  applyNavigationConstraint({ elastic: true });
  applyDistanceConstraint({ elastic: true });
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  startNavigationReturn();
  scheduleRestingResolutionRestore(140);
  sendCameraState({ force: true });
  requestRender();
}

function refreshMaterialFinish() {
  if (!model || geometryOnly) return;
  model.traverse((object) => {
    if (!object.isMesh || object.userData.isGroundSunRay) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    for (const material of materials) applyMaterialFinish(material);
  });
  applyDaylightProfile();
  requestRender();
}

function debugSnapshot() {
  const materials = [];
  const zones = [];
  const seenMaterials = new Set();
  let modelMeshes = 0;
  let modelTriangles = 0;
  model?.traverse((object) => {
    if (!object.isMesh) return;
    modelMeshes++;
    modelTriangles += (object.geometry?.index?.count ?? object.geometry?.attributes.position?.count ?? 0) / 3;
    const objectMaterials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    for (const material of objectMaterials) {
      if (!material || seenMaterials.has(material.uuid)) continue;
      seenMaterials.add(material.uuid);
      materials.push({
        name: material.name,
        type: material.type,
        color: material.color?.getHexString(),
        roughness: material.roughness,
        clearcoat: material.clearcoat,
        clearcoatRoughness: material.clearcoatRoughness,
        envMapIntensity: material.envMapIntensity,
        hasColorTexture: Boolean(material.map),
        hasNormalTexture: Boolean(material.normalMap),
        proceduralTexture: material.userData.nightProceduralTexture === true,
        normalScale: material.normalScale?.toArray(),
      });
    }
  });
  for (const [nodeName, node] of zoneNodes.entries()) {
    const bounds = new THREE.Box3().setFromObject(node);
    zones.push({
      nodeName,
      min: bounds.min.toArray(),
      max: bounds.max.toArray(),
      center: bounds.getCenter(new THREE.Vector3()).toArray(),
      size: bounds.getSize(new THREE.Vector3()).toArray(),
    });
  }
  return {
    geometryOnly,
    features: featurePanelEnabled ? { ...testFeatures } : null,
    featureBusy,
    quality: { ...mapQuality, pixelRatio: renderer.getPixelRatio(),
      drawingBufferSize: [renderer.domElement.width, renderer.domElement.height],
      antialiasPass: mapAntialias?.snapshot() ?? null },
    windows: {
      mode: windowPresetGroups.size === 0 ? 'off'
        : windowGlowLights.length > 0 ? 'full' : 'basic',
      groups: windowPresetGroups.size,
      presets: [...windowPresetGroups.values()].reduce((sum, group) => sum + group.length, 0),
      litPresets: [...windowPresetGroups.values()].flat().filter(preset => preset.node.visible &&
        preset.materialStates.some(state => state.supportsEmission &&
          state.material.emissiveIntensity > 0 && state.material.emissive.getHex() !== 0)).length,
      pointLights: windowGlowLights.length,
      activePointLights: windowGlowLights.filter(light => light.visible && light.intensity > 0).length,
      pointLightShadows: windowGlowLights.filter(light => light.castShadow).length,
    },
    reflectionEnvironmentInstalled: reflectionEnvironment !== null,
    shadowsAllocated: keyLight?.shadow.map != null,
    basicLightingTest,
    testStage: geometryOnly ? (basicLightingTest ? 'basic-lighting' : 'raw') : 'full',
    modelMeshes,
    modelTriangles,
    postProcessingAllocated: effectComposer !== null || mobileBloom !== null,
    localTimeMinutes: config?.localTimeMinutes,
    effectiveLocalTimeMinutes: localTimeMinutes(),
    previewLocalTimeMinutes,
    daylightPreviewEnabled: daylightPreviewOverrides !== null,
    atmosphere: {
      canvasSize: atmosphereCanvas
        ? [atmosphereCanvas.width, atmosphereCanvas.height]
        : null,
      projectedSun: projectedSunPosition(),
      rayColor: activeDaylightProfile?.rays?.color.getHexString(),
      rayOpacity: activeDaylightProfile?.rays?.opacity,
    },
    nightSky: {
      generated: nightSkyPoints !== null,
      count: nightSkyPoints?.geometry.attributes.position.count ?? 0,
      amount: nightSkyAmount(),
      visible: nightSkyPoints?.visible ?? false,
    },
    middaySky: middaySkyMesh ? {
      visible: middaySkyMesh.visible,
      position: middaySkyMesh.position.toArray(),
      rotation: middaySkyMesh.rotation.toArray(),
      textureSize: [middaySkyMesh.material.map.image.width, middaySkyMesh.material.map.image.height],
      textureId: middaySkyMesh.material.map.uuid,
      triangles: middaySkyMesh.geometry.index.count / 3,
      cloudCount: middaySkyMesh.userData.cloudDirections.length,
      cloudSizes: middaySkyMesh.userData.cloudSizes,
      cloudProjections: middaySkyMesh.userData.cloudDirections.map(direction =>
        camera.position.clone().addScaledVector(direction, 1900).project(camera).toArray()),
    } : null,
    sunsetSky: sunsetSkyMesh ? {
      visible: sunsetSkyMesh.visible,
      position: sunsetSkyMesh.position.toArray(),
      rotation: sunsetSkyMesh.rotation.toArray(),
      textureId: sunsetSkyMesh.material.map.uuid,
      cloudCount: sunsetSkyMesh.userData.cloudDirections.length,
      cloudProjections: sunsetSkyMesh.userData.cloudDirections.map(direction =>
        camera.position.clone().addScaledVector(direction, 1900).project(camera).toArray()),
    } : null,
    morningSky: morningSkyMesh ? {
      visible: morningSkyMesh.visible,
      textureId: morningSkyMesh.material.map.uuid,
      cloudCount: morningSkyMesh.userData.cloudDirections.length,
      position: morningSkyMesh.position.toArray(),
      rotation: morningSkyMesh.rotation.toArray(),
      cloudProjections: morningSkyMesh.userData.cloudDirections.map(direction =>
        camera.position.clone().addScaledVector(direction, 1900).project(camera).toArray()),
    } : null,
    nightCinema: nightCinema?.stats(),
    toneMapping: rendererTuning.toneMapping,
    exposure: renderer.toneMappingExposure,
    bloom: bloomPass
      ? {
          enabled: bloomPass.enabled,
          strength: bloomPass.strength,
          radius: bloomPass.radius,
          threshold: bloomPass.threshold,
          ...mobileBloom?.snapshot(),
        }
      : null,
    cameraPosition: camera.position.toArray(),
    viewMode: mapViewMode,
    cameraProjection: camera.isOrthographicCamera ? 'orthographic' : 'perspective',
    cameraProjectionMatrix: camera.projectionMatrix.toArray(),
    cameraMatrixWorld: camera.matrixWorld.toArray(),
    polarLimits: [controls.minPolarAngle, controls.maxPolarAngle],
    cameraZoom: camera.zoom,
    viewTransition: viewTransition ? { mode: viewTransition.mode } : null,
    navigationReturning: navigationSpring !== null,
    cameraAnimating: cameraTransitionActive(),
    navigationError: navigationBounds && !viewTransition
      ? constrainedNavigationTarget().distanceTo(controls.target) : 0,
    zoomLimits: [controls.minZoom, controls.maxZoom],
    cameraTarget: controls.target.toArray(),
    selection: {
      active: selectionState !== null,
      options: { ...selectionOptions },
      zoneId: selectedZoneId,
      objectFades: objectFades.size,
      outline: selectionOutline.snapshot(),
      outlineWidth: outlineMaterial.uniforms.outlineWidth.value,
      selectedMeshes: selectedMeshes.length,
      animatedMaterials: selectedMaterialStates.reduce(
        (count, state) => count + state.materials.filter(
          (entry) => entry.effectUniforms !== null,
        ).length,
        0,
      ),
      excludedWindowMaterials: selectedMaterialStates.reduce(
        (count, state) => count + state.materials.filter(
          (entry) => entry.effectUniforms === null,
        ).length,
        0,
      ),
    },
    shadow: keyLight?.shadow
      ? {
          dynamicFit: lightingTuning.shadows?.dynamicFit === true,
          camera: [
            keyLight.shadow.camera.left,
            keyLight.shadow.camera.right,
            keyLight.shadow.camera.top,
            keyLight.shadow.camera.bottom,
            keyLight.shadow.camera.near,
            keyLight.shadow.camera.far,
          ],
        }
      : null,
    keyLight: keyLight
      ? {
          color: keyLight.color.getHexString(),
          intensity: keyLight.intensity,
          castShadow: keyLight.castShadow,
          position: keyLight.position.toArray(),
        }
      : null,
    ambientIntensity: ambientLight?.intensity ?? null,
    hemisphereIntensity: hemisphereLight?.intensity ?? null,
    fillLight: fillLight
      ? {
          color: fillLight.color.getHexString(),
          intensity: fillLight.intensity,
          position: fillLight.position.toArray(),
        }
      : null,
    zones,
    materials,
  };
}

function debugAtmosphereDataUrl() {
  return atmosphereCanvas?.toDataURL('image/png') ?? null;
}

function normalizedGraphicsProfile(value) {
  return 'basic';
}

function ensureGraphicsProfile(value) {
  const profile = normalizedGraphicsProfile(value);
  if (profile === savedGraphicsProfile) return false;
  try {
    if (profile === 'auto') {
      localStorage.removeItem(graphicsProfileStorageKey);
    } else {
      localStorage.setItem(graphicsProfileStorageKey, profile);
    }
  } catch (_) {
    return false;
  }
  location.reload();
  return true;
}

function setGraphicsProfile(value) {
  ensureGraphicsProfile(value);
}

function applyTexturePreview() {
  const visited = new Set();
  model?.traverse((object) => {
    if (!object.isMesh) return;
    for (const material of [].concat(object.material)) {
      if (!material || visited.has(material)) continue;
      visited.add(material);
      let original = materialTextureStates.get(material);
      if (!original) {
        original = { normalScale: material.normalScale?.clone() };
        for (const key of ['map', 'normalMap', 'roughnessMap', 'metalnessMap', 'aoMap']) {
          original[key] = material[key];
        }
        materialTextureStates.set(material, original);
      }
      for (const key of ['map', 'normalMap', 'roughnessMap', 'metalnessMap', 'aoMap']) {
        if (original[key] !== undefined) material[key] = texturesEnabled ? original[key] : null;
      }
      if (original.normalScale) {
        material.normalScale.copy(original.normalScale).multiplyScalar(nightLook.textureDetail ?? 1);
      }
      material.needsUpdate = true;
    }
  });
}

function configureNightLook(settings = {}) {
  const limits = {
    exposure: [0.25, 1.2], moonlight: [0, 6], ambient: [0, 0.2],
    hemisphere: [0, 0.6], fill: [0, 1], windows: [0, 4],
    reflections: [0, 3], wetness: [0, 1], textureDetail: [0, 2],
    grassBrightness: [0, 0.3], floorRoughness: [0.07, 1],
    floorReflection: [0, 4], moonShafts: [0, 2],
    temperature: [-1, 1],
  };
  for (const [key, [min, max]] of Object.entries(limits)) {
    if (Number.isFinite(settings[key])) nightLook[key] = THREE.MathUtils.clamp(settings[key], min, max);
  }
  if (typeof settings.textures === 'boolean') texturesEnabled = settings.textures;
  applyTexturePreview();
  applyDaylightProfile();
  requestRender();
}

function visualTestSettings() {
  const morningLook = effectiveMorningLook();
  const profile = daylightProfileWithPreview(daylightProfile());
  return {
    ...nightLook, textures: texturesEnabled,
    ...(isDayCustomization() ? {
      exposure: profile.exposure, key: profile.key.intensity,
      ambient: profile.ambient.intensity, hemisphere: profile.hemisphere.intensity,
      fill: profile.fill.intensity, rays: profile.rays.opacity,
      contrast: profile.grading.contrast, saturation: profile.grading.saturation,
      shadowRadius: profile.shadowRadius, textures: morningLook.textures !== false,
      sunHighlights: morningLook.sunHighlights ?? 1,
      foliageStrength: morningLook.foliageStrength ?? 0,
      textureDetail: morningLook.textureDetail ?? 1.65,
      reflections: morningLook.reflections ?? rendererTuning.dawnSurface?.environmentScale ?? 8,
      floorRoughness: morningLook.floorRoughness ?? rendererTuning.dawnSurface?.pavement?.roughness ?? 0.27,
      wetness: morningLook.wetness ?? rendererTuning.dawnSurface?.pavement?.clearcoat ?? 0.65,
    } : {}),
    morning: isMorning(),
    midday: isMidday(),
    sunset: isSunset(),
    temperature: activeColorTemperature(),
    resting: rendererTuning.maxPixelRatio,
    moving: rendererTuning.interactionPixelRatio,
    shadows: renderer.shadowMap.enabled ? keyLight?.shadow.mapSize.x ?? 0 : 0,
    bloom: postProcessingTuning.bloom?.enabled !== false,
    bloomStrength: postProcessingTuning.bloom?.strength ?? 0.25,
    toneMapping: rendererTuning.toneMapping,
    minutes: localTimeMinutes(),
  };
}

function resetNightLook() {
  Object.assign(nightLook, defaultNightLook);
  texturesEnabled = defaultNightLook.textures !== false;
  configureNightLook();
  setToneMapping(defaultToneMapping);
  configureBloom(defaultBloom);
  return visualTestSettings();
}

function configureSky(settings = {}, phase = isMorning() ? 'morning' : isSunset() ? 'sunset' : 'midday') {
    // Preview de calibracao: gera de novo apenas quando os ajustes mudam,
    // nunca nos gestos da camera. Libera a textura anterior antes de trocar.
    const sunset = phase === 'sunset';
    const morning = phase === 'morning';
    const sky = rendererTuning[`${phase}Sky`] ??= {};
    for (const key of ['zenithColor', 'horizonColor']) {
      if (settings[key] !== undefined) sky[key] = cssColor(settings[key], sky[key]);
    }
    for (const [key, min, max] of [
      ['resolution', 512, 1536], ['cloudCount', 0, 144],
      ['cloudWidthMin', 0.015, 0.20], ['cloudWidthMax', 0.015, 0.20],
      ['cloudHeightMin', 0.08, 0.50], ['cloudHeightMax', 0.08, 0.50],
      ['horizonHaze', 1, 8],
      ['patchStrength', 0, 2], ['cloudOpacity', 0, 1.5],
      ['brightness', 0.3, 1.8], ['glowStrength', 0, 1.5], ['glowSize', 0.05, 0.4],
      ['sunCoreStrength', 0, 4],
    ]) {
      if (Number.isFinite(settings[key])) {
        const value = THREE.MathUtils.clamp(settings[key], min, max);
        sky[key] = key === 'resolution' || key === 'cloudCount' ? Math.round(value) : value;
      }
    }
    if (Number.isFinite(settings.seed)) sky.seed = settings.seed >>> 0;
    const mesh = morning ? morningSkyMesh : sunset ? sunsetSkyMesh : middaySkyMesh;
    if (mesh) {
      scene.remove(mesh);
      mesh.material.map.dispose();
      mesh.material.dispose();
      mesh.geometry.dispose();
      if (morning) morningSkyMesh = null;
      else if (sunset) sunsetSkyMesh = null;
      else middaySkyMesh = null;
    }
    installMiddaySky({ sunset, morning });
    updateAtmosphericBackground(activeDaylightProfile, { force: true });
    updateNightSky();
    requestRender();
}

function skySettings() {
  const sunset = isSunset();
  const morning = isMorning();
  return {
    brightness: 1, patchStrength: 1, cloudOpacity: 1, glowStrength: 1, glowSize: 0.22, sunCoreStrength: 0,
    ...rendererTuning[morning ? 'morningSky' : sunset ? 'sunsetSky' : 'middaySky'],
    morning, sunset, supported: morning || sunset || isMidday(), minutes: localTimeMinutes(),
  };
}

window.whereIfMap = {
  setEventMarkers,
  navigateToMapLocation,
  cancelEventNavigation(){mapEventNavigationRequest++;},
  eventMarkersSnapshot:()=>eventMarkers.snapshot(),
  skyPixelSamples() {
    const mesh = isMorning() ? morningSkyMesh : isSunset() ? sunsetSkyMesh : middaySkyMesh;
    if (!mesh) return null;
    const canvas = mesh.material.map.image;
    const context = canvas.getContext('2d');
    const direction = new THREE.Vector3().fromArray(skySettings().sunDirection ?? [-0.78, 0.17, 0.62]);
    const sunX = ((Math.atan2(direction.z, -direction.x) / (Math.PI * 2)) + 1) % 1;
    const sample = (offset, y) => Array.from(context.getImageData(
      Math.floor(((sunX + offset + 1) % 1) * canvas.width), Math.floor(y * canvas.height), 1, 1).data);
    return { solar: sample(0, 0.52), solarLower: sample(0, 0.60), opposite: sample(0.5, 0.52) };
  },
  skySettings,
  configureSky(settings = {}) {
    if (!isDayCustomization()) return;
    configureSky(settings);
  },
  resetSky() {
    if (!isDayCustomization()) return;
    const phase = isMorning() ? 'morning' : isSunset() ? 'sunset' : 'midday';
    rendererTuning[`${phase}Sky`] = { ...savedSkySettings[phase] };
    configureSky({}, phase);
  },
  configureMiddaySky(settings = {}) {
    configureSky(settings, 'midday');
  },
  configureSunsetLook(settings = {}) {
    Object.assign(sunsetLook, settings);
    applyDaylightProfile();
    requestRender();
  },
  resetSunsetLook() {
    sunsetLook = { ...defaultSunsetLook };
    applyDaylightProfile();
    requestRender();
  },
  configureMiddayLook(settings = {}) {
    Object.assign(middayLook, settings);
    applyDaylightProfile();
    requestRender();
  },
  resetMiddayLook() {
    middayLook = { ...defaultMiddayLook };
    applyDaylightProfile();
    requestRender();
  },
  configureMorningLook(settings = {}) {
    Object.assign(morningLook, settings);
    applyDaylightProfile();
    requestRender();
  },
  resetMorningLook() {
    morningLook = {};
    applyDaylightProfile();
    requestRender();
  },
  configureNightLook,
  visualTestSettings,
  resetNightLook,
  beginExternalRotation,
  clearDaylightPreview,
  clearPreviewTime,
  configure,
  disposeViewer,
  setVisible,
  setRawMode,
  setInteriorFloor,
  interiorSnapshot() {
    return { floorId: interiors?.current?.id ?? null, busy: interiorLoading,
      exportedWindowPresetsVisible: exportedWindowPresetObjects.some(node=>node.visible),
      spaceColors: interiors?.current?.spaces.map(space=>{
        const colors=new Set();space.node.traverse(node=>{
          if(!node.isMesh||node.userData.interiorSpace?.marker===node)return;
          for(const material of Array.isArray(node.material)?node.material:[node.material])if(material.color)colors.add(material.color.getHexString());
        });return {nodeName:space.nodeName,colors:[...colors]};
      })??[],
      activeFloorIds: interiors?.activeFloors.map(floor => floor.id) ?? [],
      activeFloorBounds: interiors?.activeFloors.map(floor => ({
        min: floor.bounds.min.toArray(), max: floor.bounds.max.toArray(),
      })) ?? [],
      campusVisible: model?.visible ?? false,
      exteriorVisible: zoneNodes.get(config?.zones.find(
        zone => zone.id === 'bloco-didatico')?.nodeName)?.visible ?? false,
      windowPresetsVisible: [...windowPresetGroups.values()].some(group =>
        group.some(preset => preset.node.visible)),
      distance: camera.position.distanceTo(controls.target),
      distanceLimits: [baseMinDistance, baseMaxDistance],
      visibleSpaces: interiors?.current?.spaces.map(s => {
        const center = s.bounds.getCenter(new THREE.Vector3());
        center.y = s.bounds.min.y + 0.15;
        const point = center.project(camera);
        return { nodeName: s.nodeName, bounds: [s.bounds.min.toArray(), s.bounds.max.toArray()], x: (point.x + 1) * renderer.domElement.clientWidth / 2,
          y: (1 - point.y) * renderer.domElement.clientHeight / 2 };
      }) ?? [],
      floors: [...(interiors?.floors.values() ?? [])].map(f => ({ id: f.id,
        spaces: f.spaces.map(s => s.nodeName), gpuReady: f.gpuReady })),
      selectedSpace: interiors?.selected?.nodeName ?? null };
  },
  setMapTestFeature,
  setMapTestFeatures,
  setMapQuality,
  setInteriorEventSize,
  setEventMarkerAutoLayout,
  setMapPerformanceMode,
  setSelectionOptions,
  setInterfaceBlur,
  setNavBlur,
  mapTestSnapshot: () => ({ features: { ...testFeatures }, busy: featureBusy,
    gesturePointers: cameraPointerIds.size, multiTouchGesture,
    performanceModeEnabled,
    selectionOptions: { ...selectionOptions },
    interfaceBlurEnabled,
    navBlurEnabled,
    fps: document.getElementById('map-fps-counter')?.textContent }),
  diagnosticsSnapshot,
  beginModelTransfer,
  appendModelChunk,
  configureAtmosphere,
  configureGroundRays,
  focusZone,
  debugAtmosphereDataUrl,
  debugSnapshot,
  endExternalRotation,
  ensureGraphicsProfile,
  configureBloom,
  refreshMaterialFinish,
  resetBearing,
  resetCamera,
  setAtmosphereResolution,
  setGraphicsProfile,
  setInteractionRenderScale,
  setRestingRenderScale,
  setShadowMapSize,
  setToneMapping,
  setDaylightPreview,
  setLocalTimeMinutes,
  setPreviewCamera,
  setPreviewTimeMinutes,
  setMapViewMode,
  rotateCameraBy,
  selectZone,
};
if (window.__whereIfPendingConfig) {
  configure(window.__whereIfPendingConfig);
}

renderer.domElement.addEventListener(
  'pointerdown',
  (event) => {
    if (viewTransition) return;
    if(pendingMarkerPointer&&pendingMarkerPointer.event.pointerId!==event.pointerId)forwardPendingMarkerPointer();
    cameraPointerIds.add(event.pointerId);
    eventMarkers.setCameraGestureActive(true);
    if (!event.isPrimary || cameraPointerIds.size > 1) {
      multiTouchGesture = true;
      pointerStart = null;
      beginManualCameraGesture();
      return;
    }
    multiTouchGesture = false;
    // Dismiss the open event fan now, but remember it for this gesture's up:
    // the document listener otherwise closes it before selection can check.
    const dismissedEventStack = eventMarkers.dismissOutsideTap(event.mapMarkerTarget??event.target);
    // Pick the position the user actually touched, even between rapid room
    // changes. No interior camera flight may move the target under that tap.
    if (interiors?.current) {
      beginManualCameraGesture();
    }
    pointerStart = {
      pointerId: event.pointerId,
      x: event.clientX,
      y: event.clientY,
      at: performance.now(),
      dismissedEventStack,
      maxDistance: 0,
      cameraPosition: camera.position.clone(),
      cameraTarget: controls.target.clone(),
    };
  },
  { capture: true, signal: viewerEvents.signal },
);

renderer.domElement.addEventListener(
  'pointermove',
  (event) => {
    if (!pointerStart || event.pointerId !== pointerStart.pointerId) return;
    pointerStart.maxDistance = Math.max(
      pointerStart.maxDistance,
      Math.hypot(
        event.clientX - pointerStart.x,
        event.clientY - pointerStart.y,
      ),
    );
    if (pointerStart.maxDistance > (selectionTuning.tapTolerance ?? 18)) {
      beginManualCameraGesture();
    }
  },
  { capture: true, signal: viewerEvents.signal },
);

renderer.domElement.addEventListener(
  'pointerup',
  (event) => {
    cameraPointerIds.delete(event.pointerId);
    const gestureEnded = cameraPointerIds.size === 0;
    const start = pointerStart;
    if (!start || event.pointerId !== start.pointerId) {
      if(gestureEnded){multiTouchGesture=false;eventMarkers.setCameraGestureActive(false);}
      return;
    }
    pointerStart = null;

    const distance = Math.max(
      start.maxDistance,
      Math.hypot(event.clientX - start.x, event.clientY - start.y),
    );
    const elapsed = performance.now() - start.at;
    if (
      !multiTouchGesture && gestureEnded &&
      distance <= (selectionTuning.tapTolerance ?? 18) &&
      elapsed <= 600
    ) {
      // OrbitControls emits `end` after this capture listener. Ignore that
      // matching event so it cannot schedule another camera correction.
      suppressNextControlsEnd = true;
      queueMicrotask(() => {
        suppressNextControlsEnd = false;
      });
      const shouldPreserveCamera = start.dismissedEventStack ||
        selectAt(event.clientX, event.clientY);
      if (shouldPreserveCamera) {
        preserveCameraAfterTap({
          position: start.cameraPosition,
          target: start.cameraTarget,
        });
      }
    }
    if(gestureEnded){multiTouchGesture=false;eventMarkers.setCameraGestureActive(false);}
  },
  { capture: true, signal: viewerEvents.signal },
);

renderer.domElement.addEventListener(
  'pointercancel',
  (event) => {
    cameraPointerIds.delete(event.pointerId);
    pointerStart = null;
    if(cameraPointerIds.size===0){multiTouchGesture=false;eventMarkers.setCameraGestureActive(false);}
  },
  { capture: true, signal: viewerEvents.signal },
);

function resize() {
  if (viewerDisposed) return;
  const width = Math.max(1, document.documentElement.clientWidth);
  const height = Math.max(1, document.documentElement.clientHeight);
  const ratio = budgetPixelRatio();
  rendererTuning.maxPixelRatio = ratio;
  rendererTuning.interactionPixelRatio = ratio;
  if (Math.abs(renderer.getPixelRatio() - ratio) > 0.01) renderer.setPixelRatio(ratio);
  renderer.setSize(width, height, false);
  effectComposer?.setPixelRatio(renderer.getPixelRatio());
  effectComposer?.setSize(width, height);
  mobileBloom?.setSize(width * renderer.getPixelRatio(), height * renderer.getPixelRatio());
  mapAntialias?.resize();
  resizeAtmosphericBackground(width, height);
  updateNightSkyRenderScale();
  if (viewTransition) { requestRender(); return; }
  camera.aspect = width / height;
  if (camera.isOrthographicCamera) {
    camera.left = -topViewHalfHeight * camera.aspect;
    camera.right = topViewHalfHeight * camera.aspect;
    camera.top = topViewHalfHeight;
    camera.bottom = -topViewHalfHeight;
  }
  updatePerspectiveProjection(camera);
  requestRender();
}

function useInteractionResolution(active) {
  const ratioLimit = budgetPixelRatio();
  const ratio = THREE.MathUtils.clamp(
    Number(ratioLimit) || window.devicePixelRatio || 1,
    0.5,
    4,
  );
  if (Math.abs(renderer.getPixelRatio() - ratio) < 0.01) return;
  renderer.setPixelRatio(ratio);
  resize();
}

function cameraTransitionActive() {
  return viewTransition !== null || resettingCamera !== null ||
    cameraFocus !== null ||
    navigationSpring !== null;
}

function cancelRestingResolutionRestore() {
  if (resolutionRestoreTimer === null) return;
  clearTimeout(resolutionRestoreTimer);
  resolutionRestoreTimer = null;
}

function beginCameraTransitionResolution() {
  cancelRestingResolutionRestore();
  useInteractionResolution(true);
}

function scheduleRestingResolutionRestore(delay = 100) {
  cancelRestingResolutionRestore();
  if (controlsInteractionActive || cameraTransitionActive()) return;
  if (Math.abs(renderer.getPixelRatio() - budgetPixelRatio()) < 0.01) return;
  resolutionRestoreTimer = setTimeout(() => {
    resolutionRestoreTimer = null;
    if (controlsInteractionActive || cameraTransitionActive()) return;
    useInteractionResolution(false);
    requestRender();
  }, delay);
}

function finishCameraTransition(position, target) {
  camera.position.copy(position);
  controls.target.copy(target);
  camera.lookAt(target);
  clearControlsMomentum();
  sendCameraState({ force: true });
}

function sendPerformanceSample(now, { force = false } = {}) {
  if (!controlsInteractionActive && !force) return;
  const elapsed = now - lastPerformanceReportAt;
  if (elapsed <= 0 || (!force && elapsed < 500)) return;
  const renderedFrames = interactionFrameCount - lastPerformanceFrameCount;
  if (renderedFrames <= 0) return;
  send('performance', {
    fps: renderedFrames * 1000 / elapsed,
    graphicsProfile,
    graphicsProfilePreference: savedGraphicsProfile,
    pixelRatio: renderer.getPixelRatio(),
    restingPixelRatio: rendererTuning.maxPixelRatio,
    interactionPixelRatio: rendererTuning.interactionPixelRatio,
    shadowMapSize: renderer.shadowMap.enabled
      ? keyLight?.shadow?.mapSize?.x ?? 0
      : 0,
    atmosphereResolution: lightingTuning.atmosphere?.enabled === false
      ? 0
      : lightingTuning.atmosphere?.resolution ?? 0,
    drawCalls: renderer.info.render.calls,
    triangles: renderer.info.render.triangles,
  });
  lastPerformanceReportAt = now;
  lastPerformanceFrameCount = interactionFrameCount;
}

function setRestingRenderScale(value) {
  const scale = THREE.MathUtils.clamp(Number(value) || 1, 0.5, 4);
  rendererTuning.maxPixelRatio = scale;
  if (!controlsInteractionActive && !cameraTransitionActive()) {
    useInteractionResolution(false);
  }
}

function setMapQuality(settings) {
  const run = qualityApplyQueue.catch(() => {}).then(() => applyMapQuality(settings));
  qualityApplyQueue = run;
  return run;
}

function setInteriorEventSize(percent) {
  if (viewerDisposed) return interiorEventSize;
  interiorEventSize = eventMarkers.setInteriorSize(percent);
  featurePanel?.updateInteriorEventSize(interiorEventSize);
  persistRenderPreferences();
  // Only DOM layout changed: do not redraw the 3D campus for slider input.
  eventMarkers.update(camera, interiors?.current);
  return interiorEventSize;
}

function setEventMarkerAutoLayout(enabled) {
  if (viewerDisposed) return eventMarkerAutoLayout;
  eventMarkerAutoLayout = eventMarkers.setAutoLayout(enabled);
  featurePanel?.updateEventMarkerAutoLayout(eventMarkerAutoLayout);
  persistRenderPreferences();
  return eventMarkerAutoLayout;
}

function renderSettingsSnapshot() {
  return { features: { ...testFeatures }, quality: { ...mapQuality },
    selectionOptions: { ...selectionOptions }, interfaceBlurEnabled, navBlurEnabled };
}

function renderPresetForMode(enabled) {
  const normal={features:normalizedMapFeatures(rendererTuning.approvedMapFeatures??{}),
    quality:normalizedMapQuality(rendererTuning.approvedMapQuality),
    selectionOptions:{...optimizedSelectionOptions},
    interfaceBlurEnabled:rendererTuning.approvedInterfaceBlur??false,
    navBlurEnabled:rendererTuning.approvedNavBlur??false};
  if(!enabled) {
    try {
      const saved=readNormalRenderPreferences(normal);
      if(typeof saved.interfaceBlurEnabled!=='boolean'||typeof saved.navBlurEnabled!=='boolean')return normal;
      return {...saved,features:normalizedMapFeatures(saved.features),quality:normalizedMapQuality(saved.quality),
        selectionOptions:normalizedSelectionOptions(saved.selectionOptions)};
    }catch{return normal;}
  }
  const current=renderSettingsSnapshot();
  if(!performanceModeEnabled&&!matchesPerformancePreset(current))saveNormalRenderPreferences(current);
  return performanceMapPreset;
}

function setMapPerformanceMode(enabled) {
  if(typeof enabled!=='boolean')return Promise.reject(new Error('Modo desempenho inválido.'));
  const run=performanceModeQueue.catch(()=>{}).then(async()=>{
    while(!viewerDisposed&&(modelLoading||interiorLoading))await yieldLoadingWork();
    if(viewerDisposed||performanceModeEnabled===enabled)return performanceModeEnabled;
    const preset=renderPresetForMode(enabled);
    performanceModeApplying=true;
    try {
      await setMapTestFeatures(preset.features);
      setSelectionOptions(preset.selectionOptions);
      await setMapQuality(preset.quality);
      setInterfaceBlur(preset.interfaceBlurEnabled);setNavBlur(preset.navBlurEnabled);
      performanceModeEnabled=enabled;
      persistRenderPreferences();
      send('performanceMode',{enabled,source:'request'});
      return enabled;
    }finally{performanceModeApplying=false;}
  });
  performanceModeQueue=run;
  return run;
}

function persistRenderPreferences() {
  if (!featurePanelEnabled) return;
  const settings=renderSettingsSnapshot();
  if(performanceModeEnabled&&!performanceModeApplying&&!matchesPerformancePreset(settings)) {
    performanceModeEnabled=false;
    send('performanceMode',{enabled:false,source:'customization'});
  }
  saveRenderPreferences({ ...settings, performanceModeEnabled, interiorEventSize, eventMarkerAutoLayout });
}

async function applyMapQuality(settings) {
  if (viewerDisposed) return { ...mapQuality };
  const next = normalizedMapQuality(settings, mapQuality);
  if (next.antialias !== mapQuality.antialias) {
    if (next.antialias === 'off') { mapAntialias?.dispose(); mapAntialias = null; }
    else {
      mapAntialias ??= createMapAntialias(renderer, next.antialias);
      mapAntialias.setLevel(next.antialias);
      await mapAntialias.warmup();
      if (viewerDisposed) return { ...mapQuality };
    }
  }
  mapQuality = next;
  persistRenderPreferences();
  resize();
  featurePanel?.updateQuality(mapQuality);
  requestRender();
  return { ...mapQuality };
}

function setInteractionRenderScale(value) {
  const scale = THREE.MathUtils.clamp(Number(value) || 1, 0.5, 4);
  rendererTuning.interactionPixelRatio = scale;
  if (controlsInteractionActive || cameraTransitionActive()) {
    useInteractionResolution(true);
  }
}

function setShadowMapSize(value) {
  const requestedSize = Math.max(0, Math.round(Number(value) || 0));
  if (!keyLight || requestedSize === 0) {
    renderer.shadowMap.enabled = false;
    if (keyLight) keyLight.castShadow = false;
    requestRender();
    return;
  }
  renderer.shadowMap.enabled = true;
  keyLight.castShadow = true;
  const size = Math.min(requestedSize, renderer.capabilities.maxTextureSize);
  lightingTuning.shadows ??= {};
  lightingTuning.shadows.mapSize = size;
  keyLight.shadow.mapSize.setScalar(size);
  refreshDirectionalShadow({ recreate: true });
  updateDirectionalShadowForView({ force: true });
  requestRender();
}

function setAtmosphereResolution(value) {
  const resolution = THREE.MathUtils.clamp(
    Math.round(Number(value) || 420),
    160,
    2048,
  );
  lightingTuning.atmosphere ??= {};
  lightingTuning.atmosphere.resolution = resolution;
  resizeAtmosphericBackground(
    Math.max(1, document.documentElement.clientWidth),
    Math.max(1, document.documentElement.clientHeight),
  );
  updateAtmosphericBackground(activeDaylightProfile, { force: true });
  requestRender();
}

function requestRender() {
  if (viewerDisposed || viewerSuspended || document.hidden) return;
  if (animationFrame !== null) return;
  animationFrame = requestAnimationFrame(renderFrame);
}

function renderFrame(time) {
  try {
    renderMapFrame(time);
  } catch (error) {
    setVisible(false);
    send('error', { message: error instanceof Error ? error.message : String(error) });
  }
}

function renderMapFrame(time) {
  animationFrame = null;
  if (viewerDisposed || viewerSuspended || document.hidden || (modelLoading && !modelGpuReady)) return;
  if (interiorLoading && ![...objectFades].some(fade =>
      Number.isFinite(fade.startedAt))) return;
  const diagnosticsStartedAt = performance.now();
  let keepAnimating = false;
  let cameraIsTransitioning = false;

  if (viewTransition) {
    cameraIsTransitioning = true;
    const transition = viewTransition;
    const progress = THREE.MathUtils.clamp((time - transition.startedAt) / transition.duration, 0, 1);
    const eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10);
    camera.position.lerpVectors(transition.fromPosition, transition.toPosition, eased);
    camera.quaternion.slerpQuaternions(transition.fromQuaternion, transition.toQuaternion, eased);
    controls.target.lerpVectors(transition.fromTarget, transition.toTarget, eased);
    for (let i = 0; i < 16; i++) camera.projectionMatrix.elements[i] =
      THREE.MathUtils.lerp(transition.fromProjection.elements[i], transition.toProjection.elements[i], eased);
    camera.projectionMatrixInverse.copy(camera.projectionMatrix).invert();
    if (progress >= 1) {
      viewTransition = null;
      activateMapCamera(transition.mode);
      camera.zoom = transition.zoom;
      camera.updateProjectionMatrix();
      finishCameraTransition(transition.toPosition, transition.toTarget);
      startNavigationReturn();
    } else keepAnimating = true;
  } else if (resettingCamera) {
    cameraIsTransitioning = true;
    const elapsed = (time - resettingCamera.startedAt) / resettingCamera.duration;
    const progress = Math.min(1, Math.max(0, elapsed));
    const eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10);
    camera.position.lerpVectors(
      resettingCamera.fromPosition,
      initialCameraPosition,
      eased,
    );
    controls.target.lerpVectors(
      resettingCamera.fromTarget,
      initialTarget,
      eased,
    );
    if (progress >= 1) {
      finishCameraTransition(initialCameraPosition, initialTarget);
      resettingCamera = null;
      applyNavigationConstraint();
    } else {
      keepAnimating = true;
    }
  } else if (cameraFocus) {
    cameraIsTransitioning = true;
    const progress = THREE.MathUtils.clamp(
      (time - cameraFocus.startedAt) / cameraFocus.duration,
      0,
      1,
    );
    const eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10);
    camera.position.lerpVectors(
      cameraFocus.fromPosition,
      cameraFocus.toPosition,
      eased,
    );
    controls.target.lerpVectors(
      cameraFocus.fromTarget,
      cameraFocus.toTarget,
      eased,
    );
    applyNavigationConstraint();
    applyDistanceConstraint();
    if (progress >= 1) {
      const completedFocus = cameraFocus;
      finishCameraTransition(
        completedFocus.toPosition,
        completedFocus.toTarget,
      );
      controls.minDistance = completedFocus.finalMinDistance;
      controls.maxDistance = completedFocus.finalMaxDistance;
      cameraFocus = null;
      navigationConstraintSuspended = false;
      applyNavigationConstraint();
      applyDistanceConstraint();
    } else {
      keepAnimating = true;
    }
  } else if (navigationSpring) {
    cameraIsTransitioning = true;
    const progress = THREE.MathUtils.clamp(
      (time - navigationSpring.startedAt) / navigationSpring.duration,
      0,
      1,
    );
    const shifted = progress - 1;
    const bounce = navigationSpring.bounce ?? 0;
    const eased = 1 + (bounce + 1) * shifted * shifted * shifted +
      bounce * shifted * shifted;
    if (navigationSpring.fromZoom !== undefined) {
      camera.zoom = THREE.MathUtils.lerp(navigationSpring.fromZoom, navigationSpring.toZoom, eased);
      camera.updateProjectionMatrix();
    }
    camera.position.lerpVectors(
      navigationSpring.fromPosition,
      navigationSpring.toPosition,
      eased,
    );
    controls.target.lerpVectors(
      navigationSpring.fromTarget,
      navigationSpring.toTarget,
      eased,
    );
    if (progress >= 1) {
      const completedSpring = navigationSpring;
      if (completedSpring.toZoom !== undefined) {
        camera.zoom = completedSpring.toZoom;
        camera.updateProjectionMatrix();
        const limits = topViewZoomLimits();
        controls.minZoom = limits.min;
        controls.maxZoom = limits.max;
      }
      finishCameraTransition(
        completedSpring.toPosition,
        completedSpring.toTarget,
      );
      navigationSpring = null;
      applyNavigationConstraint();
      applyDistanceConstraint();
    } else {
      keepAnimating = true;
    }
  }

  const selectionAnimating = updateSelectionEffects(time);
  keepAnimating = updateObjectFades(time) || selectionAnimating || keepAnimating;

  if (viewTransition) {
    camera.updateMatrixWorld();
  } else if (cameraIsTransitioning) {
    camera.lookAt(controls.target);
  } else {
    controls.update();
  }
  if (!cameraIsTransitioning) {
    applyNavigationConstraint({
      elastic: controlsInteractionActive,
    });
    applyDistanceConstraint({ elastic: controlsInteractionActive });
  }
  if (!geometryOnly && !rawModeEnabled && !interiors?.current) updateAtmosphericBackground(activeDaylightProfile);
  if (nightSkyPoints) nightSkyPoints.position.copy(camera.position);
  if (middaySkyMesh) middaySkyMesh.position.copy(camera.position);
  if (sunsetSkyMesh) sunsetSkyMesh.position.copy(camera.position);
  if (morningSkyMesh) morningSkyMesh.position.copy(camera.position);
  if (!geometryOnly && !rawModeEnabled && !interiors?.current) {
    updateDaylightBloom(activeDaylightProfile);
    updateDirectSunExposure(activeDaylightProfile);
    if (!cameraIsTransitioning) {
      updateDirectionalShadowForView();
    } else if (!keepAnimating) {
      updateDirectionalShadowForView({ force: true });
    }
  }
  if (featurePanelEnabled && testFeatures.bloom) {
    updateDaylightBloom(activeDaylightProfile);
    if (bloomPass) bloomPass.enabled = true;
  }
  const measureGpu = diagnosticsEnabled && model && diagnosticsGpuExtension && !diagnosticsGpuQuery;
  const gl = renderer.getContext();
  if (measureGpu) {
    diagnosticsGpuQuery = gl.createQuery();
    gl.beginQuery(diagnosticsGpuExtension.TIME_ELAPSED_EXT, diagnosticsGpuQuery);
  }
  if (diagnosticsEnabled) renderer.info.reset();
  try {
    renderSceneWithSelection();
    eventMarkers.update(camera,interiors?.current,{moving:cameraIsTransitioning||controlsInteractionActive});
    fpsCounter.recordFrame();
  } finally {
    if (measureGpu) gl.endQuery(diagnosticsGpuExtension.TIME_ELAPSED_EXT);
  }
  if (diagnosticsEnabled) diagnosticsRenderMaxMs = Math.max(
    diagnosticsRenderMaxMs, performance.now() - diagnosticsStartedAt);
  // A slow CPU submission does not establish a GPU fill-rate bottleneck.
  // Reducing DPR on that signal made the image blurry without fixing stalls.
  if (controlsInteractionActive) {
    interactionFrameCount += 1;
    sendPerformanceSample(time);
  }
  sendCameraState();

  if (keepAnimating) {
    requestRender();
  } else if (!controlsInteractionActive && !cameraTransitionActive()) {
    scheduleRestingResolutionRestore();
  }
}

function updateSelectionEffects(time) {
  if (!selectionState) return false;
  if (selectionState.effectsSettled && selectionState.leavingAt === null) return false;
  const entranceDuration = selectionTuning.entranceDuration ?? 360;
  const exitDuration = selectionTuning.exitDuration ?? 190;
  const targetOpacity = selectionTuning.restingOpacity ?? 0.92;

  if (selectionState.leavingAt !== null) {
    const progress = THREE.MathUtils.clamp(
      (time - selectionState.leavingAt) / exitDuration,
      0,
      1,
    );
    const remaining = 1 - progress * progress;
    outlineMaterial.uniforms.outlineOpacity.value = targetOpacity * remaining;
    updateSelectedMaterialGradient(0, 0, (selectionState.restingLight ?? 0) * remaining);
    if (progress >= 1) {
      releaseSelectedMeshes();
      selectionState = null;
      return false;
    }
    return true;
  }

  const animated = selectionOptions.pulse ||
    (selectionOptions.outline && selectionOptions.outlineAnimation);
  const progress = animated ? THREE.MathUtils.clamp(
    (time - selectionState.startedAt) / entranceDuration,
    0,
    1,
  ) : 1;
  const eased = 1 - Math.pow(1 - progress, 3);
  const pulse = Math.sin(progress * Math.PI);
  const colorPhase = 0.5 - 0.5 * Math.cos(progress * Math.PI * 2);
  selectionState.effectColor.lerpColors(
    selectionState.accentColor,
    selectionState.flashColor,
    colorPhase,
  );
  updateSelectedMaterialGradient(
    selectionOptions.pulse ? (selectionTuning.flashIntensity ?? 0.48) * Math.pow(pulse, 0.82) : 0,
    progress * Math.PI * 2 * (selectionTuning.flashCycles ?? 1.15),
    (selectionState.restingLight ?? 0) * eased,
  );
  const outlineEase = selectionOptions.outlineAnimation ? eased : 1;
  outlineMaterial.uniforms.outlineOpacity.value = THREE.MathUtils.clamp(
    targetOpacity * outlineEase + (selectionOptions.outlineAnimation ? pulse * 0.12 : 0),
    0,
    1,
  );
  outlineMaterial.uniforms.outlineWidth.value = THREE.MathUtils.lerp(
    selectionState.room ? 4.5 : selectionTuning.initialOutlineWidth ?? 7,
    selectionState.room ? 2.8 : selectionTuning.outlineWidth ?? 3.5,
    outlineEase,
  );
  outlineMaterial.uniforms.outlineColor.value.lerpColors(
    selectionState.startColor,
    selectionOptions.outlineAnimation ? selectionState.effectColor : selectionState.accentColor,
    outlineEase,
  );
  if (progress >= 1) {
    selectionState.effectsSettled = true;
    // Exterior blocks need the gradient only during the pulse, not forever.
    // Rooms retain their steady colored light, with the pulse branch disabled.
    if (!selectionState.room || !selectionOptions.roomGlow) releaseSelectedMaterials();
  }
  return progress < 1;
}

function renderSceneWithSelection() {
  const useComposer = effectComposer &&
    (featurePanelEnabled ? testFeatures.bloom || testFeatures.grading
      : bloomPass?.enabled || isDayCustomization() || activeColorTemperature() !== 0);
  interiors?.setExposure(useComposer ? renderer.toneMappingExposure : 1);
  const originalLayerMask = camera.layers.mask;
  camera.layers.set(0);
  renderer.setRenderTarget(null);
  renderer.autoClear = true;
  if (rawModeEnabled && !featurePanelEnabled) {
    const hidden = [];
    for (const child of scene.children) {
      if (child !== model && child.visible && !(basicLightingTest && child.isLight)) {
        hidden.push(child);
        child.visible = false;
      }
    }
    const background = scene.background;
    const fog = scene.fog;
    const shadows = renderer.shadowMap.enabled;
    const toneMapping = renderer.toneMapping;
    const exposure = renderer.toneMappingExposure;
    try {
      scene.background = rawBackground;
      scene.fog = null;
      renderer.shadowMap.enabled = false;
      renderer.toneMapping = THREE.NoToneMapping;
      renderer.toneMappingExposure = 1;
      renderer.render(scene, camera);
    } finally {
      scene.background = background;
      scene.fog = fog;
      renderer.shadowMap.enabled = shadows;
      renderer.toneMapping = toneMapping;
      renderer.toneMappingExposure = exposure;
      for (const child of hidden) child.visible = true;
      camera.layers.mask = originalLayerMask;
    }
    return;
  }
  if (mobileBloom && testFeatures.bloom && mobileBloom.enabled) {
    mobileBloom.render(scene, camera, objectFades.size > 0 ||
      Boolean(selectionState && !selectionState.effectsSettled));
  } else if (useComposer) {
    effectComposer.render();
  } else {
    renderer.render(scene, camera);
  }

  if (model && renderer.shadowMap.autoUpdate) {
    renderer.shadowMap.autoUpdate = false;
  }
  camera.layers.mask = originalLayerMask;
  if (selectionOptions.outline && selectionState && selectedMeshes.length) selectionOutline.draw(camera);
  mapAntialias?.draw();
}

installLighting();
installPostProcessing();
resize();
window.addEventListener('resize', resize, { signal: viewerEvents.signal });
document.addEventListener('visibilitychange', () => setVisible(!document.hidden), { signal: viewerEvents.signal });
renderer.domElement.addEventListener('webglcontextlost', event => {
  event.preventDefault();
  if (viewerDisposed) return;
  setVisible(false);
  send('error', { message: 'A GPU interrompeu o mapa. Abra a aba novamente para tentar recuperar.' });
}, { signal: viewerEvents.signal });
controls.addEventListener('start', () => {
  if (viewTransition) return;
  enableElasticDistanceBounds();
  controlsInteractionActive = true;
  interactionStartedAt = performance.now();
  interactionFrameCount = 0;
  lastPerformanceReportAt = interactionStartedAt;
  lastPerformanceFrameCount = 0;
  shadowUpdateResumeAt = Infinity;
  cancelRestingResolutionRestore();
  useInteractionResolution(true);
  if (!pointerStart || multiTouchGesture) beginManualCameraGesture();
});
controls.addEventListener('change', () => {
  requestRender();
});
controls.addEventListener('end', () => {
  sendPerformanceSample(performance.now(), { force: true });
  controlsInteractionActive = false;
  if (!geometryOnly && !interiors?.current && (graphicsProfile === 'basic' || graphicsProfile === 'balanced')) {
    updateAtmosphericBackground(activeDaylightProfile, { force: true });
  }
  shadowUpdateResumeAt = performance.now() + 140;
  if (suppressNextControlsEnd || cameraTransitionActive()) {
    suppressNextControlsEnd = false;
    sendCameraState({ force: true });
    requestRender();
    return;
  }
  applyNavigationConstraint({ elastic: true });
  applyDistanceConstraint({ elastic: true });
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  startNavigationReturn();
  if (!cameraTransitionActive()) scheduleRestingResolutionRestore(140);
  sendCameraState({ force: true });
});
requestRender();
