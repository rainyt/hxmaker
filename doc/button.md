# 按钮组件

`Button` 是 Hxmaker 内置的按钮组件，支持图片皮肤、文本标签、按下动画和点击音效。

## 基本用法

```haxe
import hx.display.Button;

var button = new Button();
button.text = "开始游戏";
button.x = 100;
button.y = 200;
button.width = 200;
button.height = 60;

// 监听点击事件
button.addEventListener(MouseEvent.CLICK, function(event) {
    trace("按钮被点击！");
});

this.addChild(button);
```

## 设置按钮皮肤

按钮使用 `ButtonSkin` 来定义外观，至少需要提供 `up` 状态的图片：

```haxe
var button = new Button();

// 通过 BitmapData 设置皮肤
var skin:ButtonSkin = {};
skin.up = UIManager.getBitmapData("btn_normal");
button.skin = skin;

button.text = "确定";
button.width = 200;
button.height = 60;
this.addChild(button);
```

`ButtonSkin` 的定义：

```haxe
typedef ButtonSkin = {
    ?up:BitmapData,    // 正常状态的纹理
}
```

## 按钮文本

```haxe
var button = new Button();
button.text = "提交";
button.fontSize = 24;
button.color = 0xFFFFFF;

// 自定义文本格式
button.textFormat = new TextFormat();
button.textFormat.bold = true;

// 调整文本偏移
button.labelOffsetPoint = new Point(0, -2);

this.addChild(button);
```

## 九宫格缩放按钮

按钮支持九宫格缩放，适合背景图需要保持边框不变形的情况：

```haxe
var button = new Button();
button.text = "确认";

// 设置九宫格区域（与 Image 的 scale9Grid 用法一致）
button.scale9Grid = new Rectangle(15, 15, 10, 10);

button.width = 300;
button.height = 80;
this.addChild(button);
```

## 按下动画

按钮内置了按下缩放动画，点击时按钮会缩小到 94%：

```haxe
// 按下缩放动画是默认行为，无需额外配置
// 它通过 BoxContainer 内部的 Box 实现缩放效果
```

## 设置点击音效

可以为所有按钮设置全局点击音效：

```haxe
// 设置全局点击音效（影响所有 Button 实例）
Button.clickSoundEffectId = "click_sound";
```

> 需要在 `SoundManager` 中注册对应的音效资源。

## 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `skin` | ButtonSkin | 按钮皮肤 |
| `text` | String | 按钮文本 |
| `fontSize` | Int | 文本字号 |
| `color` | UInt | 文本颜色 |
| `textFormat` | TextFormat | 文本格式对象 |
| `labelOffsetPoint` | Point | 文本偏移量 |
| `scale9Grid` | Rectangle | 九宫格缩放区域 |
| `width` | Float | 按钮宽度 |
| `height` | Float | 按钮高度 |
