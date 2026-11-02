# Spine 双运行时支持说明

hxmaker 根据项目引入的运行时库，在编译期选择 Spine 类型和渲染路径，公共入口仍为 `hx.display.Spine`、`hx.display.SpineSprite`、`hx.assets.Assets`。

## 选择规则

| 项目依赖 | 编译行为 |
| --- | --- |
| `spine-hx 3.8.2` | 使用 Spine 3.8 适配路径 |
| `spine-haxe 4.2.x` | 使用现有 Spine 4.2 适配路径，本机参考版本为 4.2.9 |
| 同时引入两库 | 明确报错，避免同名 `spine.*` 类型混用 |
| 均未引入 | 普通资源和界面代码不依赖 Spine 原生类型 |

`hx.spine.SpineTypes` 集中定义两库之间不同路径的类型别名。`#if spine_hx`、`#if spine_haxe` 使用 Haxelib 自动提供的条件宏；`hx.macro.SpineMacro` 校验依赖冲突和版本。OpenFL 的 `include.xml` 会调用校验宏，Spine 显示对象、图集和事件类上的构建宏也会覆盖直接使用源码的项目。没有可靠版本号的开发版依赖仍交由编译类型检查。

`Spine.runtimeName` 返回当前选择的运行时名称。每个构建只能选择一种运行时；Spine 3.8.x 和 4.2.x 导出数据应分别配合对应运行时使用。JSON 加载入口会对有版本信息的资源检查主、次版本，不匹配时明确报错。

## 引入方式

Spine 3.8 项目：

```xml
<haxelib name="hxmaker-openfl" />
<haxelib name="spine-hx" version="3.8.2" />
```

Spine 4.2 项目保留原有配置：

```xml
<haxelib name="hxmaker-openfl" />
<haxelib name="spine-haxe" />
```

不要同时引入两库，也不需要手工设置 `use_spine_hx`。直接使用 HXML 时应使用 `--library` 引入库；可添加 `--macro hx.macro.SpineMacro.configure()` 提前校验。

## 兼容行为

- 两库共用 `play`、`setSkinByName`、`renderFps`、`skeleton`、`animationState` 及世界变换回调；原生类型由所选依赖决定。
- Spine 3.8 通过 `AnimationStateListener` 转发 `START`、`INTERRUPT`、`END`、`DISPOSE`、`EVENT` 与 `Event.COMPLETE`；Spine 4.2 保留其原生监听集合。
- 设置动画后立即生成首帧；相同动画改变循环方式时重新设置轨道；已完成的单次动画允许重播。无效动画名由原生运行时抛出错误，调用方可捕获。
- `SpineSprite.stop()` 与 `Spine.stop()` 一样清空轨道并保留当前姿势；对已有 `ISpine` 接口没有新增实现要求。
- 每个实例独立持有裁剪器；裁剪结果在提交前复制索引，防止后续插槽覆盖；空附件和透明插槽也会结束对应的裁剪范围。
- 骨架、插槽、附件的普通颜色和透明度共同影响绘制。双色着色不在当前范围。
- `SpineSprite` 为不同插槽保留独立绘制数据，每帧开始统一清理；颜色对象池回收同时覆盖普通绘制和插槽绘制。销毁对象时移除内部运行时监听。

`Assets.loadSpineAtlas(png, atlas)` 维持单页图集接口；3.8 JSON 可通过 `loadString`、`getSkeletonData` 使用。本次没有新增 3.8 二进制、多页图集、双色着色或 Multiply/Screen 混合模式支持。

## 示例和待执行验证

示例位于 [samples/2d/spine3.8](../samples/2d/spine3.8/README.md)，固定引用 `spine-hx 3.8.2` 和官方 Spine 3.8.55 资源。

以下命令在仓库根目录执行，目前均尚未运行：

```bash
# Spine 3.8 公共 API 编译检查。
haxe vscode-openfl-spine3-8.hxml

# Spine 4.2 使用同一入口检查，避免入口为空导致兼容代码未被编译。
haxe vscode-openfl.hxml

# 不引入 Spine 库的编译检查。
haxe test/spine-optional.hxml

# 应明确报错：不能同时引入两库。
haxe vscode-openfl-spine3-8.hxml --library spine-haxe
```

`vscode-openfl-spine3-2.hxml` 保留为旧文件名兼容入口，转发到 3.8 配置；它没有提供 Spine 3.2 支持。两套主配置共用 `test/SpineCompile.hx`，强制引用显示、事件、插槽和资源 API。以上检查只进行编译，不替代示例运行验收。

运行验收应覆盖示例全部按钮、单次动画重播、传送门裁剪、透明插槽、事件顺序、皮肤切换和挂点位置；4.2 还需使用匹配的 4.2 资源做回归。按项目约定，功能测试前先通知用户，本次仅完成源码审阅和示例资源静态校验。
