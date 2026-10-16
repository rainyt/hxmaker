# hxmaker
一个追求快速开发、渲染性能的游戏引擎。它可以自由实现游戏引擎渲染后端，从而实现渲染到其他引擎上。

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

基础 3D 框架已加入首版代码，并通过 HTML5 基础示例验证；完整验收仍在进行，参阅[使用说明](docs/基础3D框架使用说明.md)、[示例](samples/basic-3d/README.md)和[验证记录](docs/基础3D框架验证记录.md)。

另有通过 hxmaker 资源加载系统读取 GLB 的[恐龙模型示例](samples/glb-model/README.md)，包含基础蒙皮与 Idle 动画代码。用户已确认模型能够显示，完整回归尚待执行。

新增[贴图动画角色示例](samples/textured-character/README.md)：通过 Assets 加载带三张内嵌贴图的原创机器人，提供待机／行走、多个独立实例及多纹理合批对比。采用纯 hxmaker API 的 Main → Stage → Scene 结构，包含[动画过渡与骨骼挂点](docs/3D动画过渡与骨骼挂点使用说明.md)，用户已反馈该阶段测试通过。

新增[相机与三维交互示例](samples/camera-interaction/README.md)：纯 hxmaker API 实现环绕、跟随、角色与附件选择、点击地面移动、二维 UI 遮挡及双视口输入隔离。本轮尚未编译或运行，接口见[使用说明](docs/3D相机控制与交互使用说明.md)。

新增[引擎验收与性能基线示例](samples/engine-acceptance/README.md)：提供固定负载、阶段耗时、资源生命周期、二维混用及上下文诊断，并可导出 JSON。用户已提供实测基线并确认画面正常，结果见[最终报告分析](samples/engine-acceptance/Baselines/2026-10-16-最终分析.md)；各项诊断的覆盖范围以报告记录为准。

基础方向光、Lambert 光照与单方向光硬阴影已加入代码，提供恐龙／方块对照场景，参阅[光照与阴影使用说明](docs/基础3D光照与阴影使用说明.md)。用户已反馈光照和阴影运行正常，完整回归和跨平台验证尚待执行。

下一阶段设计见[3D 引擎第二阶段设计方案](docs/3D引擎第二阶段设计方案.md)：依次补充动画过渡与骨骼挂点、相机与交互控制、可操作的角色场景，沿用现有多纹理合批和帧调度。首个里程碑已收到用户通过反馈，第二个里程碑等待用户测试。

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
