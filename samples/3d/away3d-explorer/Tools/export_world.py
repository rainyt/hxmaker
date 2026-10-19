"""从 Blender 导出本示例的视觉 GLB、显式碰撞和交互清单。"""
import importlib.util
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy

ROOT = Path(__file__).resolve().parents[4]


def load_fog_addon():
    existing = sys.modules.get('hxmaker_distance_fog')
    if existing is not None:
        return existing
    spec = importlib.util.spec_from_file_location('hxmaker_distance_fog', ROOT / 'tools/blender/hxmaker_distance_fog.py')
    addon = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = addon
    spec.loader.exec_module(addon)
    if not hasattr(bpy.types.Scene, 'hxmaker_distance_fog'):
        addon.register()
    return addon


def world_position(obj):
    p = obj.matrix_world.translation
    return [round(p.x, 5), round(p.z, 5), round(-p.y, 5)]


def export_world(output):
    addon = load_fog_addon()
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    boxes = []
    interactions = []
    spawn = None
    for obj in scene.objects:
        kind = obj.get('hx_kind')
        if kind == 'box':
            boxes.append({'id': obj.get('hx_id', obj.name), 'position': world_position(obj), 'size': list(obj['hx_size'])})
        elif kind in ('beacon', 'gate', 'archive', 'robot', 'lore'):
            interactions.append({'id': obj['hx_id'], 'kind': kind, 'label': obj['hx_label'],
                                 'position': world_position(obj), 'node': obj.get('hx_node', ''), 'radius': float(obj.get('hx_radius', 3))})
        elif kind == 'spawn':
            spawn = world_position(obj)
    if spawn is None:
        raise ValueError('场景缺少出生点')
    mobility = {}
    for obj in bpy.data.collections['WorldVisuals'].all_objects:
        value = obj.get('hx_shadow_mobility', 'static')
        if value not in ('static', 'dynamic'):
            raise ValueError(f'{obj.name} 的 hx_shadow_mobility 必须为 static 或 dynamic')
        if obj.type == 'MESH':
            mobility[obj.name] = value
    data = {'shadowMobility': mobility, 'format': 'hxmaker-explorer-world-1', 'spawn': spawn, 'colliders': boxes, 'interactions': interactions}
    (output / 'scene.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    addon.export_fog(scene, output / 'fog.json')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.collections['WorldVisuals'].all_objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output / 'world.glb'), export_format='GLB', use_selection=True,
                              export_apply=True, export_animations=False, export_extras=False,
                              export_image_format='AUTO', export_yup=True)
    print('HXMAKER_WORLD_EXPORT', len(boxes), len(interactions), output)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    export_world(args.output)
