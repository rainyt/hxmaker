# hxmaker
A unified game engine written in Haxe that can run on any game engine.

# Stats
At present, the game engine is still under development and cannot be fully put into use.

# What can be batched
All common display objects (see the list below) and BlendMode.ADD can be automatically batched.

# Support
| Feature | Description | Status | Auto-batch |
--- | --- | --- | ---
| hx.display.Image | Image for rendering 2D game graphics, auto-batched, supports nine-slice rendering | ✅ | ✅ |
| hx.display.Label | Text for rendering text | ✅ | ✅ |
| hx.display.Button | Button, a regular button | ✅ | ✅ |
| hx.display.Sprite | Container for combining other objects | ✅ | ✅ |
| hx.display.Quad | Rectangle display object | ✅ | ✅ |
| hx.display.Graphics | Vector graphics | ✅ | ✅ |
| hx.display.Spine | Spine animation | ✅ | ✅ |
| hx.display.Scene | Scene for managing objects | ✅ | ✅ |
| hx.display.UILoadScene | Scene that automatically loads UI resources, mostly used for opening interfaces | ✅ | ✅ |
| hx.display.MovieClip | Animation clip for playing frame animations | ✅ | ✅ |
| hx.display.FPS | Displays various game states, such as drawCall, vertex count, CPU usage, etc. | ✅ | ✅ |
| hx.display.Box | Virtual box, the width/height of this container does not affect child containers | ✅ | ✅ |
| hx.display.VBox | Vertically laid out virtual box | ✅ | ✅ |
| hx.display.HBox | Horizontally laid out virtual box | ✅ | ✅ |
| hx.display.Scroll | Scroll container for implementing scrolling, requires masking so drawcall is consumed | ✅ | ❌ |
| hx.display.BitmapLabel | Bitmap texture support | ✅ | ✅ |
| hx.display.ListView | List view for implementing lists, requires masking so drawcall is consumed | ✅ | ❌ |
| hx.display.CustomDisplayObject | Custom display object, using it for rendering will definitely produce 1 draw | ✅ | ❌ |
| hx.events.MouseEvent | Mouse events | ✅ | / |
| hx.events.KeyboardEvent | Keyboard events | ✅ | / |
| hx.assets.Assets | Resource loader, supports loading of common resource formats such as images, audio, sprite sheets, XML, JSON, etc. | ✅ | / |

# Layout Support
| Layout | Name | Description |
--- | --- | ---
| hx.layout.FlowLayout | Flow Layout | Flow layout can be implemented through `hx.display.Box` virtual box with layout |
| hx.layout.HorizontalLayout | Horizontal Layout | Horizontal layout |
| hx.layout.VerticalLayout | Vertical Layout | Vertical layout |
| hx.layout.AnchorLayout | Anchor Layout | Objects can be positioned according to the properties of `left`, `right`, `top`, `bottom`, `horizontalCenter`, `verticalCenter` |


# Underlying Engine Support
| Engine | Support Status | Multi-texture Rendering |
| --- | --- | ---
| [OpenFL](https://github.com/rainyt/hxmaker-openfl) | ✅ | ✅ |

# Multi-texture Rendering
This game engine can render with multiple textures, reducing a large number of drawcall invocations.

---

[中文版本](README_CN.md)