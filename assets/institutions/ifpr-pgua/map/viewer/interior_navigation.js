import * as THREE from './vendor/three.module.min.js';

// Floors stay detached during exterior preparation, then return to their
// original world positions. The first floor remains beneath upper floors.
export function createInteriorNavigation(root, zones, findNode, campusScene, accent = '#a64cff') {
  const scene = campusScene;
  const floors = new Map();
  const ownedMaterials = new Set();
  const ownedGeometry = new Set();
  const savedMaterials = new Map();
  const exposureCompensation = { value: 1 };
  root.updateMatrixWorld(true);
  for (const zone of zones) {
    for (const definition of zone.floors ?? []) {
      const group = new THREE.Group();
      group.name = definition.id;
      const spaces = [];
      for (const name of definition.nodeNames) {
        const node = findNode(root, name);
        if (!node) throw new Error(`Interior ausente no modelo: ${name}`);
        group.attach(node);
      }
      for (const space of definition.spaces) {
        const node = findNode(root, space.nodeName);
        if (!node) throw new Error(`Espaço ausente no modelo: ${space.nodeName}`);
        group.attach(node);
        spaces.push({ ...space, node, bounds: new THREE.Box3().setFromObject(node) });
      }
      group.updateMatrixWorld(true);
      group.traverse(node => {
        if (!node.isMesh) return;
        const preserve = source => {
          if (!savedMaterials.has(source)) {
            const copy = source.clone();
            savedMaterials.set(source, copy);
            ownedMaterials.add(copy);
          }
          return savedMaterials.get(source);
        };
        node.material = Array.isArray(node.material) ? node.material.map(preserve) : preserve(node.material);
      });
      const bounds = new THREE.Box3().setFromObject(group);
      const floorY = Math.min(...spaces.map(space => space.bounds.min.y));
      // The exported staircase of p2 extends down into p1; navigation stays on p2.
      bounds.min.y = floorY;
      floors.set(definition.id, { ...definition, zoneId: zone.id, group, spaces,
        bounds, floorY, roomPickNodes: spaces.map(space => space.node),
        markerPickNodes: [], prepared: false, gpuReady: false });
    }
  }
  let current = null;
  const activeFloors = new Set();
  let selected = null;
  const accentColor = new THREE.Color(accent);

  function prepare(floor) {
    if (floor.prepared) { restoreFloorMaterials(floor); return; }
    floor.materialAssignments = new Map();
    const cache = new Map();
    const spaceTints = new WeakMap();
    for (const space of floor.spaces) {
      const tint = space.nodeName.startsWith('lab_') ? '#91c7bb'
        : space.nodeName.startsWith('wc_') ? '#c8b9a1' : '#aabedb';
      space.node.traverse(node => { spaceTints.set(node, tint); });
    }
    floor.group.traverse(node => {
      if (!node.isMesh) return;
      const convert = source => {
        const tint = spaceTints.get(node);
        const key = `${source.uuid}:${tint ?? 'neutral'}`;
        if (cache.has(key)) return cache.get(key);
        const material = new THREE.MeshLambertMaterial({
          color: source.color?.clone() ?? new THREE.Color('white'),
          map: source.map ?? null, vertexColors: source.vertexColors === true,
          side: THREE.DoubleSide,
          transparent: source.transparent === true, opacity: source.opacity ?? 1,
          alphaTest: source.alphaTest ?? 0, toneMapped: false,
        });
        if (tint) material.color.multiply(new THREE.Color(tint));
        // Keep rooms readable under every climate, with restrained sunlight.
        material.onBeforeCompile = shader => {
          shader.uniforms.interiorExposureCompensation = exposureCompensation;
          shader.vertexShader = `varying vec3 vInteriorNormal;\n${shader.vertexShader}`
            .replace('#include <begin_vertex>', `#include <begin_vertex>
              vInteriorNormal = normalize(mat3(modelMatrix) * normal);`);
          shader.fragmentShader = `varying vec3 vInteriorNormal;
            uniform float interiorExposureCompensation;\n${shader.fragmentShader}`
            .replace('#include <tonemapping_fragment>', `
              vec3 interiorNormal = normalize(vInteriorNormal)
                * (gl_FrontFacing ? 1.0 : -1.0);
              float interiorShade = 0.38 + 0.72 * pow(max(0.0, dot(
                interiorNormal, normalize(vec3(-0.55, 1.0, 0.35)))), 0.8);
              vec3 interiorNeutral = diffuseColor.rgb * interiorShade;
              gl_FragColor.rgb = mix(interiorNeutral,
                min(gl_FragColor.rgb, diffuseColor.rgb * 1.1), 0.12)
                * interiorExposureCompensation;
              #include <tonemapping_fragment>`);
        };
        material.customProgramCacheKey = () => 'interior-neutral-light-v2';
        cache.set(key, material);
        ownedMaterials.add(material);
        return material;
      };
      node.material = Array.isArray(node.material) ? node.material.map(convert) : convert(node.material);
      floor.materialAssignments.set(node, node.material);
      node.castShadow = false;
      node.receiveShadow = false;
    });
    for (const space of floor.spaces) {
      const size = space.bounds.getSize(new THREE.Vector3());
      const center = space.bounds.getCenter(new THREE.Vector3());
      const geometry = new THREE.PlaneGeometry(Math.max(0.1, size.x - 0.15), Math.max(0.1, size.z - 0.15));
      const material = new THREE.MeshBasicMaterial({ color: accentColor, transparent: true,
        opacity: 0, colorWrite: false, depthWrite: false,
        side: THREE.DoubleSide, toneMapped: false });
      const marker = new THREE.Mesh(geometry, material);
      // These rectangles are CPU hit targets, not visual geometry. Raycaster
      // still intersects hidden meshes; do not pay a transparent draw per room.
      marker.visible = false;
      marker.rotation.x = -Math.PI / 2;
      marker.position.set(center.x, space.bounds.min.y + 0.09, center.z);
      marker.userData.interiorSpace = space;
      space.marker = marker;
      floor.group.add(marker);
      ownedGeometry.add(geometry);
      ownedMaterials.add(material);
      space.node.traverse(node => { node.userData.interiorSpace = space; });
    }
    floor.markerPickNodes = floor.spaces.map(space => space.marker);
    floor.group.updateMatrixWorld(true);
    floor.group.traverse(node => { node.matrixAutoUpdate = false; });
    floor.prepared = true;
  }

  function restoreFloorMaterials(floor) {
    for(const [node,material] of floor.materialAssignments??[]) {
      node.material=material;node.castShadow=false;node.receiveShadow=false;
    }
  }

  function clearSelection() {
    selected = null;
  }
  function leave() {
    clearSelection();
    for (const floor of activeFloors) {
      floor.group.removeFromParent();
    }
    activeFloors.clear();
    current = null;
  }
  const pickHits = [];
  const pickCandidates = [];
  const baseFloors = new Map();
  for (const floor of floors.values()) if (!baseFloors.has(floor.zoneId)) baseFloors.set(floor.zoneId, floor);
  return {
    scene, floors,
    get current() { return current; },
    get activeFloors() { return [...activeFloors]; },
    get selected() { return selected; },
    restorePreparedMaterials() {
      for(const floor of floors.values())if(floor.prepared)restoreFloorMaterials(floor);
    },
    setExposure(exposure) { exposureCompensation.value = 1 / Math.max(0.1, exposure); },
    enter(id) {
      const floor = floors.get(id);
      if (!floor) throw new Error('Andar não encontrado.');
      const baseFloor = baseFloors.get(floor.zoneId);
      const visibleFloors = baseFloor === floor ? [floor] : [baseFloor, floor];
      for (const entry of visibleFloors) prepare(entry);
      leave();
      current = floor;
      for (const entry of visibleFloors) {
        scene.add(entry.group);
        activeFloors.add(entry);
      }
      return floor;
    },
    leave,
    pick(raycaster) {
      if (!current) return null;
      pickHits.length = 0; pickCandidates.length = 0;
      for (const space of current.spaces) {
        if (raycaster.ray.intersectsBox(space.bounds)) pickCandidates.push(space.node);
      }
      if (current.zoneId === 'bloco-central') {
        // The curved Central rooms are not rectangles. Their world-aligned
        // bounds overlap, so rectangular floor markers can steal adjacent taps.
        // Raycast the exported room surfaces instead (including their walls).
        const hit = raycaster.intersectObjects(pickCandidates, true, pickHits)[0];
        return hit?.object.userData.interiorSpace ?? null;
      }
      const markerHit = raycaster.intersectObjects(current.markerPickNodes, false, pickHits)[0];
      if (markerHit) return markerHit.object.userData.interiorSpace;
      pickHits.length = 0;
      const hit = raycaster.intersectObjects(pickCandidates, true, pickHits)[0];
      return hit?.object.userData.interiorSpace ?? null;
    },
    select(space) {
      clearSelection();
      selected = space;
    },
    update() { return false; },
    dispose() {
      leave();
      for (const floor of floors.values()) floor.group.traverse(node => {
        if (node.geometry) ownedGeometry.add(node.geometry);
      });
      for (const geometry of ownedGeometry) geometry.dispose();
      const textures = new Set();
      for (const material of ownedMaterials) {
        for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
      }
      for (const material of ownedMaterials) material.dispose();
      for (const texture of textures) texture.dispose();
      floors.clear();
    },
  };
}
