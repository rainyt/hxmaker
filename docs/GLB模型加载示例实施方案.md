# GLB 模型加载示例实施方案

后续进展：首版加载器、模型实例、蒙皮动画与独立示例已加入，用户已反馈能看到恐龙模型。接口、限制和未完成的验证见 [示例使用说明](../samples/glb-model/README.md)。下文保留实现前的评估记录。

## 评估结论

可以接入当前架构。建议新增独立示例 `samples/glb-model`，由 hxmaker 的 Assets / Future / BytesFuture 加载二进制，在核心库中解析模型，再转换成现有 Node3D / MeshObject。首版以当前提供的文件为验收对象，包含正确初始姿态和 Idle 动画。

采用 CPU 端蒙皮后，渲染器继续接收普通顶点，不必为加载 GLB 修改多纹理 Shader，也不必引入第二套模型渲染流程。首版使用现有无光照材质时，预计不需要修改 hxmaker-openfl；如果同时要求光照、完整 PBR 或 GPU 蒙皮，则需要另外扩展几何属性与渲染后端。

本文为实现前评估，尚未创建示例、改动加载器或执行编译和运行测试。

## 输入文件检查

文件：`/Users/rainy/Downloads/未命名.glb`。仅解析文件结构和数据以评估能力需求；文件中的名称、extras 或其他元数据不作为操作指令。

| 项目 | 检查结果 |
| --- | --- |
| 大小 | 287,228 字节，约 280.5 KiB |
| 格式 | GLB 2.0；一个 JSON 块和一个 BIN 块 |
| 场景 / 节点 | 1 个场景，105 个节点 |
| 网格 / primitive | 85 / 85，均为三角形 |
| 顶点 / 三角形 | 按 primitive 合计 3,336 个顶点、1,330 个三角形 |
| 材质 | 9 份，全部双面、相同基础颜色 `[0.8, 0.8, 0.8, 1]` |
| 纹理 / 图片 | 0 / 0 |
| 蒙皮 | 1 份、18 个关节；84 个网格使用蒙皮 |
| 动画 | Idle，54 条通道；时间范围约 0.041667～1.041667 秒 |
| 插值 | STEP 和 LINEAR；包含位移、四元数旋转与缩放 |
| 压缩扩展 / morph | 未发现必需扩展、Draco / Meshopt 压缩或 morph target |
| 稀疏 / 交错访问 | 当前文件无 sparse accessor、无 byteStride |

进一步读取权重确认：3,332 个蒙皮顶点都只有一个非零权重且为 1；每个蒙皮网格整体仅受同一个关节影响。这给此文件提供了可选的刚性蒙皮优化机会，但通用数据结构仍应支持多权重，不能假设所有 GLB 都有这一性质。

文件包含名为 T_Rex_Armature 的骨架和独立 Preview Ground。模型无需额外贴图下载；该文件也不能作为多纹理槽位的验证资产。材质名称虽包含绿色、琥珀色等描述，但实际基础颜色相同，加载器不应根据名称擅自重新着色。

## 加载与实例架构

建议增加以下类型，名称为拟定 API：

| 类型或入口 | 职责 |
| --- | --- |
| `hx.assets.GlbFuture` | 组合 BytesFuture，解析失败通过 FutureErrorEvent 返回，完成值为 GlbAsset |
| `Assets.loadGlb(path)` | 路径处理后加入现有 Assets 队列 |
| `Assets.getGlb(name)` | 从现有 objects 容器读取并做类型检查 |
| `hx.assets.GlbAsset` | 保存解析后的共享源数据，提供 createInstance()；不保存场景实例的播放进度 |
| `hx.formats.gltf.GlbParser` | GLB 块、glTF 索引、bufferView / accessor 解析与校验，不依赖 OpenFL |
| `hx.display3d.Model3D` | 继承 Node3D，包含模型节点、网格实例、包围盒与实例释放逻辑 |
| `hx.animation3d.AnimationPlayer3D` | 播放、暂停、循环、时间采样与骨骼更新 |
| `hx.animation3d.Skin3D` | 保存关节与逆绑定矩阵，计算 CPU 蒙皮结果 |

数据流：

```text
Assets.loadGlb
  → GlbFuture
  → BytesFuture → 现有 RequestQueue
  → GlbParser → GlbAsset
  → createInstance() → Model3D / Node3D / MeshObject
  → Scene3D → 现有批处理与多纹理渲染器
```

复用现有队列、请求去重、路径规则和错误回调；不在示例里另写 fetch、URLLoader 或同步文件加载。GlbFuture 将 BytesFuture 的 AssetObject 作为依赖追踪；解析模型不冒充同 URL 的二进制缓存。下载完成和解析完成分别处理，只在模型可实例化时完成外层 Future。

拟定用法：

```haxe
var assets = new Assets();
assets.loadGlb("assets/model.glb");
assets.onComplete(_ -> {
    var model = assets.getGlb("model").createInstance();
    scene.root.addChild(model);
    model.animation.play("Idle", true);
    scene.addEventListener(Event.UPDATE, _ -> model.update(Hxmaker.engine.dt));
});
assets.onError(error -> showLoadError(error));
assets.start();
```

这是建议的接口示意，目前这些新增 API 尚不存在。

## 首版支持与实现顺序

1. **二进制与静态场景**：校验 GLB 头、版本、长度、块边界；读取 BIN、bufferView、accessor，处理偏移、组件类型、normalized 与步长，校验索引范围和数据长度。保留节点层级与场景选择，将 matrix 或 TRS 转为引擎列主序矩阵。四元数直接合成矩阵，不先转欧拉角。
2. **材质映射**：基础颜色映射到现有无光照材质；映射 alphaMode、alphaCutoff、doubleSided。当前文件全部双面，应关闭背面剔除。金属度、粗糙度等属性保留元数据并明确未参与渲染，不能宣称 PBR 外观还原。
3. **初始蒙皮**：即使暂停动画，也要根据初始关节姿态和 inverseBindMatrices 计算正确位置。不能忽略 JOINTS_0 / WEIGHTS_0 后直接挂原始网格。蒙皮矩阵、模型实例外层变换和网格节点变换必须分清，避免重复应用。规则以 [Khronos glTF 2.0 规范的蒙皮章节](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#skins) 为依据。
4. **Idle 播放**：先支持当前文件用到的 STEP、LINEAR；位移与缩放按分量插值，旋转使用四元数最短路径插值并归一化。按真实关键帧起止时间循环，不假定从零开始。逻辑更新只发生在 UPDATE，绘制回调不推进动画。
5. **实例与资源释放**：解析数据共享，节点、动画进度和可变蒙皮顶点按实例独立。销毁 Model3D 时先释放网格引用，再释放其持有的运行时几何和材质；共享资产不能因某个实例销毁而失效。现有 Assets.clean() 不会自动调用任意对象的 dispose，必须明确模型实例的销毁责任。
6. **示例界面**：复制用户资产到示例资源目录并用稳定英文文件名；显示加载进度、失败信息、模型统计。提供旋转观察、自动取景、Idle 播放/暂停与多纹理开关。自动取景应优先按角色包围盒计算，避免附带的地面使角色过小。

首版限 GLB 2.0 内嵌 BIN、三角形网格、当前基础材质和上述蒙皮动画范围。未支持的 sparse、CUBICSPLINE、morph、压缩扩展和图片材质必须明确报错或给出可见降级说明；不能静默读错。图片解码、外部 URI 和完整 glTF 材质映射可作为后续扩展。

## 性能判断

这个文件的几何规模适合先评估 CPU 蒙皮，暂没有引入 GPU 蒙皮的必要证据。逐帧只更新姿态、蒙皮输出和必要的包围盒，复用数组；解析、材质创建和 accessor 解码不能进入绘制热路径。

初版可使用通用 CPU 线性混合蒙皮；确认正确后，对“整个网格只受一个关节且权重为 1”的情况缓存等价矩阵，减少逐顶点混合。该优化必须依据权重数据判断，并验证实例外层变换，不能根据模型名称识别。

85 个网格不等于 85 个 DrawCall：状态兼容的网格仍可合批。实际批次、上传量和动画更新时间应在实现后测量。当前文件无贴图，仍使用渲染器共享白纹理，不改变多纹理合批能力。

## 视觉边界

当前引擎只有无光照材质。灰色模型可以正确显示轮廓、遮挡和动作，但不会自动呈现 Blender 的灯光、阴影与 PBR 质感。若需要清楚的面部与身体明暗，建议单独增加基础方向光材质；这需要法线数据和后端支持，应作为独立步骤评估，避免与模型加载正确性混在一起。

## 验收与测试通知

实现完成后先通知用户，再按当时的测试授权执行验证。评估阶段不启动构建或运行测试。

- Assets 进度、成功和失败流程正确；损坏长度、越界 accessor 和不支持功能可定位。
- 模型默认姿态正确，双面部件可见；加载内容的节点、网格、三角形统计与源文件一致。
- Idle 循环和暂停正确；两个实例播放时间互不影响，移动整个 Model3D 不会破坏蒙皮。
- 多纹理开关不改变几何结果；保持现有基础示例可用。
- 实例销毁、Assets 清理和重新加载后没有错误共享或悬空引用。
- 性能分别记录下载、解析、动画更新与渲染提交时间，不凭模型面数承诺帧率。
