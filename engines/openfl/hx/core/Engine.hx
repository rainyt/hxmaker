package hx.core;

import openfl.events.Event;
import hx.displays.Stage;
import openfl.display.Sprite;

/**
 * OpenFL引擎上的引擎
 */
@:access(hx.displays.Stage)
class Engine extends Sprite {
	/**
	 * 舞台对象
	 */
	public var render:Stage;

	/**
	 * 初始化引擎入口类
	 * @param mainClasses 
	 */
	public function init(mainClasses:Class<Stage>):Void {
		this.render = Type.createInstance(mainClasses, []);
		this.render.__render = new hx.core.Render();
		// 帧渲染事件
		this.addEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
	}

	private function __onRenderEnterFrame(e:Event):Void {
		this.render.render();
	}
}
