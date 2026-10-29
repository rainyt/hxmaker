# Unity 后端接入

本分支为 `unity`，从 `2d-performance` 创建。独立 Haxelib 位于 `/Users/rainy/Documents/Github/hxmaker-unity`，具体安装和使用方式参见该仓库 README。

## 核心改动

- `hxmaker_unity` 选择后端提供的资源 Future、存储和文本输入适配。
- 显示对象拒绝首版不支持的滤镜、自定义 Shader 和复杂混合模式；普通文字描边使用 Unity 文本后端。
- Future、模型图片解码后续任务、Tree／FinderView／ListView 延迟刷新交由宿主主线程驱动。
- 资源引用计数接入 Unity 请求缓存；普通文本尺寸由 Unity 字库提供。
- 系统信息与剪贴板交由 Unity 适配；Actuate 手动时钟由后端配置。
- 所有新分支均受 `hxmaker_unity` 保护，OpenFL 路径保留原有实现。

## 首版边界

保留常用二维显示、布局、组件、多纹理与多摄像机宿主接入。hxmaker 三维渲染、InputLabel 编辑、通用滤镜、复杂混合、原生显示对象、GLSL 注入及位图绘制暂不实现。Unity 原生三维和目标纹理可以与二维后端共存。

多个镜头当前显示同一业务画面，不代表已经实现 hxmaker Scene3D 的多相机接口。

## 验证状态

已按用户要求完成 Haxe C# 生成、Unity 2022.3.62f3c1 临时示例导入编译和场景生成。运行画面、资源生命周期、多镜头交互、URP 与 IL2CPP 仍待验证；当前由用户打开示例手动测试。

## Unity 项目脚手架

```sh
haxelib run hxmaker create unity MyGame
cd MyGame
python3 build.py
```

已配置 `hxmaker` 包装命令时，可使用 `hxmaker create unity MyGame` 和 `hxmaker build unity`。模板包含 `Source`、`Assets`、`Packages`、`ProjectSettings` 和构建脚本，后端使用已安装的 `hxmaker-unity`。

仓库内示例位于 `/Users/rainy/Documents/Github/hxmaker-unity/samples/basic/UnityProject`；用 Unity Hub 添加该目录，打开 `Assets/Scenes/Main.unity` 后进入播放模式。
