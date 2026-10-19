"""使用用户提供的 Away3D 资源搭建可在 Blender 继续编辑的观测站。"""
import argparse
import importlib.util
import math
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy
from mathutils import Vector, Matrix

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('export_world', Path(__file__).with_name('export_world.py'))
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)
exporter.load_fog_addon()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
visuals = bpy.data.collections.new('WorldVisuals')
bpy.context.scene.collection.children.link(visuals)
helpers = bpy.data.collections.new('WorldLogic')
bpy.context.scene.collection.children.link(helpers)


def move_collection(obj, collection):
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)


def location(x, y, z):
    return (x, -z, y)


def material(name, color, image=None, metallic=0, roughness=0.8, emission=False):
    value = bpy.data.materials.new(name)
    value.use_nodes = True
    shader = value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if image:
        texture = value.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(HERE / 'Authoring/Textures' / image))
        value.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = 1
    return value


stone = material('观测站石材', (0.7, 0.7, 0.7), 'stone.jpg')
paving = material('铺路石', (0.8, 0.8, 0.8), 'paving.jpg')
grass = material('庭院草地', (0.4, 0.5, 0.3), 'grass.jpg')
terrain_material = material('Away3D 地形', (0.7, 0.7, 0.7), 'terrain.jpg')
bark = material('树皮', (0.25, 0.2, 0.15), 'bark.jpg')
foliage = material('针叶', (0.04, 0.14, 0.11), roughness=1)
metal = material('机器人金属', (0.65, 0.72, 0.8), metallic=0.65, roughness=0.35)
blue = material('观测蓝', (0.04, 0.22, 0.4), metallic=0.4)
cyan = material('信标发光', (0.08, 0.9, 1), emission=True)
gold = material('档案金光', (1, 0.46, 0.05), metallic=0.4, emission=True)


def logic(name, kind, pos, **properties):
    obj = bpy.data.objects.new(name, None)
    helpers.objects.link(obj)
    obj.location = location(*pos)
    obj.empty_display_type = 'CUBE' if kind == 'box' else 'SPHERE'
    obj.empty_display_size = 0.5
    obj['hx_kind'] = kind
    for key, value in properties.items():
        obj['hx_' + key] = value
    return obj


def box(name, pos, size, mat=stone, collider=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location(*pos))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        for index in polygon.loop_indices:
            co = obj.data.vertices[obj.data.loops[index].vertex_index].co
            if abs(polygon.normal.z) > 0.5:
                uv.data[index].uv = (co.x / 4, co.y / 4)
            elif abs(polygon.normal.x) > 0.5:
                uv.data[index].uv = (co.y / 3, co.z / 3)
            else:
                uv.data[index].uv = (co.x / 3, co.z / 3)
    move_collection(obj, visuals)
    if collider:
        logic('碰撞_' + name, 'box', pos, id=name, size=size)
    return obj


def cylinder(name, pos, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location(*pos))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_collection(obj, visuals)
    return obj


# 可探索区为平整庭院；高度图山地是外部远景，不伪装成可行走地形物理。
box('courtyard', (0, -0.3, 0), (62, 0.6, 70), grass)
box('path_main', (0, 0.015, 4), (5.5, 0.03, 58), paving, False)
box('path_cross', (0, 0.02, -3), (53, 0.04, 4.5), paving, False)
box('path_east', (16, 0.025, -7), (4, 0.05, 16), paving, False)
for x in (-30.5, 30.5): box('boundary_x_' + str(x), (x, 0.5, 0), (0.7, 1, 70))
for z in (-34.5, 34.5): box('boundary_z_' + str(z), (0, 0.5, z), (62, 1, 0.7))
# 档案馆：前墙留出门洞，碰撞由同尺寸盒子导出。
box('hall_floor', (0, -0.04, -18), (19, 0.08, 18), paving)
box('hall_back', (0, 3, -27), (19, 6, 0.6))
for x in (-9.2, 9.2): box('hall_side_' + str(x), (x, 3, -18), (0.6, 6, 18))
for x in (-5.8, 5.8): box('hall_front_' + str(x), (x, 3, -9), (6.8, 6, 0.6))
box('hall_lintel', (0, 5.4, -9), (5, 1.2, 0.6))
box('hall_roof', (0, 6.1, -18), (19.8, 0.4, 19))
box('gate', (0, 2.1, -9), (4.6, 4.2, 0.4), blue)['hx_shadow_mobility'] = 'dynamic'
logic('闸门交互', 'gate', (0, 0, -6.4), id='gate', label='档案馆闸门', node='gate', radius=3)
# 回廊和观景柱使近景具有深度，柱脚均有真实碰撞。
for x in (-12.5, 12.5):
    for z in (-22, -14, -6, 2):
        box('pillar_base_' + str(x) + '_' + str(z), (x, 0.2, z), (1.5, 0.4, 1.5))
        cylinder('pillar', (x, 2.8, z), 0.42, 5.2, stone)
        logic('柱碰撞', 'box', (x, 2.8, z), id=f'pillar_{x}_{z}', size=(0.85, 5.2, 0.85))
    box('colonnade', (x, 5.5, -10), (2, 0.5, 28), stone, False)
# 三个探索目标。
for identity, label, x, z in [('west', '西侧气象信标', -19, -3), ('east', '东侧地质信标', 20, -14), ('south', '南侧通讯信标', 7, 23)]:
    cylinder('beacon_base_' + identity, (x, 0.35, z), 1.2, 0.7, stone)
    logic('信标碰撞', 'box', (x, 0.35, z), id='beacon_base_' + identity, size=(2, 0.7, 2))
    cylinder('beacon_stem_' + identity, (x, 1.3, z), 0.18, 1.4, metal)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.42, location=location(x, 2.2, z))
    orb = bpy.context.object; orb.name = 'beacon_' + identity; orb.data.materials.append(cyan); move_collection(orb, visuals)
    logic('信标交互_' + identity, 'beacon', (x, 0, z), id=identity, label=label, node=orb.name, radius=3)


def imported_obj(filename, name, pos, height, mat):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.wm.obj_import(filepath=str(args.source / 'intermediate/RealTimeEnvMap/Assets' / filename), forward_axis='NEGATIVE_Z', up_axis='Y')
    selected = [obj for obj in bpy.context.selected_objects if obj.type == 'MESH']
    bpy.context.view_layer.objects.active = selected[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    coordinates = [vertex.co.copy() for vertex in obj.data.vertices]
    low = Vector(tuple(min(v[i] for v in coordinates) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in coordinates) for i in range(3)))
    origin = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    factor = height / (high.z - low.z)
    obj.data.transform(Matrix.Scale(factor, 4) @ Matrix.Translation(-origin))
    obj.location = location(*pos); obj.name = name
    obj.data.materials.clear(); obj.data.materials.append(mat)
    for polygon in obj.data.polygons: polygon.material_index = 0; polygon.use_smooth = True
    modifier = obj.modifiers.new('示例离线简化', 'DECIMATE'); modifier.ratio = 0.35
    bpy.context.view_layer.objects.active = obj; bpy.ops.object.modifier_apply(modifier=modifier.name)
    move_collection(obj, visuals)
    return obj


cylinder('robot_plinth', (0, 0.18, 5), 1.5, 0.36, blue)
imported_obj('R2D2.obj', 'survey_robot', (0, 0.36, 5), 2.4, metal)
logic('机器人碰撞', 'box', (0, 1.3, 5), id='robot', size=(1.8, 2.6, 1.8))
logic('机器人交互', 'robot', (0, 0, 7.2), id='robot', label='巡检机器人', node='survey_robot', radius=3.6)
box('archive_base', (0, 0.65, -22), (2.6, 1.3, 2.6), blue)
imported_obj('head.obj', 'archive_head', (0, 1.3, -22), 2.5, stone)
logic('档案交互', 'archive', (0, 0, -19.3), id='archive', label='核心档案终端', node='archive_head', radius=3)
box('lore_base', (-19, 0.6, 15), (2.2, 1.2, 2.2))
imported_obj('head.obj', 'memorial_head', (-19, 1.2, 15), 2.2, metal)
logic('纪念像交互', 'lore', (-19, 0, 17.2), id='memorial', label='旧时代纪念像', node='memorial_head', radius=3)
# 低多边形松树与山地远景。
for index, (x, z) in enumerate([(-24, 24), (-24, 5), (-24, -23), (25, 24), (24, 4), (26, -24), (-15, 28), (19, 30)]):
    cylinder('tree_trunk', (x, 1.7, z), 0.3, 3.4, bark)
    logic('树碰撞', 'box', (x, 1.7, z), id='tree_' + str(index), size=(0.65, 3.4, 0.65))
    for layer in range(3):
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=2.3-layer*0.45, radius2=0, depth=3, location=location(x, 3.3+layer*1.3, z))
        obj=bpy.context.object;obj.name='pine';obj.data.materials.append(foliage);move_collection(obj,visuals)
height_image = bpy.data.images.load(str(HERE / 'Authoring/Textures/heights.jpg'))
width, height = height_image.size
pixels = list(height_image.pixels)
vertices, faces, uv_values = [], [], []
segments = 80
for row in range(segments + 1):
    for column in range(segments + 1):
        u, v = column / segments, row / segments
        x, z = (u - 0.5) * 240, (v - 0.5) * 240
        sample = pixels[(min(height-1, int(v*height))*width+min(width-1, int(u*width)))*4]
        outside = max(abs(x)-33, abs(z)-37, 0)
        blend = min(1, outside/18);blend=blend*blend*(3-2*blend)
        altitude = (sample*42-4)*blend-0.45
        vertices.append(location(x, altitude, z));uv_values.append((u,1-v))
for row in range(segments):
    for column in range(segments):
        a=row*(segments+1)+column;b=a+segments+1
        faces.append((a,b,b+1,a+1))
mesh=bpy.data.meshes.new('Away3D 高度图山地');mesh.from_pydata(vertices,[],faces);mesh.update()
terrain=bpy.data.objects.new('terrain_backdrop',mesh);visuals.objects.link(terrain);mesh.materials.append(terrain_material)
uv=mesh.uv_layers.new()
for polygon in mesh.polygons:
    polygon.use_smooth=True
    for loop in polygon.loop_indices:uv.data[loop].uv=uv_values[mesh.loops[loop].vertex_index]
logic('出生点','spawn',(0,0.05,27))
scene=bpy.context.scene
scene.hxmaker_distance_fog.enabled=True;scene.hxmaker_distance_fog.mode='exp2';scene.hxmaker_distance_fog.start=12
scene.hxmaker_distance_fog.density=0.014;scene.hxmaker_distance_fog.color=(0.62,0.68,0.73)
# 为 Blender 编辑提供预览相机与太阳；运行时光照由示例配置。
bpy.ops.object.light_add(type='SUN',location=(0,0,15));sun=bpy.context.object;sun.name='编辑预览太阳';sun.rotation_euler=(0.5,-0.5,-0.3);sun.data.energy=3
bpy.ops.object.camera_add(location=location(0,1.65,27));camera=bpy.context.object
camera.rotation_euler=(Vector(location(0,1.6,-12))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.world.color=(0.25,0.28,0.32)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Authoring/World.blend'))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'Authoring/World.blend'))
exporter.export_world(HERE/'Assets/world')
