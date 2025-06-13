package hx.display;

/**
 * 容器箱子，该容器会有一个独立的box ，该box会包含所有的子元素
 */
class BoxContainer extends Box {
	/**
	 * 容器显示对象
	 */
	public var box:Box = new Box();

	override function onInit() {
		super.onInit();
		super.addChildAt(box, 0);
	}

	override function get_numChildren():Int {
		return box.get_numChildren();
	}

	private function superAddChildAt(display:DisplayObject, index:Int):Void {
		super.addChildAt(display, index);
	}

	override function addChild(child:DisplayObject) {
		box.addChild(child);
	}

	override function addChildAt(child:DisplayObject, index:Int) {
		box.addChildAt(child, index);
	}

	override function getChildAt(index:Int):DisplayObject {
		return box.getChildAt(index);
	}

	override function getChildByName(name:String):DisplayObject {
		return box.getChildByName(name);
	}

	override function getChildIndexAt(child:DisplayObject):Int {
		return box.getChildIndexAt(child);
	}

	override function removeChild(child:DisplayObject) {
		box.removeChild(child);
	}

	override function removeChildAt(index:Int) {
		box.removeChildAt(index);
	}

	override function removeChildren(start:Int = 0, end:Int = -1) {
		box.removeChildren(start, end);
	}

	override function get_children():Array<DisplayObject> {
		return box.children;
	}

	override function set_width(value:Float):Float {
		box.width = value;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		box.height = value;
		return super.set_height(value);
	}
}
