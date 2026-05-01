# 高级功能

本文档介绍 Hxmaker 的高级功能，包括混合模式、滤镜效果、编译时宏和自定义渲染后端。

## 混合模式（BlendMode）

混合模式控制显示对象与背景的叠加方式。Hxmaker 支持丰富的混合模式：

```haxe
import hx.display.BlendMode;

image.blendMode = BlendMode.ADD;       // 加法混合（常用于发光、火焰）
image.blendMode = BlendMode.MULTIPLY;  // 正片叠底（常用于阴影、暗色叠加）
image.blendMode = BlendMode.SCREEN;    // 滤色（常用于高光效果）
image.blendMode = BlendMode.ERASE;     // 擦除
```

### 所有混合模式

| 枚举值 | 效果说明 |
|--------|----------|
| `NORMAL` | 正常渲染（默认） |
| `ADD` | 加法混合 — 颜色相加，适合火光、光晕等发光效果 |
| `ALPHA` | Alpha 混合 |
| `SCREEN` | 滤色 — 产生比原图更亮的效果 |
| `ERASE` | 擦除 — 擦除下层内容 |
| `MULTIPLY` | 正片叠底 — 产生比原图更暗的效果，适合阴影 |
| `DIFFERENCE` | 差值 |
| `SUBTRACT` | 减去 |
| `SUBTRACT_FAST` | 快速减去（性能优化版） |
| `INVERT` | 反转 |
| `DARKEN` | 变暗 |
| `LIGHTEN` | 变亮 |
| `LAYER` | 图层混合 |
| `HARDLIGHT` | 强光 |
| `OVERLAY` | 叠加 |

## 自动批处理

引擎会自动将使用 `NORMAL` 或 `ADD` 混合模式的普通显示对象进行**合批渲染**，以减少 DrawCall 数量，提升渲染性能。

**不会被自动合批的情况：**
- 使用了遮罩的组件（Scroll、ListView）
- `CustomDisplayObject`
- 使用了非 NORMAL/ADD 之外混合模式的对象

引擎支持**多纹理渲染**，可在单次 DrawCall 中使用多个纹理，进一步优化性能。

## 滤镜（Filter）

### 文本描边滤镜

```haxe
var label = new Label();
label.text = "描边文字";
label.stroke(3, 0x000000);  // 宽度, 颜色
this.addChild(label);
```

### 自定义 RenderFilter

滤镜系统通过 `RenderFilter` 实现。每个 `DisplayObject` 有 `filters` 属性：

```haxe
import hx.filters.RenderFilter;

class MyFilter extends RenderFilter {
    override function init():Void {
        // 滤镜初始化
    }

    override function update():Void {
        // 每帧更新
    }
}

// 应用滤镜
image.filters.push(new MyFilter());
```

## 自定义渲染后端

Hxmaker 的核心引擎与渲染后端分离，你可以为不同的渲染框架实现 `IEngine` 接口来适配。

### 实现 IEngine 接口

```haxe
import hx.core.IEngine;
import hx.display.IRender;
import hx.display.Stage;

class MyCustomEngine implements IEngine {
    public var renderer:IRender;
    public var stages:Array<Stage> = [];
    public var touchX:Float = 0;
    public var touchY:Float = 0;
    public var dt:Float = 0;
    public var frameRate:Float = 60;
    public var stageWidth:Float = 0;
    public var stageHeight:Float = 0;
    public var devicePixelRatio:Float = 1;

    public function new() {
        renderer = new MyCustomRender();
    }

    public function init(width:Int, height:Int, lockLandscape:Bool):Void {
        this.stageWidth = width;
        this.stageHeight = height;
        // 初始化你的渲染框架
    }

    public function render():Void {
        // 渲染所有 stages
        for (stage in stages) {
            renderer.renderDisplayObjectContainer(stage);
        }
    }

    public function dispose():Void {
        // 释放资源
    }

    public function addToStage(obj:DisplayObject):Void {
        // 将对象添加到舞台
    }

    public function removeToStage(obj:DisplayObject):Void {
        // 从舞台移除对象
    }
}
```

### 实现 IRender 接口

```haxe
import hx.display.IRender;
import hx.display.DisplayObject;

class MyCustomRender implements IRender {
    public var cacheAsBitmap:Bool = false;
    public var highDpi:Bool = false;
    public var multiTextureEnabled:Bool = true;

    public function clear():Void {
        // 清除画布
    }

    public function renderDisplayObjectContainer(obj:DisplayObjectContainer):Void {
        // 渲染容器及其子对象
    }

    public function renderDisplayObject(obj:DisplayObject):Void {
        // 渲染单个显示对象
    }

    public function renderImage(image:Image):Void {
        // 渲染图片
    }

    public function renderLabel(label:Label):Void {
        // 渲染文本
    }

    public function renderCustomDisplayObject(obj:CustomDisplayObject):Void {
        // 渲染自定义对象
    }

    public function renderGraphics(graphics:Graphics):Void {
        // 渲染矢量图形
    }

    public function endFill():Void {
        // 结束填充
    }

    public function renderToBitmapData(obj:Dynamic):BitmapData {
        // 渲染到纹理
        return null;
    }
}
```

### 使用自定义引擎

```haxe
// 初始化时传入自定义引擎类
Hxmaker.init(MyCustomEngine, 1920, 1080);
```

## 编译时宏（Macro）

### UIBuilder — 自动生成 UI 绑定

```haxe
@:build(hx.macro.UIBuilder.build("assets/ui/myPanel.xml"))
class MyPanel extends Box {
    // 编译时自动生成 XML 中所有带 id 元素的访问属性
}
```

### 导入宏

```haxe
// hx.macro.AutoImport 提供显示类的自动导入功能
```

### 自定义宏

`hx.macro` 包提供了 `MacroTools` 等辅助工具，你可以基于这些工具编写自己的宏。

```haxe
import hx.macro.MacroTools;

class MyBuilder {
    macro static public function build(path:String):Array<Field> {
        var fields = haxe.macro.Context.getBuildFields();
        var content = MacroTools.readContent(path);
        // 解析内容并生成字段
        return fields;
    }
}
```

## 性能调试

### FPS 组件

`FPS` 组件可以显示实时性能数据：

```haxe
import hx.display.FPS;

var fps = new FPS();
this.addChild(fps);
```

它会显示：
- FPS（帧率）
- DrawCall 数量
- 顶点数量
- 显示对象数量
- CPU 使用情况
- 帧延迟
- 内存使用
- GPU 内存使用
- Spine 和 Graphics 渲染数量
- 定时器任务数量
- 缓存状态

## 颜色变换（ColorTransform）

可以通过 `ColorTransform` 对显示对象进行颜色调整：

```haxe
import hx.geom.ColorTransform;

var ct = new ColorTransform();
ct.redMultiplier = 1.5;
ct.greenMultiplier = 1.0;
ct.blueMultiplier = 1.0;
ct.alphaMultiplier = 1.0;

image.colorTransform = ct;
```

ColorTransform 属性：

| 属性 | 说明 |
|------|------|
| `redMultiplier` | 红色通道乘数（0.0 ~ 1.0 或更高） |
| `greenMultiplier` | 绿色通道乘数 |
| `blueMultiplier` | 蓝色通道乘数 |
| `alphaMultiplier` | 透明度乘数 |
| `redOffset` | 红色通道偏移 |
| `greenOffset` | 绿色通道偏移 |
| `blueOffset` | 蓝色通道偏移 |
| `alphaOffset` | 透明度偏移 |

## 虚拟摇杆（VirtualTouchKey）

移动端虚拟摇杆，适用于手机游戏：

```haxe
import hx.display.VirtualTouchKey;

var touchKey = new VirtualTouchKey();
touchKey.addEventListener(VirtualTouchKey.VIRTUAL_TOUCH, function(event) {
    // 获取摇杆的角度和力度
    var radians = touchKey.radians;
    var influence = touchKey.influence;  // 0.0 ~ 1.0
});

this.addChild(touchKey);
```
