package hx.display;

/**
 * 切换显示对象的容器
 */
class Stack extends Box {
	private var __stackDirty:Bool = false;

	/**
	 * 显示对象列表
	 */
	public var displayObjects:Array<DisplayObject> = [];

	/**
	 * 当前显示对象ID，对应着displayObjects中的对象name属性
	 */
	public var currentId(default, set):String;

	private function set_currentId(id:String):String {
		if (this.currentId != id) {
			this.currentId = id;
			__stackDirty = true;
		}
		return id;
	}

	/**
	 * 当前显示对象索引
	 */
	public var currentIndex(get, set):Int;

	private function get_currentIndex():Int {
		for (index => display in displayObjects) {
			if (display.name == this.currentId) {
				return index;
			}
		}
		return -1;
	}

	private function set_currentIndex(index:Int):Int {
		if (this.currentIndex != index) {
			if (displayObjects[index] != null)
				this.currentId = displayObjects[index].name;
		}
		return index;
	}

	override function __updateTransform(parent:DisplayObject) {
		if (__stackDirty) {
			__stackDirty = false;
			for (object in displayObjects) {
				if (object.name == this.currentId) {
					object.visible = true;
					superAddChildAt(object, 0);
				} else if (object.parent == this) {
					superRemoveChild(object);
				}
			}
		}
		super.__updateTransform(parent);
	}

	override public function addChildAt(child:DisplayObject, index:Int) {
		if (displayObjects.indexOf(child) == -1) {
			displayObjects.push(child);
		}
	}

	override public function removeChild(child:DisplayObject):Void {
		displayObjects.remove(child);
	}

	private function superAddChildAt(child:DisplayObject, index:Int):Void {
		super.addChildAt(child, this.children.length);
	}

	private function superRemoveChild(child:DisplayObject):Void {
		super.removeChild(child);
	}
}
