# GLB 模型加载示例

通过 hxmaker 的 `Assets → GlbFuture → BytesFuture → RequestQueue` 加载模型，再使用现有 Scene3D 与 MeshObject 绘制。示例没有自行请求网络，也不直接使用 OpenFL 模型加载器。

## 运行

依赖当前开发版本的 hxmaker、hxmaker-openfl 和示例 project.xml 中列出的 haxelib。在本目录执行：

```bash
arch -x86_64 lime test html5
```

测试状态：用户已反馈能看到恐龙模型；本轮助手尚未执行编译、浏览器测试或下述回归入口，不能据此认定动画、销毁和异常路径已全部通过。遵守仓库要求，进一步测试前先通知用户。

## 资产与画面

`Assets/model.glb` 复制自用户提供的“未命名.glb”。文件约 280.5 KiB，包含 105 个节点、85 个网格、1,330 个三角形、18 个关节和一个约 1 秒的 Idle 动画。84 个网格为蒙皮网格，另一个为展示地面。

文件没有图片或纹理，9 份材质的基础颜色均为 `[0.8, 0.8, 0.8, 1]`，并设置为双面。加载器将线性基础颜色转换为显示色值，当前又是无光照材质，因此模型会呈现接近白色的浅灰外观。材质名称中的绿色、琥珀色等文字不代表实际颜色数据。

当前不提供灯光、阴影或完整 PBR 外观。法线被解析并保留在源数据中，但没有进入现有无光照着色流程。

## 操作

- 点击“动画”暂停或继续 Idle；暂停动画后仍可旋转观察。
- 点击“旋转”切换自动转台；拖动视口可手动旋转，自动转台同时停止。
- 点击“地面”显示或隐藏文件附带的 Preview Ground，默认隐藏；地面不参与角色自动取景。
- 点击“重新取景”按当前角色姿态的包围盒重新居中。
- 点击“重新加载”销毁旧实例、清理旧 Assets，再经相同加载系统创建新实例。
- 多纹理开关继续作用于现有渲染器；这个文件没有贴图，两种模式的批次数可能相同，不能用它检验多贴图合批收益。

底部显示最近绘制的批次、可见网格与三角形数量。源文件统计包含地面，实时绘制统计会受隐藏和视锥剔除影响。

## 接入自己的场景

```haxe
var assets = new hx.assets.Assets();
var model:hx.display.Model3D = null;
assets.loadGlb("assets/model.glb");
assets.onComplete(_ -> {
    var source = assets.getGlb("model");
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

`GlbAsset.createInstance(sceneIndex = -1)` 默认实例化文件指定的场景，返回继承 Node3D 的 Model3D。可使用普通位置、旋转、缩放将其放入 Scene3D。多个实例的节点、材质、运行时几何和播放时间独立。

`animation.play(name, loop)` 从片段起点播放；`pause()` 暂停，`resume()` 继续已有片段，`seek(seconds)` 按片段起点相对时间定位，`stop()` 清除当前片段并恢复文件默认姿态。动画只由 `model.update(dt)` 驱动，绘制不会额外推进逻辑；没有自动动画混合或多层播放。

`model.meshes` 返回网格引用数组的副本，可控制网格可见性或材质。`model.getBounds(filter)` 返回模型局部空间包围盒，过滤函数可排除展示地面。

## 生命周期与蒙皮

源资产保存解析后的共享数据，不包含 GPU 资源。运行时几何和材质归 Model3D 实例持有，使用结束时先 `model.dispose()`，再 `assets.clean()`；Assets.clean 不会自动销毁已经加入场景的实例。不要将实例拥有的几何或材质借给生命周期更长的外部网格。

通用蒙皮在模型局部空间计算关节全局矩阵乘逆绑定矩阵，再混合顶点。蒙皮网格节点的变换不重复应用；Model3D 的外层变换在显示树中应用一次。多权重蒙皮会更新几何版本和包围盒。

如果整个网格每个顶点都只受同一个关节、权重严格为 1，则使用等价的网格矩阵路径，保留源顶点；该判断依据实际权重，不依赖资产名称。当前恐龙的 84 个蒙皮网格满足此条件。多纹理 Shader 无需因上述两种路径改变。

## 首版支持范围

支持 GLB 2.0 单个内嵌 BIN、场景层级、matrix / TRS、三角形、索引或无索引网格、POSITION / NORMAL / TEXCOORD_0、基础颜色与双面/透明配置、JOINTS_0 / WEIGHTS_0 蒙皮，以及 STEP / LINEAR 的位移、四元数旋转、缩放动画。解码处理 bufferView / accessor 偏移、byteStride、合法的 normalized 数据和无符号索引；最终超大批次仍由现有渲染器拆分。

以下功能明确报错：图片或纹理材质、外部 URI、多 BIN、必需扩展、sparse、morph、额外顶点属性、非三角形模式、CUBICSPLINE。当前节点协议还要求可逆仿射矩阵，零缩放、极小缩放和跨越零的缩放动画暂不支持。可选扩展及未还原的外观属性会给出提示，不能将本实现视为完整 glTF 2.0 渲染器。

## 可选回归入口

授权测试后，可在同一示例启用：

```bash
arch -x86_64 lime test html5 -D hxmaker_glb_checks
```

[GlbRegression.hx](Source/GlbRegression.hx) 包含当前资产统计、独立实例、暂停循环、释放隔离，以及程序生成的小型 GLB 夹具。夹具用已知数值检查多权重蒙皮、逆绑定矩阵、四元数插值、STEP、外层变换、忽略蒙皮网格变换、刚性路径和 byteStride；损坏数据检查覆盖越界、循环节点、sparse、必需扩展、插值类型、负权重和版本错误。

成功时控制台输出 `HXMAKER_GLB_CHECKS PASS`；失败时示例显示实例化错误。此入口只在显式启用时编译，目前尚未运行，不能把“入口已加入”视为测试通过。

实现前评估见 [GLB 模型加载示例实施方案](../../docs/GLB模型加载示例实施方案.md)。
