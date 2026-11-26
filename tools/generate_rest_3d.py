"""
使用本地 Blender 5.3 生成 gofree「定时休息」8 套高精细度微缩 3D 模型（.usdz），
带 Subdivision Surface 平滑、Bevel 倒角、Solidify 实心杯壁、Bezier 曲线管状建模、
Principled BSDF 材质（导出 UsdPreviewSurface）以及 120 帧无缝循环关键帧动画。

用法：
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/generate_rest_3d.py
"""

import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector, Euler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "Resources", "RestModels")
PREVIEW_DIR = os.environ.get("REST3D_PREVIEW_DIR", "")

FRAMES = 120
FPS = 30


# ==============================================================================
# 通用清理与材质/建模工具
# ==============================================================================

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = FRAMES
    scene.render.fps = FPS
    return scene


def make_material(
    name,
    color,
    roughness=0.35,
    metallic=0.0,
    coat=0.0,
    coat_roughness=0.12,
    alpha=1.0,
    emission=None,
    emission_strength=0.0,
):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color[:3], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = coat_roughness
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
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel
        bev.segments = bevel_segments
        bev.limit_method = 'ANGLE'
    if subdiv > 0 and obj.type == 'MESH':
        sub = obj.modifiers.new(name="Subsurf", type='SUBSURF')
        sub.levels = subdiv
        sub.render_levels = subdiv
    if obj.type == 'MESH':
        for poly in obj.data.polygons:
            poly.use_smooth = True


def add_rounded_box(name, size, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.04, subdiv=1, mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth_obj(obj, subdiv=subdiv, bevel=bevel, bevel_segments=4)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_sphere(name, radius=0.5, location=(0, 0, 0), scale=(1, 1, 1), segments=32, rings=20, mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    smooth_obj(obj)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_cylinder(name, radius=0.5, depth=1.0, location=(0, 0, 0), rotation=(0, 0, 0), vertices=48, bevel=0.0, mat=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    smooth_obj(obj, bevel=bevel, bevel_segments=3)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_torus(name, major_radius=0.5, minor_radius=0.08, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), major_seg=48, minor_seg=20, mat=None):
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
    obj.scale = scale
    smooth_obj(obj)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_capsule(name, radius=0.12, length=0.6, location=(0, 0, 0), rotation=(0, 0, 0), mat=None):
    """用平滑柱体 + 两端半球 + Subsurf 构建精致圆润胶囊"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    cyl_h = max(0.01, length - 2 * radius)
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=radius)
    # 拉伸上下半球形成胶囊
    half = cyl_h * 0.5
    for v in bm.verts:
        if v.co.z > 0.0001:
            v.co.z += half
        elif v.co.z < -0.0001:
            v.co.z -= half
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    smooth_obj(obj, subdiv=1)
    if mat:
        assign_mat(obj, mat)
    return obj


def add_bezier_tube(name, points, radius=0.05, resolution=24, bevel_res=10, mat=None, cyclic=False):
    """用 Bezier 曲线 + 管状倒角生成有机弧线并转成平滑 Mesh（完美兼容 USDZ）"""
    curve_data = bpy.data.curves.new(name=name + "_Curve", type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.resolution_u = resolution
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = bevel_res
    curve_data.use_fill_caps = True

    spline = curve_data.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    spline.use_cyclic_u = cyclic
    for i, pt in enumerate(points):
        bp = spline.bezier_points[i]
        bp.co = Vector(pt)
        bp.handle_left_type = 'AUTO'
        bp.handle_right_type = 'AUTO'

    curve_obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(curve_obj)
    if mat:
        assign_mat(curve_obj, mat)

    bpy.ops.object.select_all(action='DESELECT')
    curve_obj.select_set(True)
    bpy.context.view_layer.objects.active = curve_obj
    bpy.ops.object.convert(target='MESH')
    mesh_obj = bpy.context.active_object
    smooth_obj(mesh_obj)
    return mesh_obj


def add_empty(name, location=(0, 0, 0), rotation=(0, 0, 0)):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.location = location
    empty.rotation_euler = rotation
    return empty


def parent_keep(child, parent):
    child.parent = parent


def set_bezier_keyframes(obj, data_path, keyframes):
    """keyframes: list of (frame, value_tuple_or_float)"""
    for frame, val in keyframes:
        setattr(obj, data_path, val)
        obj.keyframe_insert(data_path=data_path, frame=frame)
    if obj.animation_data and obj.animation_data.action:
        # Blender 5.x layered actions or legacy fcurves
        action = obj.animation_data.action
        fcurves = getattr(action, "fcurves", None)
        if fcurves:
            for fc in fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'BEZIER'
                    kp.handle_left_type = 'AUTO_CLAMPED'
                    kp.handle_right_type = 'AUTO_CLAMPED'


def add_plinth(accent_rgb):
    """统一的精致柔瓷展示底座 + 倒角金属环"""
    plinth_mat = make_material("PlinthCeramic", (0.94, 0.96, 0.99), roughness=0.22, coat=0.6)
    ring_mat = make_material("PlinthAccent", accent_rgb, roughness=0.2, metallic=0.35, emission=accent_rgb, emission_strength=0.45)

    base = add_cylinder("PlinthBase", radius=1.55, depth=0.14, location=(0, 0, -0.07), vertices=64, bevel=0.035, mat=plinth_mat)
    ring = add_torus("PlinthRing", major_radius=1.54, minor_radius=0.018, location=(0, 0, -0.01), major_seg=64, minor_seg=16, mat=ring_mat)
    return base, ring


# ==============================================================================
# 8 套高精细度 Blender 3D 微缩场景（Blender 坐标系：Z 朝上，-Y 朝前面向相机）
# ==============================================================================

def build_chin_rest():
    """1. 托腮/扶额伪装深思：圆润人物半身 + 轻按太阳穴 + 减压光环 + 金属笔记本"""
    accent = (0.24, 0.50, 0.98)
    add_plinth(accent)

    skin = make_material("Skin", (0.98, 0.80, 0.69), roughness=0.42, coat=0.08)
    cheek = make_material("Cheek", (0.96, 0.58, 0.56), roughness=0.55)
    sweater = make_material("Sweater", (0.22, 0.45, 0.92), roughness=0.68)
    collar_mat = make_material("Collar", (0.97, 0.98, 1.0), roughness=0.45)
    hair_mat = make_material("Hair", (0.14, 0.17, 0.24), roughness=0.32, coat=0.35)
    alu = make_material("Aluminum", (0.82, 0.86, 0.92), roughness=0.22, metallic=0.88)
    dark_key = make_material("Keyboard", (0.18, 0.20, 0.26), roughness=0.5)
    screen_mat = make_material("Screen", (0.68, 0.85, 1.0), roughness=0.1, emission=(0.55, 0.78, 1.0), emission_strength=0.9)
    glow = make_material("TempleGlow", accent, roughness=0.15, alpha=0.78, emission=accent, emission_strength=1.2)

    # 人物（略偏右后，面向左前笔记本）
    fig = add_empty("Figure", location=(0.24, 0.16, 0.0))

    torso = add_capsule("Torso", radius=0.44, length=0.92, location=(0, 0, 0.36), mat=sweater)
    torso.scale = (1.14, 0.78, 0.88)
    parent_keep(torso, fig)

    collar = add_torus("Collar", major_radius=0.23, minor_radius=0.06, location=(0, -0.02, 0.76), mat=collar_mat)
    parent_keep(collar, fig)

    neck = add_cylinder("Neck", radius=0.12, depth=0.22, location=(0, 0, 0.86), mat=skin)
    parent_keep(neck, fig)

    # 头部（微低沉思态）
    head_pivot = add_empty("HeadPivot", location=(0, 0, 1.24), rotation=(0.08, -0.06, 0.22))
    parent_keep(head_pivot, fig)

    head = add_sphere("Head", radius=0.40, scale=(0.98, 1.0, 1.03), mat=skin)
    parent_keep(head, head_pivot)

    # 立体圆润发型 + 刘海
    hair_cap = add_sphere("HairCap", radius=0.425, location=(0, 0.06, 0.08), scale=(1.02, 1.0, 0.96), mat=hair_mat)
    parent_keep(hair_cap, head_pivot)

    bangs = add_bezier_tube(
        "HairBangs",
        [(-0.34, -0.18, 0.18), (-0.12, -0.34, 0.28), (0.14, -0.35, 0.26), (0.34, -0.18, 0.16)],
        radius=0.11,
        mat=hair_mat,
    )
    parent_keep(bangs, head_pivot)

    # 双耳
    for sx in (-1, 1):
        ear = add_sphere(f"Ear_{sx}", radius=0.082, location=(sx * 0.39, 0.02, -0.02), scale=(0.7, 0.9, 1.1), mat=skin)
        parent_keep(ear, head_pivot)

    # 闭目放松睫毛弧线 + 柔和腮红
    for sx in (-1, 1):
        eye = add_bezier_tube(
            f"Eye_{sx}",
            [(sx * 0.08, -0.39, 0.03), (sx * 0.15, -0.40, 0.005), (sx * 0.22, -0.37, 0.03)],
            radius=0.017,
            mat=hair_mat,
        )
        parent_keep(eye, head_pivot)

        blush = add_sphere(f"Blush_{sx}", radius=0.055, location=(sx * 0.21, -0.35, -0.08), scale=(1.2, 0.35, 0.7), mat=cheek)
        parent_keep(blush, head_pivot)

    # 右手曲线臂从肩膀自然连出，手掌轻托太阳穴（带呼吸按压动画）
    arm_pivot = add_empty("ArmPivot", location=(0.0, 0.0, 0.0))
    parent_keep(arm_pivot, fig)

    arm_tube = add_bezier_tube(
        "ArmCurve",
        [(0.38, 0.02, 0.62), (0.58, -0.10, 0.74), (0.52, -0.18, 1.06), (0.38, -0.16, 1.24)],
        radius=0.095,
        mat=sweater,
    )
    parent_keep(arm_tube, arm_pivot)

    hand = add_capsule("Hand", radius=0.082, length=0.22, location=(0.35, -0.17, 1.28), rotation=(0.15, -0.35, 0), mat=skin)
    parent_keep(hand, arm_pivot)

    set_bezier_keyframes(arm_pivot, "location", [
        (1, (0.0, 0.0, 0.0)),
        (30, (-0.028, 0.01, 0.015)),
        (60, (0.0, 0.0, 0.0)),
        (90, (-0.028, 0.01, 0.015)),
        (120, (0.0, 0.0, 0.0)),
    ])

    # 太阳穴减压呼吸光环
    ring = add_torus("TempleRing", major_radius=0.14, minor_radius=0.016, location=(0.35, -0.22, 0.08), rotation=(0, math.radians(78), math.radians(-28)), mat=glow)
    parent_keep(ring, head_pivot)
    set_bezier_keyframes(ring, "scale", [
        (1, (0.85, 0.85, 0.85)),
        (60, (1.55, 1.55, 1.55)),
        (120, (0.85, 0.85, 0.85)),
    ])

    # 左前方精细金属笔记本
    laptop = add_empty("Laptop", location=(-0.58, -0.46, 0.02), rotation=(0, 0, -0.48))
    base_plate = add_rounded_box("LaptopBase", (0.78, 0.54, 0.036), location=(0, 0, 0.018), bevel=0.014, subdiv=1, mat=alu)
    parent_keep(base_plate, laptop)
    kb = add_rounded_box("Keyboard", (0.66, 0.24, 0.008), location=(0, 0.06, 0.038), bevel=0.003, subdiv=0, mat=dark_key)
    parent_keep(kb, laptop)
    lid = add_rounded_box("LaptopLid", (0.78, 0.028, 0.50), location=(0, 0.27, 0.27), rotation=(-0.20, 0, 0), bevel=0.012, subdiv=1, mat=alu)
    parent_keep(lid, laptop)
    scr = add_rounded_box("LaptopScreen", (0.71, 0.008, 0.43), location=(0, 0.252, 0.27), rotation=(-0.20, 0, 0), bevel=0.003, subdiv=0, mat=screen_mat)
    parent_keep(scr, laptop)


def build_under_desk_stretch():
    """2. 桌子底下的肌肉松绑：北欧原木桌 + 小盆栽 + 桌下双脚勾脚尖/绷脚背动画"""
    accent = (0.16, 0.76, 0.56)
    add_plinth((0.24, 0.50, 0.98))

    oak = make_material("OakWood", (0.85, 0.69, 0.50), roughness=0.45, coat=0.15)
    metal = make_material("DeskMetal", (0.78, 0.82, 0.88), roughness=0.22, metallic=0.85)
    trouser = make_material("Trouser", (0.22, 0.29, 0.42), roughness=0.68)
    sock_mat = make_material("Sock", (0.97, 0.98, 1.0), roughness=0.55)
    shoe_blue = make_material("SneakerBlue", (0.20, 0.52, 0.96), roughness=0.30, coat=0.35)
    shoe_sole = make_material("SneakerSole", (0.98, 0.98, 1.0), roughness=0.42)
    pot_mat = make_material("PotCeramic", (0.96, 0.94, 0.90), roughness=0.20, coat=0.5)
    leaf_mat = make_material("Succulent", (0.18, 0.68, 0.46), roughness=0.42)
    ring_mat = make_material("CircRing", accent, roughness=0.18, alpha=0.80, emission=accent, emission_strength=1.1)

    # 原木桌面（大圆角倒角）
    add_rounded_box("DeskTop", (2.15, 1.05, 0.10), location=(0, 0, 1.32), bevel=0.036, subdiv=1, mat=oak)

    # 四根金属圆桌腿
    for sx in (-0.92, 0.92):
        for sy in (-0.38, 0.38):
            add_cylinder(f"Leg_{sx}_{sy}", radius=0.036, depth=1.28, location=(sx, sy, 0.64), mat=metal)

    # 桌面微缩多肉盆栽
    add_cylinder("Pot", radius=0.11, depth=0.16, location=(0.74, 0.18, 1.45), bevel=0.02, mat=pot_mat)
    for i in range(5):
        ang = i * (2 * math.pi / 5)
        add_sphere(
            f"Leaf_{i}",
            radius=0.08,
            location=(0.74 + math.cos(ang) * 0.05, 0.18 + math.sin(ang) * 0.05, 1.57),
            scale=(0.8, 0.8, 1.35),
            mat=leaf_mat,
        )

    # 桌下双腿 + 袜口 + 精致拼色运动鞋（勾脚尖 ↔ 绷脚背循环）
    for idx, sx in enumerate((-0.32, 0.32)):
        calf = add_capsule(f"Calf_{idx}", radius=0.125, length=0.86, location=(sx, 0.02, 0.82), rotation=(-0.12, 0, 0), mat=trouser)
        add_cylinder(f"Sock_{idx}", radius=0.092, depth=0.16, location=(sx, -0.04, 0.38), mat=sock_mat)

        ankle = add_empty(f"Ankle_{idx}", location=(sx, -0.05, 0.30))

        # 鞋面 + 圆润鞋头 + 白厚底
        upper = add_capsule(f"ShoeUpper_{idx}", radius=0.105, length=0.48, location=(0, -0.15, -0.02), rotation=(math.pi / 2, 0, 0), mat=shoe_blue)
        upper.scale = (1.02, 1.0, 0.88)
        parent_keep(upper, ankle)

        sole = add_rounded_box(f"ShoeSole_{idx}", (0.22, 0.50, 0.068), location=(0, -0.15, -0.095), bevel=0.025, subdiv=1, mat=shoe_sole)
        parent_keep(sole, ankle)

        # 慢速勾脚尖 (+0.52 rad) ↔ 绷脚背 (-0.42 rad)
        phase = 12 * idx
        set_bezier_keyframes(ankle, "rotation_euler", [
            (1, (-0.38, 0, 0)),
            (40 + phase, (0.52, 0, 0)),
            (60 + phase, (0.52, 0, 0)),
            (100, (-0.38, 0, 0)),
            (120, (-0.38, 0, 0)),
        ])

    # 桌下缓升的舒缓循环光环
    ring = add_torus("CircRing", major_radius=0.58, minor_radius=0.016, location=(0, -0.14, 0.22), mat=ring_mat)
    set_bezier_keyframes(ring, "location", [
        (1, (0, -0.14, 0.16)),
        (60, (0, -0.14, 0.92)),
        (120, (0, -0.14, 0.16)),
    ])


def build_ambient_noise():
    """3. 戴降噪耳机，只听环境音：AirPods Max 风格头戴耳机 + 声波环 + 玻璃雨滴"""
    accent = (0.28, 0.64, 1.0)
    add_plinth(accent)

    alu_blue = make_material("AnodizedBlue", (0.22, 0.47, 0.94), roughness=0.22, metallic=0.72, coat=0.3)
    chrome = make_material("Chrome", (0.90, 0.93, 0.97), roughness=0.10, metallic=0.95)
    cushion = make_material("MemoryFoam", (0.15, 0.18, 0.25), roughness=0.82)
    wave_mat = make_material("SoundWave", accent, roughness=0.15, alpha=0.72, emission=accent, emission_strength=1.1)
    rain_mat = make_material("RainGlass", (0.50, 0.84, 1.0), roughness=0.06, coat=1.0, alpha=0.68, emission=(0.40, 0.76, 1.0), emission_strength=0.45)

    hp = add_empty("Headphones", location=(0, 0, 0.88))

    # 精致 Bezier 曲线双轨头梁
    pts = []
    for i in range(9):
        t = i / 8.0
        ang = math.radians(12 + 156 * t)
        pts.append((math.cos(ang) * 0.72, 0.0, math.sin(ang) * 0.76))
    add_bezier_tube("HeadbandArch", pts, radius=0.062, resolution=32, bevel_res=12, mat=alu_blue).parent = hp

    # 顶部细铬金属弓骨架
    pts_inner = []
    for i in range(9):
        t = i / 8.0
        ang = math.radians(8 + 164 * t)
        pts_inner.append((math.cos(ang) * 0.66, 0.0, math.sin(ang) * 0.70))
    add_bezier_tube("HeadbandChrome", pts_inner, radius=0.022, resolution=32, bevel_res=10, mat=chrome).parent = hp

    # 左右伸缩金属杆 + 椭圆形阳极铝耳罩 + 金属亮边 + 记忆棉耳垫
    for sx in (-1, 1):
        arm = add_cylinder(f"Arm_{sx}", radius=0.028, depth=0.34, location=(sx * 0.71, 0, 0.02), mat=chrome)
        parent_keep(arm, hp)

        cup = add_sphere(f"Cup_{sx}", radius=0.29, location=(sx * 0.71, 0, -0.22), scale=(0.46, 0.86, 1.12), mat=alu_blue)
        parent_keep(cup, hp)

        trim = add_torus(f"Trim_{sx}", major_radius=0.27, minor_radius=0.018, location=(sx * 0.62, 0, -0.22), rotation=(0, math.pi / 2, 0), scale=(1.12, 0.86, 1.0), mat=chrome)
        parent_keep(trim, hp)

        pad = add_torus(f"Pad_{sx}", major_radius=0.24, minor_radius=0.075, location=(sx * 0.56, 0, -0.22), rotation=(0, math.pi / 2, 0), scale=(1.12, 0.86, 1.0), mat=cushion)
        parent_keep(pad, hp)

    # 耳机柔和悬浮呼吸
    set_bezier_keyframes(hp, "location", [
        (1, (0, 0, 0.84)),
        (60, (0, 0, 0.98)),
        (120, (0, 0, 0.84)),
    ])

    # 声波光环
    for idx in range(2):
        w = add_torus(f"Wave_{idx}", major_radius=0.86, minor_radius=0.014, location=(0, 0, 0.72), rotation=(0.35, 0.18 * (idx + 1), 0), mat=wave_mat)
        s1 = 0.88 if idx == 0 else 1.26
        s2 = 1.26 if idx == 0 else 0.88
        set_bezier_keyframes(w, "scale", [(1, (s1, s1, s1)), (60, (s2, s2, s2)), (120, (s1, s1, s1))])

    # 精致水滴形玻璃雨滴（轻缓下落循环）
    drop_specs = [(-1.12, -0.18, 0), (-0.86, 0.34, 30), (1.02, -0.24, 15), (1.16, 0.25, 45)]
    for idx, (dx, dy, phase) in enumerate(drop_specs):
        drop = add_capsule(f"Drop_{idx}", radius=0.032, length=0.16, location=(dx, dy, 1.5), mat=rain_mat)
        f_mid = 60
        set_bezier_keyframes(drop, "location", [
            (1, (dx, dy, 1.55 if phase < 25 else 0.55)),
            (f_mid, (dx, dy, 0.45 if phase < 25 else 1.55)),
            (120, (dx, dy, 1.55 if phase < 25 else 0.55)),
        ])


def build_low_energy_camouflage():
    """4. 低耗能伪装任务：半透明玻璃 3D 文件夹 + 精致文档卡片依次归档"""
    accent = (0.24, 0.52, 0.98)
    add_plinth(accent)

    folder_back = make_material("FolderBack", (0.20, 0.48, 0.95), roughness=0.22, coat=0.55)
    folder_front = make_material("FolderFrontGlass", (0.42, 0.70, 1.0), roughness=0.10, coat=0.95, alpha=0.58)
    paper = make_material("Paper", (0.99, 0.99, 1.0), roughness=0.35, coat=0.1)
    line_mat = make_material("TextLine", (0.74, 0.82, 0.94), roughness=0.45)
    amber = make_material("TagAmber", (0.98, 0.72, 0.24), roughness=0.25, coat=0.3)
    mint = make_material("TagMint", (0.18, 0.78, 0.58), roughness=0.25, coat=0.3)

    folder = add_empty("FolderRoot", location=(0, 0, 0.62))

    add_rounded_box("FolderBack", (1.54, 0.08, 1.02), location=(0, 0.22, 0), bevel=0.035, subdiv=1, mat=folder_back).parent = folder
    add_rounded_box("FolderTab", (0.56, 0.08, 0.22), location=(-0.45, 0.22, 0.55), bevel=0.035, subdiv=1, mat=folder_back).parent = folder
    add_rounded_box("FolderFront", (1.54, 0.065, 0.90), location=(0, -0.22, -0.05), rotation=(0.14, 0, 0), bevel=0.035, subdiv=1, mat=folder_front).parent = folder

    tag_mats = [amber, mint, folder_back]
    for idx in range(3):
        card = add_empty(f"Card_{idx}")
        parent_keep(card, folder)

        add_rounded_box(f"Sheet_{idx}", (1.10, 0.034, 0.76), bevel=0.015, subdiv=1, mat=paper).parent = card
        add_rounded_box(f"Tag_{idx}", (0.34, 0.014, 0.08), location=(-0.28, -0.022, 0.21), bevel=0.005, subdiv=0, mat=tag_mats[idx]).parent = card
        add_rounded_box(f"L1_{idx}", (0.74, 0.012, 0.045), location=(-0.08, -0.022, 0.04), bevel=0.004, subdiv=0, mat=line_mat).parent = card
        add_rounded_box(f"L2_{idx}", (0.54, 0.012, 0.045), location=(-0.18, -0.022, -0.09), bevel=0.004, subdiv=0, mat=line_mat).parent = card

        y_in = 0.08 - idx * 0.08
        start_loc = ((idx - 1) * 0.34, y_in, 0.84)
        end_loc = (0.0, y_in, 0.02)
        start_rot = (0, (idx - 1) * 0.14, 0)

        set_bezier_keyframes(card, "location", [
            (1, start_loc),
            (45 + idx * 8, end_loc),
            (75 + idx * 8, end_loc),
            (120, start_loc),
        ])
        set_bezier_keyframes(card, "rotation_euler", [
            (1, start_rot),
            (45 + idx * 8, (0, 0, 0)),
            (75 + idx * 8, (0, 0, 0)),
            (120, start_rot),
        ])


def build_restroom_no_phone():
    """5. 不带手机去洗手间：钛金属手机留工位 + 禅意慢呼吸双层琉璃球"""
    accent = (0.16, 0.78, 0.58)
    add_plinth(accent)

    leather = make_material("DeskLeather", (0.78, 0.73, 0.67), roughness=0.72)
    titanium = make_material("Titanium", (0.28, 0.31, 0.38), roughness=0.22, metallic=0.88)
    glass_blk = make_material("PhoneScreen", (0.08, 0.10, 0.15), roughness=0.06, coat=1.0)
    coral = make_material("CoralNo", (0.96, 0.38, 0.34), roughness=0.18, emission=(0.96, 0.38, 0.34), emission_strength=0.95)
    jade_outer = make_material("JadeGlass", (0.16, 0.82, 0.62), roughness=0.08, coat=1.0, alpha=0.45)
    jade_core = make_material("JadeCore", (0.24, 0.92, 0.70), roughness=0.15, emission=(0.20, 0.86, 0.66), emission_strength=1.15)
    pearl = make_material("Pearl", (0.98, 0.99, 1.0), roughness=0.12, coat=0.9)

    # 左侧：工位皮垫 + 钛金属圆角手机 + 悬浮禁止环
    pg = add_empty("PhoneGroup", location=(-0.64, -0.06, 0.02), rotation=(0, 0, 0.32))
    add_rounded_box("Pad", (0.86, 1.24, 0.036), location=(0, 0, 0.018), bevel=0.016, subdiv=1, mat=leather).parent = pg
    add_rounded_box("PhoneBody", (0.56, 1.06, 0.072), location=(0, 0, 0.072), bevel=0.032, subdiv=1, mat=titanium).parent = pg
    add_rounded_box("PhoneScreen", (0.50, 0.98, 0.010), location=(0, 0, 0.110), bevel=0.004, subdiv=0, mat=glass_blk).parent = pg

    badge = add_empty("NoPhoneBadge", location=(0, 0, 0.64))
    parent_keep(badge, pg)
    add_torus("NoRing", major_radius=0.33, minor_radius=0.038, rotation=(math.pi / 2, 0, 0), mat=coral).parent = badge
    add_capsule("NoSlash", radius=0.035, length=0.62, rotation=(0, math.pi / 4, 0), mat=coral).parent = badge
    set_bezier_keyframes(badge, "location", [(1, (0, 0, 0.60)), (60, (0, 0, 0.74)), (120, (0, 0, 0.60))])

    # 右侧：禅意慢呼吸琉璃球 + 旋转星环珍珠
    bg = add_empty("BreathGroup", location=(0.64, 0.04, 0.78))
    outer = add_sphere("BreathOuter", radius=0.45, mat=jade_outer)
    parent_keep(outer, bg)
    core = add_sphere("BreathCore", radius=0.22, mat=jade_core)
    parent_keep(core, bg)

    set_bezier_keyframes(outer, "scale", [(1, (0.86, 0.86, 0.86)), (60, (1.28, 1.28, 1.28)), (120, (0.86, 0.86, 0.86))])
    set_bezier_keyframes(core, "scale", [(1, (1.18, 1.18, 1.18)), (60, (0.82, 0.82, 0.82)), (120, (1.18, 1.18, 1.18))])

    orbit = add_empty("BreathOrbit", rotation=(0.55, 0.25, 0))
    parent_keep(orbit, bg)
    add_torus("BreathHalo", major_radius=0.64, minor_radius=0.015, mat=jade_core).parent = orbit
    add_sphere("OrbitPearl", radius=0.056, location=(0.64, 0, 0), mat=pearl).parent = orbit
    set_bezier_keyframes(orbit, "rotation_euler", [(1, (0.55, 0.25, 0)), (120, (0.55, 0.25, math.pi * 2))])


def build_slow_water_refill():
    """6. 拉长接水 3 分钟：拉丝金属饮水机嘴 + 真中空釉面陶瓷马克杯 + 缓升清水 + 水汽"""
    accent = (0.18, 0.72, 0.96)
    add_plinth((0.16, 0.74, 0.56))

    chrome = make_material("DispenserChrome", (0.86, 0.90, 0.95), roughness=0.14, metallic=0.92)
    ceramic = make_material("MugCeramic", (0.98, 0.96, 0.93), roughness=0.14, coat=0.85)
    teal_band = make_material("MugTeal", (0.18, 0.64, 0.58), roughness=0.18, coat=0.7)
    water = make_material("WaterClear", accent, roughness=0.06, coat=1.0, alpha=0.72, emission=(0.22, 0.72, 1.0), emission_strength=0.45)
    steam_mat = make_material("SteamRing", (0.76, 0.92, 1.0), roughness=0.2, alpha=0.65, emission=(0.60, 0.86, 1.0), emission_strength=0.6)

    # 饮水机出水头
    add_rounded_box("DispenserHead", (0.56, 0.36, 0.20), location=(0, 0.08, 1.72), bevel=0.05, subdiv=1, mat=chrome)
    add_cylinder("Nozzle", radius=0.072, depth=0.16, location=(0, 0, 1.56), bevel=0.015, mat=chrome)

    # 清澈水流柱
    stream = add_cylinder("WaterStream", radius=0.036, depth=1.18, location=(0, 0, 0.92), mat=water)
    set_bezier_keyframes(stream, "scale", [(1, (0.92, 0.92, 1.0)), (30, (1.12, 1.12, 1.0)), (60, (0.92, 0.92, 1.0)), (90, (1.12, 1.12, 1.0)), (120, (0.92, 0.92, 1.0))])

    # 真中空陶瓷马克杯（开放顶部圆柱 + Solidify 实心厚壁 + Subsurf 圆润杯唇）
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.46, depth=0.82, end_fill_type='NGON', location=(0, 0, 0.43))
    mug = bpy.context.active_object
    mug.name = "CeramicMug"
    # 删除顶盖形成真中空杯口
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(mug.data)
    bm.faces.ensure_lookup_table()
    top_faces = [f for f in bm.faces if f.normal.z > 0.9]
    bmesh.ops.delete(bm, geom=top_faces, context='FACES')
    bmesh.update_edit_mesh(mug.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    solid = mug.modifiers.new("Solidify", type='SOLIDIFY')
    solid.thickness = 0.055
    solid.offset = -1.0
    smooth_obj(mug, subdiv=2)
    assign_mat(mug, ceramic)

    # 莫兰迪绿釉面装饰腰线
    add_cylinder("MugBand", radius=0.468, depth=0.22, location=(0, 0, 0.30), vertices=48, mat=teal_band)

    # Bezier 有机弧线 C 型杯把
    add_bezier_tube(
        "MugHandle",
        [(0.43, 0, 0.64), (0.68, 0, 0.62), (0.70, 0, 0.24), (0.43, 0, 0.22)],
        radius=0.052,
        resolution=24,
        mat=ceramic,
    )

    # 缓升的清水液面
    water_fill = add_cylinder("WaterFill", radius=0.395, depth=0.08, location=(0, 0, 0.26), vertices=48, mat=water)
    set_bezier_keyframes(water_fill, "location", [
        (1, (0, 0, 0.24)),
        (85, (0, 0, 0.74)),
        (105, (0, 0, 0.74)),
        (120, (0, 0, 0.24)),
    ])

    # 缓缓飘升的水汽环
    steam = add_torus("Steam", major_radius=0.26, minor_radius=0.015, location=(0, 0, 0.88), mat=steam_mat)
    set_bezier_keyframes(steam, "location", [(1, (0, 0, 0.86)), (120, (0, 0, 1.38))])
    set_bezier_keyframes(steam, "scale", [(1, (0.85, 0.85, 0.85)), (120, (1.45, 1.45, 1.45))])


def build_stairwell_sun():
    """7. 去楼梯间 / 下楼晒太阳：水磨石台阶 + 曲线金属扶手 + 户外小树 + 暖阳与清风丝带"""
    accent = (0.98, 0.74, 0.22)
    add_plinth((0.16, 0.74, 0.56))

    terrazzo = make_material("Terrazzo", (0.91, 0.93, 0.97), roughness=0.32, coat=0.25)
    rail_mat = make_material("RailMetal", (0.76, 0.81, 0.88), roughness=0.18, metallic=0.90)
    sun_mat = make_material("SunOrb", accent, roughness=0.15, emission=accent, emission_strength=1.35)
    halo_mat = make_material("SunHalo", (1.0, 0.84, 0.42), roughness=0.2, alpha=0.65, emission=(1.0, 0.82, 0.36), emission_strength=0.9)
    breeze_mat = make_material("Breeze", (0.20, 0.82, 0.62), roughness=0.18, alpha=0.75, emission=(0.20, 0.82, 0.62), emission_strength=0.8)
    tree_green = make_material("TreeFoliage", (0.20, 0.70, 0.48), roughness=0.52)
    trunk_mat = make_material("TreeTrunk", (0.62, 0.46, 0.34), roughness=0.68)

    # 5 级倒角水磨石台阶
    for i in range(5):
        add_rounded_box(
            f"Step_{i}",
            (0.84, 0.38, 0.16),
            location=(-0.78 + i * 0.30, -0.22 + i * 0.10, 0.10 + i * 0.20),
            bevel=0.025,
            subdiv=1,
            mat=terrazzo,
        )

    # 金属扶手 + 两根立柱
    add_bezier_tube(
        "Handrail",
        [(-0.98, -0.38, 0.56), (-0.28, -0.14, 0.98), (0.46, 0.10, 1.42)],
        radius=0.026,
        mat=rail_mat,
    )
    add_cylinder("Post1", radius=0.02, depth=0.46, location=(-0.82, -0.32, 0.38), mat=rail_mat)
    add_cylinder("Post2", radius=0.02, depth=0.46, location=(0.36, 0.06, 1.12), mat=rail_mat)

    # 角落三团层次微缩绿树
    add_cylinder("Trunk", radius=0.045, depth=0.32, location=(0.86, -0.34, 0.16), mat=trunk_mat)
    add_sphere("Canopy1", radius=0.22, location=(0.86, -0.34, 0.44), mat=tree_green)
    add_sphere("Canopy2", radius=0.16, location=(0.72, -0.28, 0.38), mat=tree_green)
    add_sphere("Canopy3", radius=0.15, location=(0.98, -0.40, 0.40), mat=tree_green)

    # 暖阳 + 双日冕旋转环
    sun_g = add_empty("SunGroup", location=(0.74, 0.22, 1.28))
    sun = add_sphere("Sun", radius=0.34, mat=sun_mat)
    parent_keep(sun, sun_g)
    set_bezier_keyframes(sun, "scale", [(1, (0.94, 0.94, 0.94)), (60, (1.10, 1.10, 1.10)), (120, (0.94, 0.94, 0.94))])

    c1 = add_torus("Corona1", major_radius=0.50, minor_radius=0.018, rotation=(0.55, 0.2, 0), mat=halo_mat)
    parent_keep(c1, sun_g)
    set_bezier_keyframes(c1, "rotation_euler", [(1, (0.55, 0.2, 0)), (120, (0.55, 0.2, math.pi * 2))])

    # 优雅 S 型清风飘带
    breeze = add_bezier_tube(
        "BreezeRibbon",
        [(-0.75, -0.48, 0.72), (-0.25, -0.52, 0.84), (0.25, -0.46, 0.68), (0.75, -0.50, 0.80)],
        radius=0.022,
        mat=breeze_mat,
    )
    set_bezier_keyframes(breeze, "location", [
        (1, (-0.38, 0, 0)),
        (60, (0.38, 0, 0.08)),
        (120, (-0.38, 0, 0)),
    ])


def build_afternoon_emergency():
    """8. 下午犯困急救组合：优雅鹅颈铬龙头 + 冷水冲手腕 + 冰蓝提神水花"""
    accent = (0.18, 0.78, 1.0)
    add_plinth(accent)

    chrome = make_material("FaucetChrome", (0.88, 0.92, 0.97), roughness=0.10, metallic=0.96)
    skin = make_material("WristSkin", (0.98, 0.80, 0.69), roughness=0.42, coat=0.08)
    band_mat = make_material("WatchBand", (0.20, 0.24, 0.32), roughness=0.55)
    watch_case = make_material("WatchCase", (0.86, 0.90, 0.96), roughness=0.14, metallic=0.92)
    ice_water = make_material("IceStream", accent, roughness=0.05, coat=1.0, alpha=0.72, emission=(0.20, 0.78, 1.0), emission_strength=0.65)
    splash_gold = make_material("SplashGold", (1.0, 0.74, 0.26), roughness=0.16, alpha=0.84, emission=(1.0, 0.72, 0.24), emission_strength=1.1)

    # 优雅弧形鹅颈水龙头（Bezier 曲线管）
    add_cylinder("FaucetBase", radius=0.14, depth=0.08, location=(0, 0.74, 0.04), bevel=0.02, mat=chrome)
    add_bezier_tube(
        "GooseneckFaucet",
        [(0, 0.74, 0.06), (0, 0.74, 1.15), (0, 0.36, 1.62), (0, -0.02, 1.38)],
        radius=0.068,
        resolution=32,
        bevel_res=14,
        mat=chrome,
    )

    # 清凉冷水柱
    stream = add_cylinder("ColdStream", radius=0.046, depth=0.90, location=(0, -0.02, 0.90), mat=ice_water)
    set_bezier_keyframes(stream, "scale", [(1, (0.92, 0.92, 1.0)), (30, (1.14, 1.14, 1.0)), (60, (0.92, 0.92, 1.0)), (90, (1.14, 1.14, 1.0)), (120, (0.92, 0.92, 1.0))])

    # 圆润前臂与手腕 + 表带 + 精致表盘
    wg = add_empty("WristGroup", location=(0, -0.02, 0.44), rotation=(0, 0, 0.14))
    forearm = add_capsule("Forearm", radius=0.18, length=1.52, rotation=(0, math.pi / 2, 0), mat=skin)
    parent_keep(forearm, wg)
    band = add_torus("WatchBand", major_radius=0.185, minor_radius=0.038, location=(-0.34, 0, 0), rotation=(0, math.pi / 2, 0), mat=band_mat)
    parent_keep(band, wg)
    wcase = add_rounded_box("WatchCase", (0.16, 0.18, 0.055), location=(-0.34, 0, 0.20), bevel=0.02, subdiv=1, mat=watch_case)
    parent_keep(wcase, wg)

    # 手腕处扩散的冰蓝 + 提神金涟漪环
    for idx, m in enumerate((ice_water, splash_gold)):
        ring = add_torus(f"Splash_{idx}", major_radius=0.26, minor_radius=0.020, location=(0, -0.02, 0.56), mat=m)
        s_a = 0.78 if idx == 0 else 1.55
        s_b = 1.65 if idx == 0 else 0.78
        set_bezier_keyframes(ring, "scale", [(1, (s_a, s_a, s_a)), (60, (s_b, s_b, s_b)), (120, (s_a, s_a, s_a))])


# ==============================================================================
# 导出与可选预览渲染
# ==============================================================================

BUILDERS = [
    ("chin-rest", build_chin_rest),
    ("under-desk-stretch", build_under_desk_stretch),
    ("ambient-noise", build_ambient_noise),
    ("low-energy-camouflage", build_low_energy_camouflage),
    ("restroom-no-phone", build_restroom_no_phone),
    ("slow-water-refill", build_slow_water_refill),
    ("stairwell-or-downstairs", build_stairwell_sun),
    ("afternoon-emergency", build_afternoon_emergency),
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


def render_preview(name):
    if not PREVIEW_DIR:
        return
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    # 添加临时预览相机与柔光灯
    bpy.ops.object.camera_add(location=(0.0, -4.6, 2.2), rotation=(math.radians(66), 0, 0))
    cam = bpy.context.active_object
    cam.data.lens = 52
    scene.camera = cam

    bpy.ops.object.light_add(type='AREA', location=(2.6, -2.8, 3.8))
    l1 = bpy.context.active_object
    l1.data.energy = 260
    l1.data.size = 3.0

    bpy.ops.object.light_add(type='AREA', location=(-2.6, -1.8, 2.2))
    l2 = bpy.context.active_object
    l2.data.energy = 120
    l2.data.size = 2.5

    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 420
    scene.render.resolution_y = 260
    scene.render.film_transparent = True
    scene.render.filepath = os.path.join(PREVIEW_DIR, f"{name}.png")
    scene.frame_set(30)
    bpy.ops.render.render(write_still=True)


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
        if PREVIEW_DIR and name in ("chin-rest", "ambient-noise", "slow-water-refill", "afternoon-emergency"):
            render_preview(name)
    print("==> All 8 Blender USDZ models generated successfully!")


if __name__ == "__main__":
    main()
