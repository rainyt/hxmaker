package hx.core;

import haxe.Timer;
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
		this.render.__render = new hx.core.Render(this);
		// 帧渲染事件
		this.addEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		__lastTime = Timer.stamp();
	}

	private var __lastTime:Float = 0;

	private function __onRenderEnterFrame(e:Event):Void {
		var now = Timer.stamp();
		var dt = now - __lastTime;
		__lastTime = now;
		this.render.onUpdate(dt);
		@:privateAccess this.render.__tranform(this.render);
		this.render.render();
	}
}
