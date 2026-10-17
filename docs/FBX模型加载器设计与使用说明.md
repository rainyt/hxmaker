# FBX 模型加载器设计与使用说明

日期：2026-10-17。实现静态 FBX 首版及示例，尚未编译或运行，由用户测试。现阶段不能视为完整 FBX 支持。

## 统一入口

所有业务模型使用同一入口：

```haxe
var assets = new hx.assets.Assets();
assets.loadModel("assets/model.fbx");
assets.onComplete(_ -> {
	var source = assets.getModel("model");
	var instance = source.createInstance(-1, {lightingEnabled: true});
	scene.root.addChild(instance);
});
assets.onError(error -> trace(error.toString()));
assets.start();
```

`Assets.loadGlb/getGlb`、`GlbAsset`、`GlbFuture` 和 `ModelAsset.fromGlb` 已删除。项目代码应改成 `loadModel/getModel`、`ModelAsset` 和 `ModelAsset.fromBytes`，没有旧接口兼容层。

`ModelImporter` 根据字节内容识别 GLB、FBX 二进制文件头或 ASCII FBX 头字段，URL 后缀不参与选择。不同格式各自解释源数据，然后进入同一个 `ModelAssetBuilder`。FBX 不生成中间 GLB。

同步 `ModelAsset.fromBytes` 仅完成结构导入；有图片时仍需要 Assets 的异步图片解码流程。释放顺序保持先销毁模型与贴图预览，再 `assets.clean()`。

## 模块划分

| 模块 | 职责 |
| --- | --- |
| `hx.formats.ModelImporter` | 内容识别与格式分发 |
| `hx.formats.fbx.FbxParser` | ASCII / 二进制语法树，不包含渲染逻辑 |
| `hx.formats.fbx.FbxDocument` | 源节点和属性类型，64 位 ID 采用整数文本 |
| `hx.formats.fbx.FbxTransform` | 欧拉顺序、枢轴、几何变换、轴向和单位换算 |
| `hx.formats.fbx.FbxTriangulator` | 平面简单多边形耳切三角化 |
| `hx.formats.fbx.FbxImporter` | 连接关系、节点、网格、材质、内嵌图片到中立源数据 |
| `hx.model.ModelAssetBuilder` | 既有的中立数据校验、法线/边界等预处理 |
| `hx.assets.ModelFuture` | 下载、导入、图片解码和失败时释放依赖 |

当前采用纯 Haxe 实现，zlib 使用标准库的 `InflateImpl`，没有引入 Heaps、Three.js、Autodesk SDK、原生进程或 WASM。代码可由 Haxe 面向其目标编译，但本轮未做任何目标平台的兼容验证。

## 首版支持范围

| 能力 | 范围 |
| --- | --- |
| 容器 | FBX 7.x ASCII、二进制；7.5 及以后使用 64 位节点记录 |
| 属性布局 | Properties70，二进制标量及原始/zlib 数值数组 |
| 对象 ID | 完整保留有符号 64 位整数，不经 JS 浮点数中转 |
| 节点 | 常规 Model 层级，保留名称；增加网格几何变换节点和归一化根节点 |
| 变换 | 局部 T/R/S、六种欧拉顺序、Pre/PostRotation、旋转/缩放枢轴和偏移 |
| 几何变换 | 几何 T/R/S 仅作用于网格，不传递给原模型子节点 |
| 坐标与单位 | 读取 Coord/Up/Front 轴、符号及厘米单位因子，通过根矩阵归一化 |
| 网格 | Mesh；三角形、四边形、平面凹多边形；每面最多 256 个角点 |
| 法线与 UV | 首个 Layer 引用的一套；Direct / IndexToDirect / Index 引用 |
| 属性映射 | ByPolygonVertex、ByVertice/ByVertex/ByControlPoint、ByPolygon、AllSame |
| 材质槽 | 面材质 AllSame/ByPolygon，按材质拆分图元 |
| 材质外观 | 基础色乘因子、透明度、内嵌基础色贴图；首版使用双面近似材质 |
| 图片 | Video 的二进制或 ASCII Base64 Content，PNG/JPEG |
| 采样 | 重复/钳制，基础线性过滤；不实现 mipmap 与 UV 变换 |

基础颜色按线性因子进入现有材质路径；FBX 软件之间的工作色彩空间及复杂材质无法保证一致，必须人工检查外观。纹理 V 坐标翻转到当前 GLB 贴图路径的约定；示例提供四色图片用于对照。

坐标归一化根节点将源层级的最终模型空间变成右手系、Y 向上和米制。源局部缓冲与局部变换仍在归一化根下保留源单位，不能脱离根节点单独把这些数值当成米。转换改变手性时调整三角形绕序；法线由既有节点法线变换处理。

不同源对象引用相同 Geometry 且材质槽相同时复用同一网格定义；材质槽不同时分别构建，各模型的几何变换辅助节点仍独立。节点索引在同一构建结果内稳定；FBX 额外辅助节点使其不等同于原对象 ID。需要跨文件稳定引用时，后续再增加独立的源对象标识映射。

## 明确拒绝的内容

骨骼、Skin/Morph Deformer、AnimationStack/Layer/Curve、约束、非 Mesh 几何、分层纹理、非基础色贴图连接、外部贴图、纹理坐标变换、球面旋转顺序、带孔面及非平面多边形会报错。当前不会退回静止姿态或自动改成 GLB。

特殊缩放继承的判定：RSrs 可直接使用普通父子矩阵；RrSs 仅在祖先缩放均为均匀缩放时接受；Rrs 仅在祖先未缩放时接受。其他组合需要先烘焙变换。几何及节点还需满足引擎既有的可逆仿射矩阵限制。

节点可见性、自带相机/灯光、附加节点属性和顶点颜色尚未还原，导入器会给出提示。没有法线时按共享顶点生成平滑法线，不解释 FBX 平滑组。完整 Phong/PBR、透明颜色混合、贴图 Alpha 自动判定、LOD 和完整多场景语义也不在首版范围内。

文件及内存限制：源文件最多 64 MiB，语法嵌套最多 128 层，节点记录最多 10 万，普通属性最多 100 万，数值数组累计最多 400 万项，数值数组原始展开字节累计最多 128 MiB，网格展开顶点累计最多 200 万。压缩数组使用固定容量输出并核对流结束，不无限展开。上述限额不等于进程内存峰值，Haxe 数组、语法树与资产复制仍有额外开销。

## 后续骨骼动画设计

保留当前语法树及连接层，后续在 FbxImporter 内分阶段加入，Model3D 和 ModelAsset 不再按格式拆分：

1. 解析 Skin/Cluster、控制点权重、Transform/TransformLink 与绑定姿态，把逐控制点权重映射到拆分后的渲染顶点。
2. 保留所需骨架祖先，统一关节索引、绑定空间与逆绑定矩阵；与当前模型空间蒙皮约定对齐。
3. 把 AnimationStack/Layer/CurveNode/Curve 解析成可求值的源动画，覆盖时间单位、欧拉顺序、枢轴与缩放继承。
4. 烘焙为中立的四元数 TRS 轨道；对无法准确表示为当前节点树的变换明确拒绝，不能只读取 Lcl 曲线后直接播放。
5. 用已知绑定矩阵和独立采样姿态做数值对照，再验证多权重蒙皮、挂点、动画过渡和多实例。

在引入这些能力前需要真实导出器样本；若复杂变换和动画兼容维护成本过高，可在同一导入边界接入 ufbx 等实现，但这将需要额外处理 Haxe 目标平台及分发依赖。当前没有把 ufbx 包装成已经可用的功能。

## 示例与用户验证

运行 [samples/fbx-model](../samples/fbx-model/README.md)，依次切换 ASCII、二进制 7.4、二进制 7.5 和 GLB。检查比例、方向、凹多边形、面罩 UV、枢轴位置、光照、阴影、双实例变色和反复加载释放。

可选纯数据入口为 `haxe test/fbx-model-data.hxml`，从仓库根目录执行。它对比四种资源的世界空间边界和顶点矩，另检查错误版本、变形拒绝及损坏偏移。该入口已写入，但没有编译或执行。

现有 samples 和文档片段已统一模型 API，并同步迁移三维类型 import；历史验证记录只代表当时版本，不代表此次接口迁移已重新通过。当前未执行编译、数值检查、浏览器、GPU 或性能测试。

## 设计参考

二进制布局参考 [Blender 开发者的 FBX 格式说明](https://code.blender.org/2013/08/fbx-binary-file-format-specification/)。静态枢轴、Pre/PostRotation 与几何变换链参考 [ufbx 的 FBX 节点变换文档](https://ufbx.github.io/fbx/node-transforms/)。这些资料用于解释源格式，当前实现没有引入其运行时依赖。
