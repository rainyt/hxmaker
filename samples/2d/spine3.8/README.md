# Spine 3.8 示例

本示例固定使用 `spine-hx 3.8.2`，展示 hxmaker 的 Spine 3.8 编译适配。入口 `Main` 继承 `hx.core.HxmakerApplication`，通过 `init(GameStage, 1100, 820)` 初始化业务舞台，资源和界面逻辑均位于 `GameStage`。

## 依赖与启动

安装 `spine-hx 3.8.2`，并让本机的 `hxmaker` 和 `hxmaker-openfl` 指向开发目录。示例的 `project.xml` 已指定本仓库源码路径和 Spine 库版本，不依赖全局选中的其他 `spine-hx` 版本。

```bash
haxelib install spine-hx 3.8.2
cd samples/2d/spine3.8
haxelib run lime test html5
```

项目只引入 `spine-hx`，不要再同时添加 `spine-haxe`。引擎根据库提供的 `spine_hx`、`spine_haxe` 条件宏自动选择类型和渲染路径，无须配置额外的版本开关。编译宏会拒绝双库同时引入及明确不受支持的版本。

## 操作说明

| 操作 | 用途 |
| --- | --- |
| 待机、行走、奔跑 | 切换 Spineboy 动画，行走和奔跑可观察自定义事件 |
| 跳跃 | 播放单次动画，观察完成事件；结束后可再次点击播放 |
| 传送门 | 播放包含裁剪和透明度变化的动画 |
| 停止 | 清空动画轨道并保留当前姿势 |
| 切换皮肤 | 在 `goblin`、`goblingirl` 之间切换 |
| 显示 / 隐藏挂点 | 黄色方块绑定到 Goblins 的 `head` 插槽 |
| 切换 30 / 60 FPS | 同时调整两个骨骼对象的刷新频率 |
| 循环开 / 关 | 调整左侧当前动画的循环方式 |
| 重置 | 恢复行走、初始皮肤、显示挂点与 60 FPS |
| 清空日志 | 清除底部事件记录 |

左侧使用 `hx.display.Spine`，右侧使用 `hx.display.SpineSprite`。事件通过现有 `SpineEvent` 及 `Event.COMPLETE` 订阅，原生对象分别位于 `event`、`trackEntry` 字段。

## 资源来源

资源来自 [Spine 官方仓库的 3.8 分支](https://github.com/EsotericSoftware/spine-runtimes/tree/3.8/examples)，固定提交为 `8b4844bd4b193ba9e54487ed397a777993cbad56`，原始 JSON、atlas 和 PNG 未修改。

| 文件 | 官方来源 |
| --- | --- |
| `Assets/spineboy-pro.json`、`spineboy.atlas`、`spineboy.png` | [Spineboy 导出资源](https://github.com/EsotericSoftware/spine-runtimes/tree/8b4844bd4b193ba9e54487ed397a777993cbad56/examples/spineboy/export) |
| `Assets/goblins-pro.json`、`goblins.atlas`、`goblins.png` | [Goblins 导出资源](https://github.com/EsotericSoftware/spine-runtimes/tree/8b4844bd4b193ba9e54487ed397a777993cbad56/examples/goblins/export) |

原始许可保存在 `Assets/SPINE-LICENSE`，来源提交保存在 `Assets/SOURCE_COMMIT`，文件摘要保存在 `Assets/SHA256SUMS`。资源沿用上游许可。

## 验证状态

2026-11-01 已完成资源静态校验：两组 JSON 均为 Spine `3.8.55`；PNG 签名、数据块校验和与压缩数据有效；图片尺寸分别为 `1024×256`、`1024×128`，与 atlas 一致；矩形及网格附件引用均能对应图集条目。Spineboy 包含矩形、网格、裁剪及边界框附件，Goblins 包含网格和关联网格。

2026-11-08 已通过 `vscode-openfl-spine3-8.hxml` 编译验证（spine-hx 3.8.2），并使用本目录 `Export/html5` 导出包完成浏览器运行验收：双角色渲染、传送门裁剪、皮肤切换、动画事件与头部挂点均正常。本机 lime 为 x86_64 构建，无法在 arm64 上重新导出。

## 当前边界

本示例通过 `Assets.loadSpineAtlas` 加载单页图集，通过 `loadString` 与 `getSkeletonData` 加载 JSON。3.8 二进制加载、多页图集、双色着色以及 Multiply/Screen 混合模式不属于本次新增支持范围。
