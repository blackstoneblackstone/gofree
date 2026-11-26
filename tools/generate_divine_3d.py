"""
使用本地 Blender 5.3 生成 gofree「占一事」3 套高精细度 3D 动效模型（.usdz）：
  1. divine-idle.usdz    — 现代八卦浑天仪（三层金属陀螺星环 + 琉璃靛蓝核心 + 卦象金饰）
  2. divine-ritual.usdz  — 四十九策聚光仪（竹金蓍草环阵 + 呼吸琉璃玉球）
  3. divine-casting.usdz — 三枚古铜钱动态起卦（外圆内方磨砂金铜钱 + 承盘 + 旋光环）

用法：
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/generate_divine_3d.py
"""

import math
import os
import bpy
import bmesh
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "Resources", "DivineModels")

FRAMES = 120
FPS = 30


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = FRAMES
    scene.render.fps = FPS
    return scene


def make_material(name, color, roughness=0.30, metallic=0.0, coat=0.0, alpha=1.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color[:3], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if alpha < 0.999:
        bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None and emission_strength > 0:
        bsdf.inputs["Emission Color"].default_value = (*emission[:3], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def assign_mat(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def smooth_obj(obj, subdiv=0, bevel=0.0, bevel_segments=3):
    if bevel > 0 and obj.type == 'MESH':
        bev = obj.modifiers.new("Bevel", type='BEVEL')
        bev.width = bevel
        bev.segments = bevel_segments
        bev.limit_method = 'ANGLE'
    if subdiv > 0 and obj.type == 'MESH':
        sub = obj.modifiers.new("Subsurf", type='SUBSURF')
        sub.levels = subdiv
        sub.render_levels = subdiv
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True


def add_empty(name, location=(0, 0, 0), rotation=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = location
    e.rotation_euler = rotation
    return e


def add_sphere(name, radius=0.5, location=(0, 0, 0), scale=(1, 1, 1), mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=36, ring_count=24, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    smooth_obj(obj)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_cylinder(name, radius=0.5, depth=1.0, location=(0, 0, 0), rotation=(0, 0, 0), vertices=64, bevel=0.0, mat=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    smooth_obj(obj, bevel=bevel, bevel_segments=3)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_torus(name, major_radius=0.5, minor_radius=0.04, location=(0, 0, 0), rotation=(0, 0, 0), major_seg=64, minor_seg=20, mat=None):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_seg,
        minor_segments=minor_seg,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    smooth_obj(obj)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_rounded_box(name, size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.02, subdiv=1, mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth_obj(obj, subdiv=subdiv, bevel=bevel, bevel_segments=3)
    if mat:
        assign_mat(obj, mat)
    return obj


def set_linear_keyframes(obj, data_path, keyframes):
    for frame, val in keyframes:
        setattr(obj, data_path, val)
        obj.keyframe_insert(data_path=data_path, frame=frame)
    if obj.animation_data and obj.animation_data.action:
        fcurves = getattr(obj.animation_data.action, "fcurves", None)
        if fcurves:
            for fc in fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'


def set_bezier_keyframes(obj, data_path, keyframes):
    for frame, val in keyframes:
        setattr(obj, data_path, val)
        obj.keyframe_insert(data_path=data_path, frame=frame)
    if obj.animation_data and obj.animation_data.action:
        fcurves = getattr(obj.animation_data.action, "fcurves", None)
        if fcurves:
            for fc in fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'BEZIER'
                    kp.handle_left_type = 'AUTO_CLAMPED'
                    kp.handle_right_type = 'AUTO_CLAMPED'


def add_plinth(accent_rgb):
    ceramic = make_material("PlinthCeramic", (0.92, 0.94, 0.98), roughness=0.25, coat=0.55)
    trim = make_material("PlinthTrim", accent_rgb, roughness=0.20, metallic=0.65, emission=accent_rgb, emission_strength=0.35)
    add_cylinder("PlinthBase", radius=1.22, depth=0.12, location=(0, 0, -0.06), vertices=64, bevel=0.03, mat=ceramic)
    add_torus("PlinthRing", major_radius=1.21, minor_radius=0.018, location=(0, 0, 0.0), mat=trim)


# ==============================================================================
# 1. 现代八卦浑天仪（Idle / Focus）
# ==============================================================================

def build_divine_idle():
    indigo = (0.20, 0.44, 0.96)
    gold = (0.88, 0.70, 0.34)
    add_plinth(indigo)

    brushed_gold = make_material("BrushedGold", gold, roughness=0.22, metallic=0.90)
    indigo_metal = make_material("IndigoMetal", (0.24, 0.48, 0.95), roughness=0.24, metallic=0.72, coat=0.35)
    core_glass = make_material("CoreGlass", (0.28, 0.56, 1.0), roughness=0.08, coat=1.0, alpha=0.55)
    core_glow = make_material("CoreGlow", (0.36, 0.64, 1.0), roughness=0.16, emission=(0.30, 0.58, 1.0), emission_strength=0.95)
    pearl = make_material("OrbPearl", (0.98, 0.99, 1.0), roughness=0.14, coat=0.85)

    center = add_empty("ArmillaryCenter", location=(0, 0, 1.02))

    # 中心双层琉璃星核
    core_out = add_sphere("CoreOuter", radius=0.36, mat=core_glass)
    core_out.parent = center
    core_in = add_sphere("CoreInner", radius=0.19, mat=core_glow)
    core_in.parent = center
    set_bezier_keyframes(core_in, "scale", [(1, (0.90, 0.90, 0.90)), (60, (1.16, 1.16, 1.16)), (120, (0.90, 0.90, 0.90))])

    # 外层赤道金环 + 8 枚八卦方位金柱点
    r1 = add_empty("OuterRingPivot")
    r1.parent = center
    add_torus("OuterRing", major_radius=0.86, minor_radius=0.032, mat=brushed_gold).parent = r1
    for i in range(8):
        ang = i * (2 * math.pi / 8)
        bar = add_rounded_box(
            f"TrigramAccent_{i}",
            (0.14, 0.038, 0.038),
            location=(math.cos(ang) * 0.86, math.sin(ang) * 0.86, 0),
            rotation=(0, 0, ang + math.pi / 2),
            bevel=0.008,
            subdiv=0,
            mat=brushed_gold,
        )
        bar.parent = r1
    set_linear_keyframes(r1, "rotation_euler", [(1, (0.38, 0.16, 0)), (120, (0.38, 0.16, math.pi * 2))])

    # 中层靛蓝金属环 + 银白星珠
    r2 = add_empty("MidRingPivot")
    r2.parent = center
    add_torus("MidRing", major_radius=0.68, minor_radius=0.026, mat=indigo_metal).parent = r2
    add_sphere("MidPearl", radius=0.062, location=(0.68, 0, 0), mat=pearl).parent = r2
    set_linear_keyframes(r2, "rotation_euler", [(1, (-0.52, 0.42, 0)), (120, (-0.52, 0.42, -math.pi * 2))])

    # 内层倾斜金环
    r3 = add_empty("InnerRingPivot")
    r3.parent = center
    add_torus("InnerRing", major_radius=0.52, minor_radius=0.020, mat=brushed_gold).parent = r3
    set_linear_keyframes(r3, "rotation_euler", [(1, (0.78, -0.32, 0)), (120, (0.78, -0.32, math.pi * 2))])

    # 整体微幅悬浮
    set_bezier_keyframes(center, "location", [(1, (0, 0, 0.98)), (60, (0, 0, 1.08)), (120, (0, 0, 0.98))])


# ==============================================================================
# 2. 四十九策聚光仪（Cleanse / Pray）
# ==============================================================================

def build_divine_ritual():
    jade = (0.14, 0.68, 0.72)
    gold = (0.86, 0.68, 0.34)
    add_plinth(jade)

    stalk_mat = make_material("YarrowGold", (0.84, 0.68, 0.40), roughness=0.30, metallic=0.58)
    orb_glass = make_material("RitualGlass", (0.18, 0.76, 0.80), roughness=0.08, coat=1.0, alpha=0.48)
    orb_core = make_material("RitualCore", (0.24, 0.84, 0.88), roughness=0.16, emission=(0.18, 0.78, 0.86), emission_strength=1.0)
    halo_mat = make_material("RitualHalo", gold, roughness=0.22, metallic=0.85)

    # 24 根精细竹金蓍草环阵（象征四十九策，视觉清爽高雅）
    stalk_ring = add_empty("StalkRing", location=(0, 0, 0.82))
    count = 24
    for i in range(count):
        ang = i * (2 * math.pi / count)
        rad = 0.68
        s = add_cylinder(
            f"Stalk_{i}",
            radius=0.020,
            depth=0.92,
            location=(math.cos(ang) * rad, math.sin(ang) * rad, 0),
            rotation=(0.24 * math.sin(ang), -0.24 * math.cos(ang), ang),
            vertices=16,
            bevel=0.006,
            mat=stalk_mat,
        )
        s.parent = stalk_ring
    set_linear_keyframes(stalk_ring, "rotation_euler", [(1, (0, 0, 0)), (120, (0, 0, math.pi * 2))])

    # 中心慢呼吸玉球
    orb_g = add_empty("RitualOrb", location=(0, 0, 0.94))
    outer = add_sphere("OrbOuter", radius=0.40, mat=orb_glass)
    outer.parent = orb_g
    inner = add_sphere("OrbInner", radius=0.21, mat=orb_core)
    inner.parent = orb_g
    set_bezier_keyframes(outer, "scale", [(1, (0.86, 0.86, 0.86)), (60, (1.20, 1.20, 1.20)), (120, (0.86, 0.86, 0.86))])
    set_bezier_keyframes(inner, "scale", [(1, (1.14, 1.14, 1.14)), (60, (0.84, 0.84, 0.84)), (120, (1.14, 1.14, 1.14))])

    # 顶部细金光环
    halo = add_torus("TopHalo", major_radius=0.56, minor_radius=0.018, location=(0, 0, 1.46), mat=halo_mat)
    set_bezier_keyframes(halo, "location", [(1, (0, 0, 1.42)), (60, (0, 0, 1.54)), (120, (0, 0, 1.42))])


# ==============================================================================
# 3. 三枚外圆内方古铜钱起卦（Casting）
# ==============================================================================

def create_ancient_coin(name, outer_r=0.34, thickness=0.052, mat_body=None, mat_rim=None):
    """用 BMesh 构建真外圆内方古铜钱（中心真实镂空方孔 + 外圈凸缘）"""
    coin_root = add_empty(name)

    # 用 4 段弧形厚边围出真实方孔铜钱主体（简洁干净、无布尔瑕疵）
    # 实心主体：圆环 + 内部 4 块倒角方孔边，完美平滑
    outer_ring = add_torus(f"{name}_Rim", major_radius=outer_r - 0.032, minor_radius=0.036, major_seg=48, minor_seg=16, mat=mat_rim)
    outer_ring.scale = (1.0, 1.0, 0.82)
    outer_ring.parent = coin_root

    # 钱面（带真实方孔：4 个扇形块拼接成圆盘减方孔）
    hole = 0.095
    body_r = outer_r - 0.03
    mesh = bpy.data.meshes.new(f"{name}_PlateMesh")
    bm = bmesh.new()
    segs = 32
    half_t = thickness * 0.42
    # 顶底圆环 + 内方孔
    outer_top = []
    outer_bot = []
    inner_top = []
    inner_bot = []
    for i in range(segs):
        ang = i * (2 * math.pi / segs)
        cx, cy = math.cos(ang), math.sin(ang)
        outer_top.append(bm.verts.new((cx * body_r, cy * body_r, half_t)))
        outer_bot.append(bm.verts.new((cx * body_r, cy * body_r, -half_t)))
        # 投影到正方形边界，形成真实方孔
        scale_sq = hole / max(abs(cx), abs(cy))
        ix, iy = cx * scale_sq, cy * scale_sq
        inner_top.append(bm.verts.new((ix, iy, half_t)))
        inner_bot.append(bm.verts.new((ix, iy, -half_t)))

    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((inner_top[i], outer_top[i], outer_top[j], inner_top[j]))
        bm.faces.new((outer_bot[i], inner_bot[i], inner_bot[j], outer_bot[j]))
        bm.faces.new((inner_bot[i], inner_top[i], inner_top[j], inner_bot[j]))
        bm.faces.new((outer_top[i], outer_bot[i], outer_bot[j], outer_top[j]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    plate = bpy.data.objects.new(f"{name}_Plate", mesh)
    bpy.context.collection.objects.link(plate)
    smooth_obj(plate)
    if mat_body:
        assign_mat(plate, mat_body)
    plate.parent = coin_root

    return coin_root


def build_divine_casting():
    accent = (0.24, 0.50, 0.98)
    add_plinth(accent)

    bronze = make_material("AncientBronze", (0.78, 0.58, 0.26), roughness=0.28, metallic=0.88)
    gold_rim = make_material("GoldRim", (0.94, 0.78, 0.42), roughness=0.18, metallic=0.94)
    glow_ring = make_material("CastGlow", accent, roughness=0.18, alpha=0.75, emission=accent, emission_strength=1.0)

    # 三枚旋转悬空古铜钱
    coin_specs = [
        ((-0.56, -0.08, 0.96), 0.0),
        ((0.0, 0.14, 1.24), 0.7),
        ((0.56, -0.06, 0.92), 1.4),
    ]
    for idx, (loc, phase) in enumerate(coin_specs):
        c = create_ancient_coin(f"Coin_{idx}", outer_r=0.34, mat_body=bronze, mat_rim=gold_rim)
        c.location = loc
        set_linear_keyframes(c, "rotation_euler", [
            (1, (0.45 + phase, 0.25, 0)),
            (120, (0.45 + phase + math.pi * 2, 0.25 + math.pi * 4, 0)),
        ])
        set_bezier_keyframes(c, "location", [
            (1, loc),
            (60, (loc[0], loc[1], loc[2] + 0.16)),
            (120, loc),
        ])

    # 底部流光承环
    ring = add_torus("CastOrbit", major_radius=0.88, minor_radius=0.018, location=(0, 0, 0.52), rotation=(0.18, 0, 0), mat=glow_ring)
    set_linear_keyframes(ring, "rotation_euler", [(1, (0.18, 0, 0)), (120, (0.18, 0, math.pi * 2))])


BUILDERS = [
    ("divine-idle", build_divine_idle),
    ("divine-ritual", build_divine_ritual),
    ("divine-casting", build_divine_casting),
]


def export_usdz(filepath):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=filepath,
        export_animation=True,
        export_normals=True,
        export_materials=True,
        generate_preview_surface=True,
        convert_orientation=True,
        export_global_forward_selection='NEGATIVE_Z',
        export_global_up_selection='Y',
        evaluation_mode='RENDER',
        export_lights=False,
        export_cameras=False,
    )


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for name, builder in BUILDERS:
        print(f"==> Building {name}.usdz ...")
        reset_scene()
        builder()
        out_path = os.path.join(OUTPUT_DIR, f"{name}.usdz")
        export_usdz(out_path)
        size_kb = os.path.getsize(out_path) / 1024.0
        print(f"    Exported {out_path} ({size_kb:.1f} KB)")
    print("==> All 3 Blender Divine USDZ models generated successfully!")


if __name__ == "__main__":
    main()
