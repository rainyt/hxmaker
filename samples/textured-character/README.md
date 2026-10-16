# 贴图动画角色示例

通过 hxmaker 的 `Assets.loadGlb` 加载完整角色 GLB，文件内包含图片、UV、材质、骨架、权重与动画。默认显示三个共用源贴图、分别播放动画的机器人，并开启环境光、方向光与硬阴影。

当前状态：源码和资源已准备，尚未执行 Haxe / Lime 编译、浏览器或回归断言。按用户要求交由用户测试；下文的画面与合批描述是验收目标。

## 运行

需要同时使用更新后的 hxmaker 与 hxmaker-openfl，在本示例目录执行：

```bash
arch -x86_64 lime test html5
```

不需要下载额外资源，也不需要先运行资源生成脚本。

## 资源

`Assets/robot.glb` 是原创程序化机器人，随代码提供，没有外部模型或贴图依赖。包含 31 个节点、16 个网格、192 个三角形、15 个关节和 3 张内嵌 PNG：

| 图片 | 大小 | 用途 |
| --- | --- | --- |
| body | 128 × 128 | 蓝色装甲、面板与方向标记 |
| screen | 128 × 128 | 机器人眼睛与嘴巴 |
| limbs | 64 × 64 | 橙色关节与警示条纹 |

所有材质为双面不透明材质，使用线性过滤和 CLAMP。装甲和关节使用非白色基础颜色因子，覆盖贴图与基础色相乘；二维预览显示原图，角色还会受到材质颜色和光照影响。躯干受两个关节混合影响，覆盖通用 CPU 蒙皮路径；其余肢体使用单关节刚性路径。`Idle` 为 2 秒待机，`Walk` 为 1 秒原地行走，均使用 LINEAR 位移与旋转轨道，不包含动画过渡。

生成器和 PNG 源图放在 `SourceAssets`，不进入资源打包。需要修改资源时执行：

```bash
python3 SourceAssets/generate_assets.py
```

脚本仅用 Python 标准库生成 PNG 和 GLB，无需 Blender。它用于制作资源，不会编译或启动示例。

## 操作与验收

- **动画**：暂停或继续；**动作**：切换待机与行走，多个实例错开播放时间。
- **角色**：在 1 / 3 / 6 个实例之间切换，实例共用三张资产贴图，材质、几何和播放状态各自独立。
- **多纹理**：切换多槽位与单槽位，比较顶部主场景批次；画面和动画应保持一致。
- **光照 / 阴影**：分别开关表面照明与投影；无光照材质不接收阴影。
- **过滤**：统一切换线性与最近点过滤，观察装甲和面板的像素边缘。
- **旋转**：自动旋转整个角色组；拖动视口手动旋转；**重新取景**恢复正面视角。
- **重新加载**：先销毁实例与二维预览，再释放旧 Assets，经相同加载系统创建新资源。

底部三张二维预览与 3D 角色使用同一批 `BitmapData`，可检查三维绘制后的二维纹理状态是否正常。身体图左上为红色标记，左下为绿色标记；脸部眼睛应位于嘴巴上方，用于观察 UV 是否倒置。

建议先暂停动画、关闭旋转和阴影，比较多纹理开关：贴图不同但其他状态一致的角色网格可以合批，地面再使用共享白图。在纹理槽位足够、程序成功链接且所有对象可见的情况下，多纹理主场景预期可合为一个批次；单纹理通常需要更多批次，实际以统计为准。阴影批次、最后一次二维合成以及普通二维 UI 不计入主场景批次数字。

再打开阴影与动画，确认不同实例的贴图一致、动作时间不同，开关多纹理不会改变画面。运行中统计包含可见网格、主场景上传量及阴影实际状态，不代表已完成性能测试。

## 加载与生命周期

```haxe
var assets = new hx.assets.Assets();
assets.loadGlb("assets/robot.glb");
assets.onComplete(_ -> {
    var source = assets.getGlb("robot");
    var model = source.createInstance(-1, {lightingEnabled:true});
    scene.root.addChild(model);
    model.animation.play("Walk", true);
    // 在业务 UPDATE 中显式调用 model.update(dt)。
});
assets.onError(error -> trace(error.toString()));
assets.start();
```

实际链路：`Assets → GlbFuture → BytesFuture / RequestQueue → GLB 结构解析 → BitmapDataBytesFuture / RequestQueue → 图片解码 → 加载完成`。图片字节直接交给后端解码，不创建临时 URL，不发起第二次网络请求。

图片按 SHA-256 内容摘要建立缓存键，重复图片复用解码结果，Future 子资产保留与释放相应引用。图片出错时释放本次已取得的二进制和图片引用，错误经原有 Assets.onError 返回。关闭 RequestQueue 缓存时，图片由共享的本地子资产管理，最后一个引用释放时销毁。

`GlbAsset.imageCount / textureCount / texturesReady` 描述图片状态，`getTexture(index)` 取得借用的共享位图，可用于预览，不应自行 dispose。多个 Model3D 实例共享源贴图，销毁实例不销毁源图。使用完必须先销毁所有模型和预览，再 `assets.clean()`；不要在模型仍绘制时释放 Assets。启用缓存时，底层图片按 RequestQueue 的既有延迟释放机制清理。

`GlbAsset.fromBytes` 仍是同步的纯解析入口；含图片的文件不能在图片解码前 createInstance。业务应通过 `Assets.loadGlb` 加载。Assets 的总进度按资源项完成计算，单个 GLB 完成意味着其所有内嵌图片也已完成，不是下载字节百分比。

## 当前贴图边界

- 支持内嵌 bufferView PNG/JPEG、`baseColorTexture`、`baseColorFactor`、TEXCOORD_0 和原有透明模式。贴图颜色与基础色在线性空间相乘，再转换为显示编码；GLB 的无光照路径也使用这一规则。
- 支持独立的放大/缩小基础层过滤，以及 CLAMP、REPEAT、MIRROR 包裹。过滤、包裹或颜色计算规则不兼容时分批，不会为每张贴图固定拆一个批次。
- 为兼容 WebGL 1，重复或镜像采样要求二次幂整图，不接受图集区域或 GPU 填充图。非二次幂图片可使用 CLAMP；GLB 的非二次幂重复图片在加载阶段明确报错。
- mipmap 过滤会提示并降级为对应的基础层过滤，未生成 mipmap。
- 外部 URI、data URI、TEXCOORD_1、KHR_texture_transform、压缩纹理、法线/金属粗糙度/遮蔽/自发光贴图仍不支持，不能据此视为完整 glTF PBR 实现。
- MASK 材质可在主场景按 Alpha 裁剪，但当前阴影 pass 仍只允许 OPAQUE 投射，不把透明轮廓当成不透明轮廓。

采样数据规则参考 [Khronos glTF 2.0 规范](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#textures)。

## 可选断言

需要验证 CPU 与资产数据时，由用户执行：

```bash
arch -x86_64 lime test html5 -D hxmaker_character_checks
```

`CharacterChecks.hx` 检查资源统计、解码尺寸与方向标记像素、双关节躯干变形、实例隔离、共享贴图以及无效纹理输入的拒绝行为。通过时输出 `HXMAKER_CHARACTER_CHECKS PASS`。该入口目前未运行，且不替代画面、多纹理、过滤、重复加载和 GPU 状态恢复的实际验证。
