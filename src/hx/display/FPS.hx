package hx.display;

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
		this.addEventListener(Event.UPDATE, onUpdated);
	}

	private function onUpdated(e:Event) {
		this.label.data = "FPS:" + ContextStats.fps + "\ndrawCall:" + ContextStats.drawCall + "\nvertexCount:" + ContextStats.vertexCount + "\ndisplays:"
			+ ContextStats.visibleDisplayCounts + "\nCPU:" + Std.int(ContextStats.cpu * 100) + "%\nMemory:" + Std.int(ContextStats.memory / 1024 / 1024)
			+ "mb\nspineRender:" + ContextStats.spineRenderCount + "\ntimerTask:" + ContextStats.timerTaskCount;
		this.__bg.width = label.width + 10;
		this.__bg.height = label.height + 10;
		if (this.parent != null && this.parent.children[this.parent.children.length - 1] != this) {
			this.parent.addChild(this);
		}
	}
}
