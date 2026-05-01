# Hxmaker 游戏引擎文档

Hxmaker 是一个使用 **Haxe** 语言编写的统一 2D 游戏引擎。它将核心引擎逻辑与渲染后端分离，通过 `IEngine` 接口适配到不同的渲染后端，让你可以用同一套代码发布到多个平台。

## 核心特性

- **引擎与渲染分离** — 核心逻辑不依赖任何特定渲染引擎，可自由适配不同后端
- **完整的显示对象树** — 提供 Image、Label、Button、Graphics 等丰富的显示对象
- **异步资源加载** — 基于 Future 模式的资源管理系统，支持图片、音频、图集、字体等
- **灵活的布局系统** — 内置锚点布局、水平布局、垂直布局、流式布局
- **XML 驱动的 UI 系统** — 通过 XML 声明式构建界面，支持编译时类型安全绑定
- **流程管理系统** — 与渲染解耦的游戏流程管理，灵感来源于 Unity GameFramework
- **粒子系统** — 支持 Cocos2d/Particle Designer JSON 格式的粒子特效
- **骨骼动画** — 集成 Spine 骨骼动画运行时
- **自动批处理** — 引擎自动合批减少 DrawCall，提升渲染性能
- **多平台支持** — 通过条件编译支持微信、QQ、百度、OPPO、华为等多个小游戏平台

## 支持的渲染后端

| 后端 | 说明 |
|------|------|
| [hxmaker-openfl](https://github.com/rainyt/hxmaker-openfl) | OpenFL 渲染后端（主要支持），可编译为 HTML5、Windows、macOS、Linux、Android、iOS 等平台 |

## 文档目录

### 入门
- [快速开始](getting-started.md) — 安装引擎、创建项目、编写 Hello World

### 核心概念
- [引擎架构](architecture.md) — 引擎生命周期、显示对象树、事件系统

### 显示对象
- [基础显示对象](display-objects.md) — Image（图片）、Quad（矩形）、Graphics（矢量绘图）、Sprite（精灵）
- [文本系统](text.md) — Label（文本标签）、BitmapLabel（位图字体）、InputLabel（输入框）
- [按钮组件](button.md) — Button 按钮的创建与使用
- [容器与布局](containers-and-layout.md) — Box、HBox、VBox、FlowBox、Stack 及布局系统
- [滚动与列表](scroll-and-list.md) — Scroll 滚动容器、ListView 列表视图
- [动画系统](animation.md) — MovieClip 帧动画、Spine 骨骼动画、Particle 粒子系统

### 系统功能
- [资源加载](assets.md) — 异步资源加载、Future 模式、资源类型
- [场景管理](scene-management.md) — 场景的创建、切换与生命周期
- [UI 系统](ui-system.md) — XML 驱动的声明式 UI 构建
- [流程系统](procedure.md) — 与渲染解耦的游戏流程管理

### 进阶
- [高级功能](advanced.md) — 滤镜与混合模式、编译时宏、自定义渲染后端
- [CLI 工具](cli-tools.md) — 命令行项目脚手架工具

## 快速上手

```haxe
// 1. 创建一个继承 Stage 的游戏主类
class GameMain extends Stage {
    override function onStageInit():Void {
        // 2. 创建一张图片
        var image = new Image("myImage");
        image.x = 100;
        image.y = 200;
        this.addChild(image);
    }
}

// 3. 在 Main.hx 中启动引擎
class Main extends HxmakerApplication {
    public function new() {
        super();
        this.init(GameMain, 1920, 1080);
    }
}
```

详细的安装和配置步骤请查看 [快速开始](getting-started.md)。
