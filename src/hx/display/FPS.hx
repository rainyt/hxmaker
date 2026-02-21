package hx.display;

import hx.core.Hxmaker;
import hx.filters.StageBitmapData;
import hx.utils.ContextStats;
import hx.events.Event;

/**
 * 渲染着hxmaker的主要数据
 */
class FPS extends DisplayObjectContainer {
	private var __bg:Quad;

	public var label:Label;

	override function onInit() {
		super.onInit();
		this.mouseEnabled = false;
		this.updateEnabled = true;
		__bg = new Quad(0, 0, 0x0);
		__bg.alpha = 0.8;
		this.addChild(__bg);
		this.label = new Label();
		label.textFormat = new TextFormat(null, 26, 0xffffff);
		this.addChild(label);
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		// 使用数组存储统计信息，方便后续追加其他内容
		var stats:Array<String> = [
			"FPS:" + ContextStats.fps,
			"drawCall:" + ContextStats.drawCall,
			"vertexCount:" + ContextStats.vertexCount,
			"displays:" + ContextStats.visibleDisplayCounts,
			"CPU:" + Std.int(ContextStats.cpu * 100) + "%",
			"FrameDelay:" + (Std.int(ContextStats.frameUsedTime * 100000) / 100) + "ms",
			"Memory:" + Std.int(ContextStats.memory / 1024 / 1024) + "mb",
			#if webgl_memory
			"GPUMemory:" + Std.int(ContextStats.gpuMemory / 1024 / 1024) + "mb",
			#end
			"spineRender:" + ContextStats.spineRenderCount,
			"graphicRender:" + ContextStats.graphicRenderCount,
			"timerTask:" + ContextStats.timerTaskCount,
			"blendModeFilter:" + ContextStats.blendModeFilterDrawCall,
			"stageBitmapDatas:" + StageBitmapData.counts,
			"cacheAsBitmap:" + Hxmaker.engine.renderer.cacheAsBitmap,
			"devicePixelRatio:" + Hxmaker.engine.devicePixelRatio,
		];
		this.label.data = stats.join("\n");
		this.__bg.width = label.width + 10;
		this.__bg.height = label.height + 10;
		if (this.parent != null && this.parent.children[this.parent.children.length - 1] != this) {
			this.parent.addChild(this);
		}
	}
}
