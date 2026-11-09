# 更新日志

## 1.0.0 (2026-10-06)

hxmaker 首个正式版本。hxmaker 是一个使用 Haxe 编写的统一游戏引擎，通过实现不同的渲染后端，可以运行在任何游戏引擎之上。本版本包含引擎的核心渲染、UI、资源、事件、动画等完整能力。

### 渲染核心

- 显示列表架构：`DisplayObject` / `DisplayObjectContainer`，支持 x/y/scaleX/scaleY/rotation/alpha、变换矩阵（含 3D 矩阵与透视视角）
- 自动合批：所有常用显示对象均可自动合批渲染，配合多纹理渲染大幅减少 drawcall
- 常用显示对象：
  - `Image`：支持九宫格（scale9Grid）、repeat 平铺、翻转
  - `Quad`：矩形显示对象
  - `Graphics`：矢量图形，支持线段、圆、圆环等绘制 API
  - `Sprite` / `Box` / `VBox` / `HBox` / `BoxContainer`
  - `MovieClip`：帧动画，支持播放完成事件、stopAt、cleanFrames
  - `BitmapLabel`：纹理位图字
  - `CustomDisplayObject`：自定义渲染入口
  - `FPS`：显示 drawCall、顶点数量、CPU 使用率、内存等运行状态
- `cacheAsBitmap` 缓存位图渲染
- 15 种 `BlendMode` 混合模式：Normal、Add、Multiply、Screen、Difference、Subtract、Subtract Fast、Invert、Darken、Lighten、Layer、Alpha、Erase、Hardlight、Overlay

### 文本

- `Label`：支持富文本范围格式（`setRangeTextFormat`、`setRegexRangeTextFormat`）、描边、对齐、颜色、wordWrap、charFilterEnabled
- 文本离屏测量：`getTextWidth` / `getTextHeight`
- `InputLabel` 输入框：placeholder、密码模式（displayAsPassword）、焦点管理
- 全局文本翻译支持
- fnt 字体纹理加载

### UI 系统

- `UIBuilder` XML 布局构造器，支持 `xml:` 格式、模块化（UIMoudle）、样式与临时样式、UI 资源复用与缓存
- 组件：
  - `Button`：支持自定义按钮音频
  - `Scroll`：类 iOS UIScrollView 弹性滚动、滚动条（VScrollBar/HScrollBar）、autoVisible、滚轮事件
  - `ListView`：列表视图，支持右键选择、selectedIndex/selectedItem
  - `Tree`：VSCode 资源管理器风格树组件，支持虚拟列表、Shift+Ctrl 多选
  - `FinderView`：Finder 风格资源浏览器，支持文件夹导航，与 Tree 共享 TreeItem 数据模型
  - `Stack`、`InputLabel`、`ImageLoader`（异步加载、scale9Grid、CHANGE 事件）
  - `ItemRenderer` 体系：DefaultItemRenderer、TreeItemRenderer、FinderItemRenderer
- 虚拟列表与流虚拟布局（超出界限立即换行的 FlowLayout）
- `SplitterLayout` 切割器布局，支持多个切割器拖拽
- `UIAnimate` / `UIAnimateGroup` 界面过渡动画

### 布局

- `FlowLayout`（流布局）、`HorizontalLayout`（横向，支持垂直对齐）、`VerticalLayout`、`AnchorLayout`（left/right/top/bottom/horizontalCenter/verticalCenter 锚点）

### 事件

- `MouseEvent`：CLICK、DOUBLE_CLICK、MOUSE_LONG_CLICK、右键事件、OVER/OUT、SELECT，支持事件冒泡
- `KeyboardEvent`：多按键支持、Shift+Ctrl 组合键、isCtrlOrCommand
- `TouchEvent`：触摸事件与 VirtualTouchKey 虚拟按键
- 焦点获得/失去事件、`UncaughtErrorEvent` 全局异常事件
- 事件流与统一 stage 事件分发

### 资源管理

- `Assets` 统一加载器：图片、音频、精灵图（atlas）、XML、JSON、fnt、zip、粒子配置等格式
- `AssetsBundle` 资源包加载，支持嵌套加载与远程地址加载
- 资源引用计数统计与 `GC` 接口，避免资源泄漏
- `Future` 异步模型与 onProgress 进度回调
- 本地缓存支持

### 音频

- `SoundManager`：BGM/音效区分（isMusic）、SoundTransform、异步地址播放、重复播放修复
- 按钮自定义音频

### 粒子系统

- 全新 `Particle` 粒子组件：支持 XML/JSON 配置读取
- 颜色过渡、缩放/旋转/切线/加速力/向量力/重力
- 动态发射点（dynamicEmitPoint）、发射角度（useEmitRotation）、圆形发射区域
- 持续时间（time）、auto 参数、start 支持从指定秒数播放、stop 播完剩余粒子

### Spine 骨骼动画

- 支持 Spine 3.8，`Spine` / `SpineSprite` 自动合批
- 插槽绑定：多 Spine 绑定（bindSlot）、解绑（unbindSlot/removeBindSlot/clearAllBindSlots）、透明度绑定
- 播放完成事件、defaultFps 帧率控制、setSkinByName

### 场景与流程

- `Scene` / `SceneManager` / `UILoadScene`（自动加载 UI 资源的场景）/ `onStageInit`
- `Procedure` 流程系统：与渲染解耦的游戏流程管理

### 系统能力

- `System`：剪贴板读写、defines 环境变量、GC 接口
- `DateUtils` 日期工具、`StorageTools` 本地存储、URL 解析器
- `Timer`：setInterval、createIntervalTimer 定时器
- 设备信息：devicePixelRatio、isPc、highDpi
- frameRate 帧率设置、横屏硬锁（lockLandscape）
- `InstanceMacro` 单例宏

### 调试与工具

- `EchoDebug` 调试渲染：边框、圆形、精灵图调试
- `ContextStats` 渲染统计：blendMode 统计、graphicRenderCount、timeTaskCounts
- GPU 内存读取（webgl-memory）、CPU 使用率统计
- 命令行工具与 API 文档生成（`haxelib run hxmaker`）
- 引擎使用文档按功能分类整理（`doc/` 目录）

### 平台支持

- HTML5、微信小游戏（含输入文本支持）
- C++ 原生目标：Windows、macOS、Android、iOS（arm64）
- 鸿蒙 hap-html5 目标

### 安装

```bash
haxelib install hxmaker
```

渲染后端需搭配 [hxmaker-openfl](https://github.com/rainyt/hxmaker-openfl) 使用。
