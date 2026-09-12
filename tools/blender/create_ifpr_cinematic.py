import math
import os
import random

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTPUT_DIR = os.path.join(ROOT, "artifacts", "blender")
BLEND_OUTPUT = os.path.join(OUTPUT_DIR, "ifpr1_cinematic.blend")
GLB_OUTPUT = os.path.join(OUTPUT_DIR, "ifpr1_cinematic.glb")
PREVIEW_OUTPUT = os.path.join(OUTPUT_DIR, "ifpr1_cinematic_preview.png")
GRASS_TEXTURE_OUTPUT = os.path.join(OUTPUT_DIR, "whereif_grass_tile.png")


def srgb(hex_color):
    value = hex_color.lstrip("#")
    encoded = tuple(int(value[index:index + 2], 16) / 255 for index in (0, 2, 4))

    def to_linear(channel):
        if channel <= 0.04045:
            return channel / 12.92
        return ((channel + 0.055) / 1.055) ** 2.4

    return tuple(to_linear(channel) for channel in encoded) + (1.0,)


def input_if_present(node, name, value):
    socket = node.inputs.get(name)
    if socket is not None:
        socket.default_value = value


def create_pbr_material(
    name,
    color,
    *,
    metallic=0.0,
    roughness=0.6,
    coat=0.0,
    coat_roughness=0.15,
):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (320, 0)
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (0, 0)
    principled.inputs["Base Color"].default_value = srgb(color)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    input_if_present(principled, "Coat Weight", coat)
    input_if_present(principled, "Coat Roughness", coat_roughness)
    input_if_present(principled, "Specular IOR Level", 0.45)
    material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    material.diffuse_color = srgb(color)
    return material


def create_grass_material():
    size = 256
    image = bpy.data.images.get("WhereIF_GrassTile")
    if image is None:
        image = bpy.data.images.new("WhereIF_GrassTile", width=size, height=size)
    image.colorspace_settings.name = "sRGB"

    rng = random.Random(260906)
    pixels = [0.0] * (size * size * 4)
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            broad = (
                math.sin(math.tau * (u * 3 + v * 2)) * 0.035
                + math.cos(math.tau * (u * 7 - v * 5)) * 0.022
                + math.sin(math.tau * (u * 13 + v * 11)) * 0.012
            )
            grain = (rng.random() - 0.5) * 0.025
            variation = broad + grain
            encoded = (
                max(0.0, min(1.0, 0.075 + variation * 0.45)),
                max(0.0, min(1.0, 0.385 + variation)),
                max(0.0, min(1.0, 0.195 + variation * 0.65)),
            )
            linear = []
            for channel in encoded:
                if channel <= 0.04045:
                    linear.append(channel / 12.92)
                else:
                    linear.append(((channel + 0.055) / 1.055) ** 2.4)
            index = (y * size + x) * 4
            pixels[index:index + 4] = (*linear, 1.0)

    image.pixels.foreach_set(pixels)
    image.filepath_raw = GRASS_TEXTURE_OUTPUT
    image.file_format = "PNG"
    image.save()
    image.pack()

    material = bpy.data.materials.get("WhereIF_Grass") or bpy.data.materials.new(
        "WhereIF_Grass"
    )
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (420, 0)
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (110, 0)
    principled.inputs["Base Color"].default_value = (1, 1, 1, 1)
    principled.inputs["Metallic"].default_value = 0.0
    principled.inputs["Roughness"].default_value = 0.66
    input_if_present(principled, "Coat Weight", 0.11)
    input_if_present(principled, "Coat Roughness", 0.28)
    input_if_present(principled, "Specular IOR Level", 0.38)
    texture = nodes.new("ShaderNodeTexImage")
    texture.location = (-230, 40)
    texture.image = image
    texture.extension = "REPEAT"
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    material.diffuse_color = srgb("#146337")
    return material


def create_planar_uv(object_name, scale=0.055):
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        return
    mesh = obj.data
    uv_layer = mesh.uv_layers.get("WhereIF_GrassUV") or mesh.uv_layers.new(
        name="WhereIF_GrassUV"
    )
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            coordinate = mesh.vertices[vertex_index].co
            uv_layer.data[loop_index].uv = (coordinate.x * scale, coordinate.y * scale)


def assign_material(object_name, material):
    obj = bpy.data.objects.get(object_name)
    if obj is None or obj.type != "MESH":
        return
    obj.data.materials.clear()
    obj.data.materials.append(material)


def assign_many(names, material):
    for name in names:
        assign_material(name, material)


def configure_materials():
    concrete = create_pbr_material(
        "WhereIF_Concrete",
        "#777A7D",
        roughness=0.58,
        coat=0.08,
        coat_roughness=0.32,
    )
    pavement = create_pbr_material(
        "WhereIF_Pavement",
        "#6D7278",
        roughness=0.74,
    )
    campus_ground = create_pbr_material(
        "WhereIF_CampusGround",
        "#A3A7AB",
        roughness=0.66,
        coat=0.06,
        coat_roughness=0.30,
    )
    asphalt = create_pbr_material(
        "WhereIF_Asphalt",
        "#17191C",
        roughness=0.84,
    )
    grass = create_grass_material()
    windows = create_pbr_material(
        "WhereIF_Windows",
        "#202A32",
        metallic=0.08,
        roughness=0.20,
        coat=0.48,
        coat_roughness=0.12,
    )
    dark_metal = create_pbr_material(
        "WhereIF_DarkMetal",
        "#252A2D",
        metallic=0.62,
        roughness=0.30,
        coat=0.16,
        coat_roughness=0.18,
    )

    assign_many(
        [
            "bloco_central",
            "bloco_didatico",
            "canaleta",
            "estaca",
            "muro",
            "portaria",
        ],
        concrete,
    )
    assign_material("calcada_rua", pavement)
    assign_many(["chao_if", "chao_if_2"], campus_ground)
    assign_many(["rua", "rua_if"], asphalt)
    assign_material("grama", grass)
    create_planar_uv("grama")
    assign_many(
        [
            "janelas_preset_central_1",
            "janelas_preset_central_2",
            "janelas_preset_central_3",
            "janelas_preset_didatico_2",
            "janelas_preset_didatico_3",
            "janelas_preset_didatido_1",
            "janelas_preset_portaria_1",
        ],
        windows,
    )

    gate = bpy.data.objects.get("portão")
    if gate and gate.type == "MESH" and not gate.data.materials:
        gate.data.materials.append(dark_metal)
    elif gate and gate.type == "MESH":
        for material in gate.data.materials:
            if not material or not material.use_nodes:
                continue
            principled = next(
                (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
                None,
            )
            if principled:
                principled.inputs["Metallic"].default_value = 0.35
                principled.inputs["Roughness"].default_value = 0.32


def remove_old_lights():
    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj, do_unlink=True)


def add_light(
    name,
    light_type,
    color,
    energy,
    location,
    rotation=None,
    size=None,
    cast_shadow=True,
):
    light_data = bpy.data.lights.new(name=name, type=light_type)
    light_data.color = srgb(color)[:3]
    light_data.energy = energy
    light_data.use_shadow = cast_shadow
    if light_type == "SUN":
        light_data.angle = math.radians(6.0)
    if size is not None and hasattr(light_data, "shape"):
        light_data.shape = "DISK"
        light_data.size = size

    light = bpy.data.objects.new(name, light_data)
    bpy.context.collection.objects.link(light)
    light.location = location
    if rotation is not None:
        light.rotation_euler = rotation
    return light


def configure_lighting():
    remove_old_lights()
    add_light(
        "WhereIF_SunsetKey",
        "SUN",
        "#FFDEC0",
        2.35,
        (160, -180, 240),
        (math.radians(31), math.radians(-18), math.radians(-132)),
    )
    add_light(
        "WhereIF_SkyFill",
        "SUN",
        "#C9DCFF",
        0.72,
        (-120, 80, 190),
        (math.radians(48), math.radians(12), math.radians(42)),
        cast_shadow=False,
    )

    world = bpy.context.scene.world or bpy.data.worlds.new("WhereIF_World")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = srgb("#182433")
    background.inputs["Strength"].default_value = 0.42


def world_bounds(names):
    points = []
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def point_camera(camera, target):
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def configure_camera():
    camera = bpy.data.objects.get("Camera")
    if camera is None:
        camera_data = bpy.data.cameras.new("Camera")
        camera = bpy.data.objects.new("Camera", camera_data)
        bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera.data.type = "PERSP"
    camera.data.lens = 42
    camera.data.sensor_width = 36
    camera.data.sensor_fit = "VERTICAL"
    camera.data.clip_start = 0.1
    camera.data.clip_end = 5000
    camera.data.dof.use_dof = False

    # Conversao do ponto zero aprovado no app: Three.js (x, y, z)
    # corresponde a Blender (x, -z, y).
    camera.location = Vector((145.7349, 186.8265, 54.0019))
    target = Vector((72.8296, 107.2569, 3.2))
    point_camera(camera, target)


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 1280
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.filepath = PREVIEW_OUTPUT

    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.72
    scene.view_settings.gamma = 1.0

    if hasattr(scene, "eevee"):
        if hasattr(scene.eevee, "taa_render_samples"):
            scene.eevee.taa_render_samples = 64
        if hasattr(scene.eevee, "use_raytracing"):
            scene.eevee.use_raytracing = True


def export_glb():
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUTPUT,
        export_format="GLB",
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_apply=False,
    )


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    configure_materials()
    configure_lighting()
    configure_camera()
    configure_render()

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUTPUT)
    bpy.context.scene.render.filepath = PREVIEW_OUTPUT
    bpy.ops.render.render(write_still=True)
    export_glb()
    print("BLEND_OUTPUT", BLEND_OUTPUT)
    print("GLB_OUTPUT", GLB_OUTPUT)
    print("PREVIEW_OUTPUT", PREVIEW_OUTPUT)


if __name__ == "__main__":
    main()
