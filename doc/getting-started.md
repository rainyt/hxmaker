# 快速开始

本文档将引导你完成 Hxmaker 引擎的安装、项目创建和第一个程序的编写。

## 前置要求

- **Haxe** — 前往 [haxe.org](https://haxe.org) 下载并安装 Haxe 编译器（推荐 4.2+）
- **Visual Studio Code**（推荐）— 安装 Lime 插件以获得语法高亮和代码提示
- **Node.js** — HTML5 目标需要（用于 Lime/OpenFL 的 HTML5 编译）

## 第一步：安装引擎库

由于引擎库尚未发布到 Haxelib 官方仓库，需要通过 Git 方式安装：

```shell
# 安装核心引擎
haxelib git hxmaker https://github.com/rainyt/hxmaker.git

# 安装 OpenFL 渲染后端
haxelib git hxmaker-openfl https://github.com/rainyt/hxmaker-openfl.git
```

安装 OpenFL 及相关依赖：

```shell
# 参考 OpenFL 官方文档安装
# https://www.openfl.org/download/
haxelib install openfl
haxelib install lime
haxelib install actuate
```

### 可选：安装 Spine 骨骼动画支持

如果你需要使用 Spine 骨骼动画，需要安装 spine-haxe 运行时：

```shell
# 下载 spine-haxe 压缩包后安装
haxelib install spine-haxe-latest.zip

# 或通过 git 安装
haxelib git spine-haxe https://github.com/rainyt/spine-haxe.git
```

## 第二步：创建项目

### 方式一：使用 CLI 工具（推荐）

```shell
# 使用 hxmaker CLI 脚手架创建项目
haxelib run hxmaker create openfl MyGame
```

这会自动生成完整的项目结构，包括：
- `project.xml` — 项目配置文件（已配置好依赖）
- `Source/Main.hx` — 入口文件
- `Source/GameStage.hx` — 游戏主舞台
- `Assets/` — 资源目录

### 方式二：手动创建

如果你更喜欢手动配置，可以先使用 OpenFL 创建基础项目：

```shell
openfl create project MyGame
cd MyGame
```

然后在 `project.xml` 中添加 hxmaker 依赖：

```xml
<haxelib name="hxmaker-openfl" />
```

## 第三步：编写代码

### 入口文件 `Main.hx`

```haxe
package;

import hx.core.HxmakerApplication;

class Main extends HxmakerApplication {
    public function new() {
        super();

        // 初始化引擎
        // 参数：游戏主舞台类, 设计宽度, 设计高度
        this.init(GameMain, 1920, 1080);
    }
}
```

`HxmakerApplication` 是 hxmaker-openfl 提供的便捷基类，它封装了 OpenFL 的 `Application` 和引擎初始化流程。

### 游戏主舞台 `GameMain.hx`

```haxe
package;

import hx.display.Stage;
import hx.display.Image;
import hx.display.Label;

class GameMain extends Stage {

    override function onStageInit():Void {
        super.onStageInit();

        // 在这里编写你的游戏初始化代码

        // 创建一个文本标签
        var label = new Label();
        label.text = "Hello Hxmaker!";
        label.fontSize = 48;
        label.color = 0xFFFFFF;
        label.x = 100;
        label.y = 100;
        this.addChild(label);

        // 创建一张图片（需要先将图片放入 Assets 目录）
        // var image = new Image("myImage");
        // image.x = 200;
        // image.y = 200;
        // this.addChild(image);
    }

    override function onUpdate(dt:Float):Void {
        super.onUpdate(dt);
        // 每帧更新逻辑（dt 为帧间隔时间，单位秒）
    }
}
```

## 第四步：运行项目

使用 Lime 命令运行项目：

```shell
# 以 HTML5 目标运行（浏览器预览）
lime test html5

# 指定端口
lime test html5 --port=3000

# 编译项目（不运行）
lime build html5
```

打开浏览器访问 `http://localhost:3000`（或命令输出的地址），即可看到你的第一个 Hxmaker 程序。

## 第五步：配置 VSCode 开发环境

1. 安装 **Lime** 插件（提供 Haxe/OpenFL 项目支持）
2. 在 VSCode 中打开项目文件夹
3. 使用 `.hxml` 文件进行编译配置（项目模板中已包含 `vscode-openfl.hxml`）

推荐使用项目模板自带的 `vscode-openfl.hxml` 作为 VSCode 的构建任务配置。

## 下一步

- 了解 [引擎架构](architecture.md)，理解显示对象树和生命周期
- 学习 [基础显示对象](display-objects.md)，掌握 Image、Quad、Graphics 等常用组件
- 查看 [资源加载](assets.md)，了解如何加载图片、音频等资源
