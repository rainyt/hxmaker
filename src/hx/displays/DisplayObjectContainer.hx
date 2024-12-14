package hx.displays;

/**
 * 可装载子对象的容器
 */
@:access(hx.displays.DisplayObject)
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
		if (child.parent != null) {
			child.parent.removeChild(child);
		}
		this.__children.insert(index, child);
		child.__parent = this;
		// 追加舞台处理
		if (this.stage != null && child.stage == null) {
			child.__onAddToStage(this.stage);
		}
	}

	/**
	 * 删除显示对象
	 * @param child 
	 */
	public function removeChild(child:DisplayObject):Void {
		this.__children.remove(child);
		child.onRemoveToStage();
		child.__parent = null;
		child.__stage = null;
	}

	override function __onAddToStage(stage:Stage):Void {
		super.__onAddToStage(stage);
		for (child in this.__children) {
			child.__onAddToStage(stage);
		}
	}
}
