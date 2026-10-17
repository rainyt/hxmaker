# 恐龙双动画展示

使用 hxmaker 3D 与 hxmaker-openfl 加载恐龙 GLB。默认从待机开始，每 8 秒切换一次待机／奔跑，动作之间使用 0.25 秒过渡。

## 运行

在此目录打开终端，使用本机已有的 Haxe、Haxelib、Lime 工具链：

```sh
cd /Users/rainy/Downloads/demo-test
haxelib run lime test html5
```

如果你的现有工程需要 x86_64 环境，可沿用：

```sh
arch -x86_64 haxelib run lime test html5
```

`project.xml` 使用本机已登记的 `hxmaker`、`hxmaker-openfl` 开发库，不修改库注册路径。其余依赖与 hxmaker 自带的 3D 示例一致。

本例未执行编译、启动或测试，由你运行检查。

## 操作

- **待机／奔跑**：手动选择动作；手动选择后关闭自动切换。
- **自动切换**：恢复每 8 秒轮播；暂停时轮播计时也暂停。
- **暂停／继续**，或者**空格**：控制当前动画。
- **速度**：依次切换 0.5、1、1.5 倍速。
- **拖动／单指拖动**：旋转镜头，开始拖动后停止自动环绕。
- **滚轮**：缩放，带距离和俯仰限制以及平滑阻尼。
- **镜头环绕**：开关缓慢自动环绕；暂停动画时仍可观察模型。
- **重置镜头**，或者 **R**：恢复初始取景。
- **1／2**：分别选择待机／奔跑。键盘操作前先点击画面。
- **重新加载**：释放旧实例与资源后重新加载 GLB。

## 目录

```text
demo-test/
├── project.xml
├── README.md
├── Assets/
│   └── dinosaur.glb
└── Source/
    ├── Main.hx
    ├── Game.hx
    ├── DemoButton.hx
    └── DinosaurScene.hx
```

`Main` 初始化应用，`Game` 创建场景。`DinosaurScene` 负责资源加载、动作过渡、逐帧推进、镜头、灯光与资源释放。

## 模型资源说明

用户提供的 `/Users/rainy/Downloads/demo1.glb` 实际只包含奔跑动画，并附带重复角色、原始立方体和展示地面。

为了展示两个动作，`Assets/dinosaur.glb` 从本次对话已生成的 `低多边形霸王龙_LOD0_待机与奔跑.blend` 补导出，只选择角色和骨骼，包含 `Idle`（待机）与 `Run`（奔跑）。原始 `demo1.glb` 保持原样。

导出采用 glTF 标准 Y 轴向上，动作时间从零开始，保留骨骼与纯色材质，不带展示场景；地面、展示台、方向光和环绕相机在示例中创建。

如需替换资源，修改 `DinosaurScene.MODEL_URL` 或替换 `Assets/dinosaur.glb`。代码按名称识别 `Idle`／`待机`、`Run`／`奔跑`，也会显示资源缺少第二个动作时的提示。
