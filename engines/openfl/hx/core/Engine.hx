package hx.core;

import openfl.events.MouseEvent;
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
		this.render.onStageInit();
		// 鼠标事件
		__initMouseEvent();
	}

	private var __lastTime:Float = 0;

	private var __lastMouseX = 0.;

	private var __lastMouseY = 0.;

	private function __onRenderEnterFrame(e:Event):Void {
		var now = Timer.stamp();
		var dt = now - __lastTime;
		__lastTime = now;
		this.render.onUpdate(dt);
		this.render.render();
	}

	private function __initMouseEvent():Void {
		this.stage.addEventListener(MouseEvent.MOUSE_DOWN, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_UP, __onMouseEvent);
		// this.stage.addEventListener(MouseEvent.CLICK, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_WHEEL, __onMouseEvent);
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, __onMouseEvent);
	}

	private function __onMouseEvent(e:MouseEvent):Void {
		var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(e.type);
		engineEvent.stageX = this.mouseX;
		engineEvent.stageY = this.mouseY;
		render.handleMouseEvent(engineEvent);
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				__lastMouseX = this.mouseX;
				__lastMouseY = this.mouseY;
			case MouseEvent.MOUSE_UP:
				// 判断距离
				if (Math.sqrt(Math.pow(__lastMouseX - this.mouseX, 2) + Math.pow(__lastMouseY - this.mouseY, 2)) < 10) {
					var engineEvent:hx.events.MouseEvent = new hx.events.MouseEvent(hx.events.MouseEvent.CLICK);
					engineEvent.stageX = this.mouseX;
					engineEvent.stageY = this.mouseY;
					render.handleMouseEvent(engineEvent);
				}
		}
	}
}
