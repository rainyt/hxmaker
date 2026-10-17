# PBR 材质使用说明

2026-10-17 首版源码实现。需要同时使用本轮 hxmaker 和 hxmaker-openfl 源码；尚未执行编译、运行、视觉或性能验收。

## 当前支持范围

- `PbrMaterial3D` 使用金属度／粗糙度工作流，提供 GGX 微表面分布、相关 Smith 可见性和 Schlick 菲涅耳响应。
- 支持基础颜色贴图、线性基础色因子、金属度、粗糙度、自发光、曝光和可选 Reinhard 色调映射。
- 复用场景方向光、点光和聚光，最多四盏；复用主方向光的硬阴影与 PCF4。
- 支持现有 OPAQUE、MASK、BLEND，以及静态和 CPU 蒙皮模型；BLEND 仍按普通表面混合处理，不包含折射。
- PBR、Lambert、Unlit 可以在同一场景混用；不同着色模型使用独立程序和批次。

首版不包含 IBL 环境反射、金属粗糙度贴图、法线贴图、AO 贴图、自发光贴图和清漆等扩展。GLB 中这些尚不支持的贴图仍明确报错，不静默丢失。`ambientColor` 只提供简化的非金属环境漫反射，不能替代 IBL；纯金属在无直接光区域偏暗属于本阶段限制。

## 手动创建材质

```haxe
var material = new hx.material.PbrMaterial3D(null, 0xf0b06c, 0, 0.65);
var mesh = new hx.display3d.MeshObject(hx.geometry.BoxGeometry.create(), material);
mesh.castShadow = true;
scene.root.addChild(mesh);

var light = new hx.light.DirectionalLight3D(0xffffff, 3);
light.direction = new hx.geom.Vector3D(-1, -2, -1);
light.shadowEnabled = true;
scene.root.addChild(light);
scene.light = light;
scene.ambientIntensity = 0.25;
```

PBR 的漫反射包含 `1/π` 因子，因此与旧 Lambert 使用同样光强时亮度不同。上面的光强是初始调色示例，不是物理单位或跨设备性能承诺。点光与聚光沿用现有范围衰减，不是严格的物理平方反比衰减。

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `texture` | null | 基础色贴图，按 sRGB 解码；借用引用 |
| `color` | 0xffffff | 显示空间 RGB 颜色，与贴图共同转线性计算 |
| `baseColorFactor` | [1,1,1] | 额外的线性 RGB 因子，范围 0～1 |
| `metallic` | 0 | 0 为非金属，1 为金属 |
| `roughness` | 0.5 | 感知粗糙度，范围 0～1，内部平方后用于微表面计算 |
| `emissive` | [0,0,0] | 非负线性 RGB 自发光，可大于 1 |
| `exposure` | 1 | 非负曝光倍率 |
| `toneMapping` | true | 在当前材质输出前进行 Reinhard 色调映射 |
| `lightingEnabled` | true | 关闭后使用无光照路径，PBR 专属因子不参与计算 |

非金属镜面基础反射率固定为 0.04，金属使用基础颜色作为镜面反射色。`roughness` 着色下限为 0.045；片元仅支持中精度的设备使用 0.1，避免高光中心的数值不稳定。

`baseColorFactor`、`emissive` 的赋值复制数组，读取返回副本；修改副本后需要重新赋值。材质参数修改会使引用该材质的网格失效；多个网格共享同一材质时一起变化。不要直接通过 `setUniform` 修改内部 `uPbr*` 参数。

曝光和色调映射仅应用于 PBR 材质，旧 Lambert 和 Unlit 行为保持不变。当前离屏目标仍为 LDR，Bloom 读取材质映射后的颜色，自发光大于 1 不代表拥有 HDR 泛光链路。

## 导入模型

```haxe
var model = assets.getModel("character").createInstance(-1, {pbrEnabled:true});
scene.root.addChild(model);
for (mesh in model.meshes) mesh.castShadow = true;
```

`pbrEnabled:true` 优先于 `lightingEnabled`。未设置 PBR 时，`lightingEnabled:true` 仍创建 Lambert；两个选项都省略时仍使用无光照材质。

启用 PBR 后，模型资产保存的基础色、金属度、粗糙度、自发光因子与透明参数传入运行时材质。线性基础色因子直接传递，避免通过整数 RGB 往返造成量化损失。未显式指定材质的 GLB 图元使用 glTF 默认的白色、金属度 1、粗糙度 1。

FBX 沿用现有导入能力：金属度通常为 0、粗糙度为 1，不会自动把 FBX 的复杂材质网络转换成 PBR。可在创建实例后调整网格的 `PbrMaterial3D`。

模型实例拥有导入创建的材质，`model.dispose()` 会释放它们。手工创建的共享材质和几何由业务在网格解除引用后显式释放；材质不会销毁借用贴图。

## Q 版建议

普通皮肤、塑料和衣物从 `metallic=0`、`roughness=0.55～0.85` 开始调色；金属装备单独设置金属材质。优先使用清晰色块、平滑法线和柔和布光，减少细碎表面纹理。

没有 IBL 时，不建议用大面积纯金属作为整个场景的主要视觉；可增加直接补光，但它不是环境反射的等价替代。需要明确二次元阴影色阶时，仍需后续独立的 Toon 材质路线。

## 示例与待验证项目

示例位于 `samples/3d/pbr-material`，启动类继承 `HxmakerApplication`，业务内容位于 `GameStage`。无外部资源，初始视角下三行球体由远到近分别为 Lambert、PBR 非金属、PBR 金属；列方向粗糙度递增。

镜头通过 `OrbitCameraController3D` 和 `Scene3DInput` 控制：视口内左键或单指拖动旋转，滚轮缩放；上方提供拉近、拉远、复位和自动环绕开关。距离限制为 4～30，俯仰角为 5°～80°。手动拖动或缩放会停止自动环绕，再次开启从当前角度继续。复位恢复初始位置并停止自动环绕；触屏可通过拉近／拉远按钮缩放，当前不提供双指缩放。输入适配器与控制器随业务舞台销毁时解除引用和监听。

按照项目要求，本次未执行以下验证。需要编译或运行验证时先通知用户，不自动执行。

1. 编译基础引擎与 PBR 示例，确认 Haxe 类型和 Shader 链接。
2. 手动调用 `test/PbrMaterialChecks.hx` 的 `run()`，检查源材质映射、默认材质、实例隔离、变更通知和合批条件。
3. 观察球体高光是否随相机移动，粗糙度是否改变高光宽度，金属是否削弱漫反射。
4. 混用三类材质，检查参数不串用；确认主光阴影不压暗补光与自发光。
5. 检查带基础贴图的 GLB、蒙皮角色、MASK、BLEND、双面与镜像网格。
6. 检查关闭光照、上下文重建、材质修改与资源释放；在目标设备上记录实际性能和精度降级表现。
7. 检查拖动、滚轮、缩放按钮、镜头复位与自动环绕切换，以及拖出视口、触摸取消和舞台销毁后的输入解绑。

算法参考：[Filament 光照模型说明](https://google.github.io/filament/main/filament.html)。本轮复用现有灯光与 LDR 管线，不等同于完整 Filament 渲染能力。
