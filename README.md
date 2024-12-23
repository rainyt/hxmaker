# hxmaker
A unified game engine written in Haxe that can run on any game engine.

# 支持
| 功能 | 描述 | 状态 | 自动合批 |
--- | --- | --- | ---
| hx.display.Image | 图片，用于渲染游戏2D画面，自动批处理实现，支持九宫格图渲染 | ✅ | ✅ |
| hx.display.Label | 文本，用于渲染文字 | ✅ | ✅ |
| hx.display.Button | 按钮，普通的按钮 | ✅ | ✅ |
| hx.display.Sprite | 容器，用于组合其他对象 | ✅ | ✅ |
| hx.display.Quad | 矩形显示对象 | ✅ | ✅ |
| hx.display.Graphic | 矢量图形 | ✅ | ✅ |
| hx.display.Spine | Spine动画 | ✅ | ✅ |
| hx.display.Scene | 场景，用于管理对象 | ✅ | ✅ |
| hx.display.MovieClip | 动画剪辑，用于播放帧动画支持 | ✅ | ✅ |
| hx.display.FPS | 显示游戏的各种状态 | ✅ | ✅ |
| hx.display.CustomDisplayObject | 自定义显示对象，使用它进行渲染必然会产生1次绘制 | ✅ | ❌ |
| hx.events.MouseEvent | 鼠标事件 | ✅ | / |
| hx.events.KeyboardEvent | 键盘事件 | ✅ | / |
| hx.utils.Assets | 资源加载器 | ✅ | / |

# 底层引擎支持
| 引擎 | 支持情况 |
| --- | ---
| OpenFL | ✅ |

# 多纹理渲染
该游戏引擎可以多纹理渲染，减少大量的drawcall调用。