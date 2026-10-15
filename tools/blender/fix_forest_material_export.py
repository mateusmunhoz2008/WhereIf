"""Repair the saved forest shaders, validate export, then save in place."""
import bpy
import hashlib
import json
import pathlib
import shutil
import struct
import sys
from datetime import datetime, timezone

args = sys.argv[sys.argv.index('--') + 1:]
assert len(args) == 2, 'Expected existing .blend and target .glb paths'
source = pathlib.Path(args[0]).resolve()
target = pathlib.Path(args[1]).resolve()
workspace = pathlib.Path(__file__).resolve().parents[2]
assert pathlib.Path(bpy.data.filepath).resolve() == source
assert source.is_file() and target.is_file()
original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
target_hash = hashlib.sha256(target.read_bytes()).hexdigest()
backup = workspace / 'recovery' / ('forest-materials-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
backup.mkdir(parents=True, exist_ok=False)
shutil.copy2(source, backup / source.name)
shutil.copy2(target, backup / target.name)

changed = []
for material in bpy.data.materials:
    if not material.name.startswith('Material.') or not material.node_tree:
        continue
    tree = material.node_tree
    linked = [link for link in tree.links
              if link.from_node.type == 'BSDF_PRINCIPLED'
              and link.to_node.type == 'OUTPUT_MATERIAL'
              and link.to_socket.name == 'Surface']
    assert len(linked) == 1, 'Ambiguous Principled output: ' + material.name
    output = linked[0].to_node
    for node in tree.nodes:
        if node.type == 'OUTPUT_MATERIAL' and node != output and node.target == 'ALL':
            node.target = 'CYCLES'
    output.target = 'ALL'
    output.is_active_output = True
    changed.append(material.name)
assert len(changed) == 6, 'Expected the six original leaf/trunk materials'

staged = workspace / 'build' / 'map-material-diagnostic' / 'corrected-campus.glb'
staged.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(staged), export_format='GLB', use_selection=False,
    use_visible=False, use_renderable=False, use_active_collection=False,
    use_active_scene=True, export_apply=True, export_animations=False,
    export_skins=False, export_morph=False, export_cameras=False,
    export_lights=False, export_materials='EXPORT',
    export_gn_mesh=False, export_gpu_instances=False,
)
raw = staged.read_bytes()
assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 8)[0] == len(raw)
gltf = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
exported_materials = {material['name']: material for material in gltf['materials']}
for name in changed:
    assert len(exported_materials[name]['pbrMetallicRoughness']['baseColorFactor']) == 4, name
names = {node.get('name') for node in gltf['nodes']}
metadata = json.loads((workspace / 'assets/institutions/ifpr-pgua/map/campus_map.json').read_text(encoding='utf-8'))
for zone in metadata['zones']:
    assert zone['nodeName'] in names
    for floor in zone.get('floors', []):
        for name in floor['nodeNames'] + [space['nodeName'] for space in floor['spaces']]:
            assert name in names, name
forest = {}
for node in gltf['nodes']:
    if node.get('name') not in ('Plano', 'Plano.1'):
        continue
    primitives = gltf['meshes'][node['mesh']]['primitives']
    triangles = sum(gltf['accessors'][primitive['indices']]['count'] // 3 for primitive in primitives)
    assert triangles > 10000, 'Forest geometry missing'
    assert len(primitives) == 6, 'Forest material groups missing'
    forest[node['name']] = triangles
assert len(forest) == 2
assert hashlib.sha256(source.read_bytes()).hexdigest() == original_hash, 'Blend changed during repair; refusing overwrite'
assert hashlib.sha256(target.read_bytes()).hexdigest() == target_hash, 'GLB changed during repair; refusing overwrite'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
shutil.copy2(staged, target)
print('REPAIR_RESULT', json.dumps({
    'blend': str(source), 'glb': str(target), 'backup': str(backup),
    'bytes': len(raw), 'forest': forest,
    'colors': {name: exported_materials[name]['pbrMetallicRoughness']['baseColorFactor'] for name in changed},
}, ensure_ascii=False))
