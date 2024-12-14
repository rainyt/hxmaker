package hx.displays;

/**
 * 可装载子对象的容器
 */
class DisplayObjectContainer extends DisplayObject {
	/**
	 * 该容器中的所有子对象
	 */
	@:noCompletion private var __children:Array<DisplayObject> = [];

	/**
	 * 添加到当前容器中
	 * @param child 
	 */
	public function addChild(child:DisplayObject):Void {
		this.addChildAt(child, this.__children.length);
	}

	/**
	 * 根据索引添加到当前容器中
	 * @param child 
	 * @param index 
	 */
	public function addChildAt(child:DisplayObject, index:Int):Void {
		if (index < 0) {
			index = 0;
		} else if (index > this.__children.length) {
			index = this.__children.length;
		}
		this.__children.insert(index, child);
	}
}
