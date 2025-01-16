package hx.display;

import motion.Actuate;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.events.MouseEvent;
import hx.gemo.Rectangle;

/**
 * 滚动遮罩支持的容器
 */
class Scroll extends Box {
	public var quad = new Quad();

	public var box:Box = new Box();

	override function addChildAt(child:DisplayObject, index:Int) {
		if (child == box || child == quad) {
			super.addChildAt(child, index);
		} else {
			box.addChildAt(child, index);
		}
	}

	override function addChild(child:DisplayObject) {
		if (child == box || child == quad) {
			super.addChild(child);
		} else {
			box.addChild(child);
		}
	}

	override function getChildAt(index:Int):DisplayObject {
		return box.getChildAt(index);
	}

	override function getChildIndexAt(child:DisplayObject):Int {
		return box.getChildIndexAt(child);
	}

	override function get_children():Array<DisplayObject> {
		return box.children;
	}

	override function removeChild(child:DisplayObject) {
		box.removeChild(child);
	}

	private var __scrollX:Float = 0;

	private var __scrollY:Float = 0;

	public var scrollX(get, set):Float;

	private function get_scrollX():Float {
		return this.__scrollX;
	}

	private function set_scrollX(value:Float):Float {
		this.__scrollX = value;
		this.box.x = value;
		return value;
	}

	public var scrollY(get, set):Float;

	private function get_scrollY():Float {
		return this.__scrollY;
	}

	private function set_scrollY(value:Float):Float {
		this.__scrollY = value;
		this.box.y = value;
		return value;
	}

	override function onInit() {
		super.onInit();
		this.addChild(quad);
		quad.alpha = 0;
		quad.layoutData = AnchorLayoutData.fill();
		this.addChild(box);
		this.layout = new AnchorLayout();
		// box.layoutData = AnchorLayoutData.fill();
		this.maskRect = new Rectangle(0, 0, 100, 100);
		this.width = 100;
		this.height = 100;
	}

	override function set_width(value:Float):Float {
		this.maskRect.width = value;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		this.maskRect.height = value;
		return super.set_height(value);
	}

	override function onAddToStage() {
		super.onAddToStage();
		if (!this.hasEventListener(MouseEvent.MOUSE_DOWN)) {
			this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			this.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		if (this.hasEventListener(MouseEvent.MOUSE_DOWN)) {
			this.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			this.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		}
	}

	private var startX:Float = 0;

	private var startY:Float = 0;

	private var __lastStepX:Float = 0;

	private var __lastStepY:Float = 0;

	private var __down:Bool = false;

	private function stopScroll():Void {
		Actuate.stop(this);
	}

	private function onMouseDown(e:MouseEvent) {
		this.startX = e.stageX;
		this.startY = e.stageY;
		this.__lastStepX = 0;
		this.__lastStepY = 0;
		__down = true;
		this.stopScroll();
	}

	private function onMouseUp(e:MouseEvent) {
		if (__down) {
			__down = false;
			if (__lastStepX != 0 || __lastStepY != 0) {
				var time = 0.5;
				Actuate.tween(this, time, getMoveingToData({
					scrollX: scrollX - __lastStepX / time * 4,
					scrollY: scrollY - __lastStepY / time * 4
				}));
			}
		}
	}

	private function getMoveingToData(data:{scrollX:Float, scrollY:Float}):{scrollX:Float, scrollY:Float} {
		var ret = box.getBounds();
		var maxWidth = ret.width - this.width;
		var maxHeight = ret.height - this.height;
		if (data.scrollX > 0 || maxWidth < 0) {
			data.scrollX = 0;
		} else if (data.scrollX < -maxWidth) {
			data.scrollX = -maxWidth;
		}
		if (data.scrollY > 0 || maxHeight < 0) {
			data.scrollY = 0;
		} else if (data.scrollY < -maxHeight) {
			data.scrollY = -maxHeight;
		}
		return data;
	}

	private function onMouseMove(e:MouseEvent) {
		if (!__down)
			return;

		var ret = box.getBounds();

		this.__lastStepX = this.startX - e.stageX;
		this.__lastStepY = this.startY - e.stageY;
		this.startX = e.stageX;
		this.startY = e.stageY;

		this.scrollX -= __lastStepX;
		var maxWidth = ret.width - this.width;
		if (this.scrollX > 0 || maxWidth < 0) {
			this.scrollX = 0;
			this.__lastStepX = 0;
		} else if (this.scrollX < -maxWidth) {
			this.scrollX = -maxWidth;
			this.__lastStepX = 0;
		}
		this.scrollY -= __lastStepY;
		var maxHeight = ret.height - this.height;
		if (this.scrollY > 0 || maxHeight < 0) {
			this.scrollY = 0;
			this.__lastStepY = 0;
		} else if (this.scrollY < -maxHeight) {
			this.scrollY = -maxHeight;
			this.__lastStepY = 0;
		}
	}
}
