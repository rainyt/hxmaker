# FPS 调试面板

`hx.display.FPS` 已恢复为 2026 年 10 月 22 日调试面板改版前的实现。

在业务舞台的 `onStageInit()` 中添加面板。应用启动类继承 `hx.core.HxmakerApplication`，由启动类初始化业务舞台。

```haxe
override function onStageInit() {
	super.onStageInit();
	var fps: hx.display.FPS = new hx.display.FPS();
	fps.refreshInterval = 0.25;
	addChild(fps);
}
```

## 接口

- `new FPS(autoShowTop)`：`autoShowTop` 默认为 `true`，自动将面板移到所在父容器的顶部。
- `label`：显示统计文字的 `Label`，可调整字体和样式。
- `refreshInterval`：文字刷新间隔，单位为秒，默认 `0.25`；设为 `0` 时逐帧刷新。底层统计仍逐帧采集。

## 显示指标

面板使用旧版文字和排列，显示 `FPS`、`drawCall`、`vertexCount`、`displays`、`CPU`、`FrameDelay`、`Memory`、`spineRender`、`graphicRender`、`timerTask`、`blendModeFilter`、`stageBitmapDatas`、`resourceRef`、`cacheAsBitmap` 和 `devicePixelRatio`。启用 `webgl_memory` 时额外显示 `GPUMemory`。

- `FPS`：最近一秒内的帧采样数量，沿用旧版整数修正规则。
- `CPU`：最近最多 180 次引擎耗时的平均值占目标帧预算的比例，不是系统 CPU 使用率。
- `FrameDelay`：同一平均引擎耗时，以毫秒显示。
- `Memory`、`GPUMemory`：字节数除以 1024² 后取整，沿用旧版 `mb` 后缀。
- `resourceRef`：资源总引用数／缓存资源总数。

绘制和更新计数直接读取 `ContextStats` 当前计数，随渲染后端的统计、重置顺序变化，包含面板自身产生的负载。

此次还原移除了精简／详细模式、帧间隔分位数、超预算计数、资源变化量和激活／失活时重置采样的逻辑；同时恢复旧版 `ContextStats`，移除了新版完整帧快照及采样摘要接口。

## 验证状态

本次未运行测试或编译验证。建议后续执行 OpenFL 编译，并检查面板指标、刷新间隔和自动置顶行为。
