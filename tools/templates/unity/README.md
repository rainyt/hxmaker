# ::project_name::

这是使用 hxmaker-unity 的 Unity 示例工程。Haxe 启动类继承 `HxmakerApplication`，业务界面位于 `Source/GameStage.hx`。

先运行 `python3 build.py`，再用 Unity 2022.3 或兼容版本打开当前目录。在菜单“Tools → Hxmaker → 创建默认场景”生成 `Assets/Scenes/Main.unity`，打开场景并进入播放模式。

也可以使用：

```sh
hxmaker build unity
```

若系统中没有 `hxmaker` 包装命令，请使用等价的 `haxelib run hxmaker build unity`。

首次生成场景和检查导入可执行：

```sh
python3 build.py --unity-editor /你的/Unity可执行文件 --create-scene --check
```

默认场景包含 Unity 原生方块、主摄像机和预览摄像机；两个镜头显示同一份 hxmaker 界面。需要发布中文游戏时，请在宿主上配置可分发的动态字体资源。

`Assets/HxmakerGenerated` 和 `build` 为生成目录，请修改 Haxe 源码并重新构建。`Packages/manifest.json` 使用创建工程时本机安装的 hxmaker-unity 路径，换机器后需要更新该本地包路径。
