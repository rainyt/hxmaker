# hxmaker
一个使用 Haxe 编写、支持 2D 与基础 3D、追求快速开发与渲染性能的游戏引擎。它可以自由实现游戏引擎渲染后端，从而实现渲染到其他引擎上。

# 状态
目前游戏引擎仍处于开发阶段，无法完全投入使用。

# 什么内容可以进行批处理
所有常用的显示对象（请参阅下面的列表），以及BlendMode.ADD混合模式也可以进行自动合批处理。

# 支持
| 功能 | 描述 | 状态 | 自动合批 |
--- | --- | --- | ---
| hx.display.DisplayObject | 所有显示对象的基类 | ✅ | / |
| hx.display.DisplayObjectContainer | 可容纳多个显示对象的容器类 | ✅ | / |
| hx.display.Image | 图片，用于渲染游戏2D画面，自动批处理实现，支持九宫格图渲染 | ✅ | ✅ |
| hx.display.Label | 文本，用于渲染文字 | ✅ | ✅ |
| hx.display.Button | 按钮，普通的按钮 | ✅ | ✅ |
| hx.display.BreadcrumbBar | [面包屑导航栏](docs/面包屑导航栏.md)，支持路径折叠、隐藏层级菜单与 XML，使用遮罩裁剪 | ✅ | ❌ |
| hx.display.Sprite | 容器，用于组合其他对象 | ✅ | ✅ |
| hx.display.Quad | 矩形显示对象 | ✅ | ✅ |
| hx.display.Graphics | 矢量图形 | ✅ | ✅ |
| hx.display.Spine | Spine动画 | ✅ | ✅ |
| hx.display.SpineSprite | Spine动画精灵，支持插槽绑定 | ✅ | ✅ |
| hx.display.Scene | 场景，用于管理对象 | ✅ | ✅ |
| hx.display.UILoadScene | 自动加载UI资源的场景，大多数用于界面打开使用 | ✅ | ✅ |
| hx.display.MovieClip | 动画剪辑，用于播放帧动画支持 | ✅ | ✅ |
| hx.display.FPS | 显示游戏的各种状态，如drawCall、顶点数量、CPU使用率等 | ✅ | ✅ |
| hx.display.Box | 虚拟盒子，该容器的width/height均不会影响到子容器 | ✅ | ✅ |
| hx.display.VBox | 竖向布局的虚拟盒子 | ✅ | ✅ |
| hx.display.HBox | 横向布局的虚拟盒子 | ✅ | ✅ |
| hx.display.Scroll | 滚动容器，用于实现滚动，需要遮罩因此需要消耗drawcall | ✅ | ❌ |
| hx.display.BitmapLabel | 位图纹理支持 | ✅ | ✅ |
| hx.display.ListView | 列表视图，用于实现列表，需要遮罩因此需要消耗drawcall | ✅ | ❌ |
| hx.display.Tree | 树形列表，类似VSCode资源管理器，支持虚拟列表，需要遮罩因此需要消耗drawcall | ✅ | ❌ |
| hx.display.CustomDisplayObject | 自定义显示对象，使用它进行渲染必然会产生1次绘制 | ✅ | ❌ |
| hx.display.Stage | 游戏引擎舞台 | ✅ | ✅ |
| hx.display.BoxContainer | 基于box布局的基础容器类 | ✅ | ✅ |
| hx.display.BaseScrollBar | 滚动条的基类 | ✅ | ✅ |
| hx.display.VScrollBar | 垂直滚动条 | ✅ | ✅ |
| hx.display.InputLabel | 输入文本框 | ✅ | ✅ |
| hx.display.ItemRenderer | 列表的基础项渲染器 | ✅ | ✅ |
| hx.display.TreeItem | Tree的树数据节点 | ✅ | ✅ |
| hx.display.TreeItemRenderer | Tree的默认行渲染器 | ✅ | ✅ |
| hx.display.DefaultItemRenderer | ListView的默认项渲染器 | ✅ | ✅ |
| hx.display.ImageLoader | 图片加载组件 | ✅ | ✅ |
| hx.display.Particle | 粒子系统 | ✅ | ✅ |
| hx.events.MouseEvent | 鼠标事件 | ✅ | / |
| hx.events.KeyboardEvent | 键盘事件 | ✅ | / |
| hx.assets.Assets | 资源加载器，支持图片、音频、精灵图、XML、JSON等常见资源格式加载 | ✅ | / |

# 3D 能力与新技术

hxmaker 通过 `hx.display.Scene3D` 将三维视口嵌入二维显示树：三维场景绘制到独立颜色／深度目标，再与文字、按钮及其他 UI 按二维顺序合成。三维节点、相机和模型统一使用 `hx.display3d`，渲染后端通过 `IScene3DRenderer` 接入。目前主要面向配套 [hxmaker-openfl](https://github.com/rainyt/hxmaker-openfl) 的 OpenGL/WebGL 路径。

**初次使用请阅读[《3D 引擎新手指南》](docs/3D引擎新手指南.md)**，包含完整入门工程、API、资源释放和当前边界。已有项目升级请参阅[3D 显示 API 包迁移说明](docs/3D显示API包迁移说明.md)：旧包没有转发兼容层。新增渲染能力需要同步更新核心库与后端源码。

| 技术方向 | 当前能力 |
| --- | --- |
| 场景与相机 | `Node3D` 层级变换、`MeshObject`、透视相机、环绕／跟随控制、多视口与二维 UI 混用 |
| 模型与资产 | `Assets.loadModel/getModel` 统一加载 GLB 2.0 子集与静态 FBX，使用 `ModelAsset` 创建独立实例；支持 ASCII 与二进制 FBX |
| 资产预处理 | 在中立资产构建阶段准备法线、局部包围盒、节点遍历顺序及刚性蒙皮分类，减少运行时重复准备 |
| 动画与挂点 | 独立播放状态、速度、循环、平滑过渡、动画事件与骨骼挂点；通用 CPU 蒙皮及单关节刚性路径 |
| 光照与阴影 | 环境光、方向光、点光和聚光，最多 4 灯参与 Lambert 漫反射；主方向光硬阴影、PCF4 柔化、MASK 轮廓投影与阴影缓存 |
| 粒子与动态特效 | CPU 粒子、广告牌、生命周期曲线、序列帧、弹道拖尾、双端刀光、UV 滚动、遮罩／噪声溶解及组合时间轴 |
| 深度与后处理 | 软粒子按场景深度淡化交界；基于普通 RGBA8 目标的视口 Bloom 泛光，默认关闭 |
| 交互与角色运动 | 射线拾取、鼠标／触摸适配、箱体与坡道代理、球／竖直胶囊查询与扫掠、滑动、重力、起跳、台阶和坡度限制 |
| 导航与流程 | 显式路点图、A*、路径跟随、动态通路重规划，以及 Procedure、加载取消、重试和退出释放示例 |
| 渲染优化与诊断 | 多纹理合批、逐网格视锥剔除、静态视口复用、按需 GPU 状态保护、HTML5 VAO 隔离、阶段 CPU 耗时与资源统计 |

## 示例与技术文档

| 主题 | 入口 |
| --- | --- |
| 基础场景与 2D/3D 叠放 | [基础示例](samples/3d/basic-3d/README.md) · [多视口示例](samples/3d/multi-scene-3d/README.md) · [框架说明](docs/基础3D框架使用说明.md) |
| 模型导入与资产构建 | [FBX / GLB 对照](samples/3d/fbx-model/README.md) · [GLB 动画模型](samples/3d/glb-model/README.md) · [中立资产设计](docs/3D模型中立资产与优化格式设计.md) · [FBX 支持范围](docs/FBX模型加载器设计与使用说明.md) |
| 动画与完整角色流程 | [贴图角色](samples/3d/textured-character/README.md) · [动画与挂点](docs/3D动画过渡与骨骼挂点使用说明.md) · [完整角色项目](samples/3d/interactive-character/README.md) |
| 多光源与阴影 | [多光源示例](samples/3d/multi-light-3d/README.md) · [新手指南光照章节](docs/3D引擎新手指南.md#10-光源与阴影) · [阴影配置与缓存](docs/基础3D光照与阴影使用说明.md) |
| 粒子、拖尾与泛光 | [特效示例](samples/3d/effects-3d/README.md) · [粒子与广告牌](docs/3D特效第一阶段使用说明.md) · [拖尾与动态材质](docs/3D特效第二阶段使用说明.md) · [软粒子与 Bloom](docs/3D特效第三阶段使用说明.md) |
| 相机与交互 | [相机示例](samples/3d/camera-interaction/README.md) · [交互说明](docs/3D相机控制与交互使用说明.md) |
| 碰撞、地形与导航 | [碰撞示例](samples/3d/collision-character/README.md) · [台阶与坡面](samples/3d/terrain-character/README.md) · [导航示例](samples/3d/navigation-character/README.md) · [导航说明](docs/3D导航使用说明.md) |
| 性能与生命周期 | [验收及基线示例](samples/3d/engine-acceptance/README.md) · [已有基线分析](samples/3d/engine-acceptance/Baselines/2026-10-16-最终分析.md) · [渲染优化记录](docs/基础3D渲染优化记录-20261016.md) |

全部三维工程见[3D 示例目录](samples/3d/README.md)。应用入口统一继承 `hx.core.HxmakerApplication`，先调用 `super()`，再通过 `init(GameStage, width, height)` 初始化；业务舞台继承 `hx.display.Stage`，在 `onStageInit()` 中先调用父类方法。场景、资源与更新逻辑放在舞台或场景中。

## 当前边界与验证状态

- 3D 仍在持续开发。基础场景、动画与交互、角色流程以及前两个特效阶段已有运行记录或用户通过反馈；新增多光源、PCF4／MASK 阴影与缓存、软粒子、Bloom，以及中立资产／静态 FBX 路径仍需各自完成验收，不能沿用早期结果。
- GLB 只支持明确子集；当前 FBX 不支持骨骼动画。尚未实现 `.hx3d` 发布文件编解码或导出工具，资产预处理不等于离线发布格式已交付。
- 当前没有 PBR、HDR、GPU 蒙皮／实例化、自动 LOD、自动 NavMesh 或通用刚体物理。Bloom 提取整个视口亮部；加法特效与泛光不会自动照亮周围模型。点光和聚光暂不投射阴影。
- 多个 `Scene3D` 各用独立深度目标，只按二维顺序合成，不共享深度。透明网格按对象排序，交叉透明面仍可能存在排序差异。
- 性能需结合目标设备、分辨率和实际资源评估。`scene.stats` 提供绘制、上传、阴影与后处理统计；开启 `scene.profilingEnabled` 后的耗时是 CPU 墙钟时间，不是 GPU 时间。已有 HTML5 基线不代表全部平台已验证。

# 布局支持

| 布局 | 名称 | 描述 |
--- | --- | --- |
| hx.layout.FlowLayout | 流式布局 | 可通过`hx.display.Box`虚拟盒子配合布局实现流式布局 |
| hx.layout.HorizontalLayout | 水平布局 | 水平布局 |
| hx.layout.VerticalLayout | 垂直布局 | 垂直布局 |
| hx.layout.AnchorLayout | 锚点布局 | 可根据`left`、`right`、`top`、`bottom`、`horizontalCenter`、`verticalCenter`属性来设置对象的位置 | 

# 混合模式支持
| 混合模式 | 支持状态 | 描述 |
| --- | --- | --- |
| Normal（正常） | ✅ | 显示对象出现在背景前面。 |
| Add（叠加） | ✅ | 将显示对象的颜色值添加到其背景的颜色中。 |
| Multiply（乘法） | ✅ | 将显示对象颜色的值和背景颜色相乘。 |
| Screen（屏幕） | ✅ | 将显示对象颜色的补色与背景颜色的补色相乘，从而产生漂白效果。 |
| Difference（差异） | ✅ | 比较显示对象的颜色值与背景，从较浅的值中减去较深的值。 |
| Subtract（减法） | ✅ | 从背景色的值中减去显示对象中组成颜色的值，应用0的下限。 |
| Subtract Fast（快速减法） | ✅ | 减去滤镜，对应`BlendMode.SUBTRACT_FAST`，更快但效果略有不同，背景色会固定为`vec4(0.5)`。 |
| Invert（反转） | ✅ | 翻转颜色。 |
| Darken（变暗） | ✅ | 选择显示对象和背景之间较暗的颜色。 |
| Lighten（变亮） | ✅ | 选择显示对象和背景之间较亮的颜色。 |
| Layer（图层） | ✅ | 强制为显示对象创建透明度组。 |
| Alpha（透明度） | ✅ | 将显示对象的每个像素的alpha值应用于背景。需要父显示对象的blendMode设置为`Layer`。 |
| Erase（擦除） | ✅ | 从背景中擦除显示对象的每个像素的alpha值。需要父显示对象的blendMode设置为`Layer`。 |
| Hardlight（强光） | ✅ | 根据显示对象的暗度调整每个像素的颜色。如果显示对象比50%灰色浅，则变亮；如果较暗，则变暗。 |
| Overlay（叠加） | ✅ | 根据背景的暗度调整每个像素的颜色。如果背景比50%灰色浅，则变亮；如果较暗，则变暗。 |

# 底层引擎支持
| 引擎 | 支持情况 | 多纹理渲染 |
| --- | --- | ---
| [OpenFL](https://github.com/rainyt/hxmaker-openfl) | ✅ | ✅ |

# 多纹理渲染
该游戏引擎可以多纹理渲染，减少大量的drawcall调用。

---

[English Version](README.md)
