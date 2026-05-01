# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- 包结构：`hx.core` → 核心 | `hx.display` → 显示对象 | `hx.events` → 事件 | `hx.assets` → 资源 | `hx.geom` → 几何 | `hx.layout` → 布局 | `hx.ui` → UI 管理 | `hx.utils` → 工具 | `hx.macro` → 编译时宏
