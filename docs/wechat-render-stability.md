# 微信小游戏渲染稳定性修复与接入

本次工作使用 `codex/wechat-render-stability` 分支，涉及 hxmaker 和 hxmaker-openfl 两个仓库。OpenFL、Lime、hx-astcenc 均不修改。本轮执行 JS 目标的浏览器验证；微信小游戏运行与真机验收由项目方执行。

## 修复协议

### 纹理槽

`MultiTextureShader`、`MultiTextureFastShader` 实现 `IBatchTextureShader.batchTextureSlots`。纯多纹理构造路径按编译时槽数声明引擎管理输入，捕获前覆盖全部管理槽，空余槽使用当前批次合法输入。GLSL 材质路径默认只管理 `uSampler0`，其余由材质显式设置。不能通过采样器名字推断材质输入归引擎所有。

构造函数最后一个可选参数 `engineSlots` 可以限制实际生成的合批采样分支，例如 1、8、16。设备上限仍然生效。额外材质纹理需要在着色器设计时预留采样器预算。运行时关闭多纹理只减少几何合批数量，不缩减已编译声明的槽位覆盖范围。

Layer 的 ALPHA、ERASE 输入关闭后仍设置语义明确的白色、透明纹理，并清除启用标记。ALPHA 的零透明度会正确遮掉内容。共享 Shader 的数值、输入和采样状态保存在各自批次的 ShaderBuffer 中；跨容量拆批时保留原自定义 Shader。

### 资源与快照

- `BitmapData.sub()` 与同一个 `IBitmapData` 的包装视图共享根所有权。释放一个视图不会销毁其他视图的根资源。
- 同一原生 OpenFL 位图的多个 OpenFlBitmapData 包装器也共享释放权。
- 公开视图 `dispose()` 后 `data` 变为 null，禁止创建新使用者；实际原生纹理等待所有公开所有者与快照持有退出后销毁。
- DirectBatchDisplay 在输入进入快照时持有基础和材质纹理，在显示树拆离、快照替换、Render.clear/dispose 时配对退役；draw 完成不退役持久画面。
- Render 重入时不会复用正在消费的批次；即将退役的消费中快照在本次消费退出后清理。
- 直接调用原生 `openfl.display.BitmapData.dispose()` 绕过该协议，属于破坏性操作。二维路径会分类报告并隔离该批次，但无法还原绕过协议时的调用堆栈。

直接把临时位图的 data 赋给另一个视图后，也要 dispose 临时包装器以交还其所有权；建议直接传递完整 BitmapData 或使用 sub，而不是隐式转移 data。

业务显示对象使用资源期间应保留相应 Assets/AssetObject；场景离开后再释放。禁止把已经 dispose 的公开位图用于新批次。手工创建的子视图使用完后也需要 dispose。

### 池、滤镜与离屏

StageBitmapData 通过令牌借用池资源，借用者 dispose 只归还令牌。池不会把正在借用、被快照读取、尺寸不符、状态失效或设备代次不符的目标再次作为输出。强制清池将条目退役，不覆写旧快照的目标。普通闲置维护只回收没有借用和读取者的资源。

GeryFilter 复用同尺寸且没有读取者的缓存，替换后按快照协议回收旧目标；错误路径恢复临时 Shader 和透明度。缓存边界使用源对象坐标系，完整逆变换用于离屏绘制，避免缩放和嵌套滤镜裁掉内容。

LayerFilter 释放内部 Render 和独占遮罩；关闭遮罩不会继续引用旧目标。keep 缓存尺寸改变、Blur 独占目标被其他快照读取时也按替换协议处理。显示对象 dispose 会释放其滤镜；滤镜 dispose 后必须显式 init 才能重新挂载。自定义滤镜不可依赖半销毁状态复用。

截图使用有界 Render 借用池，最多保留四个空闲上下文，最大嵌套深度十六。离屏 Pass 检测输出反馈，异常退出清除临时状态、解除快照持有，并恢复 OpenFL 状态。上下文已丢失或代次改变时不会恢复旧 GPU 句柄。

`RenderTargetBudget` 默认单边 4096、总像素 16777216，同时受设备 MAX_TEXTURE_SIZE 限制。空内容不分配，非法或超预算尺寸分类拒绝。小数边界向上取整。

### 缓存与异步

正常清理使用 `RequestQueue.collectUnused(maxEntries, maxMilliseconds, maxBytes, respectDelay, reason)`。它只检查有界候选队列，不每帧扫描全部缓存；有业务持有、快照读取或加载中的条目不会销毁。`maintain()` 由引擎定期调用，回收不再依赖下一次加载。

示例：

```haxe
// 场景退出后立即检查安全候选，最多检查 64 项、耗时 2 毫秒、释放 64 MiB。
var released:Int = hx.net.RequestQueue.collectUnused(64, 2, 67108864, false, "退出场景");
```

`removeCache`、`clearCache` 保留破坏性语义，不用于日常清理。超过单次字节预算的独立大资源会留到更大的显式预算；不会突破调用方设置的上限。

缓存条目使用递增 entryId；AssetObject 记录对应代号，旧请求和旧释放不修改同 URL 的新条目。重复 release 不下溢。Assets.pushAssets 共享追踪所有者；最后一个退出才清理图集视图。Assets.clean 撤销当前加载代次，晚到结果不复活资源表，旧重试定时器也不会重启清理过的宿主。

游戏端 `AssetsManager.releaseUnusedBitmaps` 可迁移到上述安全 API。不要继续通过私有缓存结构强删；不要直接删除项目的 SafeGeryFilter 保护逻辑，应先在游戏中验证引擎 GeryFilter 和业务扩展一致。

### 设备恢复与诊断

复用 Engine.contextGeneration。帧入口检查丢失状态，恢复时退役旧批次，失效程序、池、文本和离屏内容，再重建画面。普通前台恢复重置时间基准并请求一次重绘，不无条件重建全部纹理。普通浏览器区分焦点与页面可见性：可见窗口失焦继续渲染，真正隐藏时才暂停，并监听 visibilitychange 处理没有 focus 的恢复。微信和缺少页面可见性 API 的宿主沿用激活事件。

普通图片保留 CPU 像素恢复；GPU-only 离屏目标依靠滤镜重绘；文本图集清理字形视图后重写。后端的 RecoverableASTCBitmapData 保留最多 64 MiB 压缩来源，在恢复时重新检查扩展并重传。清单型 ASTC 原图路径存在时，能力变化可进行一次原图回退；失败进入终态，不逐帧重新请求。直接从外部 GPU 句柄创建、没有像素及重绘来源的位图会报告 missingRecovery，不能宣称恢复成功。

微信激活/失活沿用适配层已有事件转发。内存告警只有在具备配对注册/移除能力时额外接入；业务也可调用 Engine.requestMemorySweep()。告警只在安全帧入口加速候选清理，triggerGC 不替代 GPU 回收。

`RenderDiagnostics.snapshot()` 返回有界结构化报告和计数；`onFault` 只在同类首报触发。发布默认隔离类型明确的资源故障，开发可启用 `hxmaker_render_strict` 或设置 strict。未知异常仍抛出。`hxmaker_render_debug` 启用有上限的资源分配、持有和退役记录；记录不强引用纹理。

构建脚本生成 buildId、依赖提交/脏状态、JS SHA256 与 source map 对应清单。复现报告应同时保留 build-info.json、JS/map、设备/微信/基础库版本和操作序列。线上原故障包尚未取得；已复现的是评估指出的历史槽源码路径，不能据此指认某个线上 Shader 就是唯一根因。

## 验证与发布

示例、执行脚本及结果位于 `samples/2d/render-stability/`。测试报告见该目录 `测试报告.md`。先同步两个修复分支，在 JS 示例验证后再由游戏接入；不修改游戏逻辑或游戏 CHANGELOG。

本分支尚未自动提交或发布。建议按槽位与资源协议、滤镜与缓存、恢复与诊断分阶段审查；回滚应保留明确的提前释放修复。真机结果由项目方补充，不能把浏览器能力注入写成微信真机通过。
