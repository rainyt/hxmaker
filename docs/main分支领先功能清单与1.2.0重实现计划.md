# main 分支领先功能清单与 1.2.0 重实现计划

> 评估日期：2026-11-08
> 评估分支：`1.2.0`（当前工作分支）与 `main`
> 评估方式：以 `git diff 1.2.0 main` 的**最终状态**为准，而不是逐条提交累加。这样不会把「1.2.0 已反向移植」或「main 已回退」的内容误算成缺口。
> 本文只做盘点与实施指引；每个模块在 main 上都有更详细的设计文档，见第 11 节索引。

---

## 0. 一句话结论

main 相对 1.2.0 的增量由四块组成：

1. **2D 维护性与性能修补**：56 个文件，`+2979 / -795`。
2. **一整套 3D 引擎**：12 个源码包共 92 个文件、约 10815 行，加上 `Scene3D`、`Bounds3D`/`Ray3D`、3 个 3D 事件与 `ModelAsset`/`ModelFuture` 共 98 个文件、`+11422`。
3. **渲染基础设施**：ASTC 构建链、纹理视图所有权、资源包健壮性、Spine 3.8 双运行时。
4. **样例与验证资产**：`samples/` 529 个文件（`+161627`，其中大量为图片/模型二进制），`test/` 63 个文件（`+4111`）。

关键架构事实：**3D 是加法的**。`Scene3D` 只是一个普通 `DisplayObject`，通过可选接口 `hx.render3d.IScene3DRenderer` 由后端实现绘制，`IEngine` 与 `IRender` 没有任何改动。因此可以按模块增量移植，**不需要整体合并 main**。

反向事实：1.2.0 并不是 main 的严格子集。1.2.0 在 Tab 焦点（`tabFocusFallback`）和布局重入保护上比 main 更新，Graphics 路径 API 也已经自行移植过。重实现时必须避免用 main 的旧版本把这些能力覆盖掉。

---

## 1. 评估口径与分支关系

| 项目 | 数值 |
| --- | --- |
| 共同祖先（merge-base） | `1f77cee`（新增 BreadcrumbBar 面包屑组件） |
| main 独有提交 | 78 个非合并 + 3 个合并 = 81 |
| 1.2.0 独有提交 | 7 个非合并 |
| 全量差异 | 823 个文件，`+188450 / -857` |
| `src/hx` 差异 | 157 个文件，`+14839 / -795` |
| 其中 3D 相关 | 98 个文件，`+11422` |
| 其中非 3D（2D/资源/工具） | 56 个文件，`+2979 / -795` |
| `samples/` | 529 个文件，`+161627 / -18` |
| `test/` | 63 个文件，`+4111 / -1` |

1.2.0 独有的 7 个提交：

| 提交 | 内容 |
| --- | --- |
| `9e7f7d2` | 移植 Graphics 路径 API 与抗锯齿示例 |
| `402af54` | 删除 `drawTriangles` 中不必要的逐项校验 |
| `1cc5203` | KeyboardEvent 补充修饰键参数 |
| `641275d` | 避免连续调用 `__updateLayout` |
| `47c298f` | 优化布局重入与重复失效导致的每帧整树重排 |
| `b70aef5` | 更新 AGENTS |
| `67799d2` | 支持 Tab 焦点切换（比 main 版本更完整） |

### 移植时的推荐工作方式

```bash
# 单文件查看 main 版本
git show main:src/hx/display/graphics/GraphicsPath.hx

# 只取某个目录的最终版本作参考
git diff 1.2.0 main -- src/hx/display3d

# 小范围、无冲突的 2D 提交可以尝试 cherry-pick
git cherry-pick <commit>

# 验收基线：移植完成后，此命令的剩余差异应只剩「1.2.0 有意保留的差异」
git diff 1.2.0 main -- <path>
```

不建议对 3D 提交做 cherry-pick：3D 功能横跨多个文件与后端，逐条挑拣会产生大量编译不过的中间态。应按第 8 节的里程碑整段移植。

---

## 2. 1.2.0 已领先或已具备：不要重复实现

| 功能 | 1.2.0 状态 | 与 main 的关系 | 移植注意事项 |
| --- | --- | --- | --- |
| Graphics 路径 API、描边、抗锯齿 | 已完整具备 9 个文件（`src/hx/display/graphics/`） | 两边最终状态仅差 `Graphics.drawTriangles` 的入参校验，1.2.0 由 `402af54` 主动删除 | **不要**从 main 覆盖 `Graphics.hx` |
| Tab 焦点切换 | `ITabFocusable`、`Stage.focusNext`、`HTML5FocusNavigation` 均已具备 | 1.2.0 额外有 `tabFocusFallback`（无有效起点时从首/尾开始），main 没有 | 移植 main 的 `Stage` 改动时必须保留 1.2.0 的 focus 逻辑 |
| 布局重入保护、重复失效合并 | `DisplayObjectContainer.__updateLayout`、`__updatingLayout` | main 没有 1.2.0 的 `__updatingLayout` 重入保护 | 见 3.1 / 3.2 的冲突说明 |
| 面包屑导航栏 | `BreadcrumbBar` 已在共同祖先中 | 相同 | — |
| 通用右键菜单 | `ContextMenu*` 已在共同祖先中 | 相同 | — |
| InputLabel 文本溢出 | 已在共同祖先中 | 相同 | — |
| KeyboardEvent 修饰键 | 字段与 main 等价 | 仅字段顺序与注释不同 | 无需处理 |

**结论**：第 3 节列出的才是真正需要重实现的 2D 内容。

---

## 3. main 领先的 2D 功能模块

### 总览

| # | 模块 | main 引入提交 | 源码规模 | 依赖 | 建议优先级 |
| --- | --- | --- | --- | --- | --- |
| 3.1 | 世界变换惰性缓存与坐标查询优化 | `dc3bccd` | `DisplayObject.hx` +169/-37 等 7 个文件 | 无（但 3D 依赖它） | P2（高风险） |
| 3.2 | 布局失效通知补齐 | `2ac2fda` | `DisplayObject`/`BoxContainer`/`Container` | 3.1 | P2 |
| 3.3 | InputLabel 视口增量刷新 | `383dcd7` | `InputLabel.hx` +72/-3 | 3.1、`layoutVersion` | P2 |
| 3.4 | UIAnimate 时间轴 seek | `de0f379` + `2ac2fda` | `UIAnimate.hx` +172/-9、`UIAnimateGroup.hx` +27/-4 | Actuate | P1 |
| 3.5 | Spine 3.8 双运行时 | `af3d28f` | `Spine.hx` +202/-173、`SpineSprite.hx` +39/-39 等 11 个文件 | spine-hx / spine-haxe | P1 |
| 3.6 | ASTC 编译与运行时替换 | `c920863`、`d965187`、`f879909` | 运行时 4 文件 + 构建 3 文件 | 后端 ASTC 加载器 | P1 |
| 3.7 | 纹理视图所有权与引用计数 | `939b764` | `BitmapData.hx` +49/-3、`AssetObject`、`Atlas`、`Assets` | 后端纹理生命周期 API | P0（推荐先做） |
| 3.8 | 资源包可选加载与失败回调 | `106b751` + `939b764` | `AssetsBundleFuture.hx` +50/-20、`Assets.hx` | 无 | P0 |
| 3.9 | FPS 统计刷新节流 | `23cb757` | `FPS.hx` +11/-5 | 无 | P0 |
| 3.10 | Stage 指针捕获与 `TOUCH_CANCEL` | `b2970ec` | `Stage.hx`、`TouchEvent.hx` | 3D 输入才需要 | P1（3D 前置） |
| 3.11 | 构建指纹与 RenderFilter 生命周期 | `939b764` | `RenderBuildMacro`、`RenderBuildInfo`、`RenderFilter` | 无 | P0 |

> 注：main 上 `4d7767f`「改进调试面板功能」扩展过 `FPS.hx` / `ContextStatsFrame.hx`，随后被 `23cb757`「还原ASTC」一并回退。**最终状态只剩 FPS 刷新节流**，不要按 4d7767f 去实现完整调试面板。

---

### 3.1 世界变换惰性缓存与坐标查询优化

**目标**：把「渲染树整树更新」和「按需坐标查询」解耦。原来 `localToGlobal` / `getBounds` 依赖 `stage.__updateTransform(null)` 的整树刷新；移动一个容器会把整棵子树重新标记，查询成本高。

**main 落点文件**

- `src/hx/display/DisplayObject.hx`（核心，+169/-37）
- `src/hx/display/DisplayObjectContainer.hx`
- `src/hx/display/Image.hx`
- `src/hx/display/Label.hx`
- `src/hx/display/BitmapLabel.hx`
- `src/hx/display/Stack.hx`
- `src/hx/particle/ParticleChild.hx`
- `test/CoordinateTransformChecks.hx`、`test/coordinate-transform.hxml`
- 文档：`docs/坐标转换缓存说明.md`

**关键实现点**

1. 新增 `__changeVersion:Int`：`setDirty(true)` 时自增，**渲染清理脏标记时不清零**。它用于判断「两次查询之间对象状态是否变化」，是 3.3 的前置。
2. 新增独立的世界变换脏标记 `__worldTransformDirty`，与渲染的 `__dirty` 分离，坐标查询不再消耗渲染通知。
3. 缓存失效判定由四部分组成：
   - `__worldTransformDirty`
   - `__worldTransformParent`（实际参与计算的父节点）
   - `__parentWorldTransformVersion`
   - 本地矩阵六分量快照 `__worldLocalA/B/C/D/TX/TY`（因为 `transform` 对外可原地修改，必须识别绕过 setter 的写入）
4. `__updateTransform(parent)` 拆成三步：
   - `__prepareWorldTransform()`：只准备当前节点（布局、对齐等）
   - `__updateWorldTransform(parent)`：只计算当前节点矩阵
   - filters 的 `updateTransform`
5. 新增 `__ensureWorldTransform()`：只沿**祖先链**检查版本，父节点版本变化时惰性刷新，避免移动容器时递归标记整棵子树。
6. 离屏渲染时后端可能把节点自身当作根，`parent == this` 必须按 `null` 处理。
7. `localToGlobal(point, result = null)` / `globalToLocal(point, result = null)` 增加可复用输出点；`mouseX/mouseY/touchX/touchY` 改用内部矩阵直接换算，不再 new Point。
8. `addChild` 时 `setTransformDirty()`；`removeChild` 时清 `__worldTransformParent` 并标脏。
9. `alpha` setter 需要标 `__worldTransformDirty`。
10. `set_visible` 改为「值变化才 `setDirty`」。
11. `dispose()` 改为幂等，并释放 `filters` / `blendFilter`。
12. 子类钩子改名：`Label` / `BitmapLabel` / `Stack` 覆写 `__prepareWorldTransform`；`Image` 覆写 `__updateWorldTransform` 并调用 `__markWorldTransformUpdated(parent)`。
13. `Scene3D.stageToViewport()` 直接调用 `this.__ensureWorldTransform()`——**移植 3D 前必须先决定是移植本项，还是把 Scene3D 改为 1.2.0 的旧式刷新**。

**与 1.2.0 的冲突（高）**

- 1.2.0 在 `DisplayObjectContainer.__updateTransform()` 中调用 `__updateLayout()`，并有 `__updatingLayout` 重入保护；main 把布局调用移到 `__prepareWorldTransform()`，且没有重入保护。
- 建议以 main 的分层为骨架，把 1.2.0 的 `__updatingLayout` 语义合并进 `__updateLayout()`，而不是直接覆盖文件。

**验收**

```bash
haxe test/coordinate-transform.hxml
```

另外需回归：滚动容器、ListView、粒子发射点、`cacheAsBitmap` 离屏、Spine 挂点。

---

### 3.2 布局失效通知补齐

**目标**：修复「布局优化后动态修改 `layoutData` / `layout` 不触发重排」，同时保留相同尺寸赋值与重复查询的性能优化。

**main 落点文件**

- `src/hx/display/DisplayObject.hx`
- `src/hx/display/BoxContainer.hx`
- `src/hx/display/DisplayObjectContainer.hx`
- `src/hx/ui/UIAnimate.hx`（seek 后统一布局，见 3.4）
- `test/LayoutRefreshChecks.hx`、`test/layout-refresh.hxml`

**关键实现点**

1. `DisplayObject` 以下 setter 在值真正变化时调用 `__parent.invalidateLayout()`：
   - `hide`
   - `layoutData`（同一引用重新赋值也视为显式请求）
   - `includeInLayout`（改为 `(default, set)`）
   - `centerX` / `centerY`
   - `left` / `right` / `top` / `bottom`
2. `BoxContainer.invalidateLayout()` 覆写：内部 `box` 执行实际布局，必须同步失效。
3. `DisplayObjectContainer.set_layout`：只在引用变化时重建 `layout.parent` 并 `invalidateLayout()`。
4. `set_visible` 去重，避免重复赋值触发舞台重绘。
5. `__updateLayout` 的语义：只消费开始前的变更，布局期间产生的新失效要保留到下一轮。

**与 1.2.0 的冲突**

1.2.0 的 `invalidateLayout()` 只定义在 `DisplayObjectContainer`，且 `__updateLayout(force)` 在布局期间直接返回。移植时保留 1.2.0 的 `__updatingLayout` 保护，同时补齐 main 的 setter 通知。

**验收**

```bash
haxe test/layout-refresh.hxml
```

重点用例：动态锚点、布局策略切换、`BoxContainer` 内部 box、布局过程中再次失效。

---

### 3.3 InputLabel 视口增量刷新

**目标**：静止输入框每帧不再重复测量文本布局；同时保证光标闪烁、焦点变化、文本格式变化都能正确刷新。

**main 落点文件**

- `src/hx/display/InputLabel.hx`（`+72/-3`）
- 依赖 `hx.providers.ITextFieldLayoutProvider.layoutVersion`（1.2.0 已具备）

**关键实现点**

1. 新增一组依赖快照字段：`__viewportCurrent`、`__lastInputVersion`、`__lastLabelVersion`、`__lastPlaceholderVersion`、`__lastViewportVersion`、`__lastContentVersion`、`__lastLabelRoot`、`__lastPlaceholderRoot`、`__lastLabelLayoutVersion`、`__lastPlaceholderLayoutVersion`、`__lastViewportFocused`、`__lastFollowCaret`、`__lastCaretWidth`。
2. `isViewportCurrent(followCaret)` 比较上述快照，任一依赖变化则重新布局。
3. `rememberViewport(followCaret)` 在测量、滚动、裁剪完成后记录快照。
4. `textLayoutVersion(root)`：后端没有实现 `ITextFieldLayoutProvider` 时返回 `-1`，强制逐次测量，避免缓存无法观察后端变化。
5. `refreshViewport()` 用 `try/catch` 保证异常时复位 `__refreshingViewport` 与 `__viewportCurrent`。
6. 原 `refreshViewport` 的主体改名为 `refreshViewportLayout`。

**前置**：3.1 的 `DisplayObject.__changeVersion`。没有它就无法判断输入框自身的文本/选区是否变化。

**验收**：`test/input-label-overflow.hxml`、`test/input-label-single-line.hxml`，以及手动回归输入法组合、选区拖动、占位文本切换、光标闪烁。

---

### 3.4 UIAnimate 时间轴 seek

**目标**：支持把一组 UI 动画定位到任意时间点并保持静止，供编辑器和时间轴预览使用；同时保留旧 XML 的逐段补间行为。

**main 落点文件**

- `src/hx/ui/UIAnimate.hx`（`+172/-9`）
- `src/hx/ui/UIAnimateGroup.hx`（`+27/-4`）
- 样例：`samples/2d/ui-animate-seek/`

**关键实现点**

1. **DCE 安全**：新增静态 `easingFunctions:Map<String, IEasing>`，显式列出 `Linear/Back/Bounce/Cubic/Elastic/Expo/Quad/Quart/Quint` 的 22 个缓动；字符串解析失败时才回退 `Type.resolveClass`。
2. XML 新增 `timeline="true"`；`duration` 缺省为 `0`。
3. `totalDuration = delay + duration`，并校验非负有限。
4. `play()`：`timeline` 为 true 时转 `playTimeline(isReverse)`；否则维持原 `Actuate.tween` 路径，并把 actuator 收集到 `activeTweens` 以便精确停止。
5. `seek(time)`：先 `stopSeekPlayback()`，再 `applyTime(time)`；不触发播放或完成回调；负数按 0 处理，超过末尾保持结束值。
6. `playTimeline(isReverse)`：用一个 `UIAnimateClock { time }` 驱动，`Linear.easeNone`，`onUpdate` 调用 `applyTime`。
7. `applyTime(time)` 的核心规则：
   - 先让所有片段读取并校验静态基准，避免前一个片段写入污染后一个片段的缺省值。
   - 按 `target + 属性` 选择拥有者：**已开始的片段覆盖未来片段；同起点时以组内靠后的片段为准**。
   - `progress = time < delay ? 0 : duration == 0 ? 1 : clamp((time - delay) / duration)`。
   - 所有改动过的父级只 `updateLayout()` 一次。
8. `UIAnimateGroup`：`totalDuration` 取子片段最大值；`collectSeekTracks` 递归展开；`stopSeekPlayback` 递归停止；`play` 在 timeline 时直接走组的 `playTimeline`。

**验收**：样例 `samples/2d/ui-animate-seek/`，重点检查同属性覆盖、零时长、延迟区间、反向播放、组内多目标。

---

### 3.5 Spine 3.8 双运行时

**目标**：同时支持 `spine-hx 3.8.x` 与 `spine-haxe 4.2.x`，由条件宏自动选择；修复 spine-hx 下事件不触发、插槽覆盖、裁剪复用等问题。

**main 落点文件**

- 新增 `src/hx/spine/SpineTypes.hx`：用 `typedef` 统一两个运行时的类型名。
- 新增 `src/hx/macro/SpineMacro.hx`：编译期校验版本与冲突。
- `src/hx/display/Spine.hx`：新增 `Spine38Listener`，重构绘制循环。
- `src/hx/display/SpineSprite.hx`、`src/hx/display/ISpine.hx`、`src/hx/events/SpineEvent.hx`
- `src/hx/assets/SpineTextureAtlas.hx`、`SpineTextureAtlasFuture.hx`、`Assets.hx`
- `src/hx/ui/UIManager.hx`：统一通过 `hx.spine.SpineTypes` 引用 `SkeletonData`
- `include.xml`：新增 `--macro hx.macro.SpineMacro.configure()`
- 构建：新增 `vscode-openfl-spine3-8.hxml`；`vscode-openfl-spine3-2.hxml` 改为转发别名
- 样例：`samples/2d/spine3.8/`（含 `SPINE-LICENSE`、`SHA256SUMS`、`SOURCE_COMMIT`）
- 文档：`docs/Spine双运行时支持说明.md`

**关键实现点**

1. `SpineTypes.hx`：对 `SkeletonData`、`AttachmentColor`、`TrackEntry`、`AnimationState`、`AnimationStateData`、`SkeletonClipping`、`TextureAtlasRegion/Page`、`TextureLoader`、`TextureAtlas`、`NativeEvent` 做条件 `typedef`；同时定义两个都未引入时的 `Dynamic` 兜底。
2. `SpineMacro.configure()`：`spine-hx` 与 `spine-haxe` 同时定义时报错；版本必须匹配 `3.8` / `4.2`；开发版无版本号时放行。
3. `Spine38Listener`：3.8 使用 `AnimationStateListener` 接口，4.2 使用 `onComplete/onEvent/...` 信号；统一转发到引擎的 `onStart/onEvent/onComplete/onEnd/onDispose/onInterrupt`。
4. 绘制循环重构：
   - `onStart` 清空每个 `Graphics` 并 `removeChildren()`，即使整帧无绘制也要移除上一帧内容。
   - 每个插槽使用**独立的 `Graphics`**，避免后续插槽覆盖此前提交的数据。
   - `clipper.clipEndWithSlot(slot)` 对空附件、透明插槽和不支持的附件也要执行。
   - 裁剪产生的 `triangles` 在提交给 `Graphics` 前必须 `copy()`。
5. 播放逻辑：`play()` 对「同名、同循环、已结束的单次动画」重新 `setAnimationByName`；`stop()` 清轨道并保留姿势。
6. `dispose()`：移除运行时监听、`clipEnd()`、回收颜色对象池、置空 `__spineDrawOrder`。
7. 数据版本校验：读取 JSON 的 `skeleton.spine`，与当前运行时 `3.8` / `4.2` 比对。
8. `SpineTextureAtlasFuture` 的图集解析包 `try/catch`，失败转 `FutureErrorEvent`。

**风险**

- `include.xml` 的宏对所有使用 hxmaker 的项目生效，必须保证未引入 Spine 时也能通过。
- 1.2.0 的 `vscode-openfl-spine3-2.hxml` 文件名与实际 3.8 运行时不一致，移植时保留别名以免破坏现有项目。

---

### 3.6 ASTC 编译与运行时替换

**目标**：构建期把 PNG 增量编码为 ASTC，并把清单内嵌到二进制；运行时按清单把 `.png` 请求替换为 `.astc`，平台不支持时回退原图。

**main 落点文件（运行时）**

- `src/hx/assets/ASTCFormat.hx`：文件识别、zlib 解压、头部与长度校验。
- `src/hx/assets/ASTCManifest.hx`：读取内嵌清单（资源名 `hxmaker.astc.manifest`），`resolve(path)` 做替换。
- `src/hx/assets/ASTCManifestData.hx`：清单结构。
- `src/hx/marco/ASTCMarco.hx`：宏入口，按目录调用，`onAfterInitMacros` 合并并压缩清单。

**main 落点文件（构建期）**

- `src/hx/tools/astc/ASTCBuildOptions.hx`：输出目录、编码器、块尺寸、质量、透明预乘、zlib、严格模式、哈希校验、强制重建。
- `src/hx/tools/astc/ASTCBuilder.hx`：增量构建、清单生成、`writeIfChanged`。
- `tools/project/ASTCPreparation.hx`：在 OpenFL 构建前准备 ASTC 并写入 `project.xml`。
- `tools/project/OpenFLProject.hx`：`prepare` 流程、`hxmaker_astc_project_root`、`hxmaker_prepare_assets`。
- `tools/Tools.hx`：新增 `hxmaker prepare openfl <project>` 命令。
- 文档：`docs/ASTC.md`

**关键实现点**

1. `ASTCFormat.isValid` 校验：魔数 `13 AB A1 5C`、块尺寸白名单、`bytes[6] == 1`、`read24(13) == 1`、宽高 `1..65535`、长度公式 `16 + 16 * ceil(w/bx) * ceil(h/by)`。
2. `decode`：已压缩（zlib）时先解 16 字节头推算完整长度，再校验 Adler-32 与「无尾随数据」；允许注入平台解压器。
3. `ASTCManifest.resolve`：
   - 只替换清单内且以 `.png` 结尾的路径。
   - 保留 `?query` / `#hash`。
   - 外链只在 `Assets.defaultNativePath` 前缀下替换。
   - 清单异常时整体停用，继续使用原 PNG。
4. `ASTCMarco.build(source, prefix, options)`：
   - `Context.defined("display")` 时直接返回（资源预览模式）。
   - 支持 `hxmaker_astc_project_root` 切换工作目录。
   - 更新 `hxmaker_astc_assets` 指向的 XML，写入 `assets rename/prefix`。
   - 合并阶段检测重复前缀与重复资源路径。
   - 资源名**不能以 `$` 开头**，否则 Haxe 4.3 触发断言。
5. 构建期清单 revision 为各子清单 `prefix:revision` 的 SHA-256，用于隔离下载缓存。

**后端依赖**：`hxmaker-openfl` main 的 `src/hx/net/ASTCBytesLoader.hx`、`src/hx/render2d/openfl/RecoverableASTCBitmapData.hx`。没有后端加载器，运行时拿到 ASTC 也无法上传纹理。

**验收**：`samples/2d/render-stability/`（含 `constant.astc`）、`test/` 中相关编译入口；另需验证非二次幂、透明图、zlib 外层压缩、多目录前缀。

---

### 3.7 纹理视图所有权与引用计数

**目标**：修复「子图释放导致根纹理被销毁」「同一图集被多个 Assets 合并时重复释放」「渲染快照持有已释放纹理」等问题。

**main 落点文件**

- `src/hx/display/BitmapData.hx`（`+49/-3`）
- `src/hx/assets/BitmapDataBytesFuture.hx`（新增）：OpenFL 下是后端 `hx.core.BitmapDataBytesFuture` 的别名，其他后端是明确报错的占位实现
- `src/hx/assets/Atlas.hx`
- `src/hx/assets/AssetObject.hx`
- `src/hx/assets/Assets.hx`
- `src/hx/filters/RenderFilter.hx`
- `src/hx/display/DisplayObject.hx`（`dispose`）
- `src/hx/display/IBitmapDataLifetime.hx`（新增，后端可选实现）
- `src/hx/macro/RenderBuildMacro.hx`、`src/hx/utils/RenderBuildInfo.hx`
- `test/BlendModeTextureLifetimeChecks.hx`、`test/blend-mode-texture-lifetime.hxml`
- 文档：`docs/混合模式直接渲染修复说明.md`

**关键实现点**

1. `BitmapData.data` 改为 `(default, set)`，内部维护 `BitmapDataOwner`：
   - `js` 用 `js.lib.WeakMap`，`cpp` 用 `haxe.ds.WeakMap`，其他平台用 `ObjectMap`。
   - 替换数据时先退出旧所有权，再建立/共享根所有权。
2. `sub()` 直接 `@:bypassAccessor` 共享 `data` 与 `owner`，并 `owner.references++`，**不要**走 setter 新建第二个 owner。
3. `BitmapData.dispose()` 只释放视图；最后一个视图释放时才调用 `root.dispose()` 并移出 owners 表。
4. `Atlas.dispose()`：释放所有子图视图并清空名称表，不销毁根位图。
5. `AssetObject`：
   - `assetReferences:Int` 替代无用的 `__isRelease`。
   - `cacheEntryId`：`hx.net.RequestQueue.getEntryId(key)`。
   - `retain/release` 幂等；最后一个引用释放且 `data is Atlas` 时 `Atlas.dispose()`。
   - `RequestQueue.retain/release` 需要后端新增 `entryId` 参数。
6. `Assets.pushAssets` 不再重建 `AssetObject`，而是共享对象并 `retain()`。
7. `Assets.clean()`：`loadGeneration++`、`stop()`、清空 `futures`、重置 `__loadIndex`。
8. `RenderFilter`：新增 `isDisposed`；`init()` 复位并标脏；`update()` 对已销毁滤镜抛错；`dispose()` 置位。
9. `DisplayObject.dispose()`：释放 `filters` 与 `blendFilter`，置空世界变换父节点引用。
10. `IBitmapDataLifetime`：`isAvailable()` / `getRenderReferences()`，供后端缓存维护判断；当前 main 内暂无消费者，属于**后端契约预留**。
11. `BitmapDataBytesFuture`：让「从字节解码图片」成为后端能力（OpenFL 用 `hx.core.BitmapDataBytesFuture`），模型嵌入图片与 ASTC 回退都依赖它。

**风险（中高）**：这会改变 `dispose` 的既有语义。移植后必须做泄漏与重复释放回归：图集切片、`Atlas` 多 Assets 合并、混合模式离屏、StageBitmapData 缓存。

---

### 3.8 资源包可选加载与失败回调

**目标**：资源包下载/解压失败时能明确失败并重试，而不是静默返回空包；可选资源包失败不阻断后续单文件加载。

**main 落点文件**

- `src/hx/assets/AssetsBundleFuture.hx`（`+50/-20`）
- `src/hx/assets/Assets.hx`

**关键实现点**

1. `AssetsBundleFuture.optional:Bool`，新增 `fail(message)`：
   - `optional` 时 `completeValue(new AssetsBundle())` 并 trace。
   - 否则构造 `FutureErrorEvent.create(LOAD_ERROR, -1, message, path)` 并 `errorValue`。
2. 微信路径：
   - 下载回调校验 `statusCode == 200`。
   - 解压失败、HTTP 异常、下载失败都先 `unlink` 临时文件再 `fail`。
   - `optional` 时下载超时 12000ms，否则 60000ms。
   - 拼写修正 `donwloadFile` → `downloadFile`。
3. 非微信路径：`AssetsBundle(bytes.data)` 包 `try/catch`；`BytesFuture.onError` 转 `fail`。
4. `Assets.loadAssetsBundle(path, optional = false)`。
5. `Assets.tryLoadTimes = -1` 表示无限重试；`__onError` 判断 `tryLoadTimes != -1`。
6. `loadGeneration` 隔离过期回调：`onComplete` / `onError` / 延时重试都校验代次。
7. `Assets.loadModel(path)` / `getModel(name)`（3D 资源入口）。

**验收**：模拟 404、403、超时、损坏 zip、损坏 bundle；确认 `tryLoadTimes` 与 `optional` 组合行为。

---

### 3.9 FPS 统计刷新节流

**main 落点文件**：`src/hx/display/FPS.hx`、`src/hx/utils/ContextStats.hx`

**实现要点**

1. `FPS.refreshInterval:Float = 0.25`，`0` 表示逐帧刷新；统计采集仍逐帧进行。
2. `refreshElapsed += dt`，未到间隔直接返回。
3. `autoShowTop` 的置顶逻辑移到刷新前，保证即使节流也能保持顶层。
4. `ContextStats` 只是补齐类型标注（`Int` / `Float`），无行为变化。

**注意**：不要移植 `ContextStatsFrame.hx`，它在 main 上已被删除。

---

### 3.10 Stage 指针捕获与 `TOUCH_CANCEL`

**main 落点文件**：`src/hx/display/Stage.hx`、`src/hx/events/TouchEvent.hx`

**实现要点**

1. `Stage.addPointerCaptureListener(listener)` / `removePointerCaptureListener(listener)`：保存 `MouseEvent -> Void` 列表。
2. `handleMouseEvent` 在命中测试之前，对捕获期间的 `MOUSE_DOWN/MOVE/UP` 与 `TOUCH_BEGIN/MOVE/END/CANCEL` 先通知监听者；监听者不得改写或取消源事件。
3. `dispose()` 清空监听列表。
4. `TouchEvent.TOUCH_CANCEL = "touchCancel"`。

**用途**：3D 相机拖拽（`Scene3DInput`）需要「拖动开始后即使跨过会消费事件的 2D UI 也能继续收到移动/抬起」。纯 2D 项目可以延后。

**注意**：main 的 `Stage` 同时移除了 `tabFocusFallback`；移植时**只取指针捕获部分**，保留 1.2.0 的 `focusNext` 与 `Stage.__focus` 事件写法。

---

### 3.11 构建指纹与 RenderFilter 生命周期

- `src/hx/macro/RenderBuildMacro.hx`：`buildId()` 读取 `-D hxmaker_build_id`，编译为常量。
- `src/hx/utils/RenderBuildInfo.hx`：`buildId(default, null)`。
- `RenderFilter.isDisposed`：见 3.7 第 8 点。

这三项体量很小，但与 3.7 一起构成纹理/滤镜生命周期的完整性，建议一起移植。

---

## 4. main 领先的 3D 引擎

### 4.1 分层结构

```text
2D 显示树
└── hx.display.Scene3D                    # 普通 DisplayObject，二维视口
      │
      ├── 后端契约 hx.render3d.IScene3DRenderer.renderScene3D(scene)
      │
      ├── hx.display3d.Node3D 树
      │     ├── Camera3D
      │     ├── Light3D ── DirectionalLight3D / PointLight3D / SpotLight3D
      │     ├── MeshObject ── Geometry3D + Material3D ── PbrMaterial3D
      │     ├── Model3D ── ModelAsset + AnimationPlayer3D / Skin3D
      │     └── Effect3D ── ParticleSystem3D / Ribbon3D / Billboard3D / Trail3D
      │
      ├── 场景设置：BloomSettings3D / FogSettings3D / Skybox3D / Environment3D
      ├── 统计：Scene3DStats
      └── 查询：Raycaster3D / Scene3D.pick / Scene3D.raycast
```

独立于渲染的子系统：

```text
hx.collision3d  ──> hx.controls3d.CharacterController3D ──> hx.navigation3d.NavAgent3D
hx.formats (GLB/FBX) ──> hx.model (ModelAssetBuilder) ──> hx.assets.ModelFuture
```

### 4.2 模块清单

| 包 | 文件数 | 源码行数 | 职责 | 关键类型 |
| --- | ---: | ---: | --- | --- |
| `src/hx/display3d` | 10 | 1914 | 三维节点、相机、网格、模型、特效对象 | `Node3D`、`Camera3D`、`MeshObject`、`Model3D`、`Billboard3D`、`ParticleSystem3D`、`Ribbon3D`、`Trail3D`、`Effect3D` |
| `src/hx/render3d` | 16 | 1095 | 数学、射线、雾、泛光、天空、阴影规划、统计 | `Math3D`、`Raycaster3D`、`FogSettings3D`、`BloomSettings3D`、`Skybox3D`、`DirectionalShadowPlanner3D`、`Scene3DStats`、`IScene3DRenderer` |
| `src/hx/material` | 11 | 900 | 材质、PBR、着色/混合/剔除/过滤枚举 | `Material3D`、`PbrMaterial3D`、`UnlitTextureMaterial`、`LambertTextureMaterial`、`AnimatedEffectMaterial3D` |
| `src/hx/light` | 8 | 540 | 灯光、IBL 环境、阴影质量 | `Light3D`、`DirectionalLight3D`、`PointLight3D`、`SpotLight3D`、`Environment3D`、`SkyEnvironment3D` |
| `src/hx/geometry` | 4 | 307 | 基础几何 | `Geometry3D`、`BoxGeometry`、`PlaneGeometry`、`RampGeometry` |
| `src/hx/animation3d` | 4 | 736 | 骨骼动画、蒙皮、混合 | `AnimationClip3D`、`AnimationPlayer3D`、`AnimationPose3D`、`Skin3D` |
| `src/hx/collision3d` | 9 | 877 | 碰撞体、世界查询、扫掠 | `Collider3D`、`BoxCollider3D`、`RampCollider3D`、`CollisionWorld3D`、`CollisionMath3D` |
| `src/hx/controls3d` | 4 | 933 | 角色控制、轨道/跟随相机、场景输入 | `CharacterController3D`、`OrbitCameraController3D`、`FollowCameraController3D`、`Scene3DInput` |
| `src/hx/navigation3d` | 7 | 744 | 导航图、A*、代理 | `NavGraph3D`、`NavNode3D`、`NavEdge3D`、`NavPath3D`、`NavAgent3D` |
| `src/hx/effect3d` | 5 | 235 | 粒子/拖尾参数、广告牌几何、精灵表 | `ParticleSettings3D`、`TrailSettings3D`、`BillboardGeometry3D`、`SpriteSheet3D`、`FloatCurve3D` |
| `src/hx/model` | 5 | 582 | 中立模型数据、构建、几何工具 | `ModelSourceData`、`ModelAssetData`、`ModelAssetBuilder`、`ModelGeometryTools`、`ModelAssetSchema` |
| `src/hx/formats` | 9 | 1952 | GLB/FBX 解析与导入 | `ModelImporter`、`GlbParser`、`GlbImporter`、`FbxParser`、`FbxImporter`、`FbxTriangulator`、`FbxTransform` |
| `src/hx/display/Scene3D.hx` | 1 | 300 | 二维视口与三维场景入口 | `Scene3D` |
| `src/hx/geom/Bounds3D.hx`、`Ray3D.hx` | 2 | 176 | 三维包围盒与射线 | `Bounds3D`、`Ray3D` |
| `src/hx/events/` 3D 事件 | 3 | 131 | 动画事件、拾取结果、场景输入事件 | `AnimationEvent3D`、`PickResult3D`、`Scene3DInputEvent` |
| `src/hx/assets/ModelAsset.hx`、`ModelFuture.hx` | 2 | 181 | 模型资产与异步加载 | `ModelAsset`、`ModelFuture` |

### 4.3 核心架构约束

1. **不改核心接口**：`IEngine` / `IRender` 无改动；后端通过 `IScene3DRenderer` 接入。`Scene3D.onAddToStage()` 会检查 `Hxmaker.engine.renderer is IScene3DRenderer`，否则抛错。
2. **按需重绘**：所有 3D 状态变化通过 `Scene3D.requestRender()`（`contentVersion++`）或 `settingsKey()` 比较驱动；`autoRender` 默认开启，隐藏/裁剪时不请求。
3. **坐标系**：右手系、Y 向上、米制、列主序矩阵。`Node3D` 用 TRS + `Matrix3D`，`worldVersion` 随变换递增。
4. **资源引用计数**：`Geometry3D`、`Material3D`、`Environment3D` 都有 `retain/release/dispose`；场景不接管外部共享资源。
5. **前向光照上限**：`Scene3D.MAX_LIGHTS = 4`；`light` 是主方向光兼容入口，`addLight/removeLight` 管理显式灯光。
6. **阴影策略**：`DirectionalShadowPlanner3D` / `DirectionalShadowFit3D` / `DirectionalShadowPlan3D` 负责级联与包围盒；`ShadowMobility3D`（AUTO/STATIC/DYNAMIC）+ `MobilityTracker3D` 决定静态阴影缓存。
7. **主场景几何缓存**：`geometryCacheEnabled`、`autoStaticDelay`、`Scene3D.updateMobility()`。

### 4.4 关键公共 API

**`Scene3D`**

- `root:Node3D`、`camera:Camera3D`、`light:DirectionalLight3D`
- `addLight/removeLight/getActiveLights`
- `ambientColor`、`ambientIntensity`、`environment:Environment3D`、`skybox:Skybox3D`
- `bloom:BloomSettings3D`、`fog:FogSettings3D`、`stats:Scene3DStats`
- `setSize/resize/requestRender`
- `stageToViewport(stageX, stageY)`、`stageRay(stageX, stageY)`、`raycast(...)`、`pick(...)`
- `renderScale`、`multiTextureEnabled`、`backgroundColor`、`backgroundAlpha`、`profilingEnabled`
- `DISPOSE = "scene3DDispose"`

**`Node3D`**：`x/y/z`、`rotationX/Y/Z`、`scaleX/Y/Z`、`setPosition/setScale`、`addChild/removeChild/remove`、`getLocalMatrix/setLocalMatrix/getWorldMatrix/getWorldPosition`、`isWorldVisible`、`invalidate`、`dispose`。

**`Camera3D`**：`fieldOfView/near/far`、`getViewMatrix/getProjectionMatrix/getViewProjection`、`lookAt/lookFrom`、`screenRay`。

**`MeshObject`**：`geometry`、`material`、`pickable`、`frustumCulling`、`renderOrder`、`castShadow/receiveShadow`、`shadowMobility/geometryMobility`、`getWorldVertices/getWorldNormals/getWorldTangents/getWorldBounds`。

**`Model3D`**：`animation`、`meshes`、`triangleCount`、`getNodeByIndex`、`findNodes`、`getNodeIndex`、`createSocket`、`getBounds`。

**`Material3D`**：`texture`、`color`、`opacity`、`blendMode`、`alphaMode/alphaCutoff`、`cullMode`、`depthTest/depthWrite`、`textureWrapU/V`、`textureMinFilter`、`smoothing`、`fragmentCode/fragmentDeclarations`、`setTextureUniform`、`setUniform`、`version`。

**`PbrMaterial3D`**：`metallicRoughnessTexture`、`normalTexture`、`occlusionTexture`、`emissiveTexture`、`normalScale`、`occlusionStrength`、`metallic`、`roughness`、`baseColorFactor`、`emissive`、`exposure`、`toneMapping`、`setMapSampler`。

**`DirectionalLight3D`**：`shadowEnabled`、`shadowMapSize`、`shadowBias/SlopeBias/NormalBias`、`shadowDistance`、`shadowCascadeCount/Split/Blend`、`shadowFadeRatio`、`shadowFilter/Radius`、`shadowQuality`、`shadowAutoUpdate`、`requestShadowUpdate`。

**`CollisionWorld3D`**：`overlapSphere/overlapCapsule/sweepSphere/sweepCapsule/raycast`。

**`CharacterController3D`**：`radius/height/collisionMask/skinWidth`、`groundSnapDistance`、`minGroundNormalY`、`stepOffset`、`maxSlopeAngle`、`gravity`、`maxFallSpeed`、`grounded`、`verticalVelocity`、`teleport/jump/update/move`。

**`NavGraph3D` / `NavAgent3D`**：`addNode/moveNode/removeNode/connect/connectBoth/disconnect/nearest/findPath`；代理侧 `setDestination/stop/pause/resume/repath/update`。

### 4.5 模型资产与导入管线

**数据版本**：`ModelAssetSchema.DATA_VERSION = 3`、`BUILD_VERSION = 3`。语义为右手系、Y 向上、米制、列主序矩阵、完整纹理缩小过滤。

**格式识别**（`ModelImporter.importBytes`）：

| 格式 | 识别方式 |
| --- | --- |
| GLB | 前 4 字节 `0x46546C67`（`glTF`） |
| FBX Binary | 前 20 字节 `Kaydara FBX Binary  ` |
| FBX ASCII | 前 4096 字节包含 `FBXHeaderExtension:` |

**管线**

```text
Bytes
 └ ModelImporter.importBytes        # 识别 + 分发给 GlbImporter / FbxImporter
    └ ModelAssetData                # 中立数据（节点/网格/材质/图片/纹理/蒙皮/动画）
       └ ModelAssetBuilder.build    # 校验、法线准备、包围盒、刚性绑定、统计
          └ ModelAsset              # 只读资产
             ├ ModelFuture          # 异步加载 + 逐图解码
             └ createInstance()     # → Model3D 实例
```

**关键约束**

- `ModelFuture` 进度：解析占 0.7，图片解码占 0.3。
- 嵌入图片缓存 key：`hxmaker:embedded-image:sha256:<contentHash>`。
- 重复/镜像采样要求图片边长为 2 的幂；非二次幂必须使用 `CLAMP`。
- 图片解码完成后才 `completeValue`；失败路径必须释放已加载子对象。
- 动画轨道只支持节点 TRS 与 `LINEAR`/`STEP`。
- 蒙皮矩阵统一为「模型空间关节全局矩阵 × 逆绑定矩阵」。

### 4.6 渲染与性能策略（后端侧）

- 前向渲染，最多 4 个灯光。
- PBR：基础色 + 金属粗糙度 + 法线 + 遮蔽 + 自发光；IBL 环境。
- 阴影：方向光级联、静态/动态阴影缓存、`AUTO` 转静态、蒙皮几何上传优化。
- 天空盒、距离雾、泛光（bloom）、mipmap、多纹理合批。
- 主场景几何缓存 + `MobilityTracker3D`。

详细策略见 main 文档：`docs/主场景几何缓存与AUTO策略.md`、`docs/静态与动态阴影缓存使用说明.md`、`docs/阴影质量与级联使用说明.md`、`docs/距离雾使用说明.md`、`docs/PBR材质使用说明.md`、`docs/天空环境使用说明.md`。

---

## 5. 工具链与构建配置

| 项 | main 变更 | 说明 |
| --- | --- | --- |
| `tools/Tools.hx` | 新增 `prepare` 命令 | `hxmaker prepare openfl <project>`，只准备生成资源，供资源包构建前复用同一份宏配置 |
| `tools/project/OpenFLProject.hx` | 工作目录、`hxmaker_astc_project_root`、`ASTCPreparation`、退出码透传 | 原生平台从生成的 Haxe 目录编译时，宏仍以游戏项目根目录解析资源 |
| `tools/project/ASTCPreparation.hx` | 新增 | 构建前准备 ASTC 并写入 `project.xml` |
| `tools/generate-pbr-sample.py` | 新增（106 行） | 生成 PBR 样例 |
| `tools/generate-fbx-sample.py` | 新增（241 行） | 生成 FBX 样例 |
| `tools/bake-ibl.py` | 新增（378 行） | 烘焙 IBL 环境贴图 |
| `tools/blender/hxmaker_distance_fog.py` | 新增（112 行） | Blender 距离雾导出 |
| `include.xml` | 新增 `SpineMacro.configure()` 与 `keep("hx.display3d.*")` | 两个宏都必须在所有项目通过 |
| `vscode-openfl.hxml` | `--main` 改为 `SpineCompile`，新增 Spine 宏 | 仅供仓库内编译验证 |
| `vscode-openfl-spine3-8.hxml` | 新增 | spine-hx 3.8 编译入口 |
| `vscode-openfl-spine3-2.hxml` | 改为转发别名 | 兼容旧项目 |

---

## 6. 样例与验证资产

### 目录重组

main 把原有 `samples/breadcrumb-bar`、`samples/context-menu` 移入 `samples/2d/`，并把 `Main.hx` 拆为 `Main.hx` + `GameStage.hx`。移植时建议**直接采用 main 的目录结构**，避免后续样例路径再次分叉。

### 2D 样例（main）

`blend-mode`、`breadcrumb-bar`、`context-menu`、`context-recovery`、`render-stability`、`spine3.8`、`tab-focus`、`ui-animate-seek`。

其中：
- `render-stability`：AGRC/纹理稳定性、ASTC、性能脚本，含 `tools/run.mjs`、`cdp.mjs`、`faults.mjs` 等。
- `context-recovery`：上下文恢复基线 JSON。
- `spine3.8`：资源许可证与校验和。
- `ui-animate-seek`：时间轴 seek 示例。

### 3D 样例（main，18 个）

`away3d-explorer`、`basic-3d`、`camera-interaction`、`collision-character`、`distance-fog`、`effects-3d`、`engine-acceptance`、`fbx-model`、`glb-model`、`interactive-character`、`long`、`multi-light-3d`、`multi-scene-3d`、`navigation-character`、`pbr-material`、`skybox`、`terrain-character`、`textured-character`。

建议**直接复用 main 的资产与样例代码**（529 个文件、`+161627`），不要重新生成模型与贴图。

### 测试与编译验证入口（main）

| 类型 | 文件 |
| --- | --- |
| 坐标/布局 | `test/CoordinateTransformChecks.hx`、`test/LayoutRefreshChecks.hx` |
| 纹理/混合 | `test/BlendModeTextureLifetimeChecks.hx`、`test/StaleSamplerRepro.hx` |
| 批量渲染 | `test/DirectBatchIndicesChecks.hx`、`test/DirectBatchSamplerChecks.hx` |
| Spine | `test/SpineCompile.hx`、`test/SpineOptionalCompile.hx` |
| 模型 | `test/ModelAssetDataChecks.hx`、`test/ModelAssetRuntimeChecks.hx`、`test/FbxModelDataChecks.hx` |
| PBR/纹理 | `test/PbrMaterialChecks.hx`、`test/PbrTextureChecks.hx`、`test/MipmapChecks.hx` |
| 3D 环境 | `test/Environment3DChecks.hx`、`test/FogSettingsChecks.hx` |
| 阴影 | `test/DirectionalShadowFitChecks.hx`、`test/DirectionalShadowPlannerChecks.hx` |
| 导航 | `test/NavigationGraphChecks.hx`、`test/NavigationAgentChecks.hx` |
| GL 状态 | `test/GLStateCacheChecks.hx` |
| 阴影缓存浏览器验证 | `test/shadow-cache/` |
| 浏览器运行器 | `test/tools/run-*.cjs` |

> 注意：其中多数是**编译期/无 GPU 的逻辑检查**，需要配套后端源码才能编译（例如 `DirectBatchIndicesChecks` 直接引用 `hx.render2d.openfl.DirectBatchDisplay`）。移植 2D 时这些测试应与后端同步引入。

---

## 7. 后端配套（hxmaker-openfl）

3D 不是纯前端工程。本地 `hxmaker-openfl` 仓库的状态：

| 项目 | 数值 |
| --- | --- |
| main 领先 1.2.0 | 49 个提交（1.2.0 领先 2 个） |
| 3D 相关源码 | 20 个文件（`src/hx/render3d/openfl/`、`src/hx/render/Utils3D.hx`） |
| 新增目录 | `src/hx/render2d/openfl/`、`src/hx/render3d/openfl/`、`docs/` |

**后端 3D 文件**：`Renderer3D`、`Scene3DDisplay`、`Scene3DRenderTarget`、`MeshBatch3D`、`MainGeometryBuffer3D`、`MainGeometryCache3D`、`ShadowMap3D`、`ShadowPass3D`、`ShadowGeometryBuffer3D`、`SkyboxPass3D`、`BloomPass3D`、`SkinShader3D`、`MultiTextureShader3D`、`Program3DInfo`、`GLStateCache3D`、`RenderStateGuard3D`、`MipmapCache3D`、`TextureBridge3D`、`VertexArrayBridge3D`、`Utils3D`。

**后端 2D 重构**：`DirectBatchDisplay`、`DirectBatchRenderer`、`RenderPass`、`RenderTargetBudget`、`RenderDiagnostics`、`TextureBridge2D`、`TextureLifetime`、`TextureRecovery`、`TextureInputError`、`DisplayContextBridge`、`BatchShaderBridge`、`RecoverableASTCBitmapData`、`WechatRenderLifecycle`、`ASTCBytesLoader`，以及 `Render.hx` 的 `IScene3DRenderer` 实现。

**结论**：2D 的 3.6 / 3.7 / 3.8 与 3D 全量都必须与后端成对移植。只改 hxmaker 会出现编译失败或运行时黑屏。

---

## 8. 建议实施顺序

依赖关系：

```text
M0 基线对齐
 ├─ M1 2D 零冲突修补（3.8 资源包 / 3.9 FPS / 3.11 构建信息 / 3.10 指针捕获）
 ├─ M2 纹理与资源所有权（3.7）+ 后端纹理 API
 ├─ M3 Spine 3.8（3.5）
 ├─ M4 ASTC（3.6）+ 后端 ASTC 加载器
 └─ M5 世界变换缓存（3.1）──> M6 布局通知（3.2）──> M7 InputLabel（3.3）
                            └─> M8 3D 内核（依赖 __ensureWorldTransform）
                                   ├─ M9 3D 光照/阴影/天空/雾/泛光/PBR
                                   ├─ M10 模型管线（GLB/FBX/ModelAsset/动画/蒙皮）
                                   ├─ M11 碰撞/导航/角色/相机输入
                                   └─ M12 特效
M13 工具链、样例、文档
```

### M0 基线对齐

- 从 1.2.0 拉出 `feature/main-port-v1.2` 分支。
- 建立「模块 → main 文件 → 1.2.0 目标文件 → 验收命令」对照表（可用本文第 3、4 节）。
- 先锁定 1.2.0 的既有优势：Tab 焦点、布局重入、Graphics 校验策略，写成回归用例。

### M1 2D 零冲突修补（低风险，先做）

`AssetsBundleFuture` + `Assets.loadAssetsBundle(optional)`、`tryLoadTimes=-1`、FPS 节流、`RenderBuildInfo`、`TouchEvent.TOUCH_CANCEL` + `Stage` 指针捕获。

### M2 纹理与资源所有权

`BitmapData` owner、`Atlas.dispose`、`AssetObject` 引用计数、`Assets.pushAssets`、`RenderFilter.isDisposed`、`IBitmapDataLifetime`。**必须与后端 `RequestQueue` / `TextureLifetime` 同步。**

### M3 Spine 3.8

`SpineTypes` → `SpineMacro` → `Spine`/`SpineSprite`/`ISpine`/`SpineEvent` → 图集加载 → `include.xml`/hxml → 样例。

### M4 ASTC

运行时格式与清单 → 宏 → 构建器 → `ASTCPreparation`/`OpenFLProject`/`Tools.prepare` → 后端加载器 → 样例。

### M5–M7 2D 性能与布局（高风险，单独里程碑）

1. 世界变换缓存（3.1）。
2. 布局失效通知（3.2）。
3. InputLabel 视口缓存（3.3）。

每一步都要跑 `coordinate-transform`、`layout-refresh`、`input-label-*` 与滚动/列表/粒子回归。

### M8 3D 内核

`Geometry3D` → `Material3D` → `Node3D`/`Camera3D` → `Raycaster3D`/`Math3D` → `Scene3D` → 后端 `Renderer3D` + `Scene3DDisplay` + `Scene3DRenderTarget`。先跑通一个三角形/立方体。

### M9 3D 光照与后处理

`Light3D`/`DirectionalLight3D`/`Environment3D` → 阴影规划与缓存 → 天空盒 → 距离雾 → 泛光 → `PbrMaterial3D`。对应 `basic-3d`、`multi-light-3d`、`skybox`、`distance-fog`、`pbr-material` 样例。

### M10 模型管线

`formats`（GLB → FBX） → `model` 构建 → `ModelAsset`/`ModelFuture` → `Model3D` → `animation3d`/`Skin3D`。对应 `glb-model`、`fbx-model`、`textured-character`、`interactive-character`。

### M11 碰撞/导航/角色/相机

`collision3d` → `controls3d.CharacterController3D` → `navigation3d` → `OrbitCameraController3D`/`FollowCameraController3D`/`Scene3DInput`。对应 `collision-character`、`navigation-character`、`terrain-character`、`camera-interaction`。

### M12 特效

`effect3d` → `ParticleSystem3D`/`Ribbon3D`/`Billboard3D`/`Trail3D` → `Effect3D`。对应 `effects-3d`。

### M13 工具链与文档

`tools/*`、`samples/*`、`docs/*`、`test/*`。

---

## 9. 冲突与风险清单

| # | 风险 | 影响 | 应对 |
| --- | --- | --- | --- |
| R1 | 世界变换/布局重构与 1.2.0 的布局重入优化是两套语义 | 高：整树重排、滚动/列表错位 | 以 main 分层为骨架，合并 1.2.0 的 `__updatingLayout`；单独里程碑 + 回归 |
| R2 | 3D 必须与后端成对演进 | 高：编译失败/黑屏 | 每个里程碑同时交付 hxmaker 与 hxmaker-openfl 两端 |
| R3 | 纹理所有权改变 `dispose` 语义 | 中高：重复释放、泄漏 | 先做 M2，补齐图集切片/多 Assets/离屏回归 |
| R4 | ASTC 宏对所有项目生效 | 中高：无 ASTC 工具链的环境编译失败 | 宏必须能优雅降级；清单异常时停用替换；CI 覆盖无 ASTC 场景 |
| R5 | Spine 双运行时条件编译 | 中：同时引入两库时报错；未引入时报错 | `SpineMacro` 版本/冲突校验 + `SpineTypes` 兜底；`include.xml` 宏必须无条件可执行 |
| R6 | main 的 `Stage` 覆盖 1.2.0 的 Tab 焦点 | 中：丢失 `tabFocusFallback` | 只取指针捕获片段，逐行合并 |
| R7 | main 的 `Graphics.drawTriangles` 校验覆盖 1.2.0 的删除决定 | 低但易错 | 明确保留 1.2.0 版本；如需校验另开提交 |
| R8 | 样例目录重组 | 低 | 直接采用 `samples/2d`、`samples/3d` 结构 |
| R9 | 模型图片 POT 限制 | 中：重复/镜像采样失败 | 加载时给出明确错误；资产制作规范写入文档 |
| R10 | main 上部分功能已回退（调试面板扩展） | 低 | 只按最终 diff 移植，不按中间提交 |

---

## 10. 验收清单

### 编译

```bash
# 2D 主构建
haxe vscode-openfl.hxml

# Spine 3.8
haxe vscode-openfl-spine3-8.hxml

# 文档
haxe doc.hxml

# CLI 工具
haxe tools/tools.hxml
```

### 逻辑检查

```bash
haxe test/coordinate-transform.hxml
haxe test/layout-refresh.hxml
haxe test/input-label-overflow.hxml
haxe test/input-label-single-line.hxml
haxe test/blend-mode-texture-lifetime.hxml
haxe test/direct-batch-indices.hxml
haxe test/direct-batch-samplers.hxml
haxe test/stale-sampler-repro.hxml
haxe test/model-assets-data.hxml
haxe test/fbx-model-data.hxml
haxe test/navigation-graph.hxml
haxe test/fog-settings.hxml
```

### 最终基线比对

```bash
# 期望：只剩「1.2.0 有意保留」的差异（Tab 焦点、Graphics 校验、布局重入）
git diff 1.2.0 main -- src/hx
```

建议在 M13 完成后，把该命令的输出逐条过一遍，确认没有遗漏 main 的功能，也没有把 1.2.0 的新能力回退。

---

## 11. main 上的参考文档索引

### 2D / 基础设施

- `docs/坐标转换缓存说明.md`
- `docs/FPS调试面板.md`
- `docs/Graphics路径绘图说明.md`
- `docs/Spine双运行时支持说明.md`
- `docs/ASTC.md`
- `docs/mipmap使用说明.md`
- `docs/混合模式直接渲染修复说明.md`
- `docs/二维上下文恢复修复说明.md`
- `docs/二维场景切换索引修复说明.md`
- `docs/OpenFL二维渲染性能评估.md`、`docs/OpenFL二维渲染性能实测.md`
- `docs/wechat-render-stability.md`
- `docs/Tab焦点切换.md`（1.2.0 已有）

### 3D

- `docs/3D引擎新手指南.md`
- `docs/基础3D框架使用说明.md`、`docs/基础3D框架验证记录.md`
- `docs/基础3D光照与阴影使用说明.md`
- `docs/阴影质量与级联使用说明.md`
- `docs/静态与动态阴影缓存使用说明.md`、`docs/静态阴影几何缓存说明.md`
- `docs/主场景几何缓存与AUTO策略.md`
- `docs/天空环境使用说明.md`、`docs/天空环境验证记录-20261018.md`
- `docs/距离雾使用说明.md`、`docs/距离雾与观测站验证记录-20261019.md`
- `docs/PBR材质使用说明.md`
- `docs/3D相机控制与交互使用说明.md`
- `docs/3D动画过渡与骨骼挂点使用说明.md`
- `docs/3D台阶与坡面使用说明.md`
- `docs/基础3D碰撞与角色控制使用说明.md`
- `docs/3D导航使用说明.md`、`docs/3D导航验收记录.md`
- `docs/3D模型中立资产与优化格式设计.md`
- `docs/FBX模型加载器设计与使用说明.md`
- `docs/3D特效第一阶段使用说明.md`、`第二阶段`、`第三阶段`
- `docs/3D显示API包迁移说明.md`
- `docs/完整3D角色项目示例说明.md`
- 归档：`docs/archive/3d-20261017/`

### 性能验证记录

- `docs/基础3D渲染优化记录-20261016.md`
- `docs/观测站性能优化记录-20261019.md`
- `docs/霸王龙群体性能验证-20261019.md`
- `docs/基础3D框架验证记录.md`

---

## 附录 A：文件对照表（main → 1.2.0 目标路径）

| main 路径 | 1.2.0 目标 | 备注 |
| --- | --- | --- |
| `src/hx/display3d/*` | 同名新建 | 10 个文件 |
| `src/hx/render3d/*` | 同名新建 | 16 个文件 |
| `src/hx/material/*` | 同名新建 | 11 个文件 |
| `src/hx/light/*` | 同名新建 | 8 个文件 |
| `src/hx/geometry/*` | 同名新建 | 4 个文件 |
| `src/hx/animation3d/*` | 同名新建 | 4 个文件 |
| `src/hx/collision3d/*` | 同名新建 | 9 个文件 |
| `src/hx/controls3d/*` | 同名新建 | 4 个文件 |
| `src/hx/navigation3d/*` | 同名新建 | 7 个文件 |
| `src/hx/effect3d/*` | 同名新建 | 5 个文件 |
| `src/hx/model/*` | 同名新建 | 5 个文件 |
| `src/hx/formats/*` | 同名新建 | 9 个文件 |
| `src/hx/display/Scene3D.hx` | 同名新建 | 依赖 `__ensureWorldTransform` |
| `src/hx/geom/Bounds3D.hx`、`Ray3D.hx` | 同名新建 | |
| `src/hx/events/AnimationEvent3D.hx` 等 3 个 | 同名新建 | |
| `src/hx/assets/ModelAsset.hx`、`ModelFuture.hx` | 同名新建 | |
| `src/hx/assets/BitmapDataBytesFuture.hx` | 同名新建 | 后端字节解码入口 |
| `src/hx/spine/SpineTypes.hx` | 同名新建 | |
| `src/hx/macro/SpineMacro.hx` | 同名新建 | |
| `src/hx/macro/RenderBuildMacro.hx` | 同名新建 | |
| `src/hx/utils/RenderBuildInfo.hx` | 同名新建 | |
| `src/hx/assets/ASTC*.hx`、`src/hx/marco/ASTCMarco.hx` | 同名新建 | 注意包名是 `marco` 不是 `macro` |
| `src/hx/tools/astc/*` | 同名新建 | |
| `src/hx/display/IBitmapDataLifetime.hx` | 同名新建 | |
| `src/hx/display/BitmapData.hx` | 合并修改 | 保留 1.2.0 的既有逻辑，加入 owner |
| `src/hx/display/DisplayObject.hx` | 合并修改 | 冲突最高 |
| `src/hx/display/DisplayObjectContainer.hx` | 合并修改 | 冲突最高 |
| `src/hx/display/Stage.hx` | 部分合并 | 只取指针捕获 |
| `src/hx/display/InputLabel.hx` | 合并修改 | 依赖 3.1 |
| `src/hx/display/Spine.hx`、`SpineSprite.hx`、`ISpine.hx` | 合并修改 | |
| `src/hx/ui/UIManager.hx` | 合并修改 | 仅 Spine 类型引用调整 |
| `src/hx/assets/Assets.hx`、`AssetObject.hx`、`AssetsBundleFuture.hx`、`Atlas.hx` | 合并修改 | |
| `src/hx/filters/RenderFilter.hx` | 合并修改 | |
| `src/hx/ui/UIAnimate.hx`、`UIAnimateGroup.hx` | 合并修改 | |
| `src/hx/display/FPS.hx` | 合并修改 | |
| `src/hx/events/TouchEvent.hx` | 合并修改 | |
| `include.xml` | 合并修改 | Spine 宏 + 3D keep |
| `vscode-openfl-spine3-8.hxml` | 新增 | |
| `vscode-openfl-spine3-2.hxml` | 改为别名 | |
| `tools/Tools.hx`、`tools/project/OpenFLProject.hx` | 合并修改 | |
| `tools/project/ASTCPreparation.hx` | 新增 | |
| `samples/2d/*`、`samples/3d/*` | 新增/重组 | 复用 main 资产 |
| `test/*` | 新增 | 与后端同步引入 |

---

## 附录 B：main 领先提交速查

按时间顺序的关键非 3D 提交：

| 提交 | 主题 |
| --- | --- |
| `4d7767f` | 改进调试面板功能（大部分已被 `23cb757` 回退） |
| `354ed07` / `daabc8e` | Graphics API 升级、图形数据（1.2.0 已移植） |
| `24b8062` | Tab 焦点切换（1.2.0 已有更新版本） |
| `dc3bccd` | `localToGlobal` / `globalToLocal` 性能优化 |
| `af3d28f` | Spine 3.8 支持 |
| `de0f379` | UIAnimate seek |
| `2ac2fda` | 布局问题修复 |
| `106b751` | 资源包加载失败回调 |
| `c920863` / `d965187` | ASTC 加载与编译 |
| `939b764` | 纹理功能修复 |
| `23cb757` | 还原 ASTC 时回退调试面板扩展 |

3D 提交集中在 `7d16520`（2026-10-16）到 `1abea8c`（2026-10-18）以及后续 `2c51339`、`a806d2c`、`a86900b` 等，按第 4 节模块表对应即可。
