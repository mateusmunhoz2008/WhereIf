import * as THREE from './vendor/three.module.min.js';
import { OrbitControls } from './vendor/controls/OrbitControls.js';
import { GLTFLoader } from './vendor/loaders/GLTFLoader.js';
import { EffectComposer } from './vendor/postprocessing/EffectComposer.js';
import { OutputPass } from './vendor/postprocessing/OutputPass.js';
import { RenderPass } from './vendor/postprocessing/RenderPass.js';
import { ShaderPass } from './vendor/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from './vendor/postprocessing/UnrealBloomPass.js';
import { createNightCinema } from './night_cinema.js';

const tuning = window.WHEREIF_MAP_TUNING ?? {};
const rendererTuning = tuning.renderer ?? {};
const cameraTuning = tuning.camera ?? {};
const controlsTuning = tuning.controls ?? {};
const lightingTuning = tuning.lighting ?? {};
const nightSkyTuning = lightingTuning.nightSky ?? {};
const selectionTuning = tuning.selection ?? {};
const postProcessingTuning = rendererTuning.postProcessing ?? {};
const nightLook = lightingTuning.nightLook ?? {};
const defaultNightLook = { ...nightLook };
const defaultToneMapping = rendererTuning.toneMapping ?? 'aces';
const defaultBloom = { ...postProcessingTuning.bloom };
const materialTextureStates = new WeakMap();
let texturesEnabled = true;
let nightCinema = null;

const graphicsProfileStorageKey = 'whereif.map.graphicsProfile';
const savedGraphicsProfile = (() => {
  try {
    const value = localStorage.getItem(graphicsProfileStorageKey);
    return value === 'basic' || value === 'balanced' || value === 'cinematic'
      ? value
      : 'auto';
  } catch (_) {
    return 'auto';
  }
})();
let graphicsProfile = savedGraphicsProfile === 'auto'
  ? 'cinematic'
  : savedGraphicsProfile;

function applyBasicGraphicsTuning() {
  rendererTuning.maxPixelRatio = 3;
  rendererTuning.interactionPixelRatio = 1;
  rendererTuning.environmentIntensity = Math.min(
    rendererTuning.environmentIntensity ?? 0.42,
    0.42,
  );
  const atmosphere = lightingTuning.atmosphere ??= {};
  atmosphere.enabled = true;
  atmosphere.resolution = 560;
  const shadows = lightingTuning.shadows ??= {};
  shadows.enabled = true;
  shadows.mapSize = 4096;
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
const camera = new THREE.PerspectiveCamera(cameraTuning.fov ?? 42, 1, 0.1, 5000);

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
  precision: 'highp',
  powerPreference: 'high-performance',
});

function detectGraphicsProfile() {
  if (savedGraphicsProfile !== 'auto') return savedGraphicsProfile;
  const gl = renderer.getContext();
  const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
  const gpu = debugInfo
    ? String(gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL)).toLowerCase()
    : '';
  const memory = Number(navigator.deviceMemory) || 0;
  const userAgent = navigator.userAgent.toLowerCase();
  const deviceSignature = `${gpu} ${userAgent}`;
  const flagshipGalaxy = /sm-s(?:9|8)[0-9]{2}/.test(deviceSignature);
  const clearlyLimited =
    /mali-g5[0-9]|mali-g6[0-8]|sm-a(?:0|1|2)[0-9]/.test(deviceSignature) ||
    (!flagshipGalaxy && memory > 0 && memory <= 4);
  const clearlyPowerful =
    flagshipGalaxy ||
    /adreno.*7[0-9]{2}|xclipse|apple gpu/.test(gpu) ||
    memory >= 8;
  return clearlyPowerful && !clearlyLimited ? 'cinematic' : 'basic';
}

graphicsProfile = detectGraphicsProfile();
if (graphicsProfile === 'basic') applyBasicGraphicsTuning();
if (graphicsProfile === 'balanced') applyBalancedGraphicsTuning();
if (graphicsProfile === 'cinematic') applyCinematicGraphicsTuning();

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
renderer.shadowMap.enabled = lightingTuning.shadows?.enabled ?? true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.shadowMap.autoUpdate = false;
document.body.appendChild(renderer.domElement);

let effectComposer = null;
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

      float gradedLuminance = gradeLuminance(color);
      color = mix(vec3(gradedLuminance), color, saturation);
      color = (color - vec3(0.18)) * contrast + vec3(0.18);
      gl_FragColor = vec4(max(color, vec3(0.0)), sampleColor.a);
    }
  `,
};

function installPostProcessing() {
  const bloom = postProcessingTuning.bloom ?? {};
  if (bloom.enabled === false || effectComposer) return;

  effectComposer = new EffectComposer(renderer);
  if (renderer.capabilities.isWebGL2) {
    const context = renderer.getContext();
    const supportedSamples = context.getParameter(context.MAX_SAMPLES) ?? 0;
    const requestedSamples = postProcessingTuning.multisample ?? 4;
    const samples = Math.min(requestedSamples, supportedSamples);
    effectComposer.renderTarget1.samples = samples;
    effectComposer.renderTarget2.samples = samples;
  }
  effectComposer.addPass(new RenderPass(scene, camera));
  bloomPass = new UnrealBloomPass(
    new THREE.Vector2(1, 1),
    bloom.strength ?? 0.72,
    bloom.radius ?? 0.46,
    bloom.threshold ?? 0.72,
  );
  effectComposer.addPass(bloomPass);
  cinematicGradePass = new ShaderPass(cinematicGradeShader);
  cinematicGradePass.uniforms.atmosphereTexture.value = atmosphereTexture;
  effectComposer.addPass(cinematicGradePass);
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

const selectionMaskTarget = new THREE.WebGLRenderTarget(1, 1, {
  minFilter: THREE.LinearFilter,
  magFilter: THREE.LinearFilter,
  format: THREE.RGBAFormat,
  depthBuffer: true,
  stencilBuffer: false,
});
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
const selectionMaskMaterial = new THREE.MeshBasicMaterial({
  color: 0xffffff,
  side: THREE.DoubleSide,
});
const outlineMaterial = new THREE.ShaderMaterial({
  transparent: true,
  depthTest: false,
  depthWrite: false,
  toneMapped: false,
  uniforms: {
    maskTexture: { value: selectionMaskTarget.texture },
    texelSize: { value: new THREE.Vector2(1, 1) },
    outlineColor: { value: new THREE.Color('#ffffff') },
    outlineOpacity: { value: 0 },
    outlineWidth: { value: 1 },
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    uniform sampler2D maskTexture;
    uniform vec2 texelSize;
    uniform vec3 outlineColor;
    uniform float outlineOpacity;
    uniform float outlineWidth;
    varying vec2 vUv;

    float maskAt(vec2 offset, float radius) {
      return texture2D(maskTexture, vUv + offset * texelSize * radius).r;
    }

    void main() {
      float center = texture2D(maskTexture, vUv).r;
      float outer = 0.0;
      for (int ring = 1; ring <= 3; ring++) {
        float radius = outlineWidth * float(ring) / 3.0;
        outer = max(outer, maskAt(vec2( 1.0,  0.0), radius));
        outer = max(outer, maskAt(vec2(-1.0,  0.0), radius));
        outer = max(outer, maskAt(vec2( 0.0,  1.0), radius));
        outer = max(outer, maskAt(vec2( 0.0, -1.0), radius));
        outer = max(outer, maskAt(vec2( 0.707,  0.707), radius));
        outer = max(outer, maskAt(vec2(-0.707,  0.707), radius));
        outer = max(outer, maskAt(vec2( 0.707, -0.707), radius));
        outer = max(outer, maskAt(vec2(-0.707, -0.707), radius));
      }
      float edge = smoothstep(0.04, 0.7, outer) * (1.0 - center);
      gl_FragColor = vec4(outlineColor, edge * outlineOpacity);
    }
  `,
});
const outlineScene = new THREE.Scene();
const outlineCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
outlineScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), outlineMaterial));

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
let model = null;
let pointerStart = null;
let initialCameraPosition = null;
let initialTarget = null;
let initialAzimuth = null;
let lastSentBearing = null;
let lastCameraStateSentAt = 0;
let resettingCamera = null;
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
const materialBaseFinishes = new WeakMap();
const windowPresetGroups = new Map();
const windowGlowLights = [];
let animationFrame = null;
let selectedMeshes = [];
let selectedMaterialStates = [];
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
  const offset = camera.position.clone().sub(controls.target);
  const azimuth = Math.atan2(offset.x, offset.z);
  return normalizedBearingDegrees(
    THREE.MathUtils.radToDeg(azimuth - initialAzimuth),
  );
}

function sendCameraState({ force = false } = {}) {
  if (initialAzimuth === null) return;
  const now = performance.now();
  const bearing = currentBearingDegrees();
  const change = lastSentBearing === null
    ? Infinity
    : Math.abs(normalizedBearingDegrees(bearing - lastSentBearing));
  if (!force && (now - lastCameraStateSentAt < 48 || change < 0.08)) return;
  lastSentBearing = bearing;
  lastCameraStateSentAt = now;
  send('camera', { bearing });
}

function beginManualCameraGesture() {
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

function releaseSelectedMeshes() {
  for (const mesh of selectedMeshes) mesh.layers.disable(1);
  for (const state of selectedMaterialStates) {
    state.mesh.material = state.originalMaterial;
    for (const entry of state.materials) entry.material.dispose();
  }
  selectedMeshes = [];
  selectedMaterialStates = [];
}

function prepareSelectedMaterial(mesh) {
  const originalMaterial = mesh.material;
  const sourceMaterials = Array.isArray(originalMaterial)
    ? originalMaterial
    : [originalMaterial];
  const materials = sourceMaterials.map((source) => {
    const material = source.clone();
    const effectUniforms = {
      colorA: { value: selectionState.accentColor.clone() },
      colorB: { value: selectionState.flashColor.clone() },
      intensity: { value: 0 },
      phase: { value: 0 },
      frequency: {
        value: selectionTuning.flashSpatialFrequency ?? 0.075,
      },
    };
    const sourceOnBeforeCompile = material.onBeforeCompile.bind(material);
    const sourceProgramCacheKey = material.customProgramCacheKey.bind(material);
    material.onBeforeCompile = (shader, webGlRenderer) => {
      sourceOnBeforeCompile(shader, webGlRenderer);
      shader.uniforms.whereIfSelectionColorA = effectUniforms.colorA;
      shader.uniforms.whereIfSelectionColorB = effectUniforms.colorB;
      shader.uniforms.whereIfSelectionIntensity = effectUniforms.intensity;
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
        uniform float whereIfSelectionPhase;
        uniform float whereIfSelectionFrequency;
        varying vec3 vWhereIfSelectionWorldPosition;
        ${shader.fragmentShader}
      `.replace(
        '#include <dithering_fragment>',
        `
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
          #include <dithering_fragment>
        `,
      );
    };
    material.customProgramCacheKey = () =>
      `${sourceProgramCacheKey()}-whereif-selection-gradient-v1`;
    material.needsUpdate = true;
    return {
      material,
      effectUniforms,
    };
  });
  mesh.material = Array.isArray(originalMaterial)
    ? materials.map((entry) => entry.material)
    : materials[0].material;
  selectedMaterialStates.push({ mesh, originalMaterial, materials });
}

function updateSelectedMaterialGradient(intensity, phase) {
  for (const state of selectedMaterialStates) {
    for (const entry of state.materials) {
      entry.effectUniforms.intensity.value = intensity;
      entry.effectUniforms.phase.value = phase;
    }
  }
}

function clearSelection({ animate = true } = {}) {
  selectedZoneId = null;
  if (!selectionState) return;
  if (animate) {
    selectionState.leavingAt ??= performance.now();
  } else {
    releaseSelectedMeshes();
    selectionState = null;
    outlineMaterial.uniforms.outlineOpacity.value = 0;
  }
  requestRender();
}

function selectZone(zoneId) {
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

  clearSelection({ animate: false });
  selectedZoneId = zone.id;
  selectionState = {
    startedAt: performance.now(),
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
    prepareSelectedMaterial(object);
    object.layers.enable(1);
    selectedMeshes.push(object);
  });

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

function selectAt(clientX, clientY) {
  if (!model || !config) return false;

  const viewportBounds = renderer.domElement.getBoundingClientRect();
  pointer.x = ((clientX - viewportBounds.left) / viewportBounds.width) * 2 - 1;
  pointer.y = -((clientY - viewportBounds.top) / viewportBounds.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);

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
    edge.inward.dot(point.clone().sub(edge.origin)) - requiredDistance;

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
    const polygon = feasibleNavigationPolygon(offsets);
    const closest = closestPointInPolygon(position, polygon);
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

  const viewport = cameraTuning.navigation?.viewport ?? {};
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
  if (offsets.length === 0) return null;

  return offsets.map((offset) => new THREE.Vector2(offset.x, offset.z));
}

function constrainedNavigationTarget(
  viewCamera = camera,
  viewTarget = controls.target,
) {
  const offsets = viewportNavigationOffsets(viewCamera, viewTarget);
  return constrainNavigationPoint(viewTarget, offsets ?? []);
}

function applyNavigationConstraint({ elastic = false } = {}) {
  if (!navigationBounds || navigationConstraintSuspended) return;

  const rigidTarget = constrainedNavigationTarget();
  const desiredTarget = rigidTarget.clone();
  if (elastic) {
    const size = navigationBounds.getSize(new THREE.Vector3());
    const overshootRatio = cameraTuning.navigation?.maxOvershootRatio ?? 0.035;
    const overshoot = controls.target.clone().sub(rigidTarget);
    overshoot.y = 0;
    overshoot.multiplyScalar(
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
    duration: cameraTuning.navigation?.returnDuration ?? 280,
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

function focusPointsForNode(node) {
  const meshes = [];
  let vertexCount = 0;
  node.updateWorldMatrix(true, true);
  node.traverse((object) => {
    const positions = object.geometry?.attributes?.position;
    if (!object.isMesh || !object.visible || !positions) return;
    meshes.push({ object, positions });
    vertexCount += positions.count;
  });

  const maxPoints = selectionTuning.focusMaxSamplePoints ?? 20000;
  const stride = Math.max(1, Math.ceil(vertexCount / maxPoints));
  const points = [];
  let globalIndex = 0;
  for (const { object, positions } of meshes) {
    for (let index = 0; index < positions.count; index++, globalIndex++) {
      if (globalIndex % stride !== 0) continue;
      points.push(
        new THREE.Vector3()
          .fromBufferAttribute(positions, index)
          .applyMatrix4(object.matrixWorld),
      );
    }
  }
  return points;
}

function focusDistanceForPoints(points, target, direction, options = {}) {
  const safeWidth = options.safeWidth ?? selectionTuning.focusSafeWidth ?? 0.84;
  const safeHeight = options.safeHeight ?? selectionTuning.focusSafeHeight ?? 0.58;
  const padding = options.padding ?? selectionTuning.focusPadding ?? 1.08;
  const testCamera = camera.clone();
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
  const testCamera = camera.clone();
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

function prepareWindowPresets(root) {
  const settings = lightingTuning.dayCycle?.windows;
  const prefix = settings?.nodePrefix ?? 'janelas_preset_';
  const surfaceMaterialName = (
    settings?.surfaceMaterialName ?? 'whereif_ultra_concrete'
  ).toLowerCase();
  let surfaceMaterial = null;

  root.traverse((object) => {
    if (surfaceMaterial || !object.isMesh) return;
    const materials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    surfaceMaterial = materials.find((material) =>
      material?.name?.toLowerCase().includes(surfaceMaterialName)
    ) ?? null;
  });

  windowPresetGroups.clear();
  for (const light of windowGlowLights) {
    scene.remove(light);
    light.dispose?.();
  }
  windowGlowLights.length = 0;

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
        // Windows must behave like the facade while the sun is present:
        // no environment reflection and full participation in cast shadows.
        if ('envMapIntensity' in material) material.envMapIntensity = 0;
        if ('roughness' in material) material.roughness = 1;
        if ('clearcoat' in material) material.clearcoat = 0;
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
    if (settings?.glowEnabled !== true) continue;
    for (const preset of group) {
      const bounds = new THREE.Box3().setFromObject(preset.node);
      if (bounds.isEmpty()) continue;
      const size = bounds.getSize(new THREE.Vector3());
      const center = bounds.getCenter(new THREE.Vector3());
      center.y = bounds.min.y + size.y * 0.46;
      const glow = new THREE.PointLight(
        settings?.color ?? '#fff4cf',
        0,
        Math.max(size.x, size.y, size.z) *
          (settings?.glowDistanceRatio ?? 0.72),
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
    cyclicScheduleAmount(settings.schedule, localTimeMinutes()),
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
      preset.node.visible = true;
      if (preset.glowLight) {
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

  const minute = localTimeMinutes();
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
  if (
    !ambientLight ||
    !hemisphereLight ||
    !keyLight ||
    !fillLight ||
    !lightingFrame
  ) return;
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
  const contrastAmount = shadowContrast.enabled === false
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
  ambientLight.intensity = ambientIntensity;
  hemisphereLight.color.copy(profile.hemisphere.skyColor);
  hemisphereLight.groundColor.copy(profile.hemisphere.groundColor);
  const hemisphereIntensity = profile.hemisphere.intensity *
    THREE.MathUtils.lerp(
      1,
      shadowContrast.hemisphereScale ?? 0.62,
      contrastAmount,
    );
  hemisphereLight.intensity = hemisphereIntensity;
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
  nightCinema?.update(night, texturesEnabled, keyLight, lightingFrame);
}

function focusNode(node, options = {}) {
  const box = new THREE.Box3().setFromObject(node);
  if (box.isEmpty()) return;

  // Clear any damped orbit delta before capturing the focus route.
  clearControlsMomentum();

  const requestedTarget = box.getCenter(new THREE.Vector3());
  if (Array.isArray(options.targetOffset) && options.targetOffset.length === 3) {
    requestedTarget.add(new THREE.Vector3().fromArray(options.targetOffset));
  }
  if (!options.useVisualCenter && navigationTargetHeight !== null) {
    requestedTarget.y = navigationTargetHeight;
  }
  const direction = Array.isArray(options.direction) &&
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
  const target = options.constrainToNavigation === false
    ? requestedTarget.clone()
    : constrainedFocusTarget(requestedTarget, direction, distance);
  const destination = target.clone().addScaledVector(direction, distance);
  const finalMinDistance = baseMinDistance;
  const finalMaxDistance = baseMaxDistance;

  if (options.immediate === true) {
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

  navigationSpring = null;
  navigationConstraintSuspended = false;
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  cameraFocus = {
    startedAt: performance.now(),
    duration: selectionTuning.focusDuration ?? 620,
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
  const configuredZeroBearing = Number(cameraTuning.zeroBearingDegrees);
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
  const minute = localTimeMinutes();
  const fadeInStart = nightSkyTuning.fadeInStartMinute ?? 1140;
  const fullAt = nightSkyTuning.fullAtMinute ?? 1200;
  const fadeOutStart = nightSkyTuning.fadeOutStartMinute ?? 300;
  const hiddenAt = nightSkyTuning.hiddenAtMinute ?? 360;
  if (minute >= fullAt || minute < fadeOutStart) return 1;
  if (minute >= fadeInStart && minute < fullAt) {
    return THREE.MathUtils.smoothstep(minute, fadeInStart, fullAt);
  }
  if (minute >= fadeOutStart && minute < hiddenAt) {
    return 1 - THREE.MathUtils.smoothstep(minute, fadeOutStart, hiddenAt);
  }
  return 0;
}

function updateNightSky() {
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
    source?.x.toFixed(3) ?? 'none',
    source?.y.toFixed(3) ?? 'none',
    directViewAmount.toFixed(3),
    intensity.toFixed(3),
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
  uniforms.surfaceRayStrength.value = settings.enabled === false
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
  if (!model || !profile) return;
  const nightAmount = nightSkyAmount();
  const nightScale = (rendererTuning.nightEnvironmentScale ?? 2.4) *
    (nightLook.reflections ?? 1);
  const sunsetAmount = THREE.MathUtils.smoothstep(
    profile.rays?.opacity ?? 0,
    0.025,
    0.09,
  );
  const sunsetScale = THREE.MathUtils.lerp(
    1,
    rendererTuning.sunsetEnvironmentScale ?? 2.2,
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
          ? THREE.MathUtils.lerp(materialEnvironmentIntensities.get(material),
              (nightLook.floorReflection ?? 1.6) * (nightLook.reflections ?? 3), nightAmount)
          : materialEnvironmentIntensities.get(material) * THREE.MathUtils.lerp(sunsetScale, nightScale, nightAmount);
      const nightFinish = finishType
        ? rendererTuning.nightReflectionFinish?.[finishType]
        : null;
      const sunsetFinish = finishType
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
              sunsetAmount,
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
              sunsetAmount,
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
              sunsetAmount,
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
      if (finishType === 'pavement') {
        material.roughness = THREE.MathUtils.lerp(baseFinish.roughness,
          (nightLook.floorRoughness ?? 0.24) * (1 - (nightLook.wetness ?? 0) * 0.6), nightAmount);
        if ('clearcoat' in material) {
          material.clearcoat = THREE.MathUtils.lerp(baseFinish.clearcoat ?? 0,
            0.35 + (nightLook.wetness ?? 0) * 0.6, nightAmount);
          material.clearcoatRoughness = THREE.MathUtils.lerp(baseFinish.clearcoatRoughness ?? 0.15, 0.13, nightAmount);
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

function prepareModelMaterials(object) {
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

  object.traverse((child) => {
    if (!child.isMesh) return;

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
      if (!material) continue;
      material.side = THREE.DoubleSide;
      applyMaterialFinish(material);
      for (const texture of [
        material.map,
        material.normalMap,
        material.roughnessMap,
        material.metalnessMap,
        material.aoMap,
      ]) {
        if (!texture) continue;
        texture.anisotropy = maxAnisotropy;
        texture.needsUpdate = true;
      }
      material.needsUpdate = true;
    }
  });
}

async function loadConfiguredModel() {
  if (!config || model) return;

  applyConfiguredBackground();

  try {
    const gltf = await new GLTFLoader().loadAsync(config.modelUrl);
    model = gltf.scene;
    prepareModelMaterials(model);
    prepareWindowPresets(model);
    scene.add(model);
    nightCinema = createNightCinema(model, scene, windowPresetGroups, nightLook);
    if (graphicsProfile !== 'basic') installGroundSunRays(model);

    for (const zone of config.zones) {
      const node = findModelNode(model, zone.nodeName);
      if (node) {
        zoneNodes.set(zone.nodeName, node);
      }
    }

    frameModel(model);
    requestAnimationFrame(() => {
      renderer.domElement.classList.add('is-ready');
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
      // ANGLE/Vulkan can create an empty depth texture while the model shaders
      // are still compiling. Recreate it after the first complete scene frame.
      requestAnimationFrame(() => {
        refreshDirectionalShadow({ recreate: true });
        requestRender();
      });
    });
  } catch (error) {
    send('error', {
      message: error instanceof Error ? error.message : String(error),
    });
  }
}

function configure(nextConfig) {
  config = nextConfig;
  installNightSky();
  if (model) {
    applyConfiguredBackground();
    applyDaylightProfile();
    requestRender();
    return;
  }
  loadConfiguredModel();
}

function resetCamera() {
  if (!initialCameraPosition || !initialTarget) return;
  cameraFocus = null;
  navigationSpring = null;
  navigationConstraintSuspended = false;
  controls.minDistance = baseMinDistance;
  controls.maxDistance = baseMaxDistance;
  resettingCamera = {
    startedAt: performance.now(),
    duration: 320,
    fromPosition: camera.position.clone(),
    fromTarget: controls.target.clone(),
  };
  beginCameraTransitionResolution();
  requestRender();
}

function setLocalTimeMinutes(minutes) {
  if (!config || !Number.isFinite(minutes)) return;
  config.localTimeMinutes = ((minutes % 1440) + 1440) % 1440;
  if (model) {
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
  const zeroZoneId = cameraTuning.zeroZoneId;
  if (typeof zeroZoneId === 'string' && focusZone(zeroZoneId)) {
    lastFocusedZoneId = zeroZoneId;
    cameraMovedSinceFocus = false;
    return;
  }
  const totalRotation = currentBearingDegrees();
  if (Math.abs(totalRotation) < 0.05) return;
  beginExternalRotation();
  const startedAt = performance.now();
  const duration = 360;
  let appliedRotation = 0;

  const animate = (now) => {
    const progress = THREE.MathUtils.clamp((now - startedAt) / duration, 0, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    const targetRotation = totalRotation * eased;
    rotateCameraBy(targetRotation - appliedRotation);
    appliedRotation = targetRotation;
    if (progress < 1) {
      bearingResetFrame = requestAnimationFrame(animate);
      return;
    }
    bearingResetFrame = null;
    endExternalRotation();
  };
  bearingResetFrame = requestAnimationFrame(animate);
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
  if (!model) return;
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
  model?.traverse((object) => {
    if (!object.isMesh) return;
    const objectMaterials = Array.isArray(object.material)
      ? object.material
      : [object.material];
    for (const material of objectMaterials) {
      if (!material || seenMaterials.has(material.uuid)) continue;
      seenMaterials.add(material.uuid);
      materials.push({
        name: material.name,
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
    nightCinema: nightCinema?.stats(),
    toneMapping: rendererTuning.toneMapping,
    exposure: renderer.toneMappingExposure,
    bloom: bloomPass
      ? {
          enabled: bloomPass.enabled,
          strength: bloomPass.strength,
          radius: bloomPass.radius,
          threshold: bloomPass.threshold,
        }
      : null,
    cameraPosition: camera.position.toArray(),
    cameraTarget: controls.target.toArray(),
    keyLight: keyLight
      ? {
          color: keyLight.color.getHexString(),
          intensity: keyLight.intensity,
          position: keyLight.position.toArray(),
        }
      : null,
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
  return value === 'basic' || value === 'balanced' || value === 'cinematic'
    ? value
    : 'auto';
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
    floorReflection: [0, 4], moonShafts: [0, 2], windowSpill: [0, 3],
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
  return {
    ...nightLook, textures: texturesEnabled,
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
  texturesEnabled = true;
  configureNightLook();
  setToneMapping(defaultToneMapping);
  configureBloom(defaultBloom);
  return visualTestSettings();
}

window.whereIfMap = {
  configureNightLook,
  visualTestSettings,
  resetNightLook,
  beginExternalRotation,
  clearDaylightPreview,
  clearPreviewTime,
  configure,
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
  rotateCameraBy,
};
if (window.__whereIfPendingConfig) {
  configure(window.__whereIfPendingConfig);
}

renderer.domElement.addEventListener(
  'pointerdown',
  (event) => {
    if (!event.isPrimary) {
      multiTouchGesture = true;
      beginManualCameraGesture();
      return;
    }
    multiTouchGesture = false;
    pointerStart = {
      pointerId: event.pointerId,
      x: event.clientX,
      y: event.clientY,
      at: performance.now(),
      maxDistance: 0,
      cameraPosition: camera.position.clone(),
      cameraTarget: controls.target.clone(),
    };
  },
  { capture: true },
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
  { capture: true },
);

renderer.domElement.addEventListener(
  'pointerup',
  (event) => {
    const start = pointerStart;
    if (!start || event.pointerId !== start.pointerId) return;
    pointerStart = null;

    const distance = Math.max(
      start.maxDistance,
      Math.hypot(event.clientX - start.x, event.clientY - start.y),
    );
    const elapsed = performance.now() - start.at;
    if (
      !multiTouchGesture &&
      distance <= (selectionTuning.tapTolerance ?? 18) &&
      elapsed <= 600
    ) {
      // OrbitControls emits `end` after this capture listener. Ignore that
      // matching event so it cannot schedule another camera correction.
      suppressNextControlsEnd = true;
      queueMicrotask(() => {
        suppressNextControlsEnd = false;
      });
      const shouldPreserveCamera = selectAt(event.clientX, event.clientY);
      if (shouldPreserveCamera) {
        preserveCameraAfterTap({
          position: start.cameraPosition,
          target: start.cameraTarget,
        });
      }
    }
    multiTouchGesture = false;
  },
  { capture: true },
);

renderer.domElement.addEventListener(
  'pointercancel',
  () => {
    pointerStart = null;
    multiTouchGesture = false;
  },
  { capture: true },
);

function resize() {
  const width = Math.max(1, document.documentElement.clientWidth);
  const height = Math.max(1, document.documentElement.clientHeight);
  renderer.setSize(width, height, false);
  effectComposer?.setPixelRatio(renderer.getPixelRatio());
  effectComposer?.setSize(width, height);
  resizeAtmosphericBackground(width, height);
  const drawingSize = renderer.getDrawingBufferSize(new THREE.Vector2());
  selectionMaskTarget.setSize(drawingSize.x, drawingSize.y);
  outlineMaterial.uniforms.texelSize.value.set(
    1 / drawingSize.x,
    1 / drawingSize.y,
  );
  updateNightSkyRenderScale();
  camera.aspect = width / height;
  updatePerspectiveProjection(camera);
  requestRender();
}

function useInteractionResolution(active) {
  const ratioLimit = active
    ? rendererTuning.interactionPixelRatio ?? rendererTuning.maxPixelRatio
    : rendererTuning.maxPixelRatio;
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
  return resettingCamera !== null ||
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
  if (animationFrame !== null) return;
  animationFrame = requestAnimationFrame(renderFrame);
}

function renderFrame(time) {
  animationFrame = null;
  let keepAnimating = false;
  let cameraIsTransitioning = false;

  if (resettingCamera) {
    cameraIsTransitioning = true;
    const elapsed = (time - resettingCamera.startedAt) / resettingCamera.duration;
    const progress = Math.min(1, Math.max(0, elapsed));
    const eased = 1 - Math.pow(1 - progress, 3);
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
    const eased = progress < 0.5
      ? 4 * progress * progress * progress
      : 1 - Math.pow(-2 * progress + 2, 3) / 2;
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
  keepAnimating = selectionAnimating || keepAnimating;

  if (cameraIsTransitioning) {
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
  updateAtmosphericBackground(activeDaylightProfile);
  if (nightSkyPoints) nightSkyPoints.position.copy(camera.position);
  updateDaylightBloom(activeDaylightProfile);
  updateDirectSunExposure(activeDaylightProfile);
  if (!cameraIsTransitioning) {
    updateDirectionalShadowForView();
  } else if (!keepAnimating) {
    updateDirectionalShadowForView({ force: true });
  }
  renderSceneWithSelection();
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
    updateSelectedMaterialGradient(0, 0);
    if (progress >= 1) {
      releaseSelectedMeshes();
      selectionState = null;
      return false;
    }
    return true;
  }

  const progress = THREE.MathUtils.clamp(
    (time - selectionState.startedAt) / entranceDuration,
    0,
    1,
  );
  const eased = 1 - Math.pow(1 - progress, 3);
  const pulse = Math.sin(progress * Math.PI);
  const colorPhase = 0.5 - 0.5 * Math.cos(progress * Math.PI * 2);
  selectionState.effectColor.lerpColors(
    selectionState.accentColor,
    selectionState.flashColor,
    colorPhase,
  );
  updateSelectedMaterialGradient(
    (selectionTuning.flashIntensity ?? 0.48) * Math.pow(pulse, 0.82),
    progress * Math.PI * 2 * (selectionTuning.flashCycles ?? 1.15),
  );
  outlineMaterial.uniforms.outlineOpacity.value = THREE.MathUtils.clamp(
    targetOpacity * eased + pulse * 0.12,
    0,
    1,
  );
  outlineMaterial.uniforms.outlineWidth.value = THREE.MathUtils.lerp(
    selectionTuning.initialOutlineWidth ?? 7,
    selectionTuning.outlineWidth ?? 3.5,
    eased,
  );
  outlineMaterial.uniforms.outlineColor.value.lerpColors(
    selectionState.startColor,
    selectionState.effectColor,
    eased,
  );
  return progress < 1;
}

function renderSceneWithSelection() {
  const originalLayerMask = camera.layers.mask;
  camera.layers.set(0);
  renderer.setRenderTarget(null);
  renderer.autoClear = true;
  if (effectComposer && bloomPass?.enabled) {
    effectComposer.render();
  } else {
    renderer.render(scene, camera);
  }

  if (model && renderer.shadowMap.autoUpdate) {
    renderer.shadowMap.autoUpdate = false;
  }
  if (!selectionState || selectedMeshes.length === 0) {
    camera.layers.mask = originalLayerMask;
    return;
  }

  const originalBackground = scene.background;
  const originalOverrideMaterial = scene.overrideMaterial;
  scene.background = null;
  scene.overrideMaterial = selectionMaskMaterial;
  camera.layers.set(1);

  renderer.setRenderTarget(selectionMaskTarget);
  renderer.setClearColor(0x000000, 1);
  renderer.clear(true, true, true);
  renderer.render(scene, camera);

  scene.background = originalBackground;
  scene.overrideMaterial = originalOverrideMaterial;
  camera.layers.mask = originalLayerMask;
  renderer.setRenderTarget(null);
  renderer.autoClear = false;
  renderer.render(outlineScene, outlineCamera);
  renderer.autoClear = true;
}

installLighting();
installPostProcessing();
resize();
window.addEventListener('resize', resize);
controls.addEventListener('start', () => {
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
  if (graphicsProfile === 'basic' || graphicsProfile === 'balanced') {
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
