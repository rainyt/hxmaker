# 场景管理

场景（Scene）是管理游戏不同界面和关卡的核心组件。Hxmaker 的 `SceneManager` 提供了场景的创建、切换、释放和返回功能。

## Scene — 场景

`Scene` 继承自 `Box`，是一个全屏场景容器。它的宽度和高度自动与舞台大小保持一致。

### 创建场景

```haxe
import hx.display.Scene;

class MenuScene extends Scene {
    override function onStageInit():Void {
        super.onStageInit();

        // 创建菜单内容
        var title = new Label("我的游戏");
        title.fontSize = 48;
        title.x = 200;
        title.y = 100;
        this.addChild(title);

        var startBtn = new Button();
        startBtn.text = "开始游戏";
        startBtn.x = 200;
        startBtn.y = 300;
        startBtn.addEventListener(MouseEvent.CLICK, function(e) {
            // 切换到游戏场景
            this.replaceScene(new GameScene());
        });
        this.addChild(startBtn);
    }
}
```

### 场景背景

Scene 自带一个全尺寸的透明矩形背景，你可以通过 `sceneBackground` 设置背景色：

```haxe
class MenuScene extends Scene {
    override function onStageInit():Void {
        super.onStageInit();
        // 设置场景背景色
        this.sceneBackground.data = 0x333333;
        this.sceneBackground.alpha = 1.0;
    }
}
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `sceneBackground` | Quad | 场景背景（Quad 对象） |
| `onReleaseEvent` | FunctionListener | 场景被释放时的回调 |

## SceneManager — 场景管理器

`SceneManager` 是单例，维护一个场景栈，管理场景的显示、切换和释放。

### 切换场景

```haxe
import hx.utils.SceneManager;

// 显示一个新场景（保留旧场景在栈中）
SceneManager.getInstance().showScene(new MenuScene());

// 替换当前场景（移除旧场景）
SceneManager.getInstance().replaceScene(new GameScene());

// 替换并释放旧场景
SceneManager.getInstance().replaceScene(new GameScene(), true);
```

`showScene` 会添加到栈顶但不移除旧场景；`replaceScene` 会移除旧场景并替换。

### 返回上一个场景

```haxe
// 回到上一个场景（不释放当前场景）
SceneManager.getInstance().backScene();

// 回到上一个场景并释放当前场景
SceneManager.getInstance().backScene(true);
```

### 释放场景

```haxe
// 释放指定场景
SceneManager.getInstance().releaseScene(myScene);
```

场景内部也可以调用自身方法进行导航：

```haxe
// 在场景内部获取管理器
this.releaseScene();                      // 释放自己
this.replaceScene(new OtherScene());      // 替换为其他场景
```

### 场景切换动画

通过 `ISceneExchangeEffect` 接口，你可以自定义场景切换动画：

```haxe
// 设置默认的切换效果
SceneManager.getInstance().defaultSceneExchangeEffect = MyTransitionEffect;
```

切换效果类需要实现 `ISceneExchangeEffect` 接口：

```haxe
interface ISceneExchangeEffect {
    function onReadyExchange(newScene:Scene, callback:Void->Void):Void;
}
```

### 场景生命周期

场景遵循显示对象的标准生命周期：

```
创建 → onInit() → onAddToStage() → onStageInit() → onUpdate(dt) → ...

然后切出时：
releaseScene() → onRemoveToStage() → dispose() → onReleaseEvent 回调
```

### 完整示例

```haxe
import hx.display.Scene;
import hx.utils.SceneManager;

// 加载场景
class LoadingScene extends Scene {
    override function onStageInit():Void {
        super.onStageInit();
        this.sceneBackground.data = 0x000000;
        this.sceneBackground.alpha = 1.0;

        var loadLabel = new Label("加载中...");
        loadLabel.fontSize = 32;
        loadLabel.x = 300;
        loadLabel.y = 500;
        this.addChild(loadLabel);

        // 模拟加载
        Timer.delay(function() {
            SceneManager.getInstance().replaceScene(new MenuScene());
        }, 2000);
    }
}

// 菜单场景
class MenuScene extends Scene {
    override function onStageInit():Void {
        super.onStageInit();
        this.sceneBackground.data = 0x222244;

        var label = new Label("主菜单");
        label.fontSize = 48;
        label.x = 400;
        label.y = 200;
        this.addChild(label);

        var playBtn = new Button();
        playBtn.text = "开始游戏";
        playBtn.x = 400;
        playBtn.y = 350;
        playBtn.addEventListener(MouseEvent.CLICK, function(e) {
            SceneManager.getInstance().replaceScene(new GameScene());
        });
        this.addChild(playBtn);
    }
}

// 游戏场景
class GameScene extends Scene {
    override function onStageInit():Void {
        super.onStageInit();
        this.sceneBackground.data = 0x003300;

        var label = new Label("游戏中...");
        label.fontSize = 32;
        label.color = 0xFFFFFF;
        label.x = 400;
        label.y = 300;
        this.addChild(label);

        // 返回菜单按钮
        var backBtn = new Button();
        backBtn.text = "返回";
        backBtn.x = 50;
        backBtn.y = 50;
        backBtn.addEventListener(MouseEvent.CLICK, function(e) {
            SceneManager.getInstance().backScene(true);
        });
        this.addChild(backBtn);
    }

    override function onUpdate(dt:Float):Void {
        super.onUpdate(dt);
        // 游戏主循环逻辑
    }
}
```
