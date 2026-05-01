# 流程系统

Procedure（流程）系统是 Hxmaker 提供的与渲染/显示系统**完全解耦**的游戏流程管理功能，灵感来源于 Unity GameFramework 的 Procedure 机制。

## 为什么使用流程系统？

在复杂游戏中，游戏状态往往与 UI 显示高度耦合，导致代码难以维护。流程系统将**游戏状态管理**从**显示层**中分离出来，让你可以：

- 独立管理游戏的状态切换（如：启动 → 更新资源 → 登录 → 菜单 → 游戏中）
- 每个流程的代码独立、职责清晰
- 不依赖任何显示对象，可被纯逻辑层使用
- 方便进行单元测试

## IProcedure — 流程接口

每个流程都需要实现 `IProcedure` 接口，有五个生命周期方法：

```haxe
import hx.procedure.IProcedure;

class MyProcedure implements IProcedure {
    /**
     * 流程初始化（注册时调用一次）
     */
    public function onInit():Void {
        trace("流程初始化");
    }

    /**
     * 进入流程（每次切换到该流程时调用）
     */
    public function onEnter():Void {
        trace("进入流程");
    }

    /**
     * 每帧更新
     * @param dt 帧间隔时间（秒）
     */
    public function onUpdate(dt:Float):Void {
        // 流程的每帧逻辑
    }

    /**
     * 离开流程（切换到其他流程时调用）
     */
    public function onLeave():Void {
        trace("离开流程");
    }

    /**
     * 销毁流程（移除或管理器销毁时调用）
     */
    public function onDestroy():Void {
        trace("流程销毁");
    }
}
```

## ProcedureBase — 流程基类

如果你不需要实现所有方法，可以继承 `ProcedureBase`，它提供了所有生命周期方法的空实现：

```haxe
import hx.procedure.ProcedureBase;

class GameProcedure extends ProcedureBase {
    override function onEnter():Void {
        // 只需要在进入时初始化
        trace("游戏流程开始");
    }

    override function onUpdate(dt:Float):Void {
        // 游戏主循环逻辑
    }
}
```

## ProcedureManager — 流程管理器

`ProcedureManager` 管理所有注册的流程，负责流程的注册和切换。

### 使用全局单例

```haxe
import hx.procedure.ProcedureManager;

// 获取全局单例
var manager = ProcedureManager.instance;

// 注册流程
manager.registerProcedure(new LaunchProcedure());
manager.registerProcedure(new MenuProcedure());
manager.registerProcedure(new GameProcedure());

// 切换到指定流程
manager.switchProcedure(LaunchProcedure);
```

### 使用独立实例

你也可以创建独立的 `ProcedureManager` 实例，不依赖全局单例：

```haxe
var manager = new ProcedureManager();
manager.registerProcedure(new MyProcedure());
manager.switchProcedure(MyProcedure);
```

### 驱动更新

在游戏主循环中调用 `update()` 来驱动当前活动流程：

```haxe
class GameMain extends Stage {
    override function onUpdate(dt:Float):Void {
        super.onUpdate(dt);

        // 驱动流程系统更新
        ProcedureManager.instance.update(dt);
    }
}
```

### 获取流程实例

```haxe
// 获取已注册的流程
var menuProc = ProcedureManager.instance.getProcedure(MenuProcedure);

// 移除流程
ProcedureManager.instance.removeProcedure(LaunchProcedure);
```

## 完整示例

以下是一个完整的流程系统使用示例，模拟游戏的启动、资源更新和主菜单流程：

```haxe
import hx.procedure.ProcedureBase;
import hx.procedure.ProcedureManager;

// ----- 启动流程 -----
class LaunchProcedure extends ProcedureBase {
    override function onEnter():Void {
        trace("游戏启动...");
        // 模拟启动后立即跳转到资源更新
        ProcedureManager.instance.switchProcedure(UpdateProcedure);
    }
}

// ----- 资源更新流程 -----
class UpdateProcedure extends ProcedureBase {
    private var elapsed:Float = 0;

    override function onEnter():Void {
        trace("检查资源更新...");
        elapsed = 0;
    }

    override function onUpdate(dt:Float):Void {
        elapsed += dt;
        if (elapsed > 1.5) {
            // 资源更新完成后切换到菜单
            trace("资源更新完成");
            ProcedureManager.instance.switchProcedure(MenuProcedure);
        }
    }
}

// ----- 菜单流程 -----
class MenuProcedure extends ProcedureBase {
    override function onEnter():Void {
        trace("进入主菜单");
        // 这里可以通知显示层显示菜单界面
        // 比如：发送事件或调用 SceneManager
    }

    override function onUpdate(dt:Float):Void {
        // 等待用户输入
    }

    override function onLeave():Void {
        trace("离开主菜单");
    }
}

// ----- 初始化 -----
class Main {
    static function main() {
        var manager = ProcedureManager.instance;

        // 注册所有流程
        manager.registerProcedure(new LaunchProcedure());
        manager.registerProcedure(new UpdateProcedure());
        manager.registerProcedure(new MenuProcedure());

        // 启动第一个流程
        manager.switchProcedure(LaunchProcedure);
    }
}
```

## 生命周期流转图

```
registerProcedure()
    └─ onInit()（调用一次）

switchProcedure(NewProc)
    └─ OldProc.onLeave()
        └─ NewProc.onEnter()（如果首次切换，会先调用 onInit）
            └─ NewProc.onUpdate(dt)（每帧）

switchProcedure(AnotherProc) 或 removeProcedure()
    └─ CurrentProc.onLeave()
        └─ CurrentProc.onDestroy()
```

## 与显示系统解耦

流程系统的设计使其完全不依赖任何显示对象。如果你需要在流程中操作 UI，推荐通过以下方式：

```haxe
class GameProcedure extends ProcedureBase {
    override function onEnter():Void {
        // 方式1：通过 SceneManager 切换场景
        SceneManager.getInstance().replaceScene(new GameScene());
    }

    override function onLeave():Void {
        // 流程离开时清理
    }
}
```

或者通过事件系统解耦：

```haxe
class MenuProcedure extends ProcedureBase {
    override function onEnter():Void {
        // 发送自定义事件，让显示层监听处理
        Hxmaker.topView.dispatchEvent(new Event("show_menu"));
    }
}
```

## ProcedureManager 主要方法

| 方法 | 说明 |
|------|------|
| `registerProcedure(proc)` | 注册一个流程（以类为键，同类型只能注册一个） |
| `switchProcedure(cls)` | 切换到指定类型的流程（未注册会自动创建实例） |
| `getProcedure(cls)` | 获取指定类型的流程实例 |
| `removeProcedure(cls)` | 移除并销毁指定流程 |
| `update(dt)` | 驱动当前流程的 onUpdate |
| `destroy()` | 销毁管理器及所有流程 |
