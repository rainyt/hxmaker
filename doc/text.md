# 文本系统

Hxmaker 提供了三种文本显示方式：`Label`（基本文本）、`BitmapLabel`（位图字体）和 `InputLabel`（文本输入框）。

## Label — 文本标签

`Label` 是基本的文本显示组件，使用系统字体渲染。

### 基本用法

```haxe
import hx.display.Label;
import hx.display.TextFormat;

var label = new Label();
label.text = "Hello Hxmaker!";
label.fontSize = 32;
label.color = 0xFFFFFF;
label.x = 100;
label.y = 50;
this.addChild(label);
```

### 文本格式

```haxe
var label = new Label();
label.text = "你好，世界！";

// 基本格式
label.fontSize = 24;           // 字号
label.color = 0xFFCC00;        // 颜色
label.bold = true;             // 粗体
label.italic = true;           // 斜体

// 对齐方式
label.horizontalAlign = HorizontalAlign.CENTER;  // 水平居中
label.verticalAlign = VerticalAlign.MIDDLE;      // 垂直居中

// 自动换行
label.wordWrap = true;
label.width = 300;             // 设置宽度后自动换行
```

### TextFormat 高级格式

使用 `TextFormat` 对象可以更精细地控制文本样式：

```haxe
var format = new TextFormat();
format.font = "Arial";
format.size = 28;
format.color = 0xFFFFFF;
format.bold = true;
format.italic = false;

var label = new Label();
label.text = "使用自定义格式的文本";
label.textFormat = format;
this.addChild(label);
```

TextFormat 支持的属性：

| 属性 | 类型 | 说明 |
|------|------|------|
| `font` | String | 字体名称 |
| `size` | Int | 字号 |
| `color` | UInt | 颜色 |
| `bold` | Bool | 粗体 |
| `italic` | Bool | 斜体 |

### 文本描边

```haxe
var label = new Label();
label.text = "描边文字";
label.stroke(2, 0x000000);  // 描边宽度, 描边颜色
this.addChild(label);
```

### 范围文本格式

你可以在同一段文本中设置不同范围的格式，实现富文本效果：

```haxe
var label = new Label();
label.text = "红色文字 蓝色文字 绿色文字";
label.fontSize = 24;

// 设置指定字符范围的格式
label.setRangeTextFormat(0, 6, {color: 0xFF0000});    // "红色文字" 为红色
label.setRangeTextFormat(7, 13, {color: 0x0000FF});   // "蓝色文字" 为蓝色
label.setRangeTextFormat(14, 20, {color: 0x00FF00});  // "绿色文字" 为绿色

// 使用正则表达式设置范围格式
// label.setRegexRangeTextFormat(~/\d+/, {color: 0xFF0000});  // 所有数字为红色
```

### 文本缓存

Label 默认会缓存渲染结果以提高性能：

```haxe
label.textCacheId = "myUniqueId";  // 设置缓存 ID
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `text` | String | 文本内容 |
| `fontSize` | Int | 字号 |
| `color` | UInt | 文本颜色 |
| `bold` | Bool | 是否粗体 |
| `italic` | Bool | 是否斜体 |
| `textFormat` | TextFormat | 文本格式对象 |
| `wordWrap` | Bool | 是否自动换行 |
| `horizontalAlign` | HorizontalAlign | 水平对齐 |
| `verticalAlign` | VerticalAlign | 垂直对齐 |
| `smoothing` | Bool | 平滑处理 |
| `textCacheId` | String | 文本缓存 ID |

## BitmapLabel — 位图字体

`BitmapLabel` 使用位图字体（.fnt + .png）渲染文本，适合需要精确控制字体外观的场景。

```haxe
import hx.display.BitmapLabel;

var label = new BitmapLabel();
label.data = "Hello World!";
label.fontName = "myFont";      // 字体名称
label.space = 2;                // 字符间距
label.x = 100;
label.y = 100;
this.addChild(label);
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | String | 文本内容 |
| `fontName` | String | 字体名称（对应已加载的位图字体） |
| `space` | Float | 字符间距 |
| `warpWord` | Bool | 是否自动换行 |

## InputLabel — 文本输入框

`InputLabel` 是一个可编辑的文本输入组件，用户可以在其中输入文本。

```haxe
import hx.display.InputLabel;

var input = new InputLabel();
input.width = 300;
input.height = 40;
input.x = 100;
input.y = 50;

// 设置占位符文本
input.placeholder = "请输入内容...";

// 设置文本格式
input.fontSize = 20;
input.color = 0x333333;

// 监听文本变化事件
input.addEventListener(Event.CHANGE, function(event) {
    trace("输入内容：" + input.data);
});

this.addChild(input);
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | String | 当前输入的文本内容 |
| `placeholder` | String | 占位符文本（未输入时显示） |
| `fontSize` | Int | 字号 |
| `color` | UInt | 文本颜色 |
| `width` | Float | 输入框宽度 |
| `height` | Float | 输入框高度 |

## 水平对齐和垂直对齐枚举

```haxe
// 水平对齐
enum HorizontalAlign {
    LEFT;
    CENTER;
    RIGHT;
}

// 垂直对齐
enum VerticalAlign {
    TOP;
    MIDDLE;
    BOTTOM;
}
```
