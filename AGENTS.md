# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## 项目概述

hxmaker 是一个使用 Haxe 编写的统一 2D 游戏引擎，核心引擎逻辑与渲染后端分离，可通过 `IEngine` 接口适配到不同的渲染后端（当前主要支持 OpenFL，后端实现在单独的 [hxmaker-openfl](https://github.com/rainyt/hxmaker-openfl) 库中）。

## 构建命令

```bash
# 主要开发构建（OpenFL 后端，编译为 JS 到 bin/main.js）
haxe vscode-openfl.hxml

# 使用 Spine 3.2 的构建
haxe vscode-openfl-spine3-2.hxml

# 生成 API 文档（使用 dox，输出到 api_docs/）
haxe doc.hxml

# 编译 CLI 项目脚手架工具（输出 run.n）
haxe tools/tools.hxml
```

本项目**没有测试框架**。`test/Test.hx` 仅作为 HXML 构建的入口点用于编译验证。

## 核心架构

### 引擎与后端分离

- [src/hx/core/IEngine.hx](src/hx/core/IEngine.hx) — 引擎接口，定义了 `init()`、`render()`、`dispose()` 等核心方法。所有渲染后端必须实现此接口。
- [src/hx/core/Hxmaker.hx](src/hx/core/Hxmaker.hx) — 引擎入口，通过 `Hxmaker.init(EngineImpl, width, height)` 初始化引擎实例，持有全局 `topView:Stage` 根舞台。

`IEngine` 通过 `IRender` 接口与渲染后端交互，持有 `stages:Array<Stage>` 列表管理多个舞台。

### 显示对象树

所有可渲染对象继承自 `DisplayObject` → `DisplayObjectContainer` → 具体显示类：

- **基础显示对象**：`Image`、`Label`、`Button`、`Quad`、`Graphics`
- **容器类**：`Sprite`、`Scene`（场景管理）、`Stage`（根舞台）
- **布局容器**：`Box`（虚拟盒子）、`VBox`、`HBox`、`FlowBox`
- **特殊组件**：`Scroll`（滚动容器，需要遮罩）、`ListView`（列表视图）、`Spine`（骨骼动画）、`MovieClip`（帧动画）、`Particle`（粒子系统）
- **UI 组件**：`BitmapLabel`、`InputLabel`、`ImageLoader`、`ItemRenderer`、`VScrollBar`

核心包：`hx.display`（显示对象）、`hx.events`（事件系统）、`hx.geom`（几何类型）、`hx.layout`（布局管理器）。

### 自动批处理（Auto-Batch）

引擎会自动合批渲染使用 `BlendMode.NORMAL` 或 `BlendMode.ADD` 的普通显示对象，以减少 DrawCall。需要遮罩的组件（`Scroll`、`ListView`）和 `CustomDisplayObject` 不能被自动合批，会各自产生独立 DrawCall。引擎支持**多纹理渲染**以进一步减少 DrawCall。

### 资源加载系统

使用 Future 模式进行异步资源加载，位于 `hx.assets` 包。`Assets` 类作为统一入口，支持图片、音频、图集、XML、JSON、Spine 骨骼数据等多种格式。每种资源类型有对应的 Future 子类（如 `BitmapDataFuture`、`JsonFuture`、`SpineTextureAtlasFuture` 等）。

### 流程系统（Procedure）

位于 `hx.procedure` 包，提供与渲染/显示系统完全解耦的游戏流程管理功能，灵感来源于 Unity GameFramework 的 Procedure 机制。

- **`IProcedure`** — 流程接口，定义五个生命周期方法：`onInit()`、`onEnter()`、`onUpdate(dt)`、`onLeave()`、`onDestroy()`
- **`ProcedureManager`** — 流程管理器，以 Class<T> 为键注册和切换流程，每个类型只能注册一个实例。提供全局单例 `ProcedureManager.instance` 和独立的 new 实例化两种使用方式

使用方法：在游戏主循环中调用 `ProcedureManager.instance.update(dt)` 驱动当前活动流程的 `onUpdate`。

### CLI 项目脚手架

`tools/Tools.hx` 编译为 Neko 字节码 `run.n`，提供 `hxmaker create openfl <projectName>` 命令，通过 Haxe 模板引擎从 `tools/templates/openfl/` 生成新项目文件。

## 依赖

- `actuate` — 补间动画库
- `spine-haxe` 或 `spine-hx` — Spine 骨骼动画运行时
- `openfl` + `lime` — 跨平台框架（当前主要后端）
- `openfl-glsl` — OpenFL 着色器支持
- `vector-math` — 向量数学库
- `hxmaker-openfl` — OpenFL 渲染后端（独立 haxelib）

## 平台支持

通过 `platforms.xml` 条件编译支持多个中国小游戏平台：微信、QQ 轻游戏、百度、B站、OPPO、华为、VIVO、小米、魅族等。

## 代码风格

- 注释使用中文，变量名/函数名/类名使用英文
- 包结构：`hx.core` → 核心 | `hx.display` → 显示对象 | `hx.events` → 事件 | `hx.assets` → 资源 | `hx.geom` → 几何 | `hx.layout` → 布局 | `hx.ui` → UI 管理 | `hx.utils` → 工具 | `hx.macro` → 编译时宏 | `hx.procedure` → 流程管理


## 性能优先
所有API的设计必须遵循最佳性能来处理：
1. 尽可能减少不必要的检查；
2. 以最佳性能为主；
## 布局性能专项记录（2026-11-07，graphis-api-1.1.0）

### 背景

在 `graphis-api-1.1.0` 分支上录制 DevTools Performance（`profile2.json.gz`，3.32s / 222 帧 / 采样 23584 次）后确认：性能下降与 `Graphics` 路径 API、抗锯齿无关（Graphics 相关调用栈仅占 0.2%），瓶颈集中在布局与边界计算：

- 81.5% 的主线程采样出现在 `updateLayout` 调用栈内；
- 69.9% 出现在 `__getBounds` 调用栈内；
- 自身耗时 Top：`DisplayObjectContainer.__getBounds` 15.1%、`Box.__getBounds` 11.8%、`DisplayObject.__getBounds` 10.1%、`Rectangle.transform` 9.9%、`DisplayObjectContainer.__updateLayout` 6.4%，另有 Matrix clone/concat/Rectangle 分配约 8%；
- 每 250ms 时间片都有约 80% 耗在布局，说明布局每帧都在重复执行，而不是只在启动阶段；
- 帧间隔 p50 25.6ms、p90 29ms、最差 219ms。

### 根因

1. `DisplayObjectContainer.updateLayout()` 无条件递归所有子容器，`__updateLayout()` 只判断自身脏标记，没有“布局进行中”保护。
2. 布局管理器读取 `width`/`height` 时，若 `__width`/`__height` 为空会退化为 `__getBounds()`；而容器的 `__getBounds()` 开头又会调用 `__updateLayout()`，并递归遍历整棵子树计算边界（`__transform.clone()` + `Matrix.concat()` + `new Rectangle()`）。
3. 第 2 步会重入第 1 步，profile 中出现 10 层 `updateLayout` + 6 层 `__getBounds` 的嵌套，UI 层级越深代价越大。
4. `Box`、`Quad`、`DisplayObjectContainer` 的 `set_width`/`set_height` 不判等就置 `__layoutDirty = true`；布局管理器每轮又会写回相同尺寸，形成“布局 → 置脏 → 下一帧再布局”的自持循环。
5. 新 Graphics 的 `__geometryChanged()` 会把 `__parent.__layoutDirty` 置为 `true`（Quad 重绘、Spine 每帧 `drawTriangles` 都会触发），在缺少重入保护的老布局代码上会持续点燃上述级联。

这些逻辑在 main 的 `383dcd7`（性能优化）、`2ac2fda`（修复布局问题）、`dc3bccd`（世界矩阵缓存）中已有处理，但 `graphis-api-1.1.0` 基于 v1.1.0，尚未包含。

### 本次移植内容（只做性能收敛，不改变布局算法与结果）

- `DisplayObjectContainer`：新增 `__updatingLayout` 重入保护；`__updateLayout(force)` 区分按需失效与递归强制刷新；`updateLayout()` 公开调用仍强制刷新整棵子树；布局期间产生的新失效会保留给下一次结算，异常时恢复脏标记；新增 `invalidateLayout()` 供原地修改布局参数后显式失效。
- `DisplayObjectContainer.set_width/set_height`：尺寸或缩放未变化时不再制造布局失效。
- `Box.set_width/set_height`、`Quad.set_width/set_height`：相同值不重复置脏（`null` → 明确尺寸的首次赋值仍会布局）。
- `DisplayObject.set_width/set_height`：仅在宽度/高度或缩放实际变化时 `setTransformDirty()`。
- `DisplayObject.set_x/set_y`：相同坐标不重复置脏。
- `BoxContainer.updateLayout()`：消费内部 `box` 的布局脏标记，避免后续查询再次布局。

未改变布局管理器的排列算法、`AnchorLayout`/`HorizontalLayout`/`VerticalLayout`/`FlowLayout` 的结果，以及 `updateLayout()` 对外“强制刷新整棵子树”的语义。

`2ac2fda` 中 `layoutData`/`layout`/`hide`/`includeInLayout` 的自动父布局失效通知暂未移植，保持 1.1.0 的现有行为；原地修改布局参数后如需立即重排，请调用新增的 `invalidateLayout()`。

### 验证

```bash
haxe test/layout-refresh.hxml
```

`test/LayoutRefreshChecks.hx` 覆盖：首次递归每个容器只布局一次、无失效不重复布局、重复尺寸赋值不制造失效、尺寸变化后百分比布局生效、公开 `updateLayout` 仍刷新整棵子树、布局期间新失效保留、异常恢复、`BoxContainer` 内部 box 脏标记消费。该用例编译通过并可在浏览器/带 DOM 桩的 Node 环境执行。

### 后续可选优化

- `Graphics.__geometryChanged()` 目前只要几何变化就通知父布局；可改为仅在包围盒实际变化时通知，减少 Spine/动态 Quad 所在父容器的每帧布局。
- main 的 `dc3bccd` 世界矩阵缓存（`__ensureWorldTransform`）尚未移植，可在坐标查询/命中测试成为新瓶颈时再引入。
- 从 main 迁移时只取与性能/布局相关的逻辑，不要整体合并：main 的渲染机制与 1.1.0 差异较大，本分支以稳定性和性能优先。
