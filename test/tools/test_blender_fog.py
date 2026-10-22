"""在独立 Blender 后台实例中验证面板属性与配置导出。"""
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
sys.dont_write_bytecode = True
import bpy

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('hxmaker_distance_fog', root / 'tools/blender/hxmaker_distance_fog.py')
addon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(addon)
addon.register()
try:
    fog = bpy.context.scene.hxmaker_distance_fog
    fog.enabled = True
    fog.mode = 'exp2'
    fog.color = (0.5, 0.25, 1)
    fog.start = 4
    fog.density = 0.07
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / 'fog.json'
        data = addon.export_fog(bpy.context.scene, path)
        assert json.loads(path.read_text()) == data
        assert data['color'] == 0x8040ff
        assert data['mode'] == 'exp2' and data['enabled']
        saved = Path(temporary) / 'scene.blend'
        bpy.ops.wm.save_as_mainfile(filepath=str(saved))
        bpy.ops.wm.open_mainfile(filepath=str(saved))
        assert addon.build_fog_data(bpy.context.scene) == data
    fog = bpy.context.scene.hxmaker_distance_fog
    fog.mode = 'linear'
    fog.start = 20
    fog.end = 10
    try:
        addon.build_fog_data(bpy.context.scene)
        raise AssertionError('应拒绝结束距离小于起始距离')
    except ValueError:
        pass
    print('HXMAKER_BLENDER_FOG PASS', bpy.app.version_string)
finally:
    addon.unregister()
