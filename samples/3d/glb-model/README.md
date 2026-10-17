# GLB 模型加载示例

2026-10-17 接口更新：模型统一使用 `loadModel/getModel` 与 `ModelAsset`，三维节点 import 使用 `hx.display3d`；本次迁移尚未重新编译或测试。

通过 hxmaker 的 `Assets → ModelFuture → BytesFuture → RequestQueue` 加载模型，再使用 Scene3D 与 MeshObject 绘制。当前示例默认开启环境光、方向光与 512 分辨率硬阴影，自动检测阴影变化，并提供不依赖 GLB 加载的方块场景和使用本地纹理的镂空场景。示例没有自行请求网络，也不直接使用 OpenFL 模型加载器。

## 应用入口

[Main.hx](Source/Main.hx) 继承 `hx.core.HxmakerApplication`，构造函数调用 `super()` 后执行 `init(GameStage, 960, 640)`。场景、资源加载和更新逻辑放在 [GameStage.hx](Source/GameStage.hx)，业务舞台继承 `hx.display.Stage`，在 `onStageInit()` 中先调用父类实现再初始化界面。此次入口调整尚未编译或测试。

## 运行

依赖当前开发版本的 hxmaker、hxmaker-openfl 和示例 project.xml 中列出的 haxelib。在本目录执行：

```bash
arch -x86_64 lime test html5
```

测试状态：用户已反馈光照与阴影运行正常。此次重新导出的彩色模型仅完成文件结构与数据对比，尚未启动示例或运行回归断言，交由用户测试。需要同时使用更新后的 hxmaker 和 hxmaker-openfl。

## 资产与画面

`Assets/model.glb` 从用户提供的“未命名.blend”修正材质后重新导出。文件约 280.5 KiB，包含 105 个节点、85 个网格、1,330 个三角形、18 个关节和一个约 1 秒的 Idle 动画。84 个网格为蒙皮网格，另一个为展示地面。

文件没有图片或纹理，使用 9 份双面纯色材质，包含绿色皮肤、沙黄色腹部、琥珀色眼睛、象牙色牙齿等。源文件原先只设置了材质的视口显示颜色，原理化 BSDF 的基础色仍全部为浅灰色；本次将视口颜色的线性 RGBA 值同步到 BSDF 基础色，再通过 Blender 导出 GLB。颜色变化由基础材质数据表达，不需要新增纹理支持。

修正后的 Blender 源文件保存在 [SourceAssets/model.blend](SourceAssets/model.blend)，未修改下载目录中的原始文件。后续在 Blender 中调整颜色时，应修改原理化 BSDF 的基础色；导出使用 glTF Binary（GLB）、材质导出和动画采样，以保留当前加载器支持的 LINEAR / STEP 动画。`SourceAssets` 位于资源打包目录之外，不会随示例加载。

此次导出与最初的“未命名.glb”对比，只有 9 份材质的基础色变化，其余 JSON 字段以及完整 BIN 数据相同，Idle 的 54 条动画轨道保持不变；没有新增贴图、扩展或稀疏访问器。该数据对比不代替运行时画面验证。

当前提供一盏方向光、环境光、不透明及 MASK 物体投影、可选四采样 PCF 与独立阴影缓存，法线进入光照和蒙皮路径。完整 PBR、PCSS、级联和多光源阴影尚未实现；配置和边界见 [光照与阴影使用说明](../../../docs/基础3D光照与阴影使用说明.md)。

## 操作

- 点击“动画”暂停或继续 Idle；暂停动画后仍可旋转观察。
- 点击“旋转”切换自动转台；拖动视口可手动旋转，自动转台同时停止。
- 点击“地面”显示或隐藏接收阴影的地面，默认显示；地面不参与角色自动取景。
- 点击“重新取景”按当前角色姿态的包围盒重新居中。
- 点击“重新加载”销毁旧实例、清理旧 Assets，再经相同加载系统创建新实例。
- 多纹理开关继续作用于现有渲染器；这个文件没有贴图，两种模式的批次数可能相同，不能用它检验多贴图合批收益。
- 点击“光照”“阴影”分别切换表面光照与遮挡投影；阴影只作用于光照材质。
- 点击“阴影图”切换 1024 / 512；点击“切换光向”比较照明与投影方向。
- 点击“场景”依次切换恐龙、方块、镂空。方块用于观察基础光照；镂空场景将四瓣纹理平面悬于地面上，观察透明空隙对应的阴影。
- 点击“过滤”在硬阴影与 PCF4 之间切换；默认硬阴影，PCF4 增加接收表面的阴影采样。
- 点击“更新”切换自动与手动模式；手动模式保留已有阴影，点击“立即更新阴影”按当前状态重新生成。
- 点击“轮廓”切换镂空平面的 MASK / OPAQUE 材质，对比镂空与矩形投影；该按钮仅影响镂空示例。在手动模式下还需立即更新阴影。
- 点击“仅转动相机”暂停模型动画与自动转台，每次绕目标转动相机 15 度。自动模式下，静态投影可复用阴影缓存。

建议观察顺序：先切换到镂空场景，关闭自动旋转，再比较轮廓和过滤；点击“仅转动相机”查看缓存状态和零上传；最后切到手动更新，改变光向，点击“立即更新阴影”比较前后。首次启用或重建阴影目标仍会生成阴影。

`Assets/shadow-mask.png` 是示例自带的 128×128 透明纹理，通过独立 Assets 资源组加载，重新加载 GLB 不会释放它。

底部显示主场景批次、阴影批次、阴影实际状态、动画状态，以及最近一次重绘的缓存结果、上传字节、尺寸、过滤与更新模式。整场景未重绘时保留最近一次重绘统计。源文件统计包含地面，实时绘制统计会受隐藏和视锥剔除影响。设备不支持深度纹理时，底部会提示降级原因。

## 接入自己的场景

```haxe
var assets = new hx.assets.Assets();
var model:hx.display3d.Model3D = null;
assets.loadModel("assets/model.glb");
assets.onComplete(_ -> {
    var source = assets.getModel("model");
    model = source.createInstance();
    scene.root.addChild(model);
    if (model.animation.names.indexOf("Idle") >= 0) {
        model.animation.play("Idle", true);
    }
});
assets.onError(error -> trace(error.toString()));
assets.start();

scene.addEventListener(hx.events.Event.UPDATE, _ -> {
    if (model != null) model.update(hx.core.Hxmaker.engine.dt);
});
```

与其他资源一致，资源键由 Assets.formatName 得到，即不含目录与扩展名的文件名。`Assets.onProgress` 表示资源项完成比例；当前没有 GLB 下载字节进度。异步下载完成后会在当前线程解析，小文件适用，尚未实现分帧或 Worker 解析。

上面的接入片段保留默认无光照调用；若要像当前示例一样加入光照与阴影，应使用下述实例化选项，并按 [光照与阴影使用说明](../../../docs/基础3D光照与阴影使用说明.md) 添加方向光、投射物和接收地面。

`ModelAsset.createInstance(sceneIndex = -1, options = null)` 默认实例化文件指定的场景，返回继承 Node3D 的 Model3D。原调用默认仍为无光照；传入 `createInstance(-1, {lightingEnabled:true})` 则创建 Lambert 材质。可使用普通位置、旋转、缩放将其放入 Scene3D。多个实例的节点、材质、运行时几何和播放时间独立。

`animation.play(name, loop)` 从片段起点播放；`pause()` 暂停，`resume()` 继续已有片段，`seek(seconds)` 按片段起点相对时间定位，`stop()` 清除当前片段并恢复文件默认姿态。动画只由 `model.update(dt)` 驱动，绘制不会额外推进逻辑；没有自动动画混合或多层播放。

`model.meshes` 返回网格引用数组的副本，可控制网格可见性或材质。`model.getBounds(filter)` 返回模型局部空间包围盒，过滤函数可排除展示地面。

## 生命周期与蒙皮

源资产保存解析后的共享数据，不包含 GPU 资源。运行时几何和材质归 Model3D 实例持有，使用结束时先 `model.dispose()`，再 `assets.clean()`；Assets.clean 不会自动销毁已经加入场景的实例。不要将实例拥有的几何或材质借给生命周期更长的外部网格。

通用蒙皮在模型局部空间计算关节全局矩阵乘逆绑定矩阵，再混合顶点。蒙皮网格节点的变换不重复应用；Model3D 的外层变换在显示树中应用一次。多权重蒙皮会更新几何版本和包围盒。

如果整个网格每个顶点都只受同一个关节、权重严格为 1，则使用等价的网格矩阵路径，保留源顶点；该判断依据实际权重，不依赖资产名称。当前恐龙的 84 个蒙皮网格满足此条件。多纹理 Shader 无需因上述两种路径改变。

## 首版支持范围

支持 GLB 2.0 单个内嵌 BIN、场景层级、matrix / TRS、三角形、索引或无索引网格、POSITION / NORMAL / TEXCOORD_0、基础颜色与双面/透明配置、JOINTS_0 / WEIGHTS_0 蒙皮，以及 STEP / LINEAR 的位移、四元数旋转、缩放动画。解码处理 bufferView / accessor 偏移、byteStride、合法的 normalized 数据和无符号索引；最终超大批次仍由现有渲染器拆分。

后续新增内嵌 PNG/JPEG 基础颜色贴图支持，通过 Assets 等待图片解码后再实例化；此恐龙文件本身仍不含贴图。带贴图资源、生命周期和采样配置见[贴图动画角色示例](../textured-character/README.md)，新增路径尚未编译或运行。

以下功能明确报错：外部图片 URI、非基础颜色贴图、多 BIN、必需扩展、sparse、morph、额外顶点属性、非三角形模式、CUBICSPLINE。当前节点协议还要求可逆仿射矩阵，零缩放、极小缩放和跨越零的缩放动画暂不支持。可选扩展及未还原的外观属性会给出提示，不能将本实现视为完整 glTF 2.0 渲染器。

## 可选回归入口

授权测试后，可在同一示例启用：

```bash
arch -x86_64 lime test html5 -D hxmaker_glb_checks
```

[GlbRegression.hx](Source/GlbRegression.hx) 包含当前资产统计、独立实例、暂停循环、释放隔离，以及程序生成的小型 GLB 夹具。夹具用已知数值检查多权重蒙皮、逆绑定矩阵、四元数插值、STEP、外层变换、忽略蒙皮网格变换、刚性路径和 byteStride；损坏数据检查覆盖越界、循环节点、sparse、必需扩展、插值类型、负权重和版本错误。本轮另增法线生成、非均匀/负缩放、蒙皮法线、正交投影和 GLB 光照实例断言；所有新增断言均未运行，也不代替 GPU 画面验证。

成功时控制台输出 `HXMAKER_GLB_CHECKS PASS`；失败时示例显示实例化错误。此入口只在显式启用时编译，目前尚未运行，不能把“入口已加入”视为测试通过。

实现前评估见 [GLB 模型加载示例实施方案](../../../docs/GLB模型加载示例实施方案.md)。

## 本次阴影交互接入状态

2026-10-17：已接入过滤开关、自动/手动更新、立即更新、相机观察缓存及 MASK 镂空投影示例，保留 HxmakerApplication → GameStage 启动结构。按用户要求，尚未执行本轮编译、运行或测试；以上为使用方式与待验证的预期行为。
