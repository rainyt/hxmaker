"""在 Blender 场景属性中编辑并导出 hxmaker 距离雾；不改变现有材质和世界节点。"""
import json
import math
from pathlib import Path

import bpy
from bpy.props import BoolProperty, EnumProperty, FloatProperty, FloatVectorProperty, PointerProperty, StringProperty
from bpy_extras.io_utils import ExportHelper

bl_info = {
    "name": "hxmaker 距离雾",
    "author": "hxmaker",
    "version": (1, 0, 0),
    "blender": (3, 6, 0),
    "location": "属性 > 场景 > hxmaker 距离雾",
    "description": "编辑场景级距离雾，导出 hxmaker-fog-1 配置",
    "category": "Scene",
}


def build_fog_data(scene):
    """颜色保持 sRGB，距离保持引擎世界单位，不隐式使用显示单位换算。"""
    fog = scene.hxmaker_distance_fog
    if fog.mode == 'linear' and fog.end <= fog.start:
        raise ValueError('线性雾结束距离必须大于起始距离')
    values = [fog.start, fog.end, fog.density, fog.max_opacity, *fog.color]
    if any(not math.isfinite(value) for value in values):
        raise ValueError('距离雾参数必须为有限数值')
    channels = [round(max(0, min(1, value)) * 255) for value in fog.color]
    return {'format': 'hxmaker-fog-1', 'enabled': fog.enabled, 'mode': fog.mode,
            'color': (channels[0] << 16) | (channels[1] << 8) | channels[2],
            'start': fog.start, 'end': fog.end, 'density': fog.density,
            'maxOpacity': fog.max_opacity, 'affectSkybox': fog.affect_skybox}


def export_fog(scene, filepath):
    """可直接被后续 Blender 场景导出器复用。"""
    data = build_fog_data(scene)
    Path(filepath).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return data


class HXMAKER_PG_distance_fog(bpy.types.PropertyGroup):
    enabled: BoolProperty(name="启用距离雾", default=False)
    mode: EnumProperty(name="模式", items=[('linear', '线性', '从起始到结束距离均匀增加'),
                                            ('exp', '指数', '按距离指数增加'),
                                            ('exp2', '平方指数', '按距离平方指数增加')], default='linear')
    color: FloatVectorProperty(name="雾颜色（sRGB）", subtype='COLOR_GAMMA', size=3, min=0, max=1,
                               default=(184 / 255, 200 / 255, 216 / 255))
    start: FloatProperty(name="起始距离", min=0, max=1e9, default=10)
    end: FloatProperty(name="结束距离", min=0, max=1e9, default=100)
    density: FloatProperty(name="密度", min=0, max=1e6, default=0.02, precision=4)
    max_opacity: FloatProperty(name="最大雾量", min=0, max=1, default=1)
    affect_skybox: BoolProperty(name="影响天空", default=False)


class HXMAKER_OT_export_distance_fog(bpy.types.Operator, ExportHelper):
    bl_idname = 'hxmaker.export_distance_fog'
    bl_label = '导出距离雾 JSON'
    filename_ext = '.json'
    filter_glob: StringProperty(default='*.json', options={'HIDDEN'})

    def execute(self, context):
        try:
            export_fog(context.scene, self.filepath)
        except (OSError, ValueError) as error:
            self.report({'ERROR'}, str(error))
            return {'CANCELLED'}
        self.report({'INFO'}, '距离雾配置已导出')
        return {'FINISHED'}


class HXMAKER_PT_distance_fog(bpy.types.Panel):
    bl_label = 'hxmaker 距离雾'
    bl_idname = 'HXMAKER_PT_distance_fog'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'

    def draw(self, context):
        layout = self.layout
        fog = context.scene.hxmaker_distance_fog
        layout.prop(fog, 'enabled')
        layout.prop(fog, 'mode')
        layout.prop(fog, 'color')
        layout.prop(fog, 'start')
        layout.prop(fog, 'end' if fog.mode == 'linear' else 'density')
        layout.prop(fog, 'max_opacity')
        layout.prop(fog, 'affect_skybox')
        layout.label(text='距离使用引擎世界单位')
        layout.label(text='效果请在 hxmaker 中预览')
        layout.operator('hxmaker.export_distance_fog')


CLASSES = (HXMAKER_PG_distance_fog, HXMAKER_OT_export_distance_fog, HXMAKER_PT_distance_fog)


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.hxmaker_distance_fog = PointerProperty(type=HXMAKER_PG_distance_fog)


def unregister():
    if hasattr(bpy.types.Scene, 'hxmaker_distance_fog'):
        del bpy.types.Scene.hxmaker_distance_fog
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == '__main__':
    register()
