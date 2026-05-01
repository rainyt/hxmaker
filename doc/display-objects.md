# 基础显示对象

本文档介绍最常用的显示对象：Image（图片）、Quad（矩形）、Graphics（矢量绘图）和 Sprite（精灵容器）。

## Image — 图片

`Image` 是最常用的显示对象，用于显示一张纹理图片。

### 基本用法

```haxe
import hx.display.Image;

// 通过资源名称创建（Assets 目录中的图片，不含路径和扩展名）
var image = new Image("myImage");
image.x = 100;
image.y = 200;
this.addChild(image);

// 通过 BitmapData 对象创建
var bmpData = UIManager.getBitmapData("myImage");
var image2 = new Image(bmpData);
this.addChild(image2);
```

### 九宫格缩放（Scale9Grid）

九宫格缩放将图片分为九个区域，四个角保持原始大小，边缘单向拉伸，中心双向拉伸。适合用于 UI 面板、按钮等需要保持边框不变形的场景。

```haxe
var image = new Image("panelBg");
image.width = 400;
image.height = 300;

// 设置九宫格区域（left, top, width, height）
// 表示从图片左上角偏移 (x, y)，取宽为 width、高为 height 的区域作为可拉伸部分
image.scale9Grid = new Rectangle(20, 20, 10, 10);

this.addChild(image);
```

### 纹理平铺（Repeat）

```haxe
var image = new Image("tilePattern");
image.width = 500;
image.height = 400;
image.repeat = true;  // 启用纹理重复

this.addChild(image);
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | BitmapData | 位图数据 |
| `smoothing` | Bool | 是否平滑处理（默认 true） |
| `scale9Grid` | Rectangle | 九宫格缩放区域 |
| `repeat` | Bool | 是否平铺纹理（默认 false） |
| `useFrameRect` | Bool | 是否使用 frameRect 作为尺寸（默认 true） |

## Quad — 纯色矩形

`Quad` 用于显示一个纯色矩形，常用于背景、分割线、颜色块等场景。

```haxe
import hx.display.Quad;

// 创建一个 200x100 的红色矩形
var quad = new Quad();
quad.width = 200;
quad.height = 100;
quad.color = 0xFF0000;
quad.x = 50;
quad.y = 50;
this.addChild(quad);
```

`Quad` 继承自 `Graphics`，本质是绘制了一个填色矩形。

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `color` | UInt | 填充颜色（ARGB 格式） |
| `width` | Float | 宽度 |
| `height` | Float | 高度 |

## Graphics — 矢量绘图

`Graphics` 提供了丰富的矢量绘图 API，可以绘制矩形、圆形、线条、三角形等图形。所有绘制命令在每帧都会被重新渲染。

### 绘制基本图形

```haxe
import hx.display.Graphics;

var g = new Graphics();

// 填充色 + 绘制矩形
g.beginFill(0xFF0000, 1.0);     // 颜色, 透明度
g.drawRect(0, 0, 100, 100);

// 绘制圆形（使用矩形包围盒定义）
g.beginFill(0x00FF00, 0.8);
g.drawCircle(50, 50, 25);       // centerX, centerY, radius

// 绘制线条
g.drawLine(0, 0, 100, 100, 2);  // x1, y1, x2, y2, 线宽

// 绘制三角形
g.beginFill(0x0000FF);
g.drawTriangles([0,0, 50,100, 100,0]);
// 支持带 UV 的三角形：drawTriangles(vertices, indices, uvs)

this.addChild(g);
```

### 线条绘制

```haxe
var g = new Graphics();
g.lineStyle(2, 0xFF0000, 1.0);  // 线宽, 颜色, 透明度
g.moveTo(10, 10);               // 移动到起点
g.lineTo(100, 100);             // 画线到终点
g.lineTo(200, 50);
this.addChild(g);
```

### 纹理填充

```haxe
var g = new Graphics();
g.beginBitmapData(bitmapData);  // 使用纹理填充
g.drawRect(0, 0, 200, 200);
g.endFill();
this.addChild(g);
```

### 主要方法

| 方法 | 说明 |
|------|------|
| `beginFill(color, alpha)` | 开始颜色填充 |
| `beginBitmapData(bmp, smoothing)` | 开始纹理填充 |
| `endFill()` | 结束填充 |
| `drawRect(x, y, w, h)` | 绘制矩形 |
| `drawRectUVs(x, y, w, h, uvs, alpha)` | 绘制带 UV 的矩形 |
| `drawCircle(x, y, radius)` | 绘制圆形 |
| `drawLine(x1, y1, x2, y2, width)` | 绘制线段 |
| `drawLines(points, width)` | 绘制连续线段 |
| `drawTriangles(vertices, ?indices, ?uvs)` | 绘制三角形 |
| `moveTo(x, y)` / `lineTo(x, y)` | 路径绘制 |
| `clear()` | 清除所有绘制命令 |

## Sprite — 轻量容器

`Sprite` 是最简单的容器类，用于将多个显示对象组合在一起，形成一个逻辑组。

```haxe
import hx.display.Sprite;

var sprite = new Sprite();
sprite.x = 100;
sprite.y = 50;

// 向 Sprite 中添加子对象
sprite.addChild(new Image("player"));
sprite.addChild(new Label("PlayerName"));

// Sprite 作为一个整体可以被移动、缩放、旋转
sprite.rotation = 0.5;
sprite.scaleX = 2.0;

this.addChild(sprite);
```

与 `Box` 的区别：`Sprite` 的尺寸由其子对象的内容决定，而 `Box` 的尺寸独立于子对象。

## 显示对象的通用操作

### 设置位置和大小

```haxe
obj.x = 100;
obj.y = 200;
obj.width = 300;
obj.height = 150;
```

### 设置缩放和旋转

```haxe
obj.scaleX = 1.5;    // 水平缩放
obj.scaleY = 1.5;    // 垂直缩放
obj.rotation = 0.5;  // 旋转（单位：弧度）
```

### 设置锚点

```haxe
obj.originX = 0.5;   // 锚点 X（0=左边，0.5=中心，1=右边）
obj.originY = 0.5;   // 锚点 Y（0=顶部，0.5=中心，1=底部）
```

### 透明度与可见性

```haxe
obj.alpha = 0.5;     // 半透明
obj.visible = false; // 隐藏
```

### 层级管理

```haxe
// 添加到指定层级
container.addChildAt(obj, 0);  // 插入到最底层

// 交换两个对象的层级
container.swapChildren(a, b);

// 获取子对象数量
trace(container.numChildren);
```
