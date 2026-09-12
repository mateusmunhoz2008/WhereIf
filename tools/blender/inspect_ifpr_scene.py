import bpy


def material_summary(material):
    principled = None
    if material.use_nodes and material.node_tree:
        principled = next(
            (
                node
                for node in material.node_tree.nodes
                if node.type == "BSDF_PRINCIPLED"
            ),
            None,
        )

    base_color = None
    metallic = None
    roughness = None
    if principled:
        base_color = tuple(round(value, 4) for value in principled.inputs["Base Color"].default_value)
        metallic = round(principled.inputs["Metallic"].default_value, 4)
        roughness = round(principled.inputs["Roughness"].default_value, 4)

    return {
        "name": material.name,
        "nodes": len(material.node_tree.nodes) if material.use_nodes and material.node_tree else 0,
        "base_color": base_color,
        "metallic": metallic,
        "roughness": roughness,
        "blend_method": getattr(material, "surface_render_method", None),
    }


print("=== SCENE ===")
print("file:", bpy.data.filepath)
print("objects:", len(bpy.data.objects))
print("materials:", len(bpy.data.materials))
print("world:", bpy.context.scene.world.name if bpy.context.scene.world else None)
print("render_engine:", bpy.context.scene.render.engine)
print("resolution:", bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y)
print("camera:", bpy.context.scene.camera.name if bpy.context.scene.camera else None)
if bpy.context.scene.camera:
    camera = bpy.context.scene.camera
    print("camera_location:", tuple(round(value, 4) for value in camera.location))
    print("camera_rotation:", tuple(round(value, 4) for value in camera.rotation_euler))
    print("camera_lens:", camera.data.lens)

print("=== OBJECTS ===")
for obj in bpy.data.objects:
    if obj.type not in {"MESH", "LIGHT", "CAMERA"}:
        continue
    dimensions = tuple(round(value, 3) for value in obj.dimensions)
    location = tuple(round(value, 3) for value in obj.location)
    material_names = [slot.material.name for slot in obj.material_slots if slot.material]
    print(
        obj.type,
        obj.name,
        "location=",
        location,
        "dims=",
        dimensions,
        "materials=",
        material_names,
    )

print("=== MATERIALS ===")
for material in bpy.data.materials:
    print(material_summary(material))
    if material.node_tree:
        for node in material.node_tree.nodes:
            print("  NODE", node.name, node.type)
        for link in material.node_tree.links:
            print(
                "  LINK",
                link.from_node.name,
                link.from_socket.name,
                "->",
                link.to_node.name,
                link.to_socket.name,
            )

print("=== LIGHTS ===")
for light in bpy.data.lights:
    print(light.name, light.type, "energy=", light.energy, "color=", tuple(light.color))
