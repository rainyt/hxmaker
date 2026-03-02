# hxmaker
A game engine that pursues fast development and rendering performance. It can freely implement game engine rendering backend, thereby enabling rendering to other engines.

# Stats
At present, the game engine is still under development and cannot be fully put into use.

# What can be batched
All common display objects (see the list below) and BlendMode.ADD can be automatically batched.

# Support
| Feature | Description | Status | Auto-batch |
--- | --- | --- | ---
| hx.display.DisplayObject | Base class for all display objects | ✅ | / |
| hx.display.DisplayObjectContainer | Container class that can hold multiple display objects | ✅ | / |
| hx.display.Image | Image for rendering 2D game graphics, auto-batched, supports nine-slice rendering | ✅ | ✅ |
| hx.display.Label | Text for rendering text | ✅ | ✅ |
| hx.display.Button | Button, a regular button | ✅ | ✅ |
| hx.display.Sprite | Container for combining other objects | ✅ | ✅ |
| hx.display.Quad | Rectangle display object | ✅ | ✅ |
| hx.display.Graphics | Vector graphics | ✅ | ✅ |
| hx.display.Spine | Spine animation | ✅ | ✅ |
| hx.display.SpineSprite | Spine animation sprite, support solt binds. | ✅ | ✅ |
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
| hx.display.Stage | Game engine stage | ✅ | ✅ |
| hx.display.BoxContainer | Base container class for box-based layouts | ✅ | ✅ |
| hx.display.BaseScrollBar | Base class for scroll bars | ✅ | ✅ |
| hx.display.VScrollBar | Vertical scroll bar | ✅ | ✅ |
| hx.display.InputLabel | Input text field | ✅ | ✅ |
| hx.display.ItemRenderer | Base item renderer for lists | ✅ | ✅ |
| hx.display.DefaultItemRenderer | Default item renderer for ListView | ✅ | ✅ |
| hx.display.ImageLoader | Image loader component | ✅ | ✅ |
| hx.display.Particle | Particle system | ✅ | ✅ |
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

# BlendMode Support
| BlendMode | Support Status | Description |
| --- | --- | --- |
| Normal | ✅ | The display object appears in front of the background. |
| Add | ✅ | Add the color value of the displayed object to its background color. |
| Multiply | ✅ | Multiply the value of the displayed object color by the background color. |
| Screen | ✅ | The color value of the displayed object is added to the inverse of the background color. |
| Difference | ✅ | Compares the display object's color values with its background and subtracts the darker value from the lighter one. |
| Subtract | ✅ | Subtracts the display object's color values from the background color values, with a lower limit of 0. |
| Subtract Fast | ✅ | Subtract blend mode, corresponding to `BlendMode.SUBTRACT_FAST`, faster but with slightly different results, background color is fixed to `vec4(0.5)`. |
| Invert | ✅ | Inverts colors. |
| Darken | ✅ | Selects the darker color between the display object and background. |
| Lighten | ✅ | Selects the lighter color between the display object and background. |
| Layer | ✅ | Forces the creation of a transparency group for the display object. |
| Alpha | ✅ | Applies the alpha value of each pixel of the display object to the background. Requires parent's blendMode to be `Layer`. |
| Erase | ✅ | Erases the alpha value of each pixel of the display object from the background. Requires parent's blendMode to be `Layer`. |
| Hardlight | ✅ | Adjusts each pixel's color based on the darkness of the display object. If the display object is lighter than 50% gray, it lightens; if darker, it darkens. |
| Overlay | ✅ | Adjusts each pixel's color based on the darkness of the background. If the background is lighter than 50% gray, it lightens; if darker, it darkens. |


# Underlying Engine Support
| Engine | Support Status | Multi-texture Rendering |
| --- | --- | ---
| [OpenFL](https://github.com/rainyt/hxmaker-openfl) | ✅ | ✅ |

# Multi-texture Rendering
This game engine can render with multiple textures, reducing a large number of drawcall invocations.

---

[中文版本](README_CN.md)
