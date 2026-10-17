# 示例目录

示例按显示内容分为 [二维示例](2d/README.md) 和 [三维示例](3d/README.md)。包含三维场景及二维 UI 的混合示例归入 `3d`。

所有可运行示例的 `Source/Main.hx` 继承 `hx.core.HxmakerApplication`，构造函数先调用 `super()`，再调用 `init(GameStage, width, height)` 或 `init(Game, width, height)`。业务舞台继承 `hx.display.Stage`，在 `onStageInit()` 中先调用父类实现，再创建场景、资源与界面。

三维显示节点统一使用 `hx.display3d`；`Scene3D` 作为二维容器中的三维视口，仍使用 `hx.display.Scene3D`。几何、材质、灯光和控制器保留各自原包。

进入具体示例目录后，按其 README 和 `project.xml` 配置运行。迁移后的示例路径为 `samples/2d/<示例名>` 或 `samples/3d/<示例名>`。

2026-10-17：完成目录分类与入口整理，仅进行源码和路径审阅，未执行编译、测试或浏览器验收。各示例中的历史验证记录不代表本次迁移已通过验证。
