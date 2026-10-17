# PBR 材质使用说明

2026-10-17 已补充第一阶段直接光照与第二阶段静态 IBL 的源码。需要同时使用本轮 hxmaker 和 hxmaker-openfl 源码。已离线生成示例环境资源；尚未执行 Haxe 编译、运行、视觉或性能验收。

## 当前支持范围

- `PbrMaterial3D` 使用金属度／粗糙度工作流，提供 GGX 微表面分布、相关 Smith 可见性和 Schlick 菲涅耳响应。
- 支持基础颜色贴图、线性基础色因子、金属度、粗糙度、自发光、曝光和可选 Reinhard 色调映射。
- 复用场景方向光、点光和聚光，最多四盏；复用主方向光的硬阴影与 PCF4。
- 支持现有 OPAQUE、MASK、BLEND，以及静态和 CPU 蒙皮模型；BLEND 仍按普通表面混合处理，不包含折射。
- PBR、Lambert、Unlit 可以在同一场景混用；不同着色模型使用独立程序和批次。
- 可选静态 IBL：GGX 预过滤环境反射、漫反射环境积分及 split-sum BRDF 查找表，支持强度与绕 Y 轴旋转。

尚不包含第三阶段的金属粗糙度贴图、法线贴图、AO 贴图、自发光贴图和清漆等扩展。GLB 中这些尚不支持的贴图仍明确报错，不静默丢失。`ambientColor` 继续提供原有的简化环境漫反射；启用 IBL 后可降低 `ambientIntensity`，避免重复补光。

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

## 第二阶段：IBL 环境光照与反射

环境资源由 `tools/bake-ibl.py` 离线生成，不能把普通全景图直接赋给环境接口。输出为 `environment.png` 和 `environment.json`，通过现有 Assets 加载：

```haxe
var assets = new hx.assets.Assets();
assets.loadBitmapData("assets/ibl/environment.png");
assets.loadJson("assets/ibl/environment.json");
assets.onComplete(_ -> {
    var environment = hx.light.Environment3D.fromData(
        assets.getBitmapData("environment"), assets.getObject("environment")
    );
    environment.intensity = 1;
    environment.rotation = 30;
    scene.environment = environment;
    scene.requestRender();
});
assets.onError(error -> { trace("环境资源加载失败：" + error.error); });
assets.start();
```

Assets 必须在场景使用期间保持存活。`Environment3D` 与场景都借用图片；释放时先从所有场景清除 `environment` 引用，再调用环境的 `dispose()`，最后调用持有图片的 `assets.clean()`。销毁一个场景不会销毁其他场景共享的环境。

| 环境参数 | 默认值 | 作用 |
| --- | --- | --- |
| `scene.environment` | null | 仅对启用光照的 PBR 材质使用环境资源 |
| `environment.enabled` | true | 开关环境光照与反射 |
| `environment.intensity` | 1 | 非负环境亮度倍率，0 相当于关闭 |
| `environment.rotation` | 0 | 绕世界 Y 轴旋转角度，不改变背景 |
| `environment.invalidate()` | — | 图片内容更新后递增版本，使场景重绘检测失效 |

### 生成环境资源

从仓库根目录执行以下命令可重新生成自有示例摄影棚，不需要第三方素材、Pillow 或 GPU：

```bash
python3 tools/bake-ibl.py --output samples/3d/pbr-material/Assets/ibl
```

生成自定义环境时提供宽高比 2:1 的等距柱状全景图：

```bash
python3 tools/bake-ibl.py --input /绝对路径/studio.hdr --output /绝对路径/ibl --width 256 --levels 6 --samples 512
```

支持常见 `-Y/+X` 方向的 Radiance RGBE HDR（现代扫描行 RLE 或无压缩扫描行）；旧式 RGBE 游程编码、XYZE 和 EXR 尚不支持。PNG/JPEG 输入需要可选的 Pillow，并按 sRGB 解码。HDR 输入按线性值处理，不再次进行 sRGB 解码。`--exposure` 可在烘焙前缩放辐射值；采样数和分辨率越高，离线处理越慢。

图集依次存放按感知粗糙度等距排列的反射层、漫反射 `E/π` 层和 BRDF 查找表。各反射层由 GGX 重要性采样预过滤，漫反射通过余弦加权半球采样积分；运行时按粗糙度混合相邻反射层，并用 `N·V` 和粗糙度查 BRDF 表。全景接缝和各层边缘有独立保护像素。

### 性能与阶段边界

- 全部预积分数据打包为单张二维图集，额外占用一个纹理单元；不依赖立方体贴图或显式纹理 LOD 扩展，不增加独立绘制通道。
- 同一场景共享环境，不改变原有材质合批条件。统一示例 PBR 参数后，主场景仍预计为 2 批；剩余基础纹理槽位减少，在多贴图的大场景中可能提前拆批。
- 图集使用不透明 PNG 保存范围归一化的线性 RGB，范围在 JSON 中记录；RGB 查找表分量按 0～1 保存。采样时不会再次执行 sRGB 解码。不得将图集作为普通图片做调色、Alpha 处理或有损压缩。
- 这种 8 位范围编码可存储大于 1 的环境辐射，但不是浮点 HDR 纹理。极端明暗比会损失暗部精度，BRDF 表也存在 8 位量化误差；后续高保真路线可增加浮点或独立 HDR 编码。
- 当前仍为 LDR 场景输出和材质级色调映射，未升级 HDR 后处理管线。环境光在色调映射前与直接光、自发光在线性空间相加。
- 当前为远距离静态环境，不反射场景内角色或动态物体，不提供局部探针、视差修正、实时环境捕获或天空盒背景。
- IBL 不受主方向光阴影衰减；环境遮蔽贴图属于第三阶段，当前不提供遮挡环境光的局部 AO。因此接触位置仍需直接光阴影辅助。
- 纹理槽位不足、资源超过设备尺寸限制或低精度片元无法表示环境范围时，保留直接光照并关闭 IBL；结果见 `scene.stats.environmentStatus`。`environmentTextureBytes` 是借用图集按实际上传尺寸估算的显存，不属于离屏目标独占内存。
- 图集不能同时作为 PBR 基础色或辅助纹理，以免采样状态和数据含义冲突。资源释放、二维采样状态恢复及上下文重新上传沿用已有 OpenFL 协议。

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

示例位于 `samples/3d/pbr-material`，启动类继承 `HxmakerApplication`，业务内容位于 `GameStage`。自带程序生成的摄影棚资源，无需下载外部素材；初始视角下三行球体由远到近分别为 Lambert、PBR 非金属、PBR 金属；列方向粗糙度递增。

镜头通过 `OrbitCameraController3D` 和 `Scene3DInput` 控制：视口内左键或单指拖动旋转，滚轮缩放；上方提供拉近、拉远、复位和自动环绕开关。距离限制为 4～30，俯仰角为 5°～80°。手动拖动或缩放会停止自动环绕，再次开启从当前角度继续。复位恢复初始位置并停止自动环绕；触屏可通过拉近／拉远按钮缩放，当前不提供双指缩放。输入适配器与控制器随业务舞台销毁时解除引用和监听。

示例新增环境光开关、亮度增减、每次 30° 的旋转与复位按钮。保留统一 PBR 参数和恢复原始参数按钮，可同时观察环境变化和批次变化。

按照项目要求，本次未执行以下验证。需要编译或运行验证时先通知用户，不自动执行。

1. 编译基础引擎与 PBR 示例，确认 Haxe 类型和 Shader 链接。
2. 手动调用 `test/PbrMaterialChecks.hx` 的 `run()`，检查源材质映射、默认材质、实例隔离、变更通知和合批条件。
3. 观察球体高光是否随相机移动，粗糙度是否改变高光宽度，金属是否削弱漫反射。
4. 混用三类材质，检查参数不串用；确认主光阴影不压暗补光与自发光。
5. 检查带基础贴图的 GLB、蒙皮角色、MASK、BLEND、双面与镜像网格。
6. 检查关闭光照、上下文重建、材质修改与资源释放；在目标设备上记录实际性能和精度降级表现。
7. 手动调用 `test/Environment3DChecks.hx` 的 `run()`，检查共享环境、参数失效和借用资源生命周期。
8. 比较环境开关下金属暗部与粗糙度反射，检查亮度、旋转、全景接缝及极点；确认环境光不被主光阴影一并压暗。
9. 在支持与不支持高精度片元的设备上检查图集精度、纹理槽位回退、上下文重建和二维纹理状态恢复。
10. 检查拖动、滚轮、缩放按钮、镜头复位与自动环绕切换，以及拖出视口、触摸取消和舞台销毁后的输入解绑。

算法参考：[Filament 光照模型说明](https://google.github.io/filament/main/filament.html)。本轮复用现有灯光与 LDR 管线，不等同于完整 Filament 渲染能力。
