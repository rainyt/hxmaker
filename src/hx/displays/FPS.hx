package hx.displays;

import hx.utils.ContextStats;
import hx.events.Event;

class FPS extends Label {
	override function onInit() {
		super.onInit();
		this.updateEnabled = true;
		this.addEventListener(Event.UPDATE, onUpdated);
	}

	private function onUpdated(e:Event) {
		this.data = "FPS:" + ContextStats.fps + "\ndrawCall:" + ContextStats.drawCall + "\nvertexCount:" + ContextStats.vertexCount;
	}
}
