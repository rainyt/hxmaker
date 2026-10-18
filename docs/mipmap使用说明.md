# mipmap 使用说明与实现评估

本次实现覆盖 `hxmaker` 与相邻 `hxmaker-openfl` 两个仓库，需要一起使用。已完成源码修改及代码走查；按项目要求，尚未执行编译、自动检查入口或 GPU 验证。

## 使用方式

基础色、Unlit、Lambert、PBR 材质均通过基础材质属性选择完整缩小过滤：

```haxe
import hx.material.TextureMinFilter3D;

material.textureMinFilter = TextureMinFilter3D.LINEAR_MIPMAP_LINEAR;
```

PBR 数据贴图独立配置：

```haxe
import hx.material.TextureMinFilter3D;
import hx.material.TextureWrap3D;

material.setMapSampler("normal", true, true,
    TextureWrap3D.REPEAT, TextureWrap3D.REPEAT,
    TextureMinFilter3D.LINEAR_MIPMAP_LINEAR);
```

基础材质的 `textureMinFilter=null` 表示继续使用 `textureMinSmoothing`，后者为 null 时沿用 `smoothing`。完整过滤非 null 时具有更高优先级。恢复旧行为时先将 `textureMinFilter` 设回 null。

`setMapSampler` 的最后一个参数可省略，旧调用保持基础层过滤；传入完整模式时，它优先于第三个布尔参数。GLB 显式指定的六种 `minFilter` 均保留到 GPU；未指定时保持原先的 LINEAR 默认值。FBX 默认不启用 mipmap。资产数据版本与构建版本均升级为 3，构建器仍接受缺少 `minFilter` 的旧源数据。

| 模式 | 单层过滤 | mip 层选择 |
| --- | --- | --- |
| `NEAREST` | 最近邻 | 仅基础层 |
| `LINEAR` | 线性 | 仅基础层 |
| `NEAREST_MIPMAP_NEAREST` | 最近邻 | 最近层 |
| `LINEAR_MIPMAP_NEAREST` | 线性 | 最近层 |
| `NEAREST_MIPMAP_LINEAR` | 最近邻 | 相邻层插值 |
| `LINEAR_MIPMAP_LINEAR` | 线性 | 相邻层插值，即三线性过滤 |

## 支持范围与降级

当前使用跨 WebGL 1 的保守范围：宽、高均为二次幂，无 `texture.rect` 图集区域，无上传填充，并保留 OpenFL CPU 图片。基础色、PBR 四类数据贴图以及 MASK 阴影采样接入同一套生成逻辑。支持 CLAMP、REPEAT 和 MIRROR。

不满足这些条件的 mipmap 请求会保留层内过滤，降级为 NEAREST 或 LINEAR；每个源位图在一个渲染器的生命周期内最多输出一次降级提示。即使图集区域覆盖整图，只要 `rect != null` 也降级。白色占位纹理不受业务图片图集区域影响。

非二次幂图片的基础色 REPEAT/MIRROR 仍沿用已有的明确拒绝规则，不会因为 mipmap 降级而放开。PBR 辅助图的非二次幂或图集区域继续采用 Shader 区域内包裹，并关闭 mipmap。WebGL 2 的非二次幂 mipmap 尚未单独开放。

同一底层图片在一次绘制中共享 GL 采样状态，实际缩小过滤、放大过滤以及硬件包裹必须一致，否则报错。完整 mipmap 模式进入合批键；请求 mipmap 时图集与整图也会分批，防止误用另一材质的图集资格。

## 后端方案与代价

本次采用显式 `gl.generateMipmap` 扩展 OpenFL 已上传的二维纹理。RectangleTexture 本身不会自动生成 mip 链，因此必须先完成生成，再设置对应过滤枚举。

没有额外复制基础层，也没有另建 GPU 纹理缓存。`MipmapCache3D` 只记录源位图、实际 TextureBase 对象和 `__textureVersion`：首次使用或 OpenFL 上传版本变化时生成，重复绘制复用。位图释放后沿用 OpenFL 的纹理销毁机制，记录在下次渲染时清理；渲染器销毁或上下文失效时清空全部记录。多个渲染器共享图片时，各自首次使用可能重复生成一次，但不会各自分配基础纹理。

共享纹理的采样参数经过现有状态保护协议保存和恢复。没有旧采样缓存时恢复 LINEAR + CLAMP，避免将没有 mip 链的图片恢复成 GL 默认 mipmap 过滤而变成不完整纹理。原有完整 GL 参数查询模式继续恢复精确快照。

满足整图条件的 PBR 贴图改用硬件包裹，Shader 使用连续的原始 UV，让硬件计算隐式 LOD。图集继续采用区域内包裹，且不启用 mipmap。用户自定义 UV Shader 若自行使用 `fract` 等不连续变换，仍需自行处理导数问题。

对于较大的正方形纹理，完整 mip 链额外显存约为基础层的三分之一；狭长纹理比例更高。首次生成与图片更新会有 GPU 开销。关闭采样的 mipmap 模式后，不单独移除已经生成的层级，它们随源纹理释放。

目前没有增加各向异性过滤、LOD bias、自定义 mip 层、线性空间基础色 mip 生成或法线专用预滤波。颜色空间与法线缩小质量仍有进一步优化空间。仅追踪 OpenFL 的 CPU 图片上传版本，外部直接修改 GPU 纹理或外部代码重定义 mip 链不在本轮支持范围内。

## 待执行验证

新增 `test/MipmapChecks.hx` 手动入口，覆盖六种 GLB 过滤语义、导入与构建传递、旧源数据、非法值拒绝、材质变更通知与 PBR 采样兼容。夹具仅含 PNG 签名，用于解析与构建，不代表图片解码或 GPU 测试。

用户安排后需要完成以下验证：

1. 按项目 OpenFL 构建配置编译核心库与后端，并执行新增的数值检查入口。
2. 使用二次幂棋盘整图，在明显缩小和倾斜的地面上比较无 mipmap、最近 mip 与三线性过滤；读取 GPU 结果并检查 GL 错误。
3. 分别覆盖 NEAREST 与 LINEAR 放大过滤，确认独立缩小模式不影响放大效果。
4. 检查 NPOT + CLAMP、图集降级及降级提示去重；确认现有基础色 NPOT + REPEAT/MIRROR 仍明确拒绝。
5. 检查 PBR REPEAT/MIRROR 接缝、共享 ORM 图片，以及不同实际采样状态的冲突拒绝。
6. 同一图片交替用于 2D 与 3D，确认二维采样恢复正常；同时覆盖 `hxmaker_3d_full_state_queries` 配置。
7. 修改 CPU 位图后触发场景重绘，确认 mip 链重建；反复加载释放和恢复 WebGL 上下文，确认无黑图、旧句柄残留与持续显存增长。

评估结论：已形成可供验证的最小 mipmap 闭环，适用于常规二次幂独立贴图；尚不能据此宣称所有平台或真实 GPU 画质已经验证通过。
