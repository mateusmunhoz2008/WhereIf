import * as THREE from './vendor/three.module.min.js';

// World-space surface detail; no UVs or image assets are required by the
// standard campus GLB.
export function createNightCinema(root, scene, settings, { textures = true, shaders = true } = {}) {
  const moonHits = [];
  const beams = [];
  const uniforms = {
    ncNight: { value: 0 },
    ncSurface: { value: 0 },
    ncSunHighlights: { value: 1 },
    ncReflections: { value: 1 },
    ncFoliageStrength: { value: 0 },
    ncSunDirection: { value: new THREE.Vector3(0, 1, 0) },
    ncSunColor: { value: new THREE.Color() },
    ncLeafShadowOffset: { value: new THREE.Vector4() },
    ncDetail: { value: settings.textureDetail ?? 1.65 },
    ncTextures: { value: 1 },
    ncMoon: { value: settings.moonShafts ?? 0.9 },
    ncMoonHits: { value: Array.from({ length: 3 }, () => new THREE.Vector4()) },
  };
  root.updateWorldMatrix(true, true);
  const floorMeshes = [];
  const solidMeshes = [];
  const visited = new Set();
  root.traverse((mesh) => {
    if (!mesh.isMesh) return;
    const materials = [].concat(mesh.material);
    if (!materials.some((m) => /windows|cerca/i.test(m.name))) solidMeshes.push(mesh);
    if (materials.some((m) => /pavement|asphalt|ground|street|grass/i.test(m.name))) floorMeshes.push(mesh);
    for (const material of materials) {
      if (visited.has(material) || !material.isMeshStandardMaterial || /windows|cerca/i.test(material.name)) continue;
      visited.add(material);
      const floor = /pavement|asphalt|ground|street/i.test(material.name);
      const grass = /grass|grama/i.test(material.name);
      const road = /asphalt|street|rua/i.test(material.name);
      const foliage = (window.WHEREIF_MAP_TUNING?.renderer?.foliageMaterials ?? []).includes(material.name);
      const previous = material.onBeforeCompile.bind(material);
      const previousKey = material.customProgramCacheKey.bind(material)();
      material.onBeforeCompile = (shader, renderer) => {
        previous(shader, renderer);
        Object.assign(shader.uniforms, uniforms);
        shader.vertexShader = 'varying vec3 ncWorld;\n' + shader.vertexShader;
        shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>',
          '#include <begin_vertex>\nncWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;');
        shader.fragmentShader = `
          varying vec3 ncWorld;
          uniform float ncNight, ncSurface, ncDetail, ncTextures, ncMoon;
          uniform float ncSunHighlights, ncReflections;
          uniform float ncFoliageStrength;
          uniform vec3 ncSunDirection, ncSunColor;
          uniform vec4 ncLeafShadowOffset;
          uniform vec4 ncMoonHits[3];
          float ncHash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
          float ncNoise(vec3 p) {
            vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
            return mix(mix(mix(ncHash(i), ncHash(i+vec3(1,0,0)),f.x),
              mix(ncHash(i+vec3(0,1,0)),ncHash(i+vec3(1,1,0)),f.x),f.y),
              mix(mix(ncHash(i+vec3(0,0,1)),ncHash(i+vec3(1,0,1)),f.x),
              mix(ncHash(i+vec3(0,1,1)),ncHash(i+vec3(1,1,1)),f.x),f.y),f.z);
          }
        ` + shader.fragmentShader;
        if (textures) shader.fragmentShader = shader.fragmentShader.replace('#include <color_fragment>', `
          #include <color_fragment>
          float ncFine = ncNoise(ncWorld * ${grass ? '7.5' : road ? '5.0' : floor ? '2.0' : '18.0'});
          float ncBroad = ncNoise(ncWorld * ${road ? '1.1' : grass || floor ? '0.32' : '3.2'});
          float ncTextureAmount = ncTextures * ncSurface;
          diffuseColor.rgb *= mix(1.0, ${road
            ? '0.94 + ncFine * 0.10 + ncBroad * 0.04'
            : grass || floor
            ? '0.70 + ncFine * 0.35 + ncBroad * 0.22'
            : '0.97 + ncFine * 0.04 + ncBroad * 0.02'}, ncTextureAmount);
        `);
        else shader.fragmentShader = shader.fragmentShader.replace('#include <color_fragment>',
          '#include <color_fragment>\nfloat ncBroad = 0.5;');
        if (textures) shader.fragmentShader = shader.fragmentShader.replace('#include <roughnessmap_fragment>', `
          #include <roughnessmap_fragment>
          roughnessFactor = clamp(roughnessFactor * mix(1.0,
            ${grass ? '1.0' : road ? '0.96 + ncBroad * 0.05 + ncFine * 0.02'
              : '0.88 + ncBroad * 0.20 + ncFine * 0.06'}, ncTextureAmount), 0.07, 1.0);
        `);
        if (textures) shader.fragmentShader = shader.fragmentShader.replace('#include <normal_fragment_maps>', `
          #include <normal_fragment_maps>
          float ncHeight = (${road ? 'ncFine * 0.003 + ncBroad * 0.005'
            : grass || floor ? 'ncFine * 0.007 + ncBroad * 0.024'
            : 'ncFine * 0.0008 + ncBroad * 0.0004'}) * ncDetail * ncTextureAmount;
          vec3 ncDx = dFdx(-vViewPosition), ncDy = dFdy(-vViewPosition);
          vec3 ncR1 = cross(ncDy, normal), ncR2 = cross(normal, ncDx);
          float ncDet = dot(ncDx, ncR1);
          normal = normalize(max(abs(ncDet), 0.000001) * normal - sign(ncDet) *
            (dFdx(ncHeight) * ncR1 + dFdy(ncHeight) * ncR2));
          vec3 ncNormalDx = dFdx(normal), ncNormalDy = dFdy(normal);
          float ncVariance = max(dot(ncNormalDx,ncNormalDx),dot(ncNormalDy,ncNormalDy));
          roughnessFactor = clamp(sqrt(roughnessFactor*roughnessFactor +
            min(ncVariance*0.5,0.2)*ncTextureAmount), 0.07, 1.0);
        `);
        if (shaders) shader.fragmentShader = shader.fragmentShader.replace('#include <lights_fragment_end>', `
          #include <lights_fragment_end>
          reflectedLight.directDiffuse *= ncSunHighlights;
          reflectedLight.directSpecular *= ncSunHighlights * ncReflections;
          #ifdef USE_CLEARCOAT
            clearcoatSpecularDirect *= ncSunHighlights * ncReflections;
          #endif
        `);
        if (shaders && foliage) shader.fragmentShader = shader.fragmentShader.replace('#include <opaque_fragment>', `
          // Uniform branch: the canopy transmission contributes exactly zero
          // at night or with strength zero. Skip its extra shadow sample then.
          if (ncFoliageStrength != 0.0 && ncNight != 1.0) {
          // Approximate light crossing a shallow canopy, in world space.
          // Sampling toward the sun avoids treating the canopy as opaque solid.
          float leafVisibility = 1.0;
          #if defined(USE_SHADOWMAP) && NUM_DIR_LIGHT_SHADOWS > 0
            DirectionalLightShadow leafShadow = directionalLightShadows[0];
            leafVisibility = receiveShadow ? getShadow(directionalShadowMap[0],
              leafShadow.shadowMapSize, leafShadow.shadowIntensity,
              leafShadow.shadowBias, leafShadow.shadowRadius,
              vDirectionalShadowCoord[0] + ncLeafShadowOffset) : 1.0;
          #endif
          vec3 leafNormal = inverseTransformDirection(normal, viewMatrix);
          float leafFacing = dot(leafNormal, ncSunDirection);
          float leafTransmission = 0.22 + 0.78 * max(-leafFacing, 0.0);
          vec3 leafPigment = sqrt(max(diffuseColor.rgb, vec3(0.0)));
          outgoingLight += leafPigment * ncSunColor * leafTransmission *
            leafVisibility * ncFoliageStrength * (1.0 - ncNight);
          }
          #include <opaque_fragment>
        `);
        if (shaders && floor) shader.fragmentShader = shader.fragmentShader.replace('#include <opaque_fragment>', `
          // Daytime keeps the same sun shader; moon pools contribute zero.
          // Avoid three exponentials per pixel when their uniforms disable it.
          if (ncNight != 0.0 && ncMoon != 0.0) {
          vec3 ncLighting = vec3(0.0);
          for (int i = 0; i < 3; i++) {
            vec4 hit = ncMoonHits[i];
            vec2 delta = ncWorld.xz - hit.xz;
            float pool = exp(-dot(delta,delta)/max(hit.w*hit.w,0.1)*1.8);
            pool *= 1.0 - smoothstep(0.1, 0.9, abs(ncWorld.y-hit.y));
            ncLighting += vec3(0.35,0.53,0.92) * pool * ncMoon * 0.9;
          }
          outgoingLight += ncLighting * ncNight * (0.74 + ncBroad * 0.26);
          }
          #include <opaque_fragment>
        `);
      };
      material.customProgramCacheKey = () => `${previousKey}:night-cinema-9:${floor}:${grass}:${road}:${foliage}:${textures}:${shaders}`;
      material.userData.nightProceduralTexture = textures;
      material.needsUpdate = true;
    }
  });

  const ray = new THREE.Raycaster();
  const down = new THREE.Vector3(0, -1, 0);
  let moonInstalled = false;
  function installMoon(keyLight, frame) {
    if (moonInstalled || !frame) return;
    moonInstalled = true;
    const toMoon = keyLight.position.clone().sub(keyLight.target.position).normalize();
    // Fixed outdoor positions sampled against the real campus surfaces.
    const candidates = [[55,-113], [43,-84], [16,-119], [71,-104], [-6,-80], [36,-57],
      [70,-75], [40,-140], [75,-135], [55,-95], [65,-60], [-50,-160], [85,-145], [25,-45]];
    for (const [x,z] of candidates) {
      ray.set(new THREE.Vector3(x, 80, z), down); ray.far = 120;
      const floor = ray.intersectObjects(floorMeshes, false)[0];
      if (!floor) continue;
      const target = floor.point.clone().add(new THREE.Vector3(0, 0.08, 0));
      const length = 100;
      const start = target.clone().addScaledVector(toMoon, length);
      ray.set(start, toMoon.clone().negate()); ray.far = length;
      const obstruction = ray.intersectObjects(solidMeshes, false)[0];
      if (obstruction && obstruction.distance < length - 1) continue;
      const radius = [3.4, 2.1, 4.2][moonHits.length];
      moonHits.push(new THREE.Vector4(target.x, floor.point.y, target.z, radius));
      const material = new THREE.ShaderMaterial({
        uniforms: { opacity: { value: 0 } },
        vertexShader: `varying vec2 beamUv; varying vec3 beamNormal, beamView;
          void main() { beamUv=uv; vec4 p=modelViewMatrix*vec4(position,1.0);
            beamNormal=normalMatrix*normal; beamView=-p.xyz; gl_Position=projectionMatrix*p; }`,
        fragmentShader: `uniform float opacity; varying vec2 beamUv; varying vec3 beamNormal,beamView;
          void main() { float edge=pow(abs(dot(normalize(beamNormal),normalize(beamView))),1.6);
            float ends=smoothstep(0.0,0.12,beamUv.y)*(1.0-smoothstep(0.6,1.0,beamUv.y));
            gl_FragColor=vec4(0.44,0.61,1.0,edge*ends*opacity); }`,
        transparent: true, depthWrite: false, depthTest: true,
        blending: THREE.AdditiveBlending, toneMapped: false,
      });
      const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.5, radius, length, 16, 1, true), material);
      beam.position.copy(start).add(target).multiplyScalar(0.5);
      beam.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0), toMoon);
      beam.raycast = () => {};
      beam.name = 'night_moon_shaft';
      scene.add(beam); beams.push(beam);
      if (moonHits.length === 3) break;
    }
    moonHits.forEach((hit, i) => uniforms.ncMoonHits.value[i].copy(hit));
  }

  return {
    update(amount, enabled, keyLight, frame, dawnAmount = 0, detail, sunHighlights = 1, reflections = 1, foliageStrength = 0) {
      if (shaders && amount > 0.01) installMoon(keyLight, frame);
      uniforms.ncNight.value = amount;
      uniforms.ncSurface.value = Math.max(amount, dawnAmount);
      uniforms.ncSunHighlights.value = sunHighlights;
      uniforms.ncReflections.value = reflections;
      uniforms.ncFoliageStrength.value = foliageStrength;
      if (keyLight) {
        uniforms.ncSunDirection.value.copy(keyLight.position).sub(keyLight.target.position).normalize();
        uniforms.ncSunColor.value.copy(keyLight.color).multiplyScalar(keyLight.intensity * 0.22);
        const direction = uniforms.ncSunDirection.value;
        uniforms.ncLeafShadowOffset.value.set(direction.x * 3, direction.y * 3, direction.z * 3, 0);
        if (keyLight.shadow) uniforms.ncLeafShadowOffset.value.applyMatrix4(keyLight.shadow.matrix);
      }
      uniforms.ncTextures.value = textures && enabled ? 1 : 0;
      uniforms.ncDetail.value = detail ?? settings.textureDetail ?? 1.65;
      uniforms.ncMoon.value = settings.moonShafts ?? 0.9;
      for (const beam of beams) {
        beam.visible = amount > 0.01 && uniforms.ncMoon.value > 0;
        beam.material.uniforms.opacity.value = amount * uniforms.ncMoon.value * 0.085;
      }
    },
    stats() { return { surfaceMaterials: visited.size, windowProjections: 0, moonShafts: beams.length,
      textures: uniforms.ncTextures.value > 0, shaders,
      sunHighlights: uniforms.ncSunHighlights.value,
      reflections: uniforms.ncReflections.value,
      foliageStrength: uniforms.ncFoliageStrength.value }; },
    dispose() {
      for (const beam of beams) {
        beam.removeFromParent(); beam.geometry.dispose(); beam.material.dispose();
      }
      beams.length = 0;
    },
  };
}
