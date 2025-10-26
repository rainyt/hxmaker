# hxmaker
一个统一的Haxe游戏引擎，可以运行在任何游戏引擎之上。

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
| hx.display.Sprite | 容器，用于组合其他对象 | ✅ | ✅ |
| hx.display.Quad | 矩形显示对象 | ✅ | ✅ |
| hx.display.Graphics | 矢量图形 | ✅ | ✅ |
| hx.display.Spine | Spine动画 | ✅ | ✅ |
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
| hx.display.CustomDisplayObject | 自定义显示对象，使用它进行渲染必然会产生1次绘制 | ✅ | ❌ |
| hx.display.Stage | 游戏引擎舞台 | ✅ | ✅ |
| hx.display.BoxContainer | 基于box布局的基础容器类 | ✅ | ✅ |
| hx.display.BaseScrollBar | 滚动条的基类 | ✅ | ✅ |
| hx.display.VScrollBar | 垂直滚动条 | ✅ | ✅ |
| hx.display.InputLabel | 输入文本框 | ✅ | ✅ |
| hx.display.ItemRenderer | 列表的基础项渲染器 | ✅ | ✅ |
| hx.display.DefaultItemRenderer | ListView的默认项渲染器 | ✅ | ✅ |
| hx.display.ImageLoader | 图片加载组件 | ✅ | ✅ |
| hx.events.MouseEvent | 鼠标事件 | ✅ | / |
| hx.events.KeyboardEvent | 键盘事件 | ✅ | / |
| hx.assets.Assets | 资源加载器，支持图片、音频、精灵图、XML、JSON等常见资源格式加载 | ✅ | / |

# 布局支持
| 布局 | 名称 | 描述 |
--- | --- | ---
| hx.layout.FlowLayout | 流式布局 | 可通过`hx.display.Box`虚拟盒子配合布局实现流式布局 |
| hx.layout.HorizontalLayout | 水平布局 | 水平布局 |
| hx.layout.VerticalLayout | 垂直布局 | 垂直布局 |
| hx.layout.AnchorLayout | 锚点布局 | 可根据`left`、`right`、`top`、`bottom`、`horizontalCenter`、`verticalCenter`属性来设置对象的位置 | 


# 底层引擎支持
| 引擎 | 支持情况 | 多纹理渲染 |
| --- | --- | ---
| [OpenFL](https://github.com/rainyt/hxmaker-openfl) | ✅ | ✅ |

# 多纹理渲染
该游戏引擎可以多纹理渲染，减少大量的drawcall调用。

---

[English Version](README.md)