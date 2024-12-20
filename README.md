# hxmaker
A unified game engine written in Haxe that can run on any game engine.

# 支持
| 功能 | 描述 | 状态 | 自动合批 |
--- | --- | --- | ---
| hx.displays.Image | 图片，用于渲染游戏2D画面，自动批处理实现 | ✅ | ✅ |
| hx.displays.Label | 文本，用于渲染文字 | ✅ | ✅ |
| hx.displays.Button | 按钮，普通的按钮 | ✅ | ✅ |
| hx.displays.DisplayObjectContainer | 容器，用于组合其他对象 | ✅ | ✅ |
| hx.displays.Quad | 矩形显示对象 | ✅ | ✅ |
| hx.displays.Graphic | 矢量图形 | ✅ | ✅ |
| hx.displays.Spine | Spine动画 | ✅ | ✅ |
| hx.displays.Scene | 场景，用于管理对象 | ✅ | ✅ |
| hx.events.MouseEvent | 鼠标事件 | ✅ | / |
| hx.events.KeyboardEvent | 键盘事件 | ✅ | / |

# 底层引擎支持
| 引擎 | 支持情况 |
| --- | ---
| OpenFL | ✅ |

# 多纹理渲染
该游戏引擎可以多纹理渲染，减少大量的drawcall调用。