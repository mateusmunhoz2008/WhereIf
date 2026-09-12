import * as THREE from './vendor/three.module.min.js';

// World-space surface detail and light projections; no UVs or image assets
// are required by the standard campus GLB. Sources never follow the camera.
export function createNightCinema(root, scene, windowGroups, settings) {
  const maxWindows = 24;
  const sources = [];
  const moonHits = [];
  const beams = [];
  const uniforms = {
    ncNight: { value: 0 },
    ncDetail: { value: settings.textureDetail ?? 1.65 },
    ncTextures: { value: 1 },
    ncSpill: { value: settings.windowSpill ?? 1.5 },
    ncMoon: { value: settings.moonShafts ?? 0.9 },
    ncWindows: { value: Array.from({ length: maxWindows }, () => new THREE.Vector4()) },
    ncShapes: { value: Array.from({ length: maxWindows }, () => new THREE.Vector4()) },
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
          uniform float ncNight, ncDetail, ncTextures, ncSpill, ncMoon;
          uniform vec4 ncWindows[24], ncShapes[24], ncMoonHits[3];
          float ncHash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
          float ncNoise(vec3 p) {
            vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
            return mix(mix(mix(ncHash(i), ncHash(i+vec3(1,0,0)),f.x),
              mix(ncHash(i+vec3(0,1,0)),ncHash(i+vec3(1,1,0)),f.x),f.y),
              mix(mix(ncHash(i+vec3(0,0,1)),ncHash(i+vec3(1,0,1)),f.x),
              mix(ncHash(i+vec3(0,1,1)),ncHash(i+vec3(1,1,1)),f.x),f.y),f.z);
          }
        ` + shader.fragmentShader;
        shader.fragmentShader = shader.fragmentShader.replace('#include <color_fragment>', `
          #include <color_fragment>
          float ncFine = ncNoise(ncWorld * ${grass ? '7.5' : '2.0'});
          float ncBroad = ncNoise(ncWorld * 0.32);
          float ncTextureAmount = ncTextures * ncNight;
          diffuseColor.rgb *= mix(1.0, 0.70 + ncFine * 0.35 + ncBroad * 0.22, ncTextureAmount);
        `);
        shader.fragmentShader = shader.fragmentShader.replace('#include <roughnessmap_fragment>', `
          #include <roughnessmap_fragment>
          roughnessFactor = clamp(roughnessFactor * mix(1.0,
            ${grass ? '1.0' : '0.88 + ncBroad * 0.20 + ncFine * 0.06'}, ncTextureAmount), 0.07, 1.0);
        `);
        shader.fragmentShader = shader.fragmentShader.replace('#include <normal_fragment_maps>', `
          #include <normal_fragment_maps>
          float ncHeight = (ncFine * 0.007 + ncBroad * 0.024) * ncDetail * ncTextureAmount;
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
        if (floor) shader.fragmentShader = shader.fragmentShader.replace('#include <opaque_fragment>', `
          vec3 ncLighting = vec3(0.0);
          for (int i = 0; i < 24; i++) {
            vec4 source = ncWindows[i], shape = ncShapes[i];
            vec2 delta = ncWorld.xz - source.xz;
            float along = dot(delta, shape.xy);
            float across = dot(delta, vec2(-shape.y, shape.x));
            float width = max(shape.z * (1.0 + max(along, 0.0) * 0.035), 0.1);
            float reach = max(shape.w, 0.1);
            float pool = exp(-pow(across / width, 2.0) * 1.8) * exp(-max(along, 0.0)/reach*2.8);
            pool *= smoothstep(-0.1, 0.5, along) * (1.0-smoothstep(reach*0.7, reach, along));
            pool *= 1.0 - smoothstep(source.y+0.1, source.y+1.0, ncWorld.y);
            float bars = 0.62 + 0.38*smoothstep(0.10,0.26,abs(sin(across*2.2)));
            ncLighting += vec3(1.0,0.48,0.14) * pool * bars * source.w * ncSpill * 1.8;
          }
          for (int i = 0; i < 3; i++) {
            vec4 hit = ncMoonHits[i];
            vec2 delta = ncWorld.xz - hit.xz;
            float pool = exp(-dot(delta,delta)/max(hit.w*hit.w,0.1)*1.8);
            pool *= 1.0 - smoothstep(0.1, 0.9, abs(ncWorld.y-hit.y));
            ncLighting += vec3(0.35,0.53,0.92) * pool * ncMoon * 0.9;
          }
          outgoingLight += ncLighting * ncNight * (0.74 + ncBroad * 0.26);
          #include <opaque_fragment>
        `);
      };
      material.customProgramCacheKey = () => `${previousKey}:night-cinema-3:${floor}:${grass}`;
      material.userData.nightProceduralTexture = true;
      material.needsUpdate = true;
    }
  });

  const ray = new THREE.Raycaster();
  const down = new THREE.Vector3(0, -1, 0);
  // Cluster real window triangles into small facade patches, not one light
  // at the centre of an entire building or at the centre of a preset group.
  for (const group of windowGroups.values()) for (const preset of group) {
    const patches = new Map();
    preset.node.traverse((mesh) => {
      if (!mesh.isMesh) return;
      const pos = mesh.geometry.attributes.position, indices = mesh.geometry.index;
      if (!pos) return;
      const count = indices?.count ?? pos.count;
      for (let i = 0; i + 2 < count; i += 3) {
        const vertices = [0, 1, 2].map((j) => new THREE.Vector3()
          .fromBufferAttribute(pos, indices ? indices.getX(i+j) : i+j).applyMatrix4(mesh.matrixWorld));
        const normal = vertices[1].clone().sub(vertices[0]).cross(vertices[2].clone().sub(vertices[0]));
        const area = normal.length() * 0.5;
        if (area < 0.02) continue;
        normal.normalize();
        if (Math.abs(normal.y) > 0.4) continue;
        const center = vertices[0].clone().add(vertices[1]).add(vertices[2]).divideScalar(3);
        const key = [Math.floor(center.x/7), Math.floor(center.y/4), Math.floor(center.z/7),
          Math.round(normal.x),Math.round(normal.z)].join(':');
        const patch = patches.get(key) ?? { center: new THREE.Vector3(), normal, area: 0, preset };
        patch.center.addScaledVector(center, area); patch.area += area;
        patches.set(key, patch);
      }
    });
    const candidates = [...patches.values()].sort((a,b) => b.area-a.area);
    for (const patch of candidates.slice(0, 3)) {
      patch.center.divideScalar(patch.area);
      patch.normal.y = 0; patch.normal.normalize();
      const origin = patch.center.clone().addScaledVector(patch.normal, 0.3);
      ray.set(origin, patch.normal); ray.far = 14;
      const obstacle = ray.intersectObjects(solidMeshes, false)[0];
      patch.reach = Math.min(14, obstacle?.distance ?? 14);
      if (patch.reach < 1) continue;
      patch.width = THREE.MathUtils.clamp(Math.sqrt(patch.area), 1.8, 4.0);
      sources.push(patch);
      if (sources.length >= maxWindows) break;
    }
    if (sources.length >= maxWindows) break;
  }

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
    update(amount, enabled, keyLight, frame) {
      if (amount > 0.01) installMoon(keyLight, frame);
      uniforms.ncNight.value = amount;
      uniforms.ncTextures.value = enabled ? 1 : 0;
      uniforms.ncDetail.value = settings.textureDetail ?? 1.65;
      uniforms.ncSpill.value = settings.windowSpill ?? 1.5;
      uniforms.ncMoon.value = settings.moonShafts ?? 0.9;
      sources.forEach((source, i) => {
        const emission = Math.max(0, ...source.preset.materialStates.map(({ material }) => {
          const color = material.emissive;
          return color ? Math.max(color.r, color.g, color.b) * (material.emissiveIntensity ?? 0) : 0;
        }));
        uniforms.ncWindows.value[i].set(source.center.x,source.center.y,source.center.z,emission);
        uniforms.ncShapes.value[i].set(source.normal.x,source.normal.z,source.width,source.reach);
      });
      for (const beam of beams) {
        beam.visible = amount > 0.01 && uniforms.ncMoon.value > 0;
        beam.material.uniforms.opacity.value = amount * uniforms.ncMoon.value * 0.085;
      }
    },
    stats() { return { surfaceMaterials: visited.size, windowProjections: sources.length, moonShafts: beams.length, textures: uniforms.ncTextures.value > 0 }; },
  };
}
