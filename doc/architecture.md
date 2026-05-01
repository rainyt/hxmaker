# 引擎架构

本文档介绍 Hxmaker 引擎的核心架构，帮助你理解引擎的工作原理。

## 整体架构

Hxmaker 采用**引擎核心与渲染后端分离**的设计。核心引擎只负责管理显示对象列表和游戏逻辑，不包含任何具体的渲染代码。所有渲染操作通过 `IEngine` 接口委托给后端实现。

```
┌─────────────────────────────────────────┐
│              游戏逻辑代码                  │
├─────────────────────────────────────────┤
│           Hxmaker 引擎核心                │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐  │
│  │ 显示树   │ │ 事件系统  │ │ 资源管理  │  │
│  ├─────────┤ ├──────────┤ ├──────────┤  │
│  │ 布局系统 │ │ UI 系统   │ │ 流程系统  │  │
│  └─────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────┤
│           IEngine 接口                    │
├─────────────────────────────────────────┤
│    渲染后端（如 hxmaker-openfl）           │
│    实际调用 OpenFL/Lime 进行渲染           │
└─────────────────────────────────────────┘
```

## 引擎入口：Hxmaker

[Hxmaker](src/hx/core/Hxmaker.hx) 是整个引擎的单例入口，负责创建和管理引擎实例。

```haxe
// 初始化引擎
Hxmaker.init(EngineImpl, 1920, 1080);

// 访问全局根舞台
var stage = Hxmaker.topView;

// 获取当前引擎实例
var engine = Hxmaker.engine;
```

主要成员：

| 成员 | 说明 |
|------|------|
| `Hxmaker.init(Class, width, height)` | 初始化引擎，创建舞台 |
| `Hxmaker.topView` | 全局根舞台（Stage），所有显示对象的根 |
| `Hxmaker.engine` | 当前引擎实例 |

## IEngine 接口

[IEngine](src/hx/core/IEngine.hx) 定义了引擎后端必须实现的接口：

```haxe
interface IEngine {
    var renderer:IRender;    // 渲染器
    var stages:Array<Stage>; // 舞台列表（支持多舞台）
    var touchX:Float;        // 当前触摸/鼠标 X
    var touchY:Float;        // 当前触摸/鼠标 Y
    var dt:Float;            // 帧间隔时间
    var frameRate:Float;     // 帧率

    function init(width:Int, height:Int, lockLandscape:Bool):Void;
    function dispose():Void;
    function render():Void;
}
```

## 显示对象树

所有可视元素都组织在一棵**显示对象树**中。树的根节点是 `Stage`（舞台），树枝是各种容器类，叶子是具体的显示对象。

### 类的继承层次

```
EventDispatcher          — 事件分发基类
  └─ DisplayObject       — 所有显示对象的基类（位置、缩放、旋转、透明度等）
       └─ DisplayObjectContainer — 可包含子对象的容器
            └─ Box               — 虚拟盒子（宽高不影响子对象）
            │    └─ Stage         — 根舞台
            │    └─ HBox          — 水平布局盒子
            │    └─ VBox          — 垂直布局盒子
            │    └─ FlowBox       — 流式布局盒子
            │    └─ Stack         — 栈式页面切换器
            │    └─ Scene         — 全屏场景
            │    └─ BoxContainer  — 内部包含 Box 的容器
            │         └─ Scroll   — 滚动容器
            │              └─ ListView — 列表视图
            └─ Sprite            — 轻量容器
       └─ Image                 — 纹理图片
       └─ Quad                  — 纯色矩形
       └─ Graphics              — 矢量绘图
       └─ Label                 — 文本标签
       └─ MovieClip             — 帧动画
```

### 核心属性

所有显示对象都继承 `DisplayObject`，拥有以下核心属性：

| 属性 | 类型 | 说明 |
|------|------|------|
| `x`, `y` | Float | 位置坐标（相对于父容器） |
| `width`, `height` | Float | 宽度和高度 |
| `scaleX`, `scaleY` | Float | 缩放比例 |
| `rotation` | Float | 旋转角度（弧度） |
| `alpha` | Float | 透明度（0.0 ~ 1.0） |
| `visible` | Bool | 是否可见 |
| `blendMode` | BlendMode | 混合模式 |
| `name` | String | 对象名称（用于查找） |

### 容器类核心方法

所有容器类（`DisplayObjectContainer` 的子类）提供：

| 方法 | 说明 |
|------|------|
| `addChild(obj)` | 添加子对象 |
| `addChildAt(obj, index)` | 在指定位置添加子对象 |
| `removeChild(obj)` | 移除子对象 |
| `removeChildAt(index)` | 移除指定位置的子对象 |
| `removeChildren()` | 移除所有子对象 |
| `getChildAt(index)` | 获取指定位置的子对象 |
| `getChildByName(name)` | 按名称查找子对象 |
| `swapChildren(a, b)` | 交换两个子对象的层级 |

## 生命周期

每个显示对象都有以下生命周期方法，按顺序调用：

```
new() → onInit() → onAddToStage() → onStageInit() → onUpdate(dt) → ... → onRemoveToStage() → dispose()
```

| 方法 | 触发时机 | 用途 |
|------|----------|------|
| `onInit()` | 构造函数调用后 | 初始化自身属性 |
| `onAddToStage()` | 被添加到舞台时 | 注册事件监听 |
| `onStageInit()` | 首次添加到舞台 | 创建子对象、初始化 UI |
| `onUpdate(dt)` | 每帧调用 | 游戏逻辑更新 |
| `onRemoveToStage()` | 从舞台移除时 | 清理事件监听 |
| `dispose()` | 销毁对象时 | 释放资源 |

## 事件系统

引擎内置了完整的事件分发机制，所有显示对象都可以触发和监听事件。

```haxe
// 监听事件
image.addEventListener(MouseEvent.CLICK, function(event) {
    trace("图片被点击了！");
});

// 触发自定义事件
var event = new Event("myCustomEvent");
displayObject.dispatchEvent(event);
```

事件支持**冒泡机制**，事件会从目标对象向上传播到父容器，直到被处理。

常用的内置事件类型：

| 事件类 | 事件类型 | 说明 |
|--------|----------|------|
| `Event.UPDATE` | update | 每帧更新 |
| `Event.RESIZE` | resize | 尺寸变化 |
| `Event.ADDED_TO_STAGE` | addedToStage | 添加到舞台 |
| `Event.REMOVED_FROM_STAGE` | removedFromStage | 从舞台移除 |
| `MouseEvent.CLICK` | click | 鼠标/触摸点击 |
| `MouseEvent.MOUSE_DOWN` | mouseDown | 鼠标按下 |
| `MouseEvent.MOUSE_UP` | mouseUp | 鼠标抬起 |
| `MouseEvent.MOUSE_MOVE` | mouseMove | 鼠标移动 |
| `KeyboardEvent.KEY_DOWN` | keyDown | 键盘按下 |
| `KeyboardEvent.KEY_UP` | keyUp | 键盘抬起 |

更多详情请参阅各功能模块文档。
