package hx.display;

import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.events.MouseEvent;
import hx.gemo.Rectangle;

/**
 * 滚动遮罩支持的容器
 */
class Scroll extends Box {
	public var box:Box = new Box();

	override function addChildAt(child:DisplayObject, index:Int) {
		if (child == box) {
			super.addChildAt(child, index);
		} else {
			box.addChildAt(child, index);
		}
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
		this.addChild(box);
		this.layout = new AnchorLayout();
		box.layoutData = AnchorLayoutData.fill();
		this.makeRect = new Rectangle(0, 0, 100, 100);
		this.width = 100;
		this.height = 100;
	}

	override function set_width(value:Float):Float {
		this.makeRect.width = value;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		this.makeRect.height = value;
		return super.set_height(value);
	}

	override function onAddToStage() {
		super.onAddToStage();
		this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		this.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		this.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
	}

	private var startX:Float = 0;

	private var startY:Float = 0;

	private var __nowX:Float = 0;

	private var __nowY:Float = 0;

	private var __down:Bool = false;

	private function onMouseDown(e:MouseEvent) {
		this.startX = e.stageX;
		this.startY = e.stageY;
		this.__nowX = this.scrollX;
		this.__nowY = this.scrollY;
		__down = true;
	}

	private function onMouseUp(e:MouseEvent) {
		__down = false;
	}

	private function onMouseMove(e:MouseEvent) {
		if (!__down)
			return;

		var ret = box.getBounds();

		this.scrollX = this.__nowX - (this.startX - e.stageX);
		var maxWidth = ret.width - this.width;
		if (this.scrollX < -maxWidth) {
			this.scrollX = -maxWidth;
		} else if (this.scrollX > 0) {
			this.scrollX = 0;
		}
		this.scrollY = this.__nowY - (this.startY - e.stageY);
		var maxHeight = ret.height - this.height;
		if (this.scrollY < -maxHeight) {
			this.scrollY = -maxHeight;
		} else if (this.scrollY > 0) {
			this.scrollY = 0;
		}

		trace(this.scrollX, this.scrollY);
	}
}
