# PBR 材质使用说明

2026-10-17 已补充直接光照、静态 IBL 与第三阶段 PBR 贴图链路。用户已确认第二阶段测试通过；第三阶段尚未编译或运行验证。需要同时使用本轮 hxmaker 和 hxmaker-openfl 源码，示例环境及贴图资源已离线生成。

## 当前支持范围

- `PbrMaterial3D` 使用金属度／粗糙度工作流，提供 GGX 微表面分布、相关 Smith 可见性和 Schlick 菲涅耳响应。
- 支持基础颜色、金属粗糙度、切线空间法线、AO 和自发光贴图，以及对应因子、曝光和可选 Reinhard 色调映射。
- 复用场景方向光、点光和聚光，最多四盏；复用主方向光的硬阴影与 PCF4。
- 支持现有 OPAQUE、MASK、BLEND，以及静态和 CPU 蒙皮模型；BLEND 仍按普通表面混合处理，不包含折射。
- PBR、Lambert、Unlit 可以在同一场景混用；不同着色模型使用独立程序和批次。
- 可选静态 IBL：GGX 预过滤环境反射、漫反射环境积分及 split-sum BRDF 查找表，支持强度与绕 Y 轴旋转。

GLB 已支持上述五类贴图，仍不包含清漆、透射、各向异性等扩展。第二套 UV、纹理坐标变换、压缩纹理及必需扩展仍明确报错。`ambientColor` 继续提供原有的简化环境漫反射；启用 IBL 后可降低 `ambientIntensity`，避免重复补光。

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
- 当前为远距离静态环境，不反射场景内角色或动态物体，不提供局部探针、视差修正、实时环境捕获。天空背景现由独立的 `Scene3D.skybox` 提供，见[天空环境使用说明](天空环境使用说明.md)。
- IBL 不受主方向光阴影衰减；第三阶段的 AO 贴图衰减 IBL 和旧环境光，不影响直接光与自发光。静态 AO 不能代替动态角色接触阴影。
- 纹理槽位不足、资源超过设备尺寸限制或低精度片元无法表示环境范围时，保留直接光照并关闭 IBL；结果见 `scene.stats.environmentStatus`。`environmentTextureBytes` 是借用图集按实际上传尺寸估算的显存，不属于离屏目标独占内存。
- 图集不能同时作为 PBR 基础色或辅助纹理，以免采样状态和数据含义冲突。资源释放、二维采样状态恢复及上下文重新上传沿用已有 OpenFL 协议。

## 第三阶段：PBR 贴图

以下代码假设五张图片已经通过 Assets 加载完成：

```haxe
var material = new hx.material.PbrMaterial3D();
material.texture = assets.getBitmapData("base-color");
material.metallic = 1;
material.roughness = 1;
material.metallicRoughnessTexture = assets.getBitmapData("metallic-roughness");
material.normalTexture = assets.getBitmapData("normal");
material.normalScale = 1;
material.occlusionTexture = assets.getBitmapData("occlusion");
material.occlusionStrength = 1;
material.emissiveTexture = assets.getBitmapData("emissive");
material.emissive = [1, 1, 1];
material.setMapSampler("normal", true, true, hx.material.TextureWrap3D.REPEAT, hx.material.TextureWrap3D.REPEAT);
```

| 贴图属性 | 编码与通道 | 与因子的关系 |
| --- | --- | --- |
| `texture` | 基础颜色 RGB 按 sRGB 解码，Alpha 控制透明 | 乘以基础色和不透明度因子 |
| `metallicRoughnessTexture` | 线性 G 为粗糙度，B 为金属度 | 乘以 `roughness` 和 `metallic` |
| `normalTexture` | 线性 RGB 解码为切线空间 XYZ，采用 +Y 约定 | XY 乘以 `normalScale` 后归一化 |
| `occlusionTexture` | 线性 R 通道 | 间接光乘以 `1 + strength × (R - 1)` |
| `emissiveTexture` | RGB 按 sRGB 解码 | 乘以线性的 `emissive`，不改变不透明度 |

默认 `metallic=0`，即使贴图 B 通道为 1 也不会变成金属；默认 `emissive=[0,0,0]`，绑定自发光贴图后仍需设置非零自发光因子。贴图设为 `null` 可关闭该项，恢复对应因子的常量行为。

### UV、切线与动画

- 各贴图独立使用原始 `TEXCOORD_0`，不受基础色图集裁切区域影响；手动绑定也支持独立位图区域。
- GLB 的 `TANGENT` 浮点 VEC4 现已导入，XYZ 为切线，W 必须为正负 1。没有切线时按位置、UV 和法线按需生成，再进行正交化。
- 自动生成采用 UV 导数累加，不是完整 MikkTSpace 实现。需要与制作软件一致时应随 GLB 导出切线；镜像 UV 边界需要拆分顶点。
- 法线使用逆转置变换，切线使用线性矩阵并重新正交化；镜像同步翻转手性。CPU 蒙皮同步更新法线与切线，刚性单关节继续走网格矩阵路径。
- 运行时几何可以使用构造函数第五个参数传入切线，或调用 `setTangents()`；`setTangents(null)` 恢复自动生成。显式切线需要随位置、法线和 UV 同步维护，自动切线在 `invalidate()` 后重算。
- 双面材质在背面翻转最终着色法线；阴影偏差继续使用几何法线，法线贴图不会改变投影轮廓。

### 采样、合批与资源

`setMapSampler(map, smoothing, minSmoothing, wrapU, wrapV, minFilter)` 分别设置放大过滤、缩小过滤和 U/V 包裹。`map` 接受 `metallicRoughness`、`normal`、`occlusion`、`emissive`。最后一个可选参数使用 `TextureMinFilter3D` 完整缩小过滤模式，非 null 时优先于 `minSmoothing`。旧调用方式保持无 mipmap。GLB 中每种贴图的采样设置独立导入。

无图集、无填充且保留 CPU 图片的二次幂整图使用硬件 CLAMP、REPEAT 或 MIRROR，并按需生成 mipmap，保留连续 UV 导数。图集与其他图片继续使用区域内包裹，mipmap 降级为对应基础层过滤，避免跨区域渗色；此路径的重复接缝不进行跨区域硬件混合。详见 [mipmap使用说明](mipmap使用说明.md)。

同一底层图片在多个槽位共用 GL 采样状态，各槽位需使用相同的实际过滤与硬件包裹配置，否则明确报错。共享 ORM 图片作为 MR 与 AO 可以使用不同通道，但仍占两个槽位。带辅助贴图的材质继续按材质实例隔离批次；同一材质实例可被多个网格共享。

四张额外贴图最多增加四个采样器，与基础色、IBL、主光阴影一起通常需要七个纹理单元。纹理或着色器资源不足时可能无法绘制完整材质；IBL 保留槽位不足降级，必要贴图不静默丢弃。法线贴图需要切线和原始 UV 属性，使用到第七个属性位置。无数据贴图的光照路径仍为每顶点 13 个浮点数；仅数据贴图为 15 个，包含法线贴图为 19 个。

图片沿用 OpenFL 位图上传路径。数据贴图建议使用不透明 PNG：解预乘不能恢复完全透明像素中已经丢失的 RGB，半透明像素也可能有量化误差。法线、MR、AO 不做 sRGB 解码，不应按基础色调色。

贴图均为借用引用；材质销毁只解除绑定，不销毁资产图片。模型数据版本和构建规则版本均提升为 2；旧中立源数据可省略新增可选字段，构建器会填入无贴图、系数 1 等默认值。

## 导入模型

```haxe
var model = assets.getModel("character").createInstance(-1, {pbrEnabled:true});
scene.root.addChild(model);
for (mesh in model.meshes) mesh.castShadow = true;
```

`pbrEnabled:true` 优先于 `lightingEnabled`。未设置 PBR 时，`lightingEnabled:true` 仍创建 Lambert；两个选项都省略时仍使用无光照材质。

启用 PBR 后，模型资产保存的五类贴图、基础色、金属度、粗糙度、自发光因子与透明参数传入运行时材质。线性基础色因子直接传递，避免通过整数 RGB 往返造成量化损失。未显式指定材质的 GLB 图元使用 glTF 默认的白色、金属度 1、粗糙度 1。

FBX 沿用现有导入能力：金属度通常为 0、粗糙度为 1，不会自动把 FBX 的复杂材质网络转换成 PBR。可在创建实例后调整网格的 `PbrMaterial3D`。

模型实例拥有导入创建的材质，`model.dispose()` 会释放它们。手工创建的共享材质和几何由业务在网格解除引用后显式释放；材质不会销毁借用贴图。

## Q 版建议

普通皮肤、塑料和衣物从 `metallic=0`、`roughness=0.55～0.85` 开始调色；金属装备单独设置金属材质。优先使用清晰色块、平滑法线和柔和布光，减少细碎表面纹理。

没有 IBL 时，不建议用大面积纯金属作为整个场景的主要视觉；可增加直接补光，但它不是环境反射的等价替代。需要明确二次元阴影色阶时，仍需后续独立的 Toon 材质路线。

## 示例与待验证项目

示例位于 `samples/3d/pbr-material`，启动类继承 `HxmakerApplication`，业务内容位于 `GameStage`。自带程序生成的摄影棚资源，无需下载外部素材；初始视角下三行球体由远到近分别为 Lambert、PBR 非金属、PBR 金属；列方向粗糙度递增。

镜头通过 `OrbitCameraController3D` 和 `Scene3DInput` 控制：视口内左键或单指拖动旋转，滚轮缩放；上方提供拉近、拉远、复位和自动环绕开关。距离限制为 4～30，俯仰角为 5°～80°。手动拖动或缩放会停止自动环绕，再次开启从当前角度继续。复位恢复初始位置并停止自动环绕；触屏可通过拉近／拉远按钮缩放，当前不提供双指缩放。输入适配器与控制器随业务舞台销毁时解除引用和监听。

示例保留环境控制、统一 PBR 参数和恢复原始参数按钮。新增“贴图示例”开关，切换为内嵌五类贴图与显式切线的 GLB 球体；MR、法线、AO、自发光各有独立开关。默认显示原球阵列，统一／恢复参数时也会回到原球阵列。

第三阶段示例资源由 `python3 tools/generate-pbr-sample.py` 生成，全部是自有程序纹理与网格，不依赖第三方素材。

第二阶段已获用户确认测试通过。本轮未执行第三阶段编译或测试，以下列出本轮及可复用的验证项目；需要执行时先通知用户，不自动执行。

1. 编译基础引擎与 PBR 示例，确认 Haxe 类型和 Shader 链接。
2. 手动调用 `test/PbrMaterialChecks.hx` 的 `run()`，检查源材质映射、默认材质、实例隔离、变更通知和合批条件。
3. 观察球体高光是否随相机移动，粗糙度是否改变高光宽度，金属是否削弱漫反射。
4. 混用三类材质，检查参数不串用；确认主光阴影不压暗补光与自发光。
5. 检查带基础贴图的 GLB、蒙皮角色、MASK、BLEND、双面与镜像网格。
6. 检查关闭光照、上下文重建、材质修改与资源释放；在目标设备上记录实际性能和精度降级表现。
7. 手动调用 `test/Environment3DChecks.hx` 的 `run()`，检查共享环境、参数失效和借用资源生命周期。
8. 比较环境开关下金属暗部与粗糙度反射，检查亮度、旋转、全景接缝及极点；确认环境光不被主光阴影一并压暗。
9. 在支持与不支持高精度片元的设备上检查图集精度、纹理槽位回退、上下文重建和二维纹理状态恢复。
10. 手动调用 `test/PbrTextureChecks.hx` 的 `run()`，检查五类贴图导入、切线隔离、镜像、自动切线失效和多关节蒙皮。
11. 开启贴图示例，逐项关闭 MR、法线、AO、自发光；确认 AO 只影响间接光，自发光不被阴影压暗。检查双面、非均匀缩放、采样冲突、切线缺省和颜色空间。
12. 检查拖动、滚轮、缩放按钮、镜头复位与自动环绕切换，以及拖出视口、触摸取消和舞台销毁后的输入解绑。

贴图语义参考：[glTF 2.0 规范](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)。算法参考：[Filament 光照模型说明](https://google.github.io/filament/main/filament.html)。本轮复用现有灯光与 LDR 管线，不等同于完整 Filament 渲染能力。
