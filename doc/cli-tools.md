# CLI 工具

Hxmaker 提供了命令行脚手架工具 `hxmaker`，帮助你快速创建和管理项目。

## 安装

CLI 工具随引擎库自动安装，无需额外配置：

```shell
haxelib git hxmaker https://github.com/rainyt/hxmaker.git
```

安装后即可使用：

```shell
haxelib run hxmaker
```

## 创建新项目

使用 `create` 命令创建新项目：

```shell
haxelib run hxmaker create openfl MyGame
```

命令格式：

```
haxelib run hxmaker create <engine> <project_name> [output_path]
```

| 参数 | 说明 |
|------|------|
| `<engine>` | 引擎后端（目前支持 `openfl`） |
| `<project_name>` | 项目名称 |
| `[output_path]` | 输出路径（可选，默认为当前目录） |

### 创建后的项目结构

```
MyGame/
├── Source/
│   ├── Main.hx           # 入口文件（继承 HxmakerApplication）
│   └── GameStage.hx      # 游戏主舞台（继承 Stage）
├── Assets/               # 资源文件夹
└── project.xml           # OpenFL 项目配置文件
```

### 生成的文件说明

**Main.hx** — 应用入口，负责初始化引擎：

```haxe
package;

import hx.core.HxmakerApplication;

class Main extends HxmakerApplication {
    public function new() {
        super();
        this.init(GameStage, 1920, 1080);
    }
}
```

**GameStage.hx** — 游戏主舞台，你的游戏逻辑从此开始：

```haxe
package;

import hx.display.Stage;

class GameStage extends Stage {
    override function onStageInit():Void {
        super.onStageInit();
        // 你的游戏代码写在这里
    }
}
```

## 构建项目

使用 `build` 命令编译项目：

```shell
haxelib run hxmaker build openfl html5 ./MyGame
```

命令格式：

```
haxelib run hxmaker build <engine> <target> <project_path>
```

| 参数 | 说明 |
|------|------|
| `<engine>` | 引擎后端（目前支持 `openfl`） |
| `<target>` | 编译目标（如 `html5`, `windows`, `mac` 等） |
| `<project_path>` | 项目路径 |

## 手动构建

你也可以直接使用 Lime 命令手动构建项目：

```shell
cd MyGame

# 测试运行（编译并启动）
lime test html5

# 编译（不运行）
lime build html5

# 指定端口
lime test html5 --port=3000

# 编译其他平台
lime test windows
lime test mac
lime test android
lime test ios
```

## 自定义模板

CLI 工具使用 Haxe 模板引擎，模板文件位于 `tools/templates/openfl/` 目录中。

你可以修改这些模板文件来自定义项目脚手架的行为。模板文件以 `.hx` 和 `.xml` 结尾的文件会经过 Haxe 模板引擎处理，支持 `::variable::` 占位符。

模板中的可用变量：

| 变量 | 说明 |
|------|------|
| `::project_name::` | 项目名称 |
| `::project_width::` | 项目宽度（默认 640） |
| `::project_height::` | 项目高度（默认 960） |

## 添加 hxmaker 到现有 OpenFL 项目

如果你已经有一个 OpenFL 项目，可以手动添加 hxmaker 依赖。在 `project.xml` 中添加：

```xml
<haxelib name="hxmaker-openfl" />
```

然后修改 `Source/Main.hx`，让它继承 `HxmakerApplication` 而不是 `Application`：

```haxe
import hx.core.HxmakerApplication;

class Main extends HxmakerApplication {
    public function new() {
        super();
        this.init(GameStage, 1920, 1080);
    }
}
```
