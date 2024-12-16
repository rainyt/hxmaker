package hx.core;

import hx.utils.ScaleUtils;
import haxe.Timer;
import openfl.events.Event;
import hx.displays.Stage;
import openfl.display.Sprite;

/**
 * OpenFL引擎上的引擎
 */
@:access(hx.displays.Stage)
class Engine extends Sprite implements IEngine {
	/**
	 * 舞台对象
	 */
	public var render:Stage;

	/**
	 * 初始化引擎入口类
	 * @param mainClasses 
	 */
	public function init(mainClasses:Class<Stage>, stageWidth:Int, stageHeight:Int):Void {
		this.render = Type.createInstance(mainClasses, []);
		this.render.__render = new hx.core.Render(this);
		// 舞台尺寸计算
		var scale = ScaleUtils.mathScale(this.stage.stageWidth, this.stage.stageHeight, stageWidth, stageHeight);
		this.scaleX = this.scaleY = scale;
		render.__stageWidth = Std.int(this.stage.stageWidth / scale);
		render.__stageHeight = Std.int(this.stage.stageHeight / scale);
		trace("Stage size and scale:", render.stageWidth, render.stageHeight, scale);
		// 帧渲染事件
		this.addEventListener(Event.ENTER_FRAME, __onRenderEnterFrame);
		__lastTime = Timer.stamp();
		this.render.onInit();
	}

	private var __lastTime:Float = 0;

	private function __onRenderEnterFrame(e:Event):Void {
		var now = Timer.stamp();
		var dt = now - __lastTime;
		__lastTime = now;
		this.render.onUpdate(dt);
		@:privateAccess this.render.__updateTransform(this.render);
		this.render.render();
	}
}
