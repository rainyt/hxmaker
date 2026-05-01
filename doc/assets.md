# 资源加载系统

Hxmaker 使用基于 **Future 模式**的异步资源加载系统。`Assets` 是核心的资源管理器，支持批量加载和队列管理。

## 核心概念

### Future 模式

`Future<T>` 是一个异步操作的抽象，当资源加载完成后会触发回调。所有资源加载器都继承自 Future。

```haxe
var future = new BitmapDataFuture("assets/image.png");

// 加载完成回调
future.onComplete = function(data) {
    trace("图片加载完成：" + data);
};

// 加载失败回调
future.onError = function(error) {
    trace("加载失败：" + error);
};

// 开始加载
future.start();
```

### Future 状态

| 状态 | 说明 |
|------|------|
| 等待中 | 尚未开始加载 |
| 加载中 | 正在异步加载 |
| 完成 | 加载成功，`value` 包含结果 |
| 错误 | 加载失败，`errorValue` 包含错误信息 |

常用属性：

| 属性 | 说明 |
|------|------|
| `isComplete` | 是否加载完成 |
| `isError` | 是否加载失败 |
| `value` | 加载结果 |
| `path` | 资源路径 |
| `progressValue` | 加载进度（0.0 ~ 1.0） |

## Assets — 资源管理器

`Assets` 是主要的资源管理入口，管理加载队列和已加载的资源。

### 基本用法

```haxe
import hx.assets.Assets;

// 创建资源管理器
var assets = new Assets();

// 添加各类资源
assets.loadBitmapData("texture", "assets/texture.png");
assets.loadAtlas("uiAtlas", "assets/ui.png", "assets/ui.xml");
assets.loadSound("bgm", "assets/bgm.mp3");
assets.loadJson("config", "assets/config.json");
assets.loadXml("level", "assets/level.xml");
assets.loadStyle("style", "assets/style.xml");
assets.loadZip("bundle", "assets/bundle.zip");

// 加载完成回调
assets.onComplete = function(loadedAssets:Assets) {
    // 获取加载后的资源
    var texture = loadedAssets.bitmapDatas.get("texture");
    var atlas = loadedAssets.atlases.get("uiAtlas");
    var sound = loadedAssets.sounds.get("bgm");
    var config = loadedAssets.objects.get("config");
    var xml = loadedAssets.xmls.get("level");
};

// 监听加载进度
assets.onProgress = function(progress:Float) {
    trace("加载进度：" + (progress * 100) + "%");
};

// 开始加载队列
assets.start();
```

### 支持的资源类型

| 方法 | 资源类型 | 说明 |
|------|---------|------|
| `loadBitmapData(id, path)` | BitmapData | 图片纹理 |
| `loadAtlas(id, png, xml)` | Atlas | 纹理图集（使用 XML 描述） |
| `loadFnt(id, png, fnt)` | FntAtlas | 位图字体 |
| `loadSound(id, path)` | Sound | 音频文件 |
| `loadJson(id, path)` | 动态对象 | JSON 数据 |
| `loadString(id, path)` | String | 纯文本文件 |
| `loadXml(id, path)` | Xml | XML 文件 |
| `loadUIAssets(id, path)` | UIAssets | UI 布局文件 |
| `loadStyle(id, path)` | StyleAssets | 样式文件 |
| `loadSpineAtlas(id, png, atlas)` | SpineTextureAtlas | Spine 骨骼图集 |
| `loadAssetsBundle(id, path)` | AssetsBundle | 资源包 |
| `loadZip(id, path)` | Zip | ZIP 压缩包 |

### 资源加载队列

Assets 使用串行加载队列，资源按添加顺序依次加载，避免并发下载导致的性能问题。每个资源最多重试 6 次。

### 全局静态资源

引擎通过 `UIManager` 维护全局的静态资源列表，可以在任何地方通过资源名称直接获取：

```haxe
import hx.ui.UIManager;

// 获取位图（直接用不含路径和扩展名的名称）
var bmp = UIManager.getBitmapData("myImage");

// 获取声音
var sound = UIManager.getSound("clickSound");

// 获取图集
var atlas = UIManager.getAtlas("uiAtlas");

// 获取文本
var text = UIManager.getString("config");

// 获取骨骼数据
var skeleton = UIManager.getSkeletonData("character");
```

## BitmapData — 位图数据

`BitmapData` 是 Hxmaker 中对纹理的封装，支持裁剪区域和九宫格数据。

```haxe
import hx.display.BitmapData;

// 从原始纹理创建
var bmp = BitmapData.formData(texture);

// 获取子区域（裁剪）
var subBmp = bmp.sub(0, 0, 100, 100);

// 绘制到位图
bmp.draw(otherBmp);

// 释放资源
bmp.dispose();
```

主要属性：

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | IBitmapData | 底层纹理对象 |
| `width` | Float | 实际宽度 |
| `height` | Float | 实际高度 |
| `rect` | Rectangle | 裁剪矩形 |
| `frameRect` | Rectangle | 帧矩形（用于图集中的子图定位） |
| `scale9Rect` | Rectangle | 九宫格缩放区域 |

## Atlas — 纹理图集

`Atlas` 用于加载由 XML 描述的纹理图集（多个小图拼接在一张大图中）。

```haxe
// 加载图集
var future = new TextureAtlasFuture("assets/uiAtlas", "assets/ui.png", "assets/ui.xml");
future.onComplete = function(atlas:Atlas) {
    // 获取特定的子图
    var btnTexture = atlas.getBitmapData("btn_ok");
    var btn = new Button();
    btn.skin = {up: btnTexture};
};

future.start();
```

图集 XML 示例格式（兼容多个图集工具）：

```xml
<TextureAtlas>
    <SubTexture name="btn_ok" x="0" y="0" width="100" height="40" />
    <SubTexture name="btn_cancel" x="100" y="0" width="100" height="40" />
</TextureAtlas>
```

## FntAtlas — 位图字体

`FntAtlas` 继承自 `Atlas`，用于加载位图字体：

```haxe
var bmpLabel = new BitmapLabel();
bmpLabel.data = "Hello World!";
bmpLabel.fontName = "myFont";  // 对应已加载的位图字体名称
```

## Sound — 音频

```haxe
var sound = new Sound(audioData);
sound.play();  // 播放音频
```

## Zip — ZIP 资源

```haxe
import hx.assets.ZipFuture;

var zipFuture = new ZipFuture("assets/bundle.zip");
zipFuture.onComplete = function(zip:Zip) {
    // 访问 ZIP 中的资源
};
zipFuture.start();
```

## 加载错误处理

```haxe
var future = new BitmapDataFuture("assets/missing.png");
future.onError = function(error) {
    trace("资源加载失败：" + error);
};

// 也可以使用通用的事件监听
future.addEventListener(FutureErrorEvent.LOAD_ERROR, function(event) {
    var e = cast(event, FutureErrorEvent);
    trace("错误码：" + e.errorCode + " 路径：" + e.path);
    trace("错误详情：" + e.error);
});
```

## 自定义 Future

你可以继承 `Future<T>` 创建自定义资源加载器：

```haxe
class MyCustomFuture extends Future<MyData, MyConfig> {
    override function start() {
        // 实现加载逻辑
        // 加载完成后调用 complete(value)
        this.complete(myData);
    }
}
```
