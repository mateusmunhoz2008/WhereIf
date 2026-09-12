import importlib.util
import math
import os

import bpy
import numpy as np


SCRIPT_DIR = os.path.dirname(__file__)
SPEC = importlib.util.spec_from_file_location(
    "whereif_cinematic_builder",
    os.path.join(SCRIPT_DIR, "create_ifpr_cinematic.py"),
)
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)
base_configure_render = builder.configure_render

builder.BLEND_OUTPUT = os.path.join(builder.OUTPUT_DIR, "ifpr1_ultra.blend")
builder.GLB_OUTPUT = os.path.join(builder.OUTPUT_DIR, "ifpr1_ultra.glb")
builder.PREVIEW_OUTPUT = os.path.join(builder.OUTPUT_DIR, "ifpr1_ultra_preview.png")

TEXTURE_SIZE = 1024


def normalized_field(seed, falloff=1.55):
    rng = np.random.default_rng(seed)
    noise = rng.normal(size=(TEXTURE_SIZE, TEXTURE_SIZE))
    frequencies = np.fft.fftfreq(TEXTURE_SIZE)
    fx, fy = np.meshgrid(frequencies, frequencies)
    radius = np.sqrt(fx * fx + fy * fy)
    spectrum = np.fft.fft2(noise)
    weight = 1.0 / np.maximum(radius, 1.0 / TEXTURE_SIZE) ** falloff
    weight[0, 0] = 0
    field = np.fft.ifft2(spectrum * weight).real
    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field.astype(np.float32)


def save_image(name, pixels, color_space):
    height, width = pixels.shape[:2]
    image = bpy.data.images.get(name) or bpy.data.images.new(name, width=width, height=height)
    image.colorspace_settings.name = color_space
    image.pixels.foreach_set(pixels.astype(np.float32).reshape(-1))
    path = os.path.join(builder.OUTPUT_DIR, f"{name}.png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def surface_images(name, seed, base_hex, variation, bump_strength, roughness_range):
    broad = normalized_field(seed, 1.72)
    fine = normalized_field(seed + 41, 0.72)
    field = np.clip(broad * 0.72 + fine * 0.28, 0, 1)

    encoded = np.array(
        [int(base_hex[index:index + 2], 16) / 255 for index in (1, 3, 5)],
        dtype=np.float32,
    )
    color = np.clip(
        encoded[None, None, :] * (1 + (field[..., None] - 0.5) * variation),
        0,
        1,
    )
    alpha = np.ones((TEXTURE_SIZE, TEXTURE_SIZE, 1), dtype=np.float32)
    color_rgba = np.concatenate((color, alpha), axis=2)

    gradient_x = np.roll(field, -1, axis=1) - np.roll(field, 1, axis=1)
    gradient_y = np.roll(field, -1, axis=0) - np.roll(field, 1, axis=0)
    normal = np.dstack(
        (-gradient_x * bump_strength, -gradient_y * bump_strength, np.ones_like(field))
    )
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-6)
    normal_rgb = normal * 0.5 + 0.5
    normal_rgba = np.concatenate((normal_rgb, alpha), axis=2)

    low, high = roughness_range
    roughness = low + (high - low) * (1 - field)
    roughness_rgba = np.dstack((roughness, roughness, roughness, np.ones_like(field)))

    return (
        save_image(f"{name}_albedo", color_rgba, "sRGB"),
        save_image(f"{name}_normal", normal_rgba, "Non-Color"),
        save_image(f"{name}_roughness", roughness_rgba, "Non-Color"),
    )


def create_textured_material(
    name,
    images,
    *,
    tint="#FFFFFF",
    metallic=0.0,
    normal_scale=1.0,
    coat=0.0,
    coat_roughness=0.2,
):
    albedo, normal, roughness = images
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (650, 0)
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (340, 0)
    principled.inputs["Base Color"].default_value = builder.srgb(tint)
    principled.inputs["Metallic"].default_value = metallic
    builder.input_if_present(principled, "Coat Weight", coat)
    builder.input_if_present(principled, "Coat Roughness", coat_roughness)
    builder.input_if_present(principled, "Specular IOR Level", 0.48)

    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.image = albedo
    albedo_node.extension = "REPEAT"
    albedo_node.location = (-420, 180)
    material.node_tree.links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])

    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_node.extension = "REPEAT"
    normal_node.location = (-420, -30)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = normal_scale
    normal_map.location = (-50, -30)
    material.node_tree.links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    material.node_tree.links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])

    roughness_node = nodes.new("ShaderNodeTexImage")
    roughness_node.image = roughness
    roughness_node.extension = "REPEAT"
    roughness_node.location = (-420, -250)
    material.node_tree.links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])
    material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    material.diffuse_color = builder.srgb(tint)
    return material


def configure_ultra_materials():
    grass_maps = surface_images(
        "whereif_ultra_grass", 901, "#185A3A", 0.24, 5.0, (0.52, 0.76)
    )
    street_maps = surface_images(
        "whereif_ultra_street", 1901, "#25282C", 0.10, 2.4, (0.68, 0.85)
    )
    campus_street_maps = surface_images(
        "whereif_ultra_campus_street", 1901, "#444A51", 0.10, 2.2, (0.62, 0.80)
    )
    concrete_maps = surface_images(
        "whereif_ultra_concrete", 2901, "#85898D", 0.08, 1.0, (0.46, 0.62)
    )
    ground_maps = surface_images(
        "whereif_ultra_ground", 3901, "#9A9EA2", 0.07, 0.8, (0.50, 0.68)
    )
    pavement_maps = surface_images(
        "whereif_ultra_pavement", 4901, "#777C82", 0.08, 1.2, (0.58, 0.74)
    )

    grass = create_textured_material(
        "WhereIF_Ultra_Grass", grass_maps, normal_scale=0.92, coat=0.02, coat_roughness=0.48
    )
    street = create_textured_material(
        "WhereIF_Ultra_Street", street_maps, normal_scale=0.62, coat=0.05
    )
    campus_street = create_textured_material(
        "WhereIF_Ultra_CampusStreet",
        campus_street_maps,
        normal_scale=0.58,
        coat=0.08,
        coat_roughness=0.28,
    )
    concrete = create_textured_material(
        "WhereIF_Ultra_Concrete",
        concrete_maps,
        normal_scale=0.32,
        coat=0.22,
        coat_roughness=0.20,
    )
    campus_ground = create_textured_material(
        "WhereIF_Ultra_CampusGround",
        ground_maps,
        normal_scale=0.28,
        coat=0.16,
        coat_roughness=0.24,
    )
    pavement = create_textured_material(
        "WhereIF_Ultra_Pavement",
        pavement_maps,
        normal_scale=0.30,
        coat=0.08,
        coat_roughness=0.30,
    )
    windows = builder.create_pbr_material(
        "WhereIF_Ultra_Windows",
        "#111C26",
        metallic=0.16,
        roughness=0.09,
        coat=0.82,
        coat_roughness=0.06,
    )

    builder.assign_many(
        ["bloco_central", "bloco_didatico", "canaleta", "estaca", "muro", "portaria"],
        concrete,
    )
    builder.assign_material("calcada_rua", pavement)
    builder.assign_many(["chao_if", "chao_if_2"], campus_ground)
    builder.assign_material("rua", street)
    builder.assign_material("rua_if", campus_street)
    builder.assign_material("grama", grass)

    for name in [
        "grama",
        "rua",
        "rua_if",
        "calcada_rua",
        "chao_if",
        "chao_if_2",
        "bloco_central",
        "bloco_didatico",
        "canaleta",
        "estaca",
        "muro",
        "portaria",
    ]:
        builder.create_planar_uv(name, scale=0.105 if name == "grama" else 0.07)

    builder.assign_many(
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
    if gate and gate.type == "MESH":
        for material in gate.data.materials:
            if not material or not material.node_tree:
                continue
            principled = next(
                (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
                None,
            )
            if principled:
                principled.inputs["Metallic"].default_value = 0.62
                principled.inputs["Roughness"].default_value = 0.20
                builder.input_if_present(principled, "Coat Weight", 0.42)


def configure_ultra_render():
    base_configure_render()
    scene = bpy.context.scene
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.view_settings.exposure = 0.82
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = 128


builder.configure_materials = configure_ultra_materials
builder.configure_render = configure_ultra_render
builder.main()
