# 主场景几何缓存与 AUTO 策略

主场景标准 OPAQUE、MASK 网格使用持久顶点与索引缓冲。固定环境按 16 个世界单位的三维空间区域及兼容材质状态分组；移动模型保留局部几何，由着色器应用模型矩阵、法线逆转置和切线手性。相机移动只更新剔除和绘制范围，不改变静态批次成员及纹理编号。

```haxe
import hx.render3d.GeometryMobility3D;
import hx.render3d.ShadowMobility3D;

building.geometryMobility = GeometryMobility3D.STATIC;
building.shadowMobility = ShadowMobility3D.STATIC;

for (mesh in character.meshes) {
    mesh.geometryMobility = GeometryMobility3D.AUTO;
    mesh.shadowMobility = ShadowMobility3D.AUTO;
}
scene.autoStaticDelay = 1.0;
```

主场景与阴影的默认策略均保留为 `DYNAMIC`，显式 `STATIC` 仍允许后续修改。两套策略独立，`castShadow`、`receiveShadow` 和灯光开关保持原有含义。

## 缓存与更新

| 变化 | 处理 |
|---|---|
| 相机、灯光、雾、IBL 参数改变 | 更新参数和可见范围，复用几何 |
| 动态或 AUTO 模型整体移动、旋转、缩放 | 更新模型矩阵，不上传几何 |
| 静态网格变换改变 | 更新受影响空间组；跨区域时重新分组 |
| 骨骼姿态、组内子节点变换改变 | 更新对应组顶点，复用索引 |
| 颜色、透明度、UV、图集区域改变 | 更新对应组的顶点或批次状态 |
| 索引、几何对象或顶点数量改变 | 重建对应布局和索引 |
| 纹理槽位、材质兼容性或可见性改变 | 重新判定组成员及拆批 |

每组顶点直接写入复用的 `Float32Array`，不再逐三角形建立映射，也不再先拼普通数组再转换。索引内容单独检测和上传，骨骼姿态更新不重复上传索引。容量不足时按二次幂增长；容量足够时使用 `bufferSubData`。当前仍使用交错顶点布局，动画重传该组的完整顶点属性，尚未拆分 UV、颜色等固定属性流。

阴影开关、IBL 或软粒子等功能改变可用纹理槽位时，相关批次需要重新分组；普通灯光参数变化不会重建几何。

静态组保存每个网格的索引范围，主相机继续逐网格剔除，连续可见范围合并提交。主相机之外的固定组不更新几何，已有容量保留以便重新进入视口。透明网格继续沿用原有深度排序和合批算法，上传缓冲也复用容量。

回退合批在同一帧内多次写入同一缓冲，因此只复用 CPU 数组容量和 GL 缓冲句柄，GPU 提交沿用 `bufferData(..., STREAM_DRAW)`，允许驱动替换存储。持久缓存组使用 `bufferSubData` 更新；不把回退合批也强制改成原地覆写，避免等待先前的 GPU 绘制。

动态或 AUTO 模型只要有成员可见，就准备该模型的全部材质组，绘制仍按各网格的可见范围提交。整个模型首次进入视野时仍需创建缓冲；已有模型的不同材质部分陆续入镜时无需再次首次上传。刚体零上传指已经建立缓存且属性、拓扑不变的模型。

若本次绘制集合包含使用特殊深度状态、自定义片元代码／UV 代码的不透明网格，或单网格超过 65535 顶点、196605 索引，则整个本次集合沿用原合批算法，以保留顺序和拆批行为。该回退路径同样复用上传缓冲。

## AUTO 的语义

主场景和阴影共用活动记录，以最近的 `Model3D` 祖先为模型组，普通网格独立判断。显式策略不参与自动转换。

- 新加入的 AUTO 网格先处于动态状态。
- 等待时间为零时，变化当帧仍保持动态，至少经过后续一次场景 UPDATE 才允许转静态。
- 自身、祖先或组内变换改变，几何版本变化，或模型动画实际推进时，立即转动态。
- 持续静止达到 `scene.autoStaticDelay` 后转静态，默认 1 秒。
- 动画未驱动、暂停或速度为零时可以转静态；只检查 `playing` 标志不足以判断活动。
- 相机、灯光、材质颜色和可见性变化不会单独被当作运动。
- 判定读取实际矩阵值，不把普通 `invalidate()` 引起的 `worldVersion` 增长误判成运动。直接修改几何数组仍须调用 `geometry.invalidate()`。

场景 UPDATE 负责静止计时，绘制前再次同步本帧业务变化。因此 `autoRender=false` 时仍能转换，物体重新移动时不会先绘制一帧旧几何。

AUTO 静态状态保留原来的局部缓存组，不立即加入固定建筑的大批次，避免角色短暂停顿、再次移动时使整个环境重建。当前版本不包含 AUTO 组之间的延迟合批。动态缓存本身也能静止零上传，因此 AUTO 的有效状态转换不等于每次都必须改变 GPU 缓冲。

```haxe
mesh.effectiveGeometryMobility;
mesh.effectiveShadowMobility;
```

以上只读属性返回最近场景同步后的有效策略。整个阴影贴图的手动冻结仍由 `light.shadowAutoUpdate` 控制。

## 统计和对照

- `geometryStaticUploadedBytes`、`geometryDynamicUploadedBytes`：按有效策略区分的缓存几何上传字节数，包括顶点和索引。
- `geometryIndexUploadedBytes`：其中索引的上传字节数，不应再次叠加。
- `geometryCacheBytes`：持久缓存的 GPU 预留容量，不含回退上传缓冲、深度贴图及 CPU 副本。
- `geometryRebuilds`、`geometryCacheHits`：本次绘制准备中重建与复用的缓存组数。
- `autoStaticMeshes`、`autoDynamicMeshes`：场景内任一策略启用 AUTO 的网格数量，包含隐藏网格，不按模型实例计数。
- `autoMobilityTransitions`：场景累计的 AUTO 网格状态切换次数，主场景与阴影共用一次计数。

缓存准备统计包含软粒子深度预绘制的准备工作；原有 `uploadedBytes` 与 `softDepthUploadedBytes` 继续分别记录主场景和预绘制上传。只有回退路径发生上传时，它不计入缓存专用的静态／动态分类。

`scene.geometryCacheEnabled=false` 可切回原合批算法做画面对照；它仍使用新的持久上传缓冲。比较性能应同时记录 DrawCall、可见网格、上传量和预留内存。缓存按区域和模型拆组后可能增加 DrawCall，静态网格数量与材质分布决定实际收益。

验收构建可在示例目录执行 `lime build html5 -D hxmaker_explorer_checks --app-path=Export/checks`，使用 `HXMAKER_EXPLORER_URL` 指向该目录的 HTTP 地址运行探索和霸王龙脚本，避免普通预览构建覆盖验收接口。普通预览仍使用 `Export/html5/bin`。

## Blender 与示例

观测站导出器支持网格的字符串自定义属性 `hx_geometry_mobility` 和 `hx_shadow_mobility`，取值为 `static`、`dynamic` 或 `auto`，默认静态，分别写入 `scene.json` 的名称映射。普通 GLB 本身不自动提供这些配置。

当前环境显式静态，闸门和十只霸王龙使用 AUTO。面板显示主场景、阴影的静态／动态上传 KB、AUTO 网格计数及 CPU 提交耗时。`U` 关闭动画但保留游走，用于验证刚体零上传；`G` 定格超过一秒后，80 个霸王龙网格会自动转静态。

缓冲在组被移除或切回原路径时释放，场景销毁释放全部资源；设备丢失后丢弃旧句柄，恢复时重建。缓存组使用节点生命周期内稳定标识，避免设备恢复改变共面物体的绘制顺序。

## 验证与当前测量

WebGL2 默认 VAO 与 WebGL1 无 VAO 路径分别通过 20 项主场景检查和 19 项阴影回归，覆盖缓存与强制重建、原合批路径的像素对照，AUTO、模型不同材质部件入镜、索引原地修改、非均匀／负缩放、PBR 法线贴图、透明排序、设备恢复和 GPU 缓冲释放。雾与软粒子两条路径各 12 项检查通过；完整探索流程 14 项、霸王龙功能与上传检查 11 项通过。Blender 后台实际导出 83 个网格，检查两套 AUTO 配置和非法值拒绝。

最终软件 WebGL 采样：刚体移动加阴影时，主场景约 1.82 ms，主场景与阴影上传均为零；动画加阴影时，主场景约 3.29 ms，静态几何及索引上传为零，动态顶点平均约 3.23 MB／采样帧，阴影约 0.924 MB。刚体无阴影的样本包含一个首次可见模型的分配，平均约 17 KB／帧，已有缓存仍为零重传。

动画对照组的主场景提交约 73.05 ms，但多数采样位于软件驱动的 `bufferData` 等待，不能解释为纯 CPU 算法节省，也不能据此推断硬件 FPS。缓存组和原路径的帧间隔中位数均约 83.3 ms，软件 GPU 在该负载下仍是限制。

主场景绘制从对照组 14 次增加到缓存组平均约 107 次，GPU 缓冲预留约 6.71 MiB，CPU TypedArray 另占近似容量。固定区域拆组、模型间分离和 PBR 材质参数隔离共同增加绘制次数，实际显卡仍需新录制验证整体收益。当前保留 `geometryCacheEnabled` 便于对照。

原始汇总位于示例的 `Validation/2026-10-19-main-cache-*.json`，GPU 专项位于 `test/shadow-cache/Validation/2026-10-19-main-cache-*.json`。动态固定属性流拆分、跨模型实例化合批和 GPU 蒙皮仍是后续可评估的方向。
