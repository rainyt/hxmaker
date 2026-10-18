# hxmaker
A Haxe game engine for 2D and foundational 3D development, focused on fast iteration and rendering performance. It can freely implement game engine rendering backend, thereby enabling rendering to other engines.

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
| hx.display.Tree | Tree list view (VSCode explorer style) with virtual list support, requires masking so drawcall is consumed | ✅ | ❌ |
| hx.display.FinderView | Finder-style resource browser list with folder navigation (double-click to enter), shares the TreeItem data model with Tree, requires masking so drawcall is consumed | ✅ | ❌ |
| hx.display.CustomDisplayObject | Custom display object, using it for rendering will definitely produce 1 draw | ✅ | ❌ |
| hx.display.Stage | Game engine stage | ✅ | ✅ |
| hx.display.BoxContainer | Base container class for box-based layouts | ✅ | ✅ |
| hx.display.BaseScrollBar | Base class for scroll bars | ✅ | ✅ |
| hx.display.VScrollBar | Vertical scroll bar | ✅ | ✅ |
| hx.display.InputLabel | Input text field | ✅ | ✅ |
| hx.display.ItemRenderer | Base item renderer for lists | ✅ | ✅ |
| hx.display.TreeItem | Tree data node for Tree | ✅ | ✅ |
| hx.display.TreeItemRenderer | Default item renderer for Tree | ✅ | ✅ |
| hx.display.FinderItemRenderer | Default item renderer for FinderView | ✅ | ✅ |
| hx.display.DefaultItemRenderer | Default item renderer for ListView | ✅ | ✅ |
| hx.display.ImageLoader | Image loader component | ✅ | ✅ |
| hx.display.Particle | Particle system | ✅ | ✅ |
| hx.events.MouseEvent | Mouse events | ✅ | / |
| hx.events.KeyboardEvent | Keyboard events | ✅ | / |
| hx.assets.Assets | Resource loader, supports loading of common resource formats such as images, audio, sprite sheets, XML, JSON, etc. | ✅ | / |

# 3D Capabilities and New Rendering Technology

hxmaker embeds 3D viewports in the 2D display tree through `hx.display.Scene3D`. Each viewport renders to its own color/depth target, then composites with text, buttons, and other UI in 2D display order. Nodes, cameras, and models live in `hx.display3d`; backends integrate through `IScene3DRenderer`. The current implementation primarily targets OpenGL/WebGL through the companion [hxmaker-openfl](https://github.com/rainyt/hxmaker-openfl) backend.

**Start with the [3D beginner guide](docs/3D引擎新手指南.md)** for complete projects, APIs, ownership rules, and limitations. The linked technical guides are currently in Chinese. Existing projects should read the [3D API package migration guide](docs/3D显示API包迁移说明.md): old packages have no forwarding compatibility layer. New rendering features require matching core and backend source versions.

| Area | Current capabilities |
| --- | --- |
| Scene and cameras | `Node3D` hierarchy transforms, `MeshObject`, perspective cameras, orbit/follow controls, multiple viewports, and 2D UI composition |
| Models and assets | Unified `Assets.loadModel/getModel` loading for a GLB 2.0 subset and static FBX; independent instances through `ModelAsset`; ASCII and binary FBX support |
| Asset preprocessing | Format-neutral asset construction prepares normals, local bounds, hierarchy traversal order, and rigid-skin classification to reduce repeated runtime preparation |
| Animation and attachments | Independent playback, speed, loops, smooth transitions, animation events, and bone attachments; general CPU skinning and a single-joint rigid path |
| Lighting and shadows | Ambient, directional, point, and spot lighting; up to four lights for Lambert shading; main directional-light hard shadows, PCF4 filtering, MASK silhouettes, and shadow caching |
| Particles and effects | CPU particles, billboards, lifetime curves, sprite sheets, projectile trails, two-ended weapon ribbons, UV scrolling, mask/noise dissolve, and effect timelines |
| Depth and post-processing | Soft-particle intersection fading against scene depth; viewport Bloom on ordinary RGBA8 targets, disabled by default |
| Interaction and movement | Ray picking, mouse/touch adaptation, box and ramp proxies, sphere/upright-capsule queries and sweeps, sliding, gravity, jumping, steps, and slope limits |
| Navigation and flow | Explicit waypoint graphs, A*, path following, dynamic-route replanning, and examples integrating Procedure, load cancellation, retries, and cleanup |
| Rendering and diagnostics | Multi-texture batching, per-mesh frustum culling, static viewport reuse, on-demand GPU state protection, HTML5 VAO isolation, CPU phase timings, and resource statistics |

## Examples and Technical Guides

| Topic | Entry points |
| --- | --- |
| Basic scenes and 2D/3D composition | [Basic scene](samples/3d/basic-3d/README.md) · [Multiple viewports](samples/3d/multi-scene-3d/README.md) · [Framework guide](docs/基础3D框架使用说明.md) |
| Model import and asset construction | [FBX / GLB comparison](samples/3d/fbx-model/README.md) · [Animated GLB](samples/3d/glb-model/README.md) · [Format-neutral assets](docs/3D模型中立资产与优化格式设计.md) · [FBX scope](docs/FBX模型加载器设计与使用说明.md) |
| Animation and complete character flow | [Textured characters](samples/3d/textured-character/README.md) · [Transitions and attachments](docs/3D动画过渡与骨骼挂点使用说明.md) · [Complete character project](samples/3d/interactive-character/README.md) |
| Multiple lights and shadows | [Multiple-light example](samples/3d/multi-light-3d/README.md) · [Lighting chapter](docs/3D引擎新手指南.md#10-光源与阴影) · [Shadow settings and caching](docs/基础3D光照与阴影使用说明.md) |
| Particles, trails, and Bloom | [Effects example](samples/3d/effects-3d/README.md) · [Particles and billboards](docs/3D特效第一阶段使用说明.md) · [Trails and dynamic materials](docs/3D特效第二阶段使用说明.md) · [Soft particles and Bloom](docs/3D特效第三阶段使用说明.md) |
| 天空背景与环境反射 | [天空环境示例](samples/3d/skybox/README.md) · [天空环境使用说明](docs/天空环境使用说明.md) |
| Cameras and interaction | [Camera example](samples/3d/camera-interaction/README.md) · [Interaction guide](docs/3D相机控制与交互使用说明.md) |
| Collision, terrain, and navigation | [Collision example](samples/3d/collision-character/README.md) · [Steps and slopes](samples/3d/terrain-character/README.md) · [Navigation example](samples/3d/navigation-character/README.md) · [Navigation guide](docs/3D导航使用说明.md) |
| Performance and lifecycle | [Acceptance and baseline example](samples/3d/engine-acceptance/README.md) · [Existing baseline analysis](samples/3d/engine-acceptance/Baselines/2026-10-16-最终分析.md) · [Rendering optimization notes](docs/基础3D渲染优化记录-20261016.md) |

Browse all projects in the [3D examples directory](samples/3d/README.md). Application entry classes extend `hx.core.HxmakerApplication`, call `super()`, then initialize with `init(GameStage, width, height)`. Business stages extend `hx.display.Stage` and call the parent method first in `onStageInit()`. Keep scene, resource, and update logic in stages or scenes.

## Limitations and Validation Status

- 3D remains under active development. Basic scenes, animation and interaction, character flow, and the first two effects stages have execution records or user acceptance feedback. New multiple-light rendering, PCF4/MASK shadows and caching, soft particles, Bloom, and format-neutral/static-FBX assets still require their own acceptance checks; earlier results do not validate them.
- GLB support is a defined subset; FBX skeletal animation is currently unsupported. No `.hx3d` file codec or export tool has been implemented. In-memory asset preprocessing does not imply an offline publishing format is available.
- 已支持 PBR 材质、IBL 与静态天空背景，当前场景输出仍为 LDR。完整 HDR 渲染、GPU 蒙皮与实例化、自动 LOD、自动 NavMesh 生成及通用刚体物理尚未实现。Bloom 提取整个视口的亮部，叠加特效与 Bloom 不照亮周边模型，点光源与聚光灯不投射阴影。
- Each `Scene3D` has independent depth and composites in 2D order without sharing depth. Transparent meshes use object-level sorting, so intersecting transparent surfaces can still show ordering artifacts.
- Evaluate performance on target devices with actual resolutions and assets. `scene.stats` reports draws, uploads, shadows, and post-processing; timings enabled by `scene.profilingEnabled` measure CPU wall time, not GPU time. Existing HTML5 baselines do not establish support across all platforms.

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
