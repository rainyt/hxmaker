package hx.display;

/**
 * 切换显示对象的容器
 */
class Stack extends Box {
	private var __stackDirty:Bool = false;

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
		for (index => display in children) {
			if (display.name == this.currentId) {
				return index;
			}
		}
		return -1;
	}

	private function set_currentIndex(index:Int):Int {
		if (this.currentIndex != index) {
			if (children[index] != null)
				this.currentId = children[index].name;
		}
		return index;
	}

	override function __updateTransform(parent:DisplayObject) {
		if (__stackDirty) {
			__stackDirty = false;
			for (object in children) {
				if (object.name == this.currentId) {
					object.visible = true;
				} else {
					object.visible = false;
				}
			}
		}
		super.__updateTransform(parent);
	}
}
