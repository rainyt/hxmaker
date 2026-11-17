package hx.display;

import hx.events.MouseEvent;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;

/**
 * 竖向滚动条
 */
class VScrollBar extends BaseScrollBar {
	public function new(?dragQuad:Dynamic, ?backage:Dynamic) {
		super();
		this.width = 6;
		this.height = 6;

		this.layout = new AnchorLayout();
		if (dragQuad == null)
			dragQuad = 0x888888;
		if (backage == null)
			backage = 0xffffff;
		if (backage != null) {
			if (backage is Int) {
				backageDisplay = new Quad(6, 6, backage);
			} else {
				backageDisplay = backage;
			}
			this.addChild(backageDisplay);
			backageDisplay.layoutData = AnchorLayoutData.fill();
		}
		if (dragQuad != null) {
			if (dragQuad is Int) {
				dragDisplay = new Quad(6, 6, dragQuad);
			} else {
				dragDisplay = dragQuad;
			}
			this.addChild(dragDisplay);
			dragDisplay.layoutData = new AnchorLayoutData(null, 1, null, 1);
			dragDisplay.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		}
	}

	private var __y = 0.;

	private function onMouseDown(e:MouseEvent) {
		__y = e.stageY;
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}

	private function onMouseMove(e:MouseEvent) {
		this.dragDisplay.y += e.stageY - __y;
		if (this.dragDisplay.y < 0) {
			this.dragDisplay.y = 0;
		} else if (this.dragDisplay.y > this.height - this.dragDisplay.height) {
			this.dragDisplay.y = this.height - this.dragDisplay.height;
		}
		__y = e.stageY;
		this.measure(true);
	}

	private function onMouseUp(e:MouseEvent) {
		removeStageListeners();
	}

	/**
	 * 销毁时也要摘掉拖拽期间挂在 stage 上的监听。
	 * 拖动中界面被关掉时 onMouseUp 不会触发，监听会把整个界面拽在内存里
	 */
	override function dispose():Void {
		removeStageListeners();
		super.dispose();
	}

	private function removeStageListeners():Void {
		var st = this.stage;
		if (st == null)
			return;
		st.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		st.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}

	override function measure(isScroll:Bool = false) {
		super.measure();
		if (this.scroll == null)
			return;
		var thumbRation = Math.min(this.scroll.height / this.scroll.contentHeight, 1);
		var thumbHeight = Math.max(thumbRation * this.scroll.box.height, 20);
		this.dragDisplay.height = thumbHeight;
		if (!isScroll) {
			this.dragDisplay.y = -this.scroll.scrollY / (this.scroll.contentHeight - this.scroll.height) * (this.height - thumbHeight);
		} else {
			this.scroll.scrollY = -this.dragDisplay.y * (this.scroll.contentHeight - this.scroll.height) / (this.height - thumbHeight);
		}
		this.visible = thumbRation < 1;
	}
}
