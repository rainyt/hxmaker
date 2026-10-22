package hx.display;

import hx.core.Hxmaker;
import hx.filters.StageBitmapData;
import hx.utils.ContextStats;
import hx.events.Event;

/**
 * 引擎调试面板：区分实际帧间隔、引擎计时段耗时和资源存量。
 * 绘制统计来自已完成帧，包含面板自身，不代表完整 GPU 绘制次数。
 */
class FPS extends DisplayObjectContainer {
	private var __bg:Quad;

	public var label:Label;

	/**
	 * 是否自动显示顶部
	 */
	public var autoShowTop:Bool = true;

	/** 统计文字的刷新间隔（秒）；设为 0 可逐帧刷新，统计采集本身仍逐帧进行。 */
	public var refreshInterval:Float = 0.25;
	/** 是否显示更新任务、资源变化和渲染配置；默认使用精简模式。 */
	public var detailed(default, set):Bool = false;
	private var refreshElapsed:Float = 1e30;
	private var observedStage:Stage;
	private var previousMemory:Null<Float>;
	private var previousCacheCount:Int = -1;
	private var previousRefCount:Int = -1;

	private function set_detailed(value:Bool):Bool {
		if (detailed != value) refreshElapsed = 1e30;
		return detailed = value;
	}

	public function new(autoShowTop:Bool = true) {
		super();
		this.autoShowTop = autoShowTop;
	}

	override function onInit() {
		super.onInit();
		this.mouseEnabled = false;
		this.mouseChildren = false;
		this.updateEnabled = true;
		__bg = new Quad(0, 0, 0x0);
		__bg.alpha = 0.8;
		this.addChild(__bg);
		this.label = new Label();
		label.textFormat = new TextFormat(null, 26, 0xffffff);
		label.x = label.y = 5;
		this.addChild(label);
	}

	override function onAddToStage() {
		super.onAddToStage();
		observedStage = stage;
		if (observedStage != null) {
			observedStage.addEventListener(Event.ACTIVATE, onTimingReset);
			observedStage.addEventListener(Event.DEACTIVATE, onTimingReset);
		}
		resetDisplaySamples();
	}

	override function onRemoveToStage() {
		if (observedStage != null) {
			observedStage.removeEventListener(Event.ACTIVATE, onTimingReset);
			observedStage.removeEventListener(Event.DEACTIVATE, onTimingReset);
			observedStage = null;
		}
		super.onRemoveToStage();
	}

	private function onTimingReset(event:Event):Void {
		ContextStats.resetTiming();
		resetDisplaySamples();
	}

	private function resetDisplaySamples():Void {
		refreshElapsed = 1e30;
		previousMemory = null;
		previousCacheCount = previousRefCount = -1;
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (autoShowTop && this.parent != null && this.parent.children[this.parent.children.length - 1] != this) {
			this.parent.addChild(this);
		}
		var interval = Math.isFinite(refreshInterval) && refreshInterval > 0 ? refreshInterval : 0;
		if (Math.isFinite(dt) && dt > 0) refreshElapsed += dt;
		if (refreshElapsed < interval) return;
		refreshElapsed = interval > 0 ? refreshElapsed % interval : 0;

		var engine = Hxmaker.engine;
		var frame = ContextStats.completedFrame;
		var timing = ContextStats.getTiming();
		var ready = timing.frameCount > 0;
		var target = engine != null && engine.frameRate > 0 ? Std.string(engine.frameRate) : "未知";
		var stats:Array<String> = ["帧率：" + (ready ? format(timing.fps) : "采样中") + " / " + target + " FPS"];
		if (ready) {
			stats.push("帧间隔：均值 " + format(timing.averageMs) + " / P95 " + format(timing.p95Ms) + " ms");
			stats.push("间隔峰值：" + format(timing.maxMs) + " ms");
			stats.push("超预算（>110%）：" + (timing.budgetMs > 0 ? timing.overBudgetCount + "/" + timing.frameCount : "不可用"));
			stats.push("引擎耗时：" + format(timing.averageUsedMs) + " ms / 预算 "
				+ (timing.budgetMs > 0 ? format(timing.budgetMs) + " ms" : "未知"));
		} else {
			stats.push("帧间隔 / 引擎耗时：等待采样");
		}
		if (frame != null) {
			stats.push("提交绘制：DC " + frame.drawCall + " / 索引顶点 " + frame.vertexCount);
			stats.push("绘制对象：" + frame.visibleDisplayCounts);
		} else {
			stats.push("提交绘制：等待完整帧");
		}

		var memory:Null<Float> = ContextStats.memoryAvailable ? ContextStats.memory / 1048576. : null;
		var memoryName = #if (js && html5) "JS 堆" #else "运行时堆" #end;
		stats.push(memoryName + "：" + (memory != null ? format(memory) + " MiB" : "不可用 / 尚未采样"));
		#if webgl_memory
		var gpuMemory = ContextStats.gpuMemory;
		stats.push("GPU 内存：" + (gpuMemory > 0 ? format(gpuMemory / 1048576.) + " MiB" : "不可用 / 尚未采样"));
		#end
		stats.push("缓存资源：" + ContextStats.totalCacheCount + " / 引用总数：" + ContextStats.totalRefCount);

		if (detailed) {
			stats.push("—— 详细信息 ——");
			stats.push("采样窗口：最近 1 秒，最多 600 帧");
			if (ready) {
				stats.push("引擎耗时峰值：" + format(timing.maxUsedMs) + " ms");
				stats.push("引擎预算占用：" + (timing.budgetMs > 0 ? format(timing.averageUsedMs / timing.budgetMs * 100) + "%" : "不可用"));
			}
			if (frame != null) {
				stats.push("Spine 更新：" + frame.spineUpdateCount + " / 定时任务更新：" + frame.timerTaskCount);
				stats.push("图形渲染：" + frame.graphicRenderCount + " / 混合滤镜绘制：" + frame.blendModeFilterDrawCall);
			}
			stats.push("舞台位图池：" + StageBitmapData.counts);
			stats.push("堆变化：" + (memory != null && previousMemory != null ? signed(memory - previousMemory) + " MiB" : "等待有效对比"));
			stats.push("缓存变化：" + (previousCacheCount >= 0 ? signedInt(ContextStats.totalCacheCount - previousCacheCount) : "等待对比")
				+ " / 引用变化：" + (previousRefCount >= 0 ? signedInt(ContextStats.totalRefCount - previousRefCount) : "等待对比"));
			stats.push("变化量均相对上次面板刷新");
			if (engine != null) {
				if (engine.renderer != null) {
					stats.push("位图缓存：" + enabled(engine.renderer.cacheAsBitmap) + " / 多纹理：" + enabled(engine.renderer.multiTextureEnabled));
					stats.push("高分辨率缓存：" + enabled(engine.renderer.highDpi));
				}
				stats.push("设备像素比：" + format(engine.devicePixelRatio) + " / 缩放：" + format(engine.scaleFactor));
				stats.push("舞台：" + format(engine.stageWidth) + " × " + format(engine.stageHeight));
			}
			stats.push("计数含面板；耗时为引擎计时段");
		}
		previousMemory = memory;
		previousCacheCount = ContextStats.totalCacheCount;
		previousRefCount = ContextStats.totalRefCount;

		var text = stats.join("\n");
		if (label.data != text) {
			label.data = text;
			var width = label.width + 10;
			var height = label.height + 10;
			if (__bg.width != width) __bg.width = width;
			if (__bg.height != height) __bg.height = height;
		}
	}

	private static function format(value:Float):String {
		if (!Math.isFinite(value)) return "不可用";
		var text = Std.string(Math.round(value * 10) / 10);
		return text.indexOf(".") >= 0 ? text : text + ".0";
	}

	private static function signed(value:Float):String {
		// 先舍入，避免把趋近于零的负数显示成负零。
		value = Math.round(value * 10) / 10;
		return (value > 0 ? "+" : "") + format(value);
	}

	private static function signedInt(value:Int):String {
		return (value > 0 ? "+" : "") + value;
	}

	private static function enabled(value:Bool):String {
		return value ? "开" : "关";
	}
}
