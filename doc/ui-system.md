# UI 系统

Hxmaker 提供了基于 **XML 声明式构建** 的 UI 系统。你可以用 XML 描述界面布局，引擎自动解析并创建对应的显示对象树。

## 为什么使用 XML UI？

- **界面与逻辑分离** — UI 布局在 XML 中定义，代码专注于业务逻辑
- **自动资源加载** — XML 中引用的图片、音频、字体等资源会自动加载
- **编译时类型安全** — 使用 `UIBuilder` 宏可以在编译时为 XML 中的元素生成类型安全的属性
- **内置动画支持** — XML 中可直接定义界面动画

## UIAssets — UI 资源

`UIAssets` 是加载和构建 UI 的入口。它解析 XML 布局文件，自动发现并加载依赖资源，然后构建显示对象树。

### 基本用法

```haxe
import hx.ui.UIAssets;

// 加载 UI 布局文件
var uiAssets = new UIAssets("assets/ui/mainMenu.xml");
uiAssets.onComplete = function(assets:UIAssets) {
    // 构建 UI 树
    assets.build(Hxmaker.topView);
};

uiAssets.start();
```

### 在 Assets 中一起加载

```haxe
var assets = new Assets();
assets.loadUIAssets("mainMenu", "assets/ui/mainMenu.xml");

assets.onComplete = function(a:Assets) {
    var uiAssets = a.uiAssetses.get("mainMenu");
    uiAssets.build(Hxmaker.topView);
};

assets.start();
```

## XML 布局格式

```xml
<?xml version="1.0" encoding="utf-8"?>
<View>
    <!-- 图片 -->
    <Image id="title" src="title_logo" x="400" y="100" />

    <!-- 按钮 -->
    <Button id="startBtn" x="400" y="300" width="200" height="60">
        <Text value="开始游戏" color="#FFFFFF" size="28" />
    </Button>

    <!-- 文本标签 -->
    <Label x="400" y="200" color="#FFFFFF" size="20" value="欢迎游玩" />

    <!-- 水平布局 -->
    <HBox id="menuBar" x="100" y="500" gap="20">
        <Button width="120" height="50">
            <Text value="设置" color="#FFFFFF" />
        </Button>
        <Button width="120" height="50">
            <Text value="帮助" color="#FFFFFF" />
        </Button>
    </HBox>
</View>
```

### 支持的 XML 元素

| XML 标签 | 对应类 | 说明 |
|----------|--------|------|
| `View` | 根节点 | 布局文件的根元素 |
| `Image` | Image | 图片 |
| `Label` | Label | 文本标签 |
| `Button` | Button | 按钮 |
| `Quad` | Quad | 矩形 |
| `Box` | Box | 盒子容器 |
| `VBox` | VBox | 垂直布局 |
| `HBox` | HBox | 水平布局 |
| `FlowBox` | FlowBox | 流式布局 |
| `Stack` | Stack | 栈式容器 |
| `Scene` | Scene | 场景 |
| `Scroll` | Scroll | 滚动容器 |
| `ListView` | ListView | 列表视图 |
| `InputLabel` | InputLabel | 输入框 |
| `ImageLoader` | ImageLoader | 异步图片加载 |
| `BitmapLabel` | BitmapLabel | 位图字体 |
| `Spine` | Spine | 骨骼动画 |
| `Particle` | Particle | 粒子系统 |
| `MovieClip` | MovieClip | 帧动画 |
| `Text` | - | 按钮的子元素，设置按钮文本 |

### XML 中的常用属性

所有元素都支持 DisplayObject 的基础属性：

| 属性 | 说明 |
|------|------|
| `id` | 元素唯一标识（用于代码中引用） |
| `x`, `y` | 位置 |
| `width`, `height` | 尺寸 |
| `scaleX`, `scaleY` | 缩放 |
| `rotation` | 旋转角度 |
| `alpha` | 透明度 |
| `visible` | 是否可见 |

## UIManager — 全局资源管理

`UIManager` 是单例，维护全局的静态资源列表。在 XML UI 中使用 `src` 引用的资源会自动注册到 `UIManager` 中。

```haxe
import hx.ui.UIManager;

// 获取位图（通过资源名，不含路径和扩展名）
var bmp = UIManager.getBitmapData("title_logo");

// 获取音频
var sound = UIManager.getSound("click_sound");

// 获取图集
var atlas = UIManager.getAtlas("uiAtlas");

// 获取字符串
var text = UIManager.getString("welcome_text");

// 获取骨骼数据
var skeleton = UIManager.getSkeletonData("character");

// 获取样式
var style = UIManager.getStyle("defaultStyle");
```

### 手动构建 UI

```haxe
// 通过 UIManager 可以用 id 构建指定的 UI 组件
UIManager.buildUi("mainMenu", Hxmaker.topView);
```

## UIBuilder 宏 — 编译时类型绑定

`UIBuilder` 宏可以在编译时为 XML 中带有 `id` 的元素生成类型安全的访问属性。

### 使用方式

```haxe
import hx.macro.UIBuilder;

@:build(hx.macro.UIBuilder.build("assets/ui/mainMenu.xml"))
class MainMenuUI extends Box {
    public function new() {
        super();
        // UIBuilder 宏会自动生成以下内容：
        // - ids: Map<String, Dynamic> 所有带 id 的元素
        // - getChildById(id): Dynamic 查找方法
        // - title: Image 类型安全的属性（对应 XML 中的 <Image id="title">）
        // - startBtn: Button 类型安全的属性
        // - menuBar: HBox 类型安全的属性
    }
}
```

使用时：

```haxe
var menu = new MainMenuUI();
this.addChild(menu);

// 直接通过类型安全的属性访问 XML 中的元素
menu.title.data = UIManager.getBitmapData("newLogo");
menu.startBtn.addEventListener(MouseEvent.CLICK, function(e) {
    trace("开始按钮被点击");
});
```

这避免了运行时字符串查找，让代码更加安全和高效。

## UIAnimate — UI 动画

`UIAnimate` 和 `UIAnimateGroup` 提供了 XML 驱动的动画系统，基于 Actuate 补间库。

### XML 中定义动画

```xml
<View>
    <Animate id="fadeIn" duration="0.5" delay="0.2" ease="Quad.easeOut">
        <startOption alpha="0" scaleX="0.8" scaleY="0.8" />
        <endOption alpha="1" scaleX="1" scaleY="1" />
    </Animate>

    <Animate id="slideIn" duration="0.3" ease="Quad.easeOut">
        <startOption x="-100" />
        <endOption x="100" />
    </Animate>
</View>
```

### 代码中使用

```haxe
// 播放单个动画
var anim = uiAssets.animates.get("fadeIn");
anim.play();

// 播放动画组
var group = new UIAnimateGroup();
group.addAnimates(uiAssets.animates);
group.play();  // 同时播放所有动画
```

动画属性：

| 属性 | 说明 |
|------|------|
| `duration` | 动画持续时间（秒） |
| `delay` | 延迟时间（秒） |
| `ease` | 缓动函数（如 `Quad.easeOut`, `Quad.easeIn` 等） |
| `startOption` | 动画起始状态 |
| `endOption` | 动画结束状态 |

## 模块系统（XML Module）

UI 系统支持模块化引用，通过 `xml:` 前缀引用其他 XML 布局文件：

```xml
<View>
    <!-- 引用另一个 UI 文件作为子组件 -->
    <xml:SharedButton id="confirmBtn" x="400" y="300" />

    <xml:PlayerPanel id="playerInfo" x="100" y="50" />
</View>
```

模块类型在 `moudle.xml` 中注册，将组件名称映射到具体的类。
