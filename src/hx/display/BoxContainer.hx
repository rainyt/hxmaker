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
}
