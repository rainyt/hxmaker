# 3D 显示 API 包迁移说明

本次将独立三维显示节点迁入 `hx.display3d`，不提供旧路径别名或 typedef 转发。这是一次需要调用方更新 import 的 API 变更。

## 类型分布

| 原路径 | 新路径 |
| --- | --- |
| hx.display.Node3D | hx.display3d.Node3D |
| hx.display.MeshObject | hx.display3d.MeshObject |
| hx.display.Camera3D | hx.display3d.Camera3D |
| hx.display.Model3D | hx.display3d.Model3D |
| hx.display.Model3DOptions | hx.display3d.Model3DOptions |

`Scene3D` 仍在 `hx.display`，仍继承二维 `DisplayObject`。其 `root`、`camera`、网格拾取和模型实例等接口使用新包类型。三维节点通过 `scene.root.addChild` 加入，不直接加入二维容器。

```haxe
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;

var scene = new Scene3D(800, 600);
var camera = new Camera3D();
scene.root.addChild(camera);
scene.camera = camera;
```

几何、材质、灯光、动画、控制器、碰撞、导航、数学、事件和 Assets 保持原包。类名、继承关系、资源所有权、显式更新及多纹理合批规则保持原行为。

## 调用方需要处理

- 将上表五个类型的 import 和全限定类型名改为 `hx.display3d`；旧路径不能继续编译。
- 字符串反射、持久化完整类名或自定义生成器若使用旧名称，需要同步更新。没有运行时旧名映射。
- hxmaker 与 hxmaker-openfl 必须配套更新，后端三个三维渲染文件已改用新路径。
- 构建配置已补充新包的类型保留规则；Assets 与节点动画内部访问权限已同步更新。

按用户安排，仓库 samples 本轮不修改，由用户重新整理。引用旧类型的示例在改完 import 前不能直接重新构建；核心 test 入口中的引用已更新。现有文档代码片段中的全限定名已同步调整。

## 本次验证

2026-10-17：核心入口编译通过；额外强制包含 `hx.display3d`、`hx.render3d.openfl` 与 `hx.navigation3d` 的 HTML5 编译通过。五个搬迁类型在归一化包路径和必要 import 后，词法逻辑与搬迁前一致。

在 `/tmp` 中复制导航示例并更新副本 import，HTML5 构建和 Chrome 软件 WebGL 运行通过：`HXMAKER_NAV_AGENT_CHECKS PASS`（15 项）、`HXMAKER_NAV_SAMPLE_CHECKS PASS`（14 项），Assets 角色加载和三维绘制正常。本验证没有修改仓库 samples，也未新增硬件性能结论。

hxmaker-openfl 配套提交：`aa7a3a8`。
