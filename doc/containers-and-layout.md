# 容器与布局

本文档介绍布局容器类和布局系统，帮助你高效地组织和管理 UI 布局。

## 容器概览

| 容器 | 说明 | 适用场景 |
|------|------|----------|
| `Box` | 虚拟盒子，尺寸独立于子对象 | 固定尺寸的容器 |
| `Sprite` | 轻量容器，尺寸由子对象决定 | 对象分组 |
| `HBox` | 水平排列子对象 | 水平列表、工具栏 |
| `VBox` | 垂直排列子对象 | 垂直列表、表单 |
| `FlowBox` | 流式排列，自动换行 | 标签云、自适应网格 |
| `Stack` | 栈式容器，一次只显示一个子对象 | 页面切换、Tab 页 |

## Box — 虚拟盒子

`Box` 是最基础的容器类。其宽度和高度由你手动设置，不影响子对象的布局。

```haxe
import hx.display.Box;

var box = new Box();
box.width = 400;
box.height = 300;
box.x = 50;
box.y = 50;

// 子对象使用绝对坐标
var rect = new Quad(200, 100, 0xFF0000);
rect.x = 10;
rect.y = 10;
box.addChild(rect);

this.addChild(box);
```

## HBox — 水平布局

`HBox` 自动将子对象水平排列，每个子对象依次从左到右放置。

```haxe
import hx.display.HBox;

var hbox = new HBox();
hbox.gap = 10;                // 子对象之间的间距
hbox.verticalAlign = VerticalAlign.MIDDLE;  // 垂直方向对齐
hbox.x = 50;
hbox.y = 100;

// 添加子对象，它们会自动水平排列
hbox.addChild(new Quad(80, 80, 0xFF0000));
hbox.addChild(new Quad(80, 80, 0x00FF00));
hbox.addChild(new Quad(80, 80, 0x0000FF));

this.addChild(hbox);
```

### HBox 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `gap` | Float | 子对象之间的水平间距 |
| `verticalAlign` | VerticalAlign | 垂直对齐方式（TOP / MIDDLE / BOTTOM） |
| `fill` | Bool | 是否填充剩余空间 |

## VBox — 垂直布局

`VBox` 自动将子对象垂直排列，每个子对象依次从上到下放置。

```haxe
import hx.display.VBox;

var vbox = new VBox();
vbox.gap = 15;                // 子对象之间的间距
vbox.horizontalAlign = HorizontalAlign.CENTER;  // 水平方向对齐
vbox.x = 50;
vbox.y = 50;

// 添加子对象，它们会自动垂直排列
vbox.addChild(new Quad(200, 50, 0xFF0000));
vbox.addChild(new Quad(200, 50, 0x00FF00));
vbox.addChild(new Quad(200, 50, 0x0000FF));

this.addChild(vbox);
```

### VBox 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `gap` | Float | 子对象之间的垂直间距 |
| `horizontalAlign` | HorizontalAlign | 水平对齐方式（LEFT / CENTER / RIGHT） |
| `fill` | Bool | 是否填充剩余空间 |

## FlowBox — 流式布局

`FlowBox` 将子对象逐行排列，当一行放不下时自动换行到下一行，类似于文本的换行行为。

```haxe
import hx.display.FlowBox;

var flow = new FlowBox();
flow.gapX = 10;               // 水平间距
flow.gapY = 10;               // 垂直间距
flow.width = 400;             // 设置宽度以触发换行
flow.x = 50;
flow.y = 50;

// 添加多个子对象，超出宽度自动换行
for (i in 0...20) {
    flow.addChild(new Quad(60, 60, 0x6699CC));
}

this.addChild(flow);
```

### FlowBox 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `gapX` | Float | 列间距 |
| `gapY` | Float | 行间距 |
| `gap` | Float | 同时设置水平和垂直间距 |

## Stack — 栈式容器

`Stack` 一次只显示一个子对象，通过切换 `currentId` 或 `currentIndex` 来切换显示的内容。适用于页面切换、Tab 页等场景。

```haxe
import hx.display.Stack;

var stack = new Stack();
stack.width = 400;
stack.height = 300;

// 添加多个页面
var page1 = new Box();
var label1 = new Label("页面一");
page1.addChild(label1);
stack.addChild(page1);

var page2 = new Box();
var label2 = new Label("页面二");
page2.addChild(label2);
stack.addChild(page2);

// 切换到第二个页面
stack.currentIndex = 1;

// 或者通过名称切换
stack.currentId = "someName";

this.addChild(stack);
```

## 布局系统

Hxmaker 的布局系统通过 `ILayout` 接口实现，每个容器可以指定不同的布局策略。

### AnchorLayout — 锚点布局

锚点布局允许子对象相对于父容器进行定位，非常适合自适应界面。

```haxe
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;

var box = new Box();
box.width = 500;
box.height = 400;
box.layout = new AnchorLayout();

// 创建子对象并设置锚点数据
var rect = new Quad(100, 50, 0xFF0000);
rect.layoutData = AnchorLayoutData.topRight();  // 固定在右上角
box.addChild(rect);

var centerRect = new Quad(200, 100, 0x00FF00);
centerRect.layoutData = AnchorLayoutData.center();  // 居中
box.addChild(centerRect);

var fillRect = new Quad(100, 100, 0x0000FF);
fillRect.layoutData = AnchorLayoutData.fill();  // 填充整个父容器
box.addChild(fillRect);

this.addChild(box);
```

#### 预设锚点

`AnchorLayoutData` 提供了便捷的静态方法创建常用锚点：

| 方法 | 效果 |
|------|------|
| `center()` | 居中 |
| `fill()` | 填充整个区域 |
| `fillHorizontal()` | 水平填充 |
| `fillVertical()` | 垂直填充 |
| `topLeft()` | 左上角 |
| `topCenter()` | 顶部居中 |
| `topRight()` | 右上角 |
| `middleLeft()` | 左侧居中 |
| `middleRight()` | 右侧居中 |
| `bottomLeft()` | 左下角 |
| `bottomCenter()` | 底部居中 |
| `bottomRight()` | 右下角 |

#### 自定义锚点

```haxe
var data = new AnchorLayoutData();
data.left = 20;              // 距左边 20px
data.right = 20;             // 距右边 20px（与 left 同时存在时会水平拉伸）
data.top = 10;               // 距顶部 10px
data.bottom = 10;            // 距底部 10px（与 top 同时存在时会垂直拉伸）
data.horizontalCenter = 0;   // 水平中心偏移
data.verticalCenter = 0;     // 垂直中心偏移
data.percentWidth = 50;      // 宽度为父容器的 50%
data.percentHeight = 30;     // 高度为父容器的 30%
```

### HorizontalLayout — 水平布局

```haxe
import hx.layout.HorizontalLayout;

var box = new Box();
box.layout = new HorizontalLayout();
cast(box.layout, HorizontalLayout).gap = 10;
cast(box.layout, HorizontalLayout).verticalAlign = VerticalAlign.MIDDLE;
```

### VerticalLayout — 垂直布局

```haxe
import hx.layout.VerticalLayout;

var box = new Box();
box.layout = new VerticalLayout();
cast(box.layout, VerticalLayout).gap = 15;
cast(box.layout, VerticalLayout).horizontalAlign = HorizontalAlign.CENTER;
```

### FlowLayout — 流式布局

```haxe
import hx.layout.FlowLayout;

var box = new Box();
box.layout = new FlowLayout();
cast(box.layout, FlowLayout).gapX = 10;
cast(box.layout, FlowLayout).gapY = 10;
```

> **提示**：HBox、VBox、FlowBox 已经内置了对应的布局，通常直接使用这些容器类更方便。手动设置布局适用于需要在 Box 上使用特定布局的情况。

## 使用 LayoutData 控制子对象尺寸

`LayoutData` 有两个百分比属性，控制子对象相对于父容器的尺寸：

```haxe
import hx.layout.LayoutData;

var rect = new Quad(100, 50, 0xFF0000);
var data = new LayoutData();
data.percentWidth = 80;    // 宽度为父容器的 80%
data.percentHeight = 20;   // 高度为父容器的 20%
rect.layoutData = data;

// 也可以继承 AnchorLayoutData 来组合使用
var anchorData = new AnchorLayoutData();
anchorData.top = 0;
anchorData.horizontalCenter = 0;
anchorData.percentWidth = 90;
anchorData.percentHeight = 15;
rect.layoutData = anchorData;
```
