# 雪岭观测站：Away3D 资源探索示例

这是一个可步行、可交互、可完成任务并保存进度的小型第一人称世界。资源取自用户提供的 Away3D 5.0.3 示例，运行时使用 hxmaker，不依赖 Away3D。

## 运行与玩法

在本目录执行：

```bash
arch -x86_64 lime test html5
```

操作：

- WASD 或方向键移动，按住 Shift 奔跑，空格跳跃。
- 按住场景拖动环顾；屏幕方向按钮支持持续移动。
- E 或“交互”按钮操作附近物体：机器人、信标、闸门、档案和纪念像。
- F 切换距离雾，K 保存，H 查看帮助，R 回到入口，Esc 停止输入。
- 右上角地图显示玩家、三个青色信标及北侧档案馆。

任务流程：与巡检机器人交谈，激活西、东、南三个信标，在北侧档案馆开门，进入并读取核心档案。尚未恢复观测网络时，闸门既不能开启，也会实际阻挡角色。完成后可以继续探索，或选择“新旅程”重置本示例的存档。

任务变化会自动保存，每八秒保存一次当前位置，也可以手动保存。页面重新加载后恢复信标、闸门、完成状态、位置与朝向；数据保存在本机浏览器，换浏览器或清除网站数据后不会保留。加载失败时右上角可重试。

## 世界与边界

- 场景模型在 Blender 制作并导出 GLB，碰撞和交互清单由同一份 .blend 导出。
- 运行时包含胶囊角色控制、重力、跳跃、墙体与门碰撞、方向光阴影、PBR、同源天空与 IBL、距离雾和轻量 Bloom。
- 可行走区域是有明确边界的庭院和档案馆。外围高度图山地与雪山天空为远景，没有将视觉高度图伪装成任意地形碰撞。
- 当前是静态场景和本地单人任务示例，没有联网、自动 NavMesh、刚体或动态天气。
- 普通构建不包含测试命令入口；界面显示的位置用于探索定位。

## 在 Blender 编辑

`Authoring/World.blend` 已打包纹理，可以独立打开。场景包含：

- `WorldVisuals`：实际导出的模型、建筑、树木、庭院和远景。
- `WorldLogic`：碰撞、交互点和出生点辅助对象。自定义属性使用 `hx_kind`、`hx_id`、`hx_size`、`hx_node` 等字段。
- 场景属性中的 hxmaker 距离雾：先安装或运行仓库 `tools/blender/hxmaker_distance_fog.py`。

修改视觉物体时，请同步移动对应的碰撞和交互辅助对象。盒碰撞的世界尺寸由 `hx_size` 明确指定，当前导出器不自动从任意网格生成碰撞，也不解析旋转盒。交互点的 `hx_node` 必须匹配对应模型节点名。

保存修改后，从仓库根导出：

```bash
/Applications/Blender.app/Contents/MacOS/Blender \
  samples/3d/away3d-explorer/Authoring/World.blend --background \
  --python samples/3d/away3d-explorer/Tools/export_world.py -- \
  --output samples/3d/away3d-explorer/Assets/world
```

导出产物为 `world.glb`、`scene.json`、`fog.json`。使用不同文件基础名，避免模型与 JSON 在 Assets 对象表中冲突。Blender 的坐标转换由导出器统一处理：引擎 `(x,y,z)` 对应 Blender `(x,-z,y)`；距离雾使用实际世界单位。

从原 Away3D 资源重建初始 .blend 的命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python samples/3d/away3d-explorer/Tools/build_world.py -- \
  --source '/Users/rainy/Documents/haxelib/away3d-samples/5,0,3'
```

此命令会重写本示例的初始 .blend 和导出文件，编辑已有场景后应使用前面的导出命令。纹理与资源来源见 [资源记录](Authoring/RESOURCE_SOURCES.md)。

## 验收

在本目录构建：`arch -x86_64 lime build html5 -D hxmaker_explorer_checks`。

从仓库根启动 `python3 -m http.server 8733 --bind 127.0.0.1` 后运行：

```bash
CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
PLAYWRIGHT_MODULE=/usr/local/lib/node_modules/playwright \
HXMAKER_TEST_REPORT=/tmp/hxmaker-explorer-report.json \
node test/tools/run-explorer-browser.cjs
```

验收通过实际键盘步行完成任务，检查门碰撞、跳跃、鼠标环顾、屏幕方向键、页面刷新恢复存档和两次销毁重进。测试宏只提供状态读取、朝向定位和少量碰撞定位入口，不会进入普通构建。软件 WebGL 的结果只用于功能验证，不代表目标设备性能。

2026-10-19 的实际结果见[距离雾与观测站验证记录](../../../docs/距离雾与观测站验证记录-20261019.md)。

## 阴影几何策略

环境网格使用 `ShadowMobility3D.STATIC`，闸门和十只霸王龙使用 `DYNAMIC`。右侧分别显示静态／动态上传 KB；`U` 关闭骨骼动画后，刚体游走不上传阴影几何。Blender 网格自定义属性 `hx_shadow_mobility` 可写 `static` 或 `dynamic`，由导出器写入 `scene.json`。详见[缓存说明](../../../docs/静态与动态阴影缓存使用说明.md)。
